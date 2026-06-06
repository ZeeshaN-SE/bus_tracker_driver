import 'package:flutter/material.dart';
import '../models/validation_result.dart';

/// Displays the outcome of a pass validation scan.
///
/// Two modes:
/// - `result != null`: a normal validation outcome (valid/expired/invalid/already_used).
/// - `errorMessage != null`: a transport/server error (no validation outcome).
///
/// Buttons:
/// - "Scan Another" pops back to the scanner screen.
/// - "Done" pops back to the active trip screen.
class ScanResultScreen extends StatelessWidget {
  final ValidationResult? result;
  final String? errorMessage;

  const ScanResultScreen({
    super.key,
    this.result,
    this.errorMessage,
  }) : assert(result != null || errorMessage != null,
            'Either result or errorMessage must be provided');

  bool get _isValid => result?.valid == true;

  Color get _bgColor {
    if (errorMessage != null) return Colors.orange.shade700;
    if (_isValid) return Colors.green.shade600;
    return Colors.red.shade600;
  }

  IconData get _icon {
    if (errorMessage != null) return Icons.warning_amber_rounded;
    if (_isValid) return Icons.check_circle;
    return Icons.cancel;
  }

  String get _title {
    if (errorMessage != null) return 'Error';
    if (_isValid) return 'Valid Pass';
    switch (result?.result) {
      case ValidationOutcome.expired:
        return 'Expired Pass';
      case ValidationOutcome.alreadyUsed:
        return 'Already Used';
      case ValidationOutcome.invalid:
      default:
        return 'Invalid Pass';
    }
  }

  String get _subtitle {
    if (errorMessage != null) return errorMessage!;
    switch (result?.result) {
      case ValidationOutcome.valid:
        return 'Allow the student to board.';
      case ValidationOutcome.expired:
        return 'This pass is no longer valid.';
      case ValidationOutcome.alreadyUsed:
        return 'This pass has already been scanned on this trip.';
      case ValidationOutcome.invalid:
      default:
        return 'The QR code could not be verified.';
    }
  }

  @override
  Widget build(BuildContext context) {
    final pass = result?.pass;

    return Scaffold(
      backgroundColor: _bgColor,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 24),
              Icon(_icon, size: 120, color: Colors.white),
              const SizedBox(height: 16),
              Text(
                _title,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                _subtitle,
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.white, fontSize: 16),
              ),
              const SizedBox(height: 24),
              if (pass != null) _buildPassInfo(pass),
              const Spacer(),
              ElevatedButton.icon(
                onPressed: () {
                  // Pop back to the scanner.
                  Navigator.of(context).pop();
                },
                icon: const Icon(Icons.qr_code_scanner),
                label: const Text('Scan Another'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.white,
                  foregroundColor: _bgColor,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  textStyle: const TextStyle(
                      fontSize: 16, fontWeight: FontWeight.w600),
                ),
              ),
              const SizedBox(height: 12),
              OutlinedButton.icon(
                onPressed: () {
                  // Pop result + scanner to return to active trip.
                  Navigator.of(context)
                      .popUntil((route) => route.isFirst || route.settings.name == '/active_trip');
                  // Fallback: pop two routes if popUntil could not find one.
                },
                icon: const Icon(Icons.check, color: Colors.white),
                label: const Text('Done',
                    style: TextStyle(color: Colors.white)),
                style: OutlinedButton.styleFrom(
                  side: const BorderSide(color: Colors.white),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  textStyle: const TextStyle(
                      fontSize: 16, fontWeight: FontWeight.w600),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPassInfo(ValidatedPass pass) {
    return Card(
      color: Colors.white,
      shape:
          RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (pass.studentName != null)
              _row(Icons.person, 'Student', pass.studentName!),
            if (pass.passType != null)
              _row(Icons.confirmation_number, 'Pass', pass.passType!),
            if (pass.validUntil != null)
              _row(Icons.event, 'Valid until', _formatIso(pass.validUntil!)),
          ],
        ),
      ),
    );
  }

  Widget _row(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Icon(icon, size: 18, color: Colors.grey),
          const SizedBox(width: 8),
          Text('$label: ',
              style: const TextStyle(color: Colors.grey, fontSize: 14)),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                  fontSize: 14, fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }

  String _formatIso(String iso) {
    try {
      final dt = DateTime.parse(iso).toLocal();
      return '${dt.day.toString().padLeft(2, '0')}/'
          '${dt.month.toString().padLeft(2, '0')}/'
          '${dt.year}';
    } catch (_) {
      return iso;
    }
  }
}
