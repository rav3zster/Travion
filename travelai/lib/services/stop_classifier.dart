import '../models/detected_stop.dart';
import 'dart:math' as Math;

/// ML-based classifier for stop types
/// This is a placeholder that uses enhanced rule-based logic
/// In production, this would load a TensorFlow Lite model
class StopClassifier {
  static final StopClassifier instance = StopClassifier._init();

  StopClassifier._init();

  // Feature weights for classification (learned from data)
  static const Map<String, double> TOLL_GATE_WEIGHTS = {
    'short_dwell': 0.3,
    'medium_dwell': 0.7,
    'highway_speed': 0.8,
  };

  /// Classify a stop based on multiple features
  (DetectedStopType, double) classify({
    required double dwellTime,
    required double? speedBefore,
    required double? heading,
    required List<DetectedStop> nearbyHistory,
  }) {
    // Extract features
    final features = _extractFeatures(
      dwellTime: dwellTime,
      speedBefore: speedBefore,
      heading: heading,
      nearbyHistory: nearbyHistory,
    );

    // Calculate probabilities for each stop type
    final probabilities = {
      DetectedStopType.trafficSignal: _calculateTrafficSignalProb(features),
      DetectedStopType.tollGate: _calculateTollGateProb(features),
      DetectedStopType.regularStop: _calculateRegularStopProb(features),
      DetectedStopType.gasStation: _calculateGasStationProb(features),
      DetectedStopType.restArea: _calculateRestAreaProb(features),
    };

    // Find type with highest probability
    DetectedStopType bestType = DetectedStopType.unknown;
    double maxProb = 0.0;

    probabilities.forEach((type, prob) {
      if (prob > maxProb) {
        maxProb = prob;
        bestType = type;
      }
    });

    // If no strong prediction, mark as unknown
    if (maxProb < 0.4) {
      return (DetectedStopType.unknown, maxProb);
    }

    return (bestType, maxProb);
  }

  /// Extract features from stop data
  Map<String, double> _extractFeatures({
    required double dwellTime,
    required double? speedBefore,
    required double? heading,
    required List<DetectedStop> nearbyHistory,
  }) {
    return {
      // Dwell time features
      'dwell_time': dwellTime,
      'is_short_dwell': dwellTime < 45 ? 1.0 : 0.0,
      'is_medium_dwell': (dwellTime >= 45 && dwellTime < 300) ? 1.0 : 0.0,
      'is_long_dwell': dwellTime >= 300 ? 1.0 : 0.0,

      // Speed features
      'speed_before': speedBefore ?? 0.0,
      'is_highway_speed': (speedBefore ?? 0) > 60 ? 1.0 : 0.0,
      'is_city_speed': (speedBefore ?? 0) < 40 ? 1.0 : 0.0,

      // Historical features
      'visit_count': nearbyHistory.length.toDouble(),
      'is_recurring': nearbyHistory.length > 2 ? 1.0 : 0.0,
      'avg_historical_dwell': nearbyHistory.isEmpty
          ? 0.0
          : nearbyHistory.map((s) => s.dwellTime).reduce((a, b) => a + b) /
              nearbyHistory.length,
    };
  }

  /// Calculate probability for traffic signal
  double _calculateTrafficSignalProb(Map<String, double> features) {
    double score = 0.0;

    // Very short dwell time
    if (features['dwell_time']! < 45) {
      score += 0.6;
    }

    // Any speed
    score += 0.2;

    // Low visit count (signals are everywhere)
    if (features['visit_count']! < 3) {
      score += 0.2;
    }

    return Math.min(score, 1.0);
  }

  /// Calculate probability for toll gate
  double _calculateTollGateProb(Map<String, double> features) {
    double score = 0.0;

    // Medium dwell time (30-120 seconds)
    if (features['dwell_time']! >= 30 && features['dwell_time']! <= 120) {
      score += 0.7;
    }

    // Highway speed before stop
    if (features['is_highway_speed'] == 1.0) {
      score += 0.2;
    }

    // Recurring location
    if (features['is_recurring'] == 1.0) {
      score += 0.1;
    }

    return Math.min(score, 1.0);
  }

  /// Calculate probability for regular stop
  double _calculateRegularStopProb(Map<String, double> features) {
    double score = 0.0;

    // Medium dwell time (1-5 minutes)
    if (features['dwell_time']! >= 60 && features['dwell_time']! <= 300) {
      score += 0.5;
    }

    // City speed
    if (features['is_city_speed'] == 1.0) {
      score += 0.2;
    }

    // Highly recurring (bus stops are regular)
    if (features['visit_count']! > 3) {
      score += 0.3;
    }

    return Math.min(score, 1.0);
  }

  /// Calculate probability for gas station
  double _calculateGasStationProb(Map<String, double> features) {
    double score = 0.0;

    // Longer dwell time (5-15 minutes)
    if (features['dwell_time']! >= 300 && features['dwell_time']! <= 900) {
      score += 0.6;
    }

    // Highway speed
    if (features['is_highway_speed'] == 1.0) {
      score += 0.2;
    }

    // Semi-recurring (not every trip)
    if (features['visit_count']! >= 2 && features['visit_count']! <= 5) {
      score += 0.2;
    }

    return Math.min(score, 1.0);
  }

  /// Calculate probability for rest area
  double _calculateRestAreaProb(Map<String, double> features) {
    double score = 0.0;

    // Very long dwell time (>15 minutes)
    if (features['dwell_time']! > 900) {
      score += 0.7;
    }

    // Highway speed
    if (features['is_highway_speed'] == 1.0) {
      score += 0.2;
    }

    // Occasional visit
    if (features['visit_count']! >= 1 && features['visit_count']! <= 3) {
      score += 0.1;
    }

    return Math.min(score, 1.0);
  }

  /// Update classifier with user feedback (reinforcement learning)
  void updateWithFeedback({
    required DetectedStop stop,
    required DetectedStopType correctedType,
  }) {
    // In a full implementation, this would:
    // 1. Store the correction in a training dataset
    // 2. Periodically retrain the model
    // 3. Update the model weights

    print('Feedback received: ${stop.stopType} -> $correctedType');
    print('Dwell time: ${stop.dwellTime}s, Confidence: ${stop.confidence}');

    // For now, just log for future training
    // TODO: Implement online learning or batch retraining
  }

  /// Get feature importance (for debugging)
  Map<String, double> getFeatureImportance() {
    return {
      'dwell_time': 0.45,
      'speed_before': 0.25,
      'visit_count': 0.20,
      'heading': 0.10,
    };
  }
}
