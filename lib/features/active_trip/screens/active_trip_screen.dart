import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_foreground_task/flutter_foreground_task.dart';
import 'package:geolocator/geolocator.dart';
import '../../../core/network/api_service.dart';
import '../../../core/network/dio_client.dart';
import '../../../core/storage/token_storage.dart';
import '../../../core/constants/api_constants.dart';
import '../../dashboard/models/trip.dart';
import '../../dashboard/screens/dashboard_screen.dart';
import '../services/gps_tracking_service.dart';
import '../../../main.dart' show startCallback;
import '../../scan/screens/scan_qr_screen.dart';

class ActiveTripScreen extends StatefulWidget {
  final Trip trip;

  const ActiveTripScreen({super.key, required this.trip});

  @override
  State<ActiveTripScreen> createState() => _ActiveTripScreenState();
}

class _ActiveTripScreenState extends State<ActiveTripScreen> {
  StreamSubscription? _taskDataSubscription;
  StreamSubscription<Position>? _positionSub;
  Timer? _elapsedTimer;
  Timer? _gpsPostTimer;
  Position? _lastPosition;
  double? _lastLat;
  double? _lastLng;
  String? _lastUpdateTime;
  DateTime? _lastUpdateAt;
  int? _currentIntervalSec;
  bool _isTracking = false;
  bool _isEndingTrip = false;

  /// Status text shown under "GPS Status" — kept fresh as we move through the
  /// startup sequence so the driver always sees what's happening.
  String _gpsStatusText = 'Initializing GPS...';

  /// When the tracking session started (used for the elapsed-time banner).
  late final DateTime _sessionStart;
  Duration _elapsed = Duration.zero;

  @override
  void initState() {
    super.initState();
    _sessionStart = DateTime.now();
    // Start GPS tracking in the MAIN isolate (reliable, no IPC issues).
    // Also start the foreground service in parallel so the OS keeps the app
    // alive when the screen is off, but the UI does not depend on it.
    _startMainIsolateTracking();
    _startBackgroundService();
    _listenToTaskData();
    // Tick the "Sharing live • 00:01:23" banner every second.
    _elapsedTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      setState(() {
        _elapsed = DateTime.now().difference(_sessionStart);
      });
    });
  }

  String _formatElapsed(Duration d) {
    final h = d.inHours.toString().padLeft(2, '0');
    final m = (d.inMinutes % 60).toString().padLeft(2, '0');
    final s = (d.inSeconds % 60).toString().padLeft(2, '0');
    return '$h:$m:$s';
  }

  /// Start the foreground service so Android keeps the app alive when the
  /// screen is locked. The service may *also* try to send GPS, but the UI
  /// does NOT depend on it — see `_startMainIsolateTracking`.
  Future<void> _startBackgroundService() async {
    try {
      final token = await TokenStorage.instance.getToken();
      if (token == null) return;
      await GpsTrackingService.instance.startTracking(
        tripId: widget.trip.id,
        authToken: token,
        baseUrl: ApiConstants.baseUrl,
        taskCallback: startCallback,
      );
    } catch (e) {
      debugPrint('Foreground service failed (non-fatal): $e');
    }
  }

  /// Robust GPS tracking that runs in the MAIN ISOLATE. This is the source of
  /// truth for the UI — no IPC, no isolate boundaries, no message-passing
  /// type quirks. Uses `Geolocator.getPositionStream` for change-driven
  /// updates plus a periodic timer as a heartbeat.
  Future<void> _startMainIsolateTracking() async {
    setState(() => _gpsStatusText = 'Checking permissions...');

    // 1. Verify location services + permission
    final svc = await Geolocator.isLocationServiceEnabled();
    if (!svc) {
      _setError('Turn on Location Services in your phone settings.');
      return;
    }
    var perm = await Geolocator.checkPermission();
    if (perm == LocationPermission.denied) {
      perm = await Geolocator.requestPermission();
    }
    if (perm == LocationPermission.denied ||
        perm == LocationPermission.deniedForever) {
      _setError('Location permission denied. Grant it in Settings.');
      return;
    }

    setState(() => _gpsStatusText = 'Acquiring first GPS fix...');

    // 2. Get a one-shot fix immediately so we don't wait for the stream.
    try {
      final first = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
        timeLimit: const Duration(seconds: 12),
      );
      _onNewPosition(first);
      await _postGps(first);
    } catch (e) {
      // Don't bail — the stream below may still produce a fix later.
      debugPrint('First fix failed: $e — relying on stream.');
    }

    // 3. Subscribe to the position stream — fires whenever the device moves
    //    more than 5 metres OR when a new high-accuracy fix arrives.
    _positionSub = Geolocator.getPositionStream(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: 5,
      ),
    ).listen(
      (pos) {
        _onNewPosition(pos);
        // Stream events are change-driven; we don't post on every event to
        // avoid hammering the backend. The periodic timer below handles
        // upload cadence.
      },
      onError: (err) {
        debugPrint('Position stream error: $err');
      },
    );

    // 4. Periodic upload heartbeat — guarantees the backend hears from us
    //    every 3 s while moving, even if the position stream doesn't fire
    //    (parked, indoors, weak GPS).
    _gpsPostTimer = Timer.periodic(const Duration(seconds: 3), (_) async {
      final pos = _lastPosition;
      if (pos == null) return;
      await _postGps(pos);
    });
  }

  void _onNewPosition(Position pos) {
    if (!mounted) return;
    setState(() {
      _lastPosition = pos;
      _lastLat = pos.latitude;
      _lastLng = pos.longitude;
      _lastUpdateAt = DateTime.now();
      _lastUpdateTime = _formatTimestamp(DateTime.now().toIso8601String());
      _isTracking = true;
      _gpsStatusText = 'GPS active • streaming';
    });
  }

  /// POST a single GPS coordinate to the backend. Uses the SAME `dioClient`
  /// instance the rest of the app uses, so it picks up the JWT interceptor
  /// automatically.
  Future<void> _postGps(Position pos) async {
    try {
      final speedKmh = pos.speed >= 0 ? pos.speed * 3.6 : 0.0;
      final response = await DioClient().dio.post('gps/location', data: {
        'trip_id': widget.trip.id,
        'latitude': pos.latitude,
        'longitude': pos.longitude,
        'speed': speedKmh,
        'heading': pos.heading >= 0 ? pos.heading : null,
        'accuracy': pos.accuracy,
      });
      if (mounted && response.statusCode == 200) {
        setState(() {
          _gpsStatusText =
              'GPS active • last upload OK (${pos.latitude.toStringAsFixed(5)}, ${pos.longitude.toStringAsFixed(5)})';
        });
      } else if (mounted) {
        setState(() {
          _gpsStatusText =
              'Backend returned status ${response.statusCode} — check trip status';
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _gpsStatusText = 'Upload error: $e';
        });
      }
      debugPrint('GPS POST failed: $e');
    }
  }

  void _setError(String msg) {
    if (!mounted) return;
    setState(() {
      _gpsStatusText = msg;
      _isTracking = false;
    });
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor: Colors.red,
        duration: const Duration(seconds: 5),
      ),
    );
  }

  void _listenToTaskData() {
    _taskDataSubscription =
        FlutterForegroundTask.receivePort?.listen((raw) {
      if (!mounted) return;
      // Messages from the foreground-task isolate arrive as `Map<dynamic,
      // dynamic>` — NOT `Map<String, dynamic>` — even though the sender
      // builds `<String, dynamic>{}`. The strict cast silently dropped
      // every event, which is why "Waiting for first GPS update" never
      // changed. Normalise the map first.
      if (raw is! Map) return;
      final data = Map<String, dynamic>.from(raw);

      // Handle "End Trip" button pressed from notification
      if (data['action'] == 'end_trip') {
        _showEndTripDialog();
        return;
      }

      // Surface error messages from the GPS isolate so the driver can see
      // why updates aren't flowing (permission revoked, network error, etc.)
      if (data['error'] != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(data['error'].toString()),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 4),
          ),
        );
        return;
      }

      // Handle location update
      if (data['lat'] != null) {
        setState(() {
          _lastLat = (data['lat'] as num).toDouble();
          _lastLng = (data['lng'] as num).toDouble();
          _lastUpdateTime = _formatTimestamp(data['timestamp'] as String?);
          _lastUpdateAt = DateTime.now();
          _currentIntervalSec = (data['interval'] as num?)?.toInt();
          _isTracking = true;
        });
      }
    });
  }

  String _formatTimestamp(String? iso) {
    if (iso == null) return 'just now';
    try {
      final dt = DateTime.parse(iso).toLocal();
      final hour = dt.hour.toString().padLeft(2, '0');
      final min = dt.minute.toString().padLeft(2, '0');
      final sec = dt.second.toString().padLeft(2, '0');
      return '$hour:$min:$sec';
    } catch (_) {
      return 'just now';
    }
  }

  Future<bool> _onWillPop() async {
    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Trip is Active'),
        content: const Text(
          'Trip is currently in progress. Do you want to end the trip before leaving?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Stay'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('End Trip'),
          ),
        ],
      ),
    );
    if (result == true) {
      await _endTrip();
    }
    return false; // We handle navigation ourselves
  }

  Future<void> _showEndTripDialog() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('End Trip'),
        content: const Text('Are you sure you want to end this trip?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('End Trip'),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      await _endTrip();
    }
  }

  Future<void> _endTrip() async {
    if (_isEndingTrip) return;
    setState(() => _isEndingTrip = true);

    // Stop GPS service first
    await GpsTrackingService.instance.stopTracking();

    // Call end trip API
    final response = await ApiService.instance.endTrip(widget.trip.id);

    if (!mounted) return;

    if (response.success) {
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (_) => const DashboardScreen()),
        (route) => false,
      );
    } else {
      // Restart tracking if end trip failed (rebuild background service +
      // re-arm the main-isolate stream).
      await _startBackgroundService();
      await _startMainIsolateTracking();
      if (!mounted) return;
      setState(() => _isEndingTrip = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(response.error?.message ?? 'Failed to end trip. Please try again.'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  void dispose() {
    _taskDataSubscription?.cancel();
    _positionSub?.cancel();
    _gpsPostTimer?.cancel();
    _elapsedTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final routeName = widget.trip.route?.name ?? 'Unknown Route';
    final routeCode = widget.trip.route?.code ?? '—';
    final busNumber = widget.trip.bus?.busNumber ?? 'Unknown Bus';
    final startTime = _formatTimestamp(widget.trip.actualStartTime ?? widget.trip.scheduledStartTime);

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) async {
        if (!didPop) {
          await _onWillPop();
        }
      },
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Active Trip'),
          automaticallyImplyLeading: false,
        ),
        body: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // ─── WhatsApp-style "Sharing Live Location" banner ──────────
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Colors.green.shade600, Colors.green.shade400],
                    begin: Alignment.centerLeft,
                    end: Alignment.centerRight,
                  ),
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.green.withValues(alpha: 0.3),
                      blurRadius: 6,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    // Pulsing dot
                    _PulsingDot(active: _isTracking),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Sharing Live Location',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 15,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'Elapsed ${_formatElapsed(_elapsed)}'
                            '${_currentIntervalSec != null ? " • every ${_currentIntervalSec}s" : ""}',
                            style: const TextStyle(
                              color: Colors.white70,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                    TextButton(
                      style: TextButton.styleFrom(
                        backgroundColor: Colors.white,
                        foregroundColor: Colors.green.shade700,
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 6),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      onPressed: _isEndingTrip ? null : _showEndTripDialog,
                      child: const Text(
                        'STOP',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 13,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              // Trip Info Card
              Card(
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
                elevation: 2,
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Trip Information',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Colors.grey,
                        ),
                      ),
                      const SizedBox(height: 12),
                      _infoRow(Icons.route, 'Route', '$routeName ($routeCode)'),
                      const SizedBox(height: 8),
                      _infoRow(Icons.directions_bus, 'Bus', busNumber),
                      const SizedBox(height: 8),
                      _infoRow(Icons.access_time, 'Started', startTime),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // GPS Status Card
              Card(
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
                elevation: 2,
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'GPS Status',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Colors.grey,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Container(
                            width: 12,
                            height: 12,
                            decoration: BoxDecoration(
                              color: _isTracking ? Colors.green : Colors.orange,
                              shape: BoxShape.circle,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            _isTracking ? 'GPS Active' : 'GPS Starting...',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              color: _isTracking ? Colors.green : Colors.orange,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      if (_lastUpdateTime != null)
                        _infoRow(Icons.update, 'Last Update', _lastUpdateTime!),
                      if (_lastLat != null && _lastLng != null) ...[
                        const SizedBox(height: 8),
                        _infoRow(
                          Icons.location_on,
                          'Location',
                          '${_lastLat!.toStringAsFixed(6)}, ${_lastLng!.toStringAsFixed(6)}',
                        ),
                      ],
                      const SizedBox(height: 8),
                      // Live diagnostic line — surfaces what's happening so the
                      // driver isn't left guessing if updates aren't flowing.
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Colors.grey[100],
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.info_outline,
                                size: 14, color: Colors.grey),
                            const SizedBox(width: 6),
                            Expanded(
                              child: Text(
                                _gpsStatusText,
                                style: TextStyle(
                                  color: Colors.grey[800],
                                  fontSize: 12,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 24),

              // GPS update info
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.blue[50],
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: Colors.blue[200]!),
                ),
                child: Row(
                  children: [
                    Icon(Icons.info_outline, color: Colors.blue[700], size: 18),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'GPS location is being sent every 10 seconds. '
                        'The service continues in the background.',
                        style: TextStyle(color: Colors.blue[700], fontSize: 13),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              // Scan Pass Button (Phase 8)
              SizedBox(
                height: 56,
                child: ElevatedButton.icon(
                  onPressed: _isEndingTrip
                      ? null
                      : () {
                          Navigator.of(context).push(
                            MaterialPageRoute(
                              settings: const RouteSettings(name: '/scan_qr'),
                              builder: (_) =>
                                  ScanQrScreen(tripId: widget.trip.id),
                            ),
                          );
                        },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Theme.of(context).colorScheme.primary,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  icon: const Icon(Icons.qr_code_scanner),
                  label: const Text(
                    'Scan Student Pass',
                    style: TextStyle(
                        fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                ),
              ),
              const SizedBox(height: 12),

              // End Trip Button
              SizedBox(
                height: 56,
                child: ElevatedButton.icon(
                  onPressed: _isEndingTrip ? null : _showEndTripDialog,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.red,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  icon: _isEndingTrip
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: Colors.white),
                        )
                      : const Icon(Icons.stop_circle_outlined),
                  label: Text(
                    _isEndingTrip ? 'Ending Trip...' : 'End Trip',
                    style: const TextStyle(
                        fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Pulsing-green-dot widget used in the live-sharing banner — purely cosmetic
  /// indicator that location updates are flowing.
  // (defined as a top-level private widget below)

  Widget _infoRow(IconData icon, String label, String value) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 18, color: Colors.grey[600]),
        const SizedBox(width: 8),
        Text(
          '$label: ',
          style: TextStyle(
            fontSize: 14,
            color: Colors.grey[600],
            fontWeight: FontWeight.w500,
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
          ),
        ),
      ],
    );
  }
}

/// A pulsing white dot used in the live-sharing banner. The dot expands and
/// fades to give a subtle visual cue that location updates are flowing.
class _PulsingDot extends StatefulWidget {
  final bool active;
  const _PulsingDot({required this.active});

  @override
  State<_PulsingDot> createState() => _PulsingDotState();
}

class _PulsingDotState extends State<_PulsingDot>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 18,
      height: 18,
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Outer pulsing halo
          if (widget.active)
            AnimatedBuilder(
              animation: _controller,
              builder: (_, __) {
                final t = _controller.value;
                return Container(
                  width: 18 * (0.6 + 0.4 * t),
                  height: 18 * (0.6 + 0.4 * t),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.white.withValues(alpha: (1 - t) * 0.6),
                  ),
                );
              },
            ),
          // Inner solid dot
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(
              color: widget.active ? Colors.white : Colors.white54,
              shape: BoxShape.circle,
            ),
          ),
        ],
      ),
    );
  }
}
