import 'package:flutter/material.dart';
import '../models/detected_stop.dart';

/// Dialog that asks user to classify a detected stop
class StopClassificationDialog extends StatelessWidget {
  final DetectedStop stop;
  final Function(DetectedStopType) onClassified;

  const StopClassificationDialog({
    super.key,
    required this.stop,
    required this.onClassified,
  });

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Row(
        children: [
          Icon(Icons.location_on, color: Colors.orange, size: 28),
          SizedBox(width: 12),
          Expanded(
            child: Text(
              'Stop Detected!',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Stop information
          Container(
            padding: EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.blue.shade50,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Stop Duration: ${stop.dwellTime.toStringAsFixed(0)} seconds',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                SizedBox(height: 4),
                if (stop.stopType != DetectedStopType.unknown)
                  Text(
                    'Suggested: ${_getStopTypeLabel(stop.stopType)}',
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey.shade700,
                      fontStyle: FontStyle.italic,
                    ),
                  ),
              ],
            ),
          ),
          SizedBox(height: 16),
          Text(
            'What type of stop was this?',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w500,
            ),
          ),
          SizedBox(height: 12),
          // Classification buttons
          _buildClassificationButton(
            context,
            DetectedStopType.regularStop,
            Icons.directions_bus,
            'Bus Stop',
            Colors.green,
            '🚌 Passenger pickup/drop',
          ),
          SizedBox(height: 8),
          _buildClassificationButton(
            context,
            DetectedStopType.trafficSignal,
            Icons.traffic,
            'Traffic Signal',
            Colors.red,
            '🚦 Red light/traffic jam',
          ),
          SizedBox(height: 8),
          _buildClassificationButton(
            context,
            DetectedStopType.tollGate,
            Icons.toll,
            'Toll Gate',
            Colors.orange,
            '💰 Toll payment',
          ),
          SizedBox(height: 8),
          _buildClassificationButton(
            context,
            DetectedStopType.gasStation,
            Icons.local_gas_station,
            'Fuel Stop',
            Colors.blue,
            '⛽ Refueling',
          ),
          SizedBox(height: 8),
          _buildClassificationButton(
            context,
            DetectedStopType.restArea,
            Icons.restaurant,
            'Rest/Meal Break',
            Colors.purple,
            '🍽️ Long break',
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () {
            Navigator.of(context).pop();
            // Ignore this stop
          },
          child: Text(
            'Skip',
            style: TextStyle(color: Colors.grey),
          ),
        ),
      ],
    );
  }

  Widget _buildClassificationButton(
    BuildContext context,
    DetectedStopType type,
    IconData icon,
    String label,
    Color color,
    String description,
  ) {
    final isHighlighted = stop.stopType == type && stop.confidence > 0.6;

    return Material(
      elevation: isHighlighted ? 4 : 1,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () {
          onClassified(type);
          Navigator.of(context).pop();
        },
        child: Container(
          padding: EdgeInsets.all(12),
          decoration: BoxDecoration(
            border: Border.all(
              color: isHighlighted ? color : Colors.grey.shade300,
              width: isHighlighted ? 2 : 1,
            ),
            borderRadius: BorderRadius.circular(12),
            color: isHighlighted ? color.withOpacity(0.1) : Colors.white,
          ),
          child: Row(
            children: [
              Container(
                padding: EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(icon, color: color, size: 24),
              ),
              SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          label,
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        if (isHighlighted) ...[
                          SizedBox(width: 6),
                          Container(
                            padding: EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: color,
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              'Suggested',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                    SizedBox(height: 2),
                    Text(
                      description,
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey.shade600,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.chevron_right,
                color: Colors.grey.shade400,
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _getStopTypeLabel(DetectedStopType type) {
    switch (type) {
      case DetectedStopType.regularStop:
        return 'Bus Stop';
      case DetectedStopType.trafficSignal:
        return 'Traffic Signal';
      case DetectedStopType.tollGate:
        return 'Toll Gate';
      case DetectedStopType.gasStation:
        return 'Fuel Stop';
      case DetectedStopType.restArea:
        return 'Rest/Meal Break';
      case DetectedStopType.unknown:
        return 'Unknown';
    }
  }
}
