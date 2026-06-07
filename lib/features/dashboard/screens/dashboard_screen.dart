import 'package:flutter/material.dart';

import '../../active_trip/screens/live_start_screen.dart';
import 'package:geolocator/geolocator.dart';
import '../../../core/network/api_service.dart';
import '../../../core/storage/token_storage.dart';
import '../models/trip.dart';
import '../../auth/screens/login_screen.dart';
import '../../active_trip/screens/active_trip_screen.dart';
import '../../scan/screens/scan_qr_screen.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  List<Trip> _allTrips = [];
  List<Trip> _filteredTrips = [];
  bool _isLoading = true;
  String? _error;
  String _selectedFilter = 'All';

  final List<String> _filters = ['All', 'Today', 'Scheduled', 'In Progress'];

  @override
  void initState() {
    super.initState();
    _loadTrips();
  }

  Future<void> _loadTrips() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    final response = await ApiService.instance.getMyTrips();

    if (!mounted) return;

    if (response.success && response.data != null) {
      setState(() {
        _allTrips = response.data!;
        _isLoading = false;
        _applyFilter(_selectedFilter);
      });
    } else {
      setState(() {
        _error = response.error?.message ?? 'Failed to load trips.';
        _isLoading = false;
      });
    }
  }

  void _applyFilter(String filter) {
    setState(() {
      _selectedFilter = filter;
      switch (filter) {
        case 'Today':
          final today = DateTime.now();
          _filteredTrips = _allTrips.where((t) {
            final timeStr = t.scheduledStartTime ?? t.actualStartTime;
            if (timeStr == null) return false;
            try {
              final time = DateTime.parse(timeStr).toLocal();
              return time.year == today.year &&
                  time.month == today.month &&
                  time.day == today.day;
            } catch (_) {
              return false;
            }
          }).toList();
          break;
        case 'Scheduled':
          _filteredTrips =
              _allTrips.where((t) => t.status == 'scheduled').toList();
          break;
        case 'In Progress':
          _filteredTrips =
              _allTrips.where((t) => t.status == 'in_progress').toList();
          break;
        default:
          _filteredTrips = List.from(_allTrips);
      }
    });
  }

  Future<void> _logout() async {
    await ApiService.instance.logout();
    await TokenStorage.instance.clearAll();
    if (!mounted) return;
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (_) => const LoginScreen()),
      (route) => false,
    );
  }

  Future<void> _startTrip(Trip trip) async {
    // 1. Check location permission
    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }

    if (!mounted) return;

    if (permission == LocationPermission.denied ||
        permission == LocationPermission.deniedForever) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Location permission required to start a trip.'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    // Show loading
    if (!mounted) return;
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(child: CircularProgressIndicator()),
    );

    // 2. Call startTrip API
    final response = await ApiService.instance.startTrip(trip.id);

    if (!mounted) return;
    Navigator.pop(context); // dismiss loading

    if (response.success && response.data != null) {
      // 3. Navigate to ActiveTripScreen
      await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => ActiveTripScreen(trip: response.data!),
        ),
      );
      // Refresh on return
      _loadTrips();
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(response.error?.message ?? 'Failed to start trip.'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  void _resumeTrip(Trip trip) async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ActiveTripScreen(trip: trip),
      ),
    );
    _loadTrips();
  }

  /// WhatsApp-style one-tap entry point: open the live-start picker.
  Future<void> _openLiveStart() async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const LiveStartScreen()),
    );
    // Refresh the trip list when the driver returns (a new live trip may now
    // be in `in_progress` state).
    _loadTrips();
  }

  Future<void> _openScanPass() async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        settings: const RouteSettings(name: '/scan_qr'),
        builder: (_) => const ScanQrScreen(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('My Trips'),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            tooltip: 'Logout',
            onPressed: _logout,
          ),
        ],
      ),
      body: Column(
        children: [
          // Big "Start Live Location" call-to-action — the WhatsApp-style
          // one-tap entry point. Always visible at the top of the dashboard.
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 4),
            child: Row(
              children: [
                Expanded(
                  child: SizedBox(
                    height: 56,
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      onPressed: _openLiveStart,
                      icon: const Icon(Icons.share_location, size: 26),
                      label: const Text(
                        'Start Live Location',
                        style: TextStyle(
                            fontSize: 16, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: SizedBox(
                    height: 56,
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.blueGrey[700],
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      onPressed: _openScanPass,
                      icon: const Icon(Icons.qr_code_scanner, size: 26),
                      label: const Text(
                        'Scan Pass',
                        style: TextStyle(
                            fontSize: 16, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          // Filter chips
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: _filters.map((f) {
                  final selected = _selectedFilter == f;
                  return Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: FilterChip(
                      label: Text(f),
                      selected: selected,
                      onSelected: (_) => _applyFilter(f),
                      selectedColor:
                          Theme.of(context).colorScheme.primary.withValues(alpha: 0.2),
                      checkmarkColor: Theme.of(context).colorScheme.primary,
                    ),
                  );
                }).toList(),
              ),
            ),
          ),
          // Content
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _error != null
                    ? _buildError()
                    : _filteredTrips.isEmpty
                        ? _buildEmpty()
                        : RefreshIndicator(
                            onRefresh: _loadTrips,
                            child: ListView.builder(
                              padding: const EdgeInsets.all(12),
                              itemCount: _filteredTrips.length,
                              itemBuilder: (_, i) => _TripCard(
                                trip: _filteredTrips[i],
                                onStart: () => _startTrip(_filteredTrips[i]),
                                onResume: () => _resumeTrip(_filteredTrips[i]),
                              ),
                            ),
                          ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _loadTrips,
        tooltip: 'Refresh',
        child: const Icon(Icons.refresh),
      ),
    );
  }

  Widget _buildError() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, size: 48, color: Colors.red),
            const SizedBox(height: 16),
            Text(
              _error!,
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.red),
            ),
            const SizedBox(height: 16),
            ElevatedButton(onPressed: _loadTrips, child: const Text('Retry')),
          ],
        ),
      ),
    );
  }

  Widget _buildEmpty() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.directions_bus_outlined,
              size: 64, color: Colors.grey[400]),
          const SizedBox(height: 16),
          Text(
            'No trips assigned',
            style: TextStyle(fontSize: 18, color: Colors.grey[600]),
          ),
          const SizedBox(height: 8),
          Text(
            'Pull down to refresh',
            style: TextStyle(fontSize: 14, color: Colors.grey[400]),
          ),
        ],
      ),
    );
  }
}

// ─── Trip Card Widget ─────────────────────────────────────────────────────────

class _TripCard extends StatelessWidget {
  final Trip trip;
  final VoidCallback onStart;
  final VoidCallback onResume;

  const _TripCard({
    required this.trip,
    required this.onStart,
    required this.onResume,
  });

  Color _statusColor(String status) {
    switch (status) {
      case 'scheduled':
        return Colors.blue;
      case 'in_progress':
        return Colors.green;
      case 'completed':
        return Colors.grey;
      case 'cancelled':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  String _statusLabel(String status) {
    switch (status) {
      case 'scheduled':
        return 'Scheduled';
      case 'in_progress':
        return 'In Progress';
      case 'completed':
        return 'Completed';
      case 'cancelled':
        return 'Cancelled';
      default:
        return status;
    }
  }

  String _formatTime(String? timeStr) {
    if (timeStr == null) return 'N/A';
    try {
      final dt = DateTime.parse(timeStr).toLocal();
      final hour = dt.hour.toString().padLeft(2, '0');
      final min = dt.minute.toString().padLeft(2, '0');
      final day = dt.day.toString().padLeft(2, '0');
      final month = dt.month.toString().padLeft(2, '0');
      return '$day/$month ${dt.year} $hour:$min';
    } catch (_) {
      return timeStr;
    }
  }

  @override
  Widget build(BuildContext context) {
    final routeName = trip.route?.name ?? 'Unknown Route';
    final routeCode = trip.route?.code ?? '—';
    final busNumber = trip.bus?.busNumber ?? 'Unknown Bus';
    final scheduledTime = _formatTime(trip.scheduledStartTime);

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Route info + status chip
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        routeName,
                        style: const TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Route: $routeCode',
                        style: TextStyle(
                          fontSize: 13,
                          color: Colors.grey[600],
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: _statusColor(trip.status).withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: _statusColor(trip.status)),
                  ),
                  child: Text(
                    _statusLabel(trip.status),
                    style: TextStyle(
                      color: _statusColor(trip.status),
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            const Divider(height: 1),
            const SizedBox(height: 12),
            // Bus & time info
            Row(
              children: [
                const Icon(Icons.directions_bus, size: 16, color: Colors.grey),
                const SizedBox(width: 6),
                Text(
                  'Bus: $busNumber',
                  style: const TextStyle(fontSize: 14),
                ),
                const SizedBox(width: 16),
                const Icon(Icons.schedule, size: 16, color: Colors.grey),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    scheduledTime,
                    style: const TextStyle(fontSize: 14),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            // Action button
            if (trip.status == 'scheduled') ...[
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: onStart,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green[600],
                    foregroundColor: Colors.white,
                  ),
                  icon: const Icon(Icons.play_arrow),
                  label: const Text('Start Trip'),
                ),
              ),
            ] else if (trip.status == 'in_progress') ...[
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: onResume,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.orange[700],
                    foregroundColor: Colors.white,
                  ),
                  icon: const Icon(Icons.navigation),
                  label: const Text('Resume'),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
