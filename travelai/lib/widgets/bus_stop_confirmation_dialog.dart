import 'package:flutter/material.dart';
import '../models/detected_stop.dart';
import '../services/smart_bus_stop_learning_service.dart';

/// Dialog to ask user if detected stop is a bus stop
class BusStopConfirmationDialog extends StatelessWidget {
  final DetectedStop detectedStop;
  final String confirmationId;

  const BusStopConfirmationDialog({
    Key? key,
    required this.detectedStop,
    required this.confirmationId,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.orange[100],
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(Icons.bus_alert, color: Colors.orange, size: 32),
          ),
          const SizedBox(width: 12),
          const Expanded(
            child: Text(
              'New Stop Detected!',
              style: TextStyle(fontSize: 20),
            ),
          ),
        ],
      ),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.blue[50],
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.blue[200]!),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    '📍 Location Details',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                  ),
                  const SizedBox(height: 8),
                  _buildInfoRow(
                    'Coordinates',
                    '${detectedStop.latitude.toStringAsFixed(6)}, ${detectedStop.longitude.toStringAsFixed(6)}',
                  ),
                  _buildInfoRow(
                    'Stopped Duration',
                    '${detectedStop.dwellTime.toStringAsFixed(0)} seconds',
                  ),
                  _buildInfoRow(
                    'Detection Type',
                    detectedStop.stopTypeName,
                  ),
                  _buildInfoRow(
                    'Confidence',
                    '${(detectedStop.confidence * 100).toStringAsFixed(1)}%',
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              '🤔 Is this location a bus stop?',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Your feedback helps improve stop detection and builds a better bus stop database for all users.',
              style: TextStyle(fontSize: 14, color: Colors.grey),
            ),
          ],
        ),
      ),
      actions: [
        Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: () {
                  _handleResponse(context, false);
                },
                icon: const Icon(Icons.close, color: Colors.red),
                label: const Text('No'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.red,
                  side: const BorderSide(color: Colors.red),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: ElevatedButton.icon(
                onPressed: () {
                  _handleResponse(context, true);
                },
                icon: const Icon(Icons.check_circle),
                label: const Text('Yes, Add It'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 110,
            child: Text(
              '$label:',
              style: const TextStyle(
                fontSize: 13,
                color: Colors.black54,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _handleResponse(BuildContext context, bool isConfirmed) {
    // Send confirmation to learning service
    SmartBusStopLearningService.instance.handleUserConfirmation(
      confirmationId,
      isConfirmed,
    );

    // Close dialog
    Navigator.of(context).pop(isConfirmed);

    // Show feedback
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          isConfirmed
              ? '✅ Bus stop added to your list!'
              : '👍 Thanks for the feedback!',
        ),
        backgroundColor: isConfirmed ? Colors.green : Colors.blue,
        duration: const Duration(seconds: 3),
      ),
    );
  }

  /// Static method to show the dialog
  static Future<bool?> show(
    BuildContext context,
    DetectedStop detectedStop,
    String confirmationId,
  ) {
    return showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) => BusStopConfirmationDialog(
        detectedStop: detectedStop,
        confirmationId: confirmationId,
      ),
    );
  }
}
