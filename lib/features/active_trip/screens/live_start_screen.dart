import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';

import '../../../core/network/api_service.dart';
import '../../dashboard/models/trip.dart';
import 'active_trip_screen.dart';

/// WhatsApp-style "Start Live Location" picker.
///
/// The driver chooses **bus + route** from dropdowns, taps the big green
/// button, and live tracking begins immediately. Mirrors the WhatsApp Live
/// Location flow: one screen, two pickers, one tap.
class LiveStartScreen extends StatefulWidget {
  const LiveStartScreen({super.key});

  @override
  State<LiveStartScreen> createState() => _LiveStartScreenState();
}

class _LiveStartScreenState extends State<LiveStartScreen> {
  final _api = ApiService.instance;

  bool _loading = true;
  bool _starting = false;
  String? _error;

  List<Map<String, dynamic>> _buses = [];
  List<Map<String, dynamic>> _routes = [];

  String? _selectedBusId;
  String? _selectedRouteId;

  @override
  void initState() {
    super.initState();
    _loadPickers();
  }

  Future<void> _loadPickers() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    final busesFuture = _api.getBuses();
    final routesFuture = _api.getRoutes();

    final busesResp = await busesFuture;
    final routesResp = await routesFuture;

    if (!mounted) return;

    if (!busesResp.success || !routesResp.success) {
      setState(() {
        _loading = false;
        _error = busesResp.error?.message ??
            routesResp.error?.message ??
            'Failed to load buses or routes';
      });
      return;
    }

    setState(() {
      _buses = busesResp.data ?? [];
      _routes = routesResp.data ?? [];
      _loading = false;
      // Auto-select if there's only one option each.
      if (_buses.length == 1) _selectedBusId = _buses.first['id'] as String?;
      if (_routes.length == 1) {
        _selectedRouteId = _routes.first['id'] as String?;
      }
    });
  }

  Future<void> _startLive() async {
    if (_selectedBusId == null || _selectedRouteId == null) return;

    // 1. Permission check
    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }
    if (!mounted) return;
    if (permission == LocationPermission.denied ||
        permission == LocationPermission.deniedForever) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
              'Location permission required to share live location.'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    // 2. Quick-start the trip on the backend.
    setState(() => _starting = true);

    final response = await _api.quickStartTrip(
      busId: _selectedBusId!,
      routeId: _selectedRouteId!,
    );

    if (!mounted) return;
    setState(() => _starting = false);

    if (!response.success || response.data == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content:
              Text(response.error?.message ?? 'Failed to start live tracking.'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    // 3. Navigate to the live tracking screen — GPS service will fire up there.
    await Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (_) => ActiveTripScreen(trip: response.data!),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Start Live Location'),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? _buildError()
              : _buildForm(),
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
            const SizedBox(height: 12),
            Text(_error!, textAlign: TextAlign.center),
            const SizedBox(height: 16),
            ElevatedButton(
                onPressed: _loadPickers, child: const Text('Retry')),
          ],
        ),
      ),
    );
  }

  Widget _buildForm() {
    final canStart = _selectedBusId != null && _selectedRouteId != null;

    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Hero banner explaining the flow
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.green[50],
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.green[200]!),
            ),
            child: Row(
              children: [
                const Icon(Icons.share_location,
                    color: Colors.green, size: 32),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: const [
                      Text(
                        'Live Location Sharing',
                        style: TextStyle(
                            fontWeight: FontWeight.bold, fontSize: 16),
                      ),
                      SizedBox(height: 4),
                      Text(
                        'Students will see your bus position in real time, '
                        'just like WhatsApp Live Location.',
                        style: TextStyle(fontSize: 13, color: Colors.black87),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // Bus dropdown
          const Text('Bus',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
          const SizedBox(height: 8),
          DropdownButtonFormField<String>(
            value: _selectedBusId,
            isExpanded: true,
            decoration: const InputDecoration(
              prefixIcon: Icon(Icons.directions_bus),
              border: OutlineInputBorder(),
              hintText: 'Select your bus',
            ),
            items: _buses
                .map((b) => DropdownMenuItem<String>(
                      value: b['id'] as String?,
                      child: Text(
                        '${b['bus_number'] ?? '?'}'
                        '${b['model'] != null ? ' · ${b['model']}' : ''}',
                      ),
                    ))
                .toList(),
            onChanged: _starting
                ? null
                : (v) => setState(() => _selectedBusId = v),
          ),
          const SizedBox(height: 20),

          // Route dropdown
          const Text('Route',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
          const SizedBox(height: 8),
          DropdownButtonFormField<String>(
            value: _selectedRouteId,
            isExpanded: true,
            decoration: const InputDecoration(
              prefixIcon: Icon(Icons.alt_route),
              border: OutlineInputBorder(),
              hintText: 'Select the route you will drive',
            ),
            items: _routes
                .map((r) => DropdownMenuItem<String>(
                      value: r['id'] as String?,
                      child: Text(
                        '${r['route_name'] ?? r['route_code'] ?? 'Route'}',
                        overflow: TextOverflow.ellipsis,
                      ),
                    ))
                .toList(),
            onChanged: _starting
                ? null
                : (v) => setState(() => _selectedRouteId = v),
          ),

          const Spacer(),

          // Start button
          SizedBox(
            height: 56,
            child: ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              onPressed: canStart && !_starting ? _startLive : null,
              icon: _starting
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                          color: Colors.white, strokeWidth: 2),
                    )
                  : const Icon(Icons.play_circle_fill, size: 28),
              label: Text(
                _starting ? 'Starting…' : 'Start Live Location',
                style: const TextStyle(
                    fontSize: 17, fontWeight: FontWeight.bold),
              ),
            ),
          ),
          const SizedBox(height: 12),
          const Text(
            'Background tracking will run via a foreground notification. '
            'Tap "End Trip" anywhere to stop sharing.',
            style: TextStyle(fontSize: 12, color: Colors.black54),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 12),
        ],
      ),
    );
  }
}
