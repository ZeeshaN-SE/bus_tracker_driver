import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:geolocator/geolocator.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:permission_handler/permission_handler.dart';

import '../../../core/network/api_service.dart';
import '../models/validation_result.dart';
import 'scan_result_screen.dart';

/// Live camera-based QR scanner for the driver. After detecting a QR code, it
/// calls the backend `/api/passes/validate` endpoint and pushes [ScanResultScreen].
///
/// Notes:
/// - We pause the camera while a network call is in-flight to avoid duplicate scans.
/// - On result, we navigate (not replace) so the user can pop back to scan another.
class ScanQrScreen extends StatefulWidget {
  final String tripId;

  const ScanQrScreen({super.key, required this.tripId});

  @override
  State<ScanQrScreen> createState() => _ScanQrScreenState();
}

class _ScanQrScreenState extends State<ScanQrScreen> {
  final MobileScannerController _controller = MobileScannerController(
    detectionSpeed: DetectionSpeed.normal,
    facing: CameraFacing.back,
  );

  bool _processing = false;
  bool _torchOn = false;
  String? _permissionError;

  @override
  void initState() {
    super.initState();
    _ensureCameraPermission();
  }

  Future<void> _ensureCameraPermission() async {
    final status = await Permission.camera.request();
    if (!mounted) return;
    if (!status.isGranted) {
      setState(() {
        _permissionError =
            'Camera permission is required to scan student passes.';
      });
    }
  }

  Future<void> _onDetect(BarcodeCapture capture) async {
    if (_processing) return;
    final code = capture.barcodes.isNotEmpty
        ? capture.barcodes.first.rawValue
        : null;
    if (code == null || code.isEmpty) return;

    setState(() => _processing = true);
    await _controller.stop();
    HapticFeedback.mediumImpact();

    // Best-effort: include current location with the validation (non-blocking on failure).
    double? lat;
    double? lng;
    try {
      final pos = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.medium,
        timeLimit: const Duration(seconds: 4),
      );
      lat = pos.latitude;
      lng = pos.longitude;
    } catch (_) {
      // Location is optional — proceed without it.
    }

    final response = await ApiService().validatePass(
      qrCode: code,
      tripId: widget.tripId,
      latitude: lat,
      longitude: lng,
    );

    if (!mounted) return;

    if (!response.success || response.data == null) {
      // Server error / network error — show as a recoverable error.
      await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => ScanResultScreen(
            errorMessage:
                response.error?.message ?? 'Failed to validate pass.',
          ),
        ),
      );
    } else {
      await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => ScanResultScreen(result: response.data),
        ),
      );
    }

    // Resume scanning when user returns.
    if (mounted) {
      setState(() => _processing = false);
      await _controller.start();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: const Text('Scan Pass'),
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            tooltip: _torchOn ? 'Turn flash off' : 'Turn flash on',
            icon: Icon(_torchOn ? Icons.flash_on : Icons.flash_off),
            onPressed: () async {
              await _controller.toggleTorch();
              if (mounted) setState(() => _torchOn = !_torchOn);
            },
          ),
        ],
      ),
      body: _permissionError != null
          ? _buildPermissionError()
          : Stack(
              children: [
                MobileScanner(
                  controller: _controller,
                  onDetect: _onDetect,
                ),
                _buildOverlay(),
                if (_processing)
                  const Positioned.fill(
                    child: ColoredBox(
                      color: Color(0x88000000),
                      child: Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            CircularProgressIndicator(color: Colors.white),
                            SizedBox(height: 12),
                            Text(
                              'Validating...',
                              style: TextStyle(color: Colors.white),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
              ],
            ),
    );
  }

  Widget _buildPermissionError() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.no_photography,
                size: 80, color: Colors.white70),
            const SizedBox(height: 16),
            Text(
              _permissionError!,
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.white, fontSize: 16),
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: () => openAppSettings(),
              icon: const Icon(Icons.settings),
              label: const Text('Open Settings'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildOverlay() {
    return IgnorePointer(
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 260,
              height: 260,
              decoration: BoxDecoration(
                border: Border.all(color: Colors.white, width: 3),
                borderRadius: BorderRadius.circular(16),
              ),
            ),
            const SizedBox(height: 24),
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.black54,
                borderRadius: BorderRadius.circular(20),
              ),
              child: const Text(
                'Align the QR code within the frame',
                style: TextStyle(color: Colors.white),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
