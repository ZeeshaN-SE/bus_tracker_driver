import 'dart:async';
import 'dart:isolate';
import 'package:dio/dio.dart';
import 'package:flutter_foreground_task/flutter_foreground_task.dart';
import 'package:geolocator/geolocator.dart';

// ─── Task Handler (runs in a separate isolate) ────────────────────────────────

class GpsTaskHandler extends TaskHandler {
  String? _tripId;
  String? _authToken;
  String? _baseUrl;
  Timer? _timer;
  SendPort? _sendPort;

  /// Adaptive update interval (seconds):
  ///   - **2 s** when the bus is moving (speed > 5 km/h) — feels real-time
  ///     to students, like WhatsApp Live Location.
  ///   - **10 s** when stationary — saves battery during stops.
  static const int _fastIntervalSec = 2;
  static const int _slowIntervalSec = 10;

  /// Speed threshold (km/h) above which we switch to fast updates.
  static const double _movingThresholdKmh = 5.0;

  /// Track current cadence so we only restart the timer when it changes.
  int _currentIntervalSec = _slowIntervalSec;

  @override
  void onStart(DateTime timestamp, SendPort? sendPort) async {
    _sendPort = sendPort;
    _tripId = await FlutterForegroundTask.getData<String>(key: 'trip_id');
    _authToken = await FlutterForegroundTask.getData<String>(key: 'auth_token');
    _baseUrl = await FlutterForegroundTask.getData<String>(key: 'base_url');

    // Send initial status to UI immediately so the banner can show "started".
    _sendPort?.send({'status': 'started'});

    // ⚡ Fire the FIRST GPS update IMMEDIATELY — don't wait for the timer
    // interval to elapse. This is what makes the student app see the bus
    // appear within seconds (instead of "waiting for first GPS update" for
    // 10 s).
    _sendLocation();

    // Then start the periodic schedule (slow → fast adapts automatically).
    _scheduleTimer(_slowIntervalSec);
  }

  @override
  void onRepeatEvent(DateTime timestamp, SendPort? sendPort) {
    // Not used — we manage our own Timer for precise interval control
  }

  @override
  void onDestroy(DateTime timestamp, SendPort? sendPort) {
    _timer?.cancel();
    _timer = null;
  }

  void _scheduleTimer(int intervalSec) {
    _currentIntervalSec = intervalSec;
    _timer?.cancel();
    _timer = Timer.periodic(
      Duration(seconds: intervalSec),
      (_) => _sendLocation(),
    );
  }

  /// If the bus speed crosses the moving threshold, switch interval cadence.
  void _maybeAdjustInterval(double speedKmh) {
    final desired = speedKmh > _movingThresholdKmh
        ? _fastIntervalSec
        : _slowIntervalSec;
    if (desired != _currentIntervalSec) {
      _scheduleTimer(desired);
    }
  }

  @override
  void onNotificationButtonPressed(String id) {
    if (id == 'end_trip') {
      _sendPort?.send({'action': 'end_trip'});
    }
  }

  @override
  void onNotificationPressed() {
    FlutterForegroundTask.launchApp();
  }

  Future<void> _sendLocation() async {
    try {
      // Defensive: make sure location services + permission are still good
      // before asking for a fix. If permission was revoked while running, the
      // call below would throw and the user would see no updates with no
      // explanation.
      final svcOn = await Geolocator.isLocationServiceEnabled();
      if (!svcOn) {
        _sendPort?.send({
          'error': 'Location services are disabled on this device.',
          'timestamp': DateTime.now().toIso8601String(),
        });
        return;
      }
      final perm = await Geolocator.checkPermission();
      if (perm == LocationPermission.denied ||
          perm == LocationPermission.deniedForever) {
        _sendPort?.send({
          'error': 'Location permission was revoked.',
          'timestamp': DateTime.now().toIso8601String(),
        });
        return;
      }

      final position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
        // Cap how long we wait for a GPS fix so the timer doesn't pile up
        // queued runs if the device is in a tunnel or indoors.
        timeLimit: const Duration(seconds: 8),
      );

      // Use a plain Dio instance inside the isolate (singleton from main isolate is not accessible)
      final dio = Dio(BaseOptions(
        baseUrl: _baseUrl ?? 'http://10.0.2.2:3000/api/',
        connectTimeout: const Duration(seconds: 10),
        receiveTimeout: const Duration(seconds: 10),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $_authToken',
        },
      ));

      // Geolocator returns speed in metres/second; backend + UI expect km/h.
      final double speedKmh =
          position.speed >= 0 ? position.speed * 3.6 : 0.0;

      final response = await dio.post('gps/location', data: {
        'trip_id': _tripId,
        'latitude': position.latitude,
        'longitude': position.longitude,
        'speed': speedKmh,
        'heading': position.heading >= 0 ? position.heading : null,
        'accuracy': position.accuracy,
      });

      // Adapt cadence based on movement so a stationary bus doesn't burn
      // battery posting the same coordinate every 2 seconds.
      _maybeAdjustInterval(speedKmh);

      // Send location data back to main isolate for UI update.
      // NB: across isolate boundaries we MUST send a Map<String, dynamic>
      // with primitive values only. We coerce types defensively so the
      // receiving side's strict cast (`data is Map<String, dynamic>`) works.
      _sendPort?.send(<String, dynamic>{
        'lat': position.latitude,
        'lng': position.longitude,
        'speed': speedKmh,
        'interval': _currentIntervalSec,
        'http_status': response.statusCode ?? 0,
        'timestamp': DateTime.now().toIso8601String(),
      });
    } on DioException catch (e) {
      // Surface backend errors so we can debug "why is GPS not getting through"
      _sendPort?.send(<String, dynamic>{
        'error':
            'Network error sending GPS: ${e.response?.statusCode ?? "no response"} — ${e.message}',
        'timestamp': DateTime.now().toIso8601String(),
      });
    } catch (e) {
      _sendPort?.send(<String, dynamic>{
        'error': 'GPS error: $e',
        'timestamp': DateTime.now().toIso8601String(),
      });
    }
  }
}

// ─── GPS Tracking Service helper (main isolate) ───────────────────────────────

class GpsTrackingService {
  GpsTrackingService._();
  static final GpsTrackingService instance = GpsTrackingService._();

  /// Initialize foreground task configuration. Call once at app start in main().
  static void initialize() {
    FlutterForegroundTask.init(
      androidNotificationOptions: AndroidNotificationOptions(
        channelId: 'gps_tracking_channel',
        channelName: 'GPS Tracking',
        channelDescription: 'Used for live GPS tracking during an active trip.',
        channelImportance: NotificationChannelImportance.LOW,
        priority: NotificationPriority.LOW,
        iconData: const NotificationIconData(
          resType: ResourceType.mipmap,
          resPrefix: ResourcePrefix.ic,
          name: 'launcher',
        ),
        buttons: [
          const NotificationButton(id: 'end_trip', text: 'End Trip'),
        ],
      ),
      iosNotificationOptions: const IOSNotificationOptions(
        showNotification: true,
        playSound: false,
      ),
      foregroundTaskOptions: const ForegroundTaskOptions(
        interval: 15000, // onRepeatEvent interval (not used for GPS — we use Timer)
        isOnceEvent: false,
        autoRunOnBoot: false,
        allowWakeLock: true,
        allowWifiLock: true,
      ),
    );
  }

  /// Start GPS tracking for the given trip.
  /// [taskCallback] must be the top-level `startCallback` function defined in main.dart.
  Future<bool> startTracking({
    required String tripId,
    required String authToken,
    required String baseUrl,
    required Function taskCallback,
  }) async {
    await FlutterForegroundTask.saveData(key: 'trip_id', value: tripId);
    await FlutterForegroundTask.saveData(key: 'auth_token', value: authToken);
    await FlutterForegroundTask.saveData(key: 'base_url', value: baseUrl);

    if (await FlutterForegroundTask.isRunningService) {
      return FlutterForegroundTask.restartService();
    } else {
      return FlutterForegroundTask.startService(
        notificationTitle: 'Trip in Progress',
        notificationText: 'GPS tracking is active',
        callback: taskCallback,
      );
    }
  }

  /// Stop GPS tracking.
  Future<bool> stopTracking() async {
    return FlutterForegroundTask.stopService();
  }

  /// Whether the tracking service is currently running.
  Future<bool> isTracking() async {
    return FlutterForegroundTask.isRunningService;
  }
}
