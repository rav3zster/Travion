/// Enum for different types of detected stops
enum DetectedStopType {
  regularStop,
  tollGate,
  gasStation,
  restArea,
  trafficSignal,
  unknown
}

/// Model representing a detected stop from GPS data
class DetectedStop {
  final int? id;
  final double latitude;
  final double longitude;
  final DateTime timestamp;
  final double dwellTime; // Duration stopped in seconds
  final DetectedStopType stopType;
  final double confidence; // ML model confidence (0-1)
  final bool userConfirmed;
  final String? notes; // User notes about the stop
  final int visitCount; // How many times stopped here
  final double? speed; // Speed before stop (km/h)
  final double? heading; // Direction before stop (degrees)

  DetectedStop({
    this.id,
    required this.latitude,
    required this.longitude,
    required this.timestamp,
    required this.dwellTime,
    required this.stopType,
    required this.confidence,
    this.userConfirmed = false,
    this.notes,
    this.visitCount = 1,
    this.speed,
    this.heading,
  });

  /// Create from database map
  factory DetectedStop.fromMap(Map<String, dynamic> map) {
    return DetectedStop(
      id: map['id'] as int?,
      latitude: map['latitude'] as double,
      longitude: map['longitude'] as double,
      timestamp: DateTime.parse(map['timestamp'] as String),
      dwellTime: map['dwell_time'] as double,
      stopType: DetectedStopType.values[map['stop_type'] as int],
      confidence: map['confidence'] as double,
      userConfirmed: (map['user_confirmed'] as int) == 1,
      notes: map['notes'] as String?,
      visitCount: map['visit_count'] as int? ?? 1,
      speed: map['speed'] as double?,
      heading: map['heading'] as double?,
    );
  }

  /// Convert to database map
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'latitude': latitude,
      'longitude': longitude,
      'timestamp': timestamp.toIso8601String(),
      'dwell_time': dwellTime,
      'stop_type': stopType.index,
      'confidence': confidence,
      'user_confirmed': userConfirmed ? 1 : 0,
      'notes': notes,
      'visit_count': visitCount,
      'speed': speed,
      'heading': heading,
    };
  }

  /// Create a copy with modified fields
  DetectedStop copyWith({
    int? id,
    double? latitude,
    double? longitude,
    DateTime? timestamp,
    double? dwellTime,
    DetectedStopType? stopType,
    double? confidence,
    bool? userConfirmed,
    String? notes,
    int? visitCount,
    double? speed,
    double? heading,
  }) {
    return DetectedStop(
      id: id ?? this.id,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      timestamp: timestamp ?? this.timestamp,
      dwellTime: dwellTime ?? this.dwellTime,
      stopType: stopType ?? this.stopType,
      confidence: confidence ?? this.confidence,
      userConfirmed: userConfirmed ?? this.userConfirmed,
      notes: notes ?? this.notes,
      visitCount: visitCount ?? this.visitCount,
      speed: speed ?? this.speed,
      heading: heading ?? this.heading,
    );
  }

  /// Get human-readable stop type name
  String get stopTypeName {
    switch (stopType) {
      case DetectedStopType.regularStop:
        return 'Regular Stop';
      case DetectedStopType.tollGate:
        return 'Toll Gate';
      case DetectedStopType.gasStation:
        return 'Gas Station';
      case DetectedStopType.restArea:
        return 'Rest Area';
      case DetectedStopType.trafficSignal:
        return 'Traffic Signal';
      case DetectedStopType.unknown:
        return 'Unknown';
    }
  }

  /// Get icon for stop type
  String get stopTypeIcon {
    switch (stopType) {
      case DetectedStopType.regularStop:
        return '🚏';
      case DetectedStopType.tollGate:
        return '💰';
      case DetectedStopType.gasStation:
        return '⛽';
      case DetectedStopType.restArea:
        return '🛑';
      case DetectedStopType.trafficSignal:
        return '🚦';
      case DetectedStopType.unknown:
        return '❓';
    }
  }

  /// Get color for stop type
  String get stopTypeColor {
    switch (stopType) {
      case DetectedStopType.regularStop:
        return '#4CAF50'; // Green
      case DetectedStopType.tollGate:
        return '#FF9800'; // Orange
      case DetectedStopType.gasStation:
        return '#2196F3'; // Blue
      case DetectedStopType.restArea:
        return '#9C27B0'; // Purple
      case DetectedStopType.trafficSignal:
        return '#F44336'; // Red
      case DetectedStopType.unknown:
        return '#757575'; // Gray
    }
  }

  @override
  String toString() {
    return 'DetectedStop(id: $id, lat: $latitude, lng: $longitude, '
        'type: $stopTypeName, dwell: ${dwellTime.toStringAsFixed(1)}s, '
        'confidence: ${(confidence * 100).toStringAsFixed(1)}%)';
  }
}
