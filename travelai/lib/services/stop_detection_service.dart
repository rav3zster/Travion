import 'dart:async';
import 'dart:math' as Math;
import 'package:geolocator/geolocator.dart';
import '../models/detected_stop.dart';
import 'stop_detection_database.dart';

/// Service for detecting bus stops from GPS data
class StopDetectionService {
  static final StopDetectionService instance = StopDetectionService._init();

  StopDetectionService._init();

  // Configuration parameters (optimized for Indian bus stops)
  static const double STOP_SPEED_THRESHOLD =
      0.5; // m/s (~1.8 km/h) - below this is considered stopped
  static const double MIN_DWELL_TIME =
      10.0; // seconds - minimum time to ask user (10s for quick stops)
  static const double MAX_BUS_STOP_DWELL =
      60.0; // seconds - maximum typical bus stop duration
  static const double CLUSTER_RADIUS =
      30.0; // meters - stops within this distance are same location
  static const int POSITION_BUFFER_SIZE =
      20; // Number of positions to keep in memory

  // State tracking
  final List<Position> _positionBuffer = [];
  Position? _lastPosition;
  DateTime? _stopStartTime;
  bool _isStopped = false;
  final List<DetectedStop> _detectedStops = [];

  // Callbacks
  Function(DetectedStop)? onStopDetected;
  Function(DetectedStop)? onStopEnded;
  Function(DetectedStop)?
      onStopNeedsClassification; // NEW: Ask user to classify

  /// Process a new GPS position
  Future<void> processPosition(Position position) async {
    // Add to buffer
    _positionBuffer.add(position);
    if (_positionBuffer.length > POSITION_BUFFER_SIZE) {
      _positionBuffer.removeAt(0);
    }

    // Use speed from GPS (already in m/s)
    double speedMs = position.speed;

    // Fallback: Calculate speed if GPS speed is unavailable
    if (_lastPosition != null && speedMs == 0) {
      speedMs = _calculateSpeed(_lastPosition!, position);
    }

    // Check if vehicle is stopped (speed < 0.5 m/s)
    if (speedMs < STOP_SPEED_THRESHOLD) {
      await _handleStopState(position);
    } else {
      await _handleMovingState(position, speedMs);
    }

    _lastPosition = position;
  }

  /// Handle state when vehicle is stopped
  Future<void> _handleStopState(Position position) async {
    if (!_isStopped) {
      // Just stopped
      _isStopped = true;
      _stopStartTime = DateTime.now();
      print('Vehicle stopped at: ${position.latitude}, ${position.longitude}');
    } else {
      // Check if stopped long enough to record
      if (_stopStartTime != null) {
        final dwellTime = DateTime.now().difference(_stopStartTime!).inSeconds;

        if (dwellTime >= MIN_DWELL_TIME) {
          // This is a significant stop - but only detect once
          // We'll wait until vehicle moves again to finalize the stop
        }
      }
    }
  }

  /// Handle state when vehicle is moving
  Future<void> _handleMovingState(Position position, double speedMs) async {
    if (_isStopped && _stopStartTime != null) {
      // Vehicle was stopped and now moving - record the stop
      final dwellTime =
          DateTime.now().difference(_stopStartTime!).inSeconds.toDouble();

      if (dwellTime >= MIN_DWELL_TIME && _lastPosition != null) {
        // Stop duration is significant - ask user to classify
        await _recordStopAndAskUser(_lastPosition!, dwellTime, speedMs);
      } else {
        print('Stop too short (${dwellTime.toStringAsFixed(1)}s) - ignoring');
      }

      _isStopped = false;
      _stopStartTime = null;
    }
  }

  /// Record a stop and ask user for classification
  Future<void> _recordStopAndAskUser(
      Position position, double dwellTime, double speedBeforeMs) async {
    print(
        '🛑 Stop detected! Duration: ${dwellTime.toStringAsFixed(1)}s - Asking user...');

    // Check if this is near a previously detected stop
    final nearbyStops =
        await StopDetectionDatabase.instance.getStopsNearLocation(
      position.latitude,
      position.longitude,
      CLUSTER_RADIUS,
    );

    // Initial classification using ML model (or rules as fallback)
    DetectedStopType suggestedType = DetectedStopType.unknown;
    double confidence = 0.3;

    if (nearbyStops.isNotEmpty) {
      // Recurring location - suggest most common type
      final mostCommonType = _getMostCommonType(nearbyStops);
      suggestedType = mostCommonType;
      confidence = 0.6 + (nearbyStops.length * 0.05).clamp(0.0, 0.3);
      print(
          '📍 Recurring location: ${nearbyStops.length} previous stops → Suggesting: $suggestedType');
    } else {
      // New location - classify based on dwell time (Indian bus stop patterns)
      (suggestedType, confidence) = _classifyIndianBusStop(dwellTime);
      print(
          '🆕 New location → Suggesting: $suggestedType (${(confidence * 100).toStringAsFixed(0)}% confidence)');
    }

    // Create detected stop with suggested classification
    final detectedStop = DetectedStop(
      latitude: position.latitude,
      longitude: position.longitude,
      timestamp: DateTime.now(),
      dwellTime: dwellTime,
      stopType: suggestedType,
      confidence: confidence,
      speed: speedBeforeMs * 3.6, // Convert m/s to km/h
      heading: position.heading,
    );

    // Save to database with initial classification
    final savedStop =
        await StopDetectionDatabase.instance.insertStop(detectedStop);
    _detectedStops.add(savedStop);

    // 🔔 TRIGGER USER PROMPT - Show dialog to confirm/correct
    onStopNeedsClassification?.call(savedStop);

    print('✅ Stop recorded: ${savedStop.toString()}');
  }

  /// Classify stop specifically for Indian bus patterns
  (DetectedStopType, double) _classifyIndianBusStop(double dwellTime) {
    // Indian bus stop patterns (10-60 seconds is typical)
    if (dwellTime >= 10 && dwellTime <= 60) {
      // Most likely a bus stop
      if (dwellTime < 20) {
        return (DetectedStopType.regularStop, 0.7); // Quick pickup/drop
      } else if (dwellTime <= 45) {
        return (DetectedStopType.regularStop, 0.85); // Normal bus stop
      } else {
        return (DetectedStopType.regularStop, 0.75); // Busy bus stop
      }
    } else if (dwellTime < 10) {
      return (
        DetectedStopType.trafficSignal,
        0.8
      ); // Too short - traffic signal
    } else if (dwellTime <= 120) {
      return (DetectedStopType.tollGate, 0.6); // 1-2 min - could be toll
    } else if (dwellTime <= 300) {
      return (DetectedStopType.gasStation, 0.5); // 2-5 min - fuel stop
    } else {
      return (DetectedStopType.restArea, 0.6); // >5 min - rest/meal break
    }
  }

  /// Update stop classification based on user feedback
  Future<void> updateStopClassification(
    DetectedStop stop,
    DetectedStopType userClassification,
  ) async {
    print('📝 User feedback: ${stop.stopType} → $userClassification');

    // Update the stop in database
    final updatedStop = DetectedStop(
      id: stop.id,
      latitude: stop.latitude,
      longitude: stop.longitude,
      timestamp: stop.timestamp,
      dwellTime: stop.dwellTime,
      stopType: userClassification,
      confidence: 1.0, // User confirmation = 100% confidence
      speed: stop.speed,
      heading: stop.heading,
    );

    await StopDetectionDatabase.instance.updateStop(updatedStop);

    // Update in-memory list
    final index = _detectedStops.indexWhere((s) => s.id == stop.id);
    if (index != -1) {
      _detectedStops[index] = updatedStop;
    }

    // TODO: Use this feedback to retrain ML model
    print('✅ Stop classification updated and saved for ML training');
  }

  /// Get most common stop type from nearby stops
  DetectedStopType _getMostCommonType(List<DetectedStop> stops) {
    final typeCounts = <DetectedStopType, int>{};

    for (final stop in stops) {
      typeCounts[stop.stopType] = (typeCounts[stop.stopType] ?? 0) + 1;
    }

    // Find type with highest count
    DetectedStopType mostCommon = DetectedStopType.unknown;
    int maxCount = 0;

    typeCounts.forEach((type, count) {
      if (count > maxCount) {
        maxCount = count;
        mostCommon = type;
      }
    });

    return mostCommon;
  }

  /// Calculate speed between two positions
  double _calculateSpeed(Position pos1, Position pos2) {
    final distance = _calculateDistance(
      pos1.latitude,
      pos1.longitude,
      pos2.latitude,
      pos2.longitude,
    );

    final timeDiff = pos2.timestamp.difference(pos1.timestamp).inSeconds;
    if (timeDiff == 0) return 0.0;

    return distance / timeDiff; // m/s
  }

  /// Calculate distance between two points using Haversine formula
  double _calculateDistance(
      double lat1, double lon1, double lat2, double lon2) {
    const double earthRadius = 6371000; // meters

    final dLat = _degreesToRadians(lat2 - lat1);
    final dLon = _degreesToRadians(lon2 - lon1);

    final a = Math.sin(dLat / 2) * Math.sin(dLat / 2) +
        Math.cos(_degreesToRadians(lat1)) *
            Math.cos(_degreesToRadians(lat2)) *
            Math.sin(dLon / 2) *
            Math.sin(dLon / 2);

    final c = 2 * Math.atan2(Math.sqrt(a), Math.sqrt(1 - a));
    return earthRadius * c;
  }

  double _degreesToRadians(double degrees) {
    return degrees * Math.pi / 180;
  }

  /// Get all detected stops from current session
  List<DetectedStop> get detectedStops => List.unmodifiable(_detectedStops);

  /// Clear session data
  void clearSession() {
    _positionBuffer.clear();
    _detectedStops.clear();
    _isStopped = false;
    _stopStartTime = null;
    _lastPosition = null;
  }

  /// Get statistics for current session
  Map<String, dynamic> getSessionStats() {
    final stopsByType = <DetectedStopType, int>{};
    double totalDwellTime = 0.0;

    for (final stop in _detectedStops) {
      stopsByType[stop.stopType] = (stopsByType[stop.stopType] ?? 0) + 1;
      totalDwellTime += stop.dwellTime;
    }

    return {
      'totalStops': _detectedStops.length,
      'stopsByType': stopsByType,
      'totalDwellTime': totalDwellTime,
      'averageDwellTime':
          _detectedStops.isEmpty ? 0.0 : totalDwellTime / _detectedStops.length,
    };
  }
}
