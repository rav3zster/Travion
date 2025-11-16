import 'package:flutter/material.dart';
import '../services/bus_stop_service.dart';

/// Widget to display bus stop proximity alert
class BusStopAlertDialog extends StatelessWidget {
  final BusStopAlert alert;

  const BusStopAlertDialog({
    super.key,
    required this.alert,
  });

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      title: Row(
        children: [
          Icon(Icons.location_on, color: Colors.orange[700], size: 32),
          const SizedBox(width: 12),
          const Expanded(
            child: Text(
              'Approaching Bus Stop',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.orange[50],
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.orange[200]!, width: 2),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  alert.stop.name,
                  style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF283593),
                  ),
                ),
                if (alert.stop.description != null) ...[
                  const SizedBox(height: 8),
                  Text(
                    alert.stop.description!,
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey[700],
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 16),
          _buildInfoRow(
            Icons.straighten,
            'Distance',
            alert.distanceText,
            Colors.blue,
          ),
          const SizedBox(height: 8),
          if (alert.estimatedTimeMinutes > 0)
            _buildInfoRow(
              Icons.access_time,
              'Arriving in',
              '~${alert.estimatedTimeMinutes} min',
              Colors.green,
            ),
          const SizedBox(height: 8),
          _buildInfoRow(
            Icons.format_list_numbered,
            'Stop Number',
            '#${alert.stop.sequenceNumber}',
            Colors.purple,
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text(
            'OK',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
        ),
      ],
    );
  }

  Widget _buildInfoRow(IconData icon, String label, String value, Color color) {
    return Row(
      children: [
        Icon(icon, size: 20, color: color),
        const SizedBox(width: 8),
        Text(
          '$label: ',
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w500,
          ),
        ),
        Text(
          value,
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
      ],
    );
  }

  /// Show the alert dialog
  static void show(BuildContext context, BusStopAlert alert) {
    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (context) => BusStopAlertDialog(alert: alert),
    );
  }
}

/// Compact notification banner for bus stop alerts
class BusStopAlertBanner extends StatelessWidget {
  final BusStopAlert alert;
  final VoidCallback onTap;
  final VoidCallback onDismiss;

  const BusStopAlertBanner({
    super.key,
    required this.alert,
    required this.onTap,
    required this.onDismiss,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      elevation: 8,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [Colors.orange[700]!, Colors.orange[500]!],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(16),
        ),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(16),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                const Icon(Icons.notification_important,
                    color: Colors.white, size: 32),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        alert.stop.name,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${alert.distanceText} away',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close, color: Colors.white),
                  onPressed: onDismiss,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
