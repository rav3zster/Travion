import 'package:geolocator/geolocator.dart';
import '../models/bus_stop.dart';
import '../models/detected_stop.dart';
import 'bus_stop_service.dart';
import 'notification_service.dart';

/// Smart learning system that asks users to confirm detected stops
/// and automatically adds confirmed stops to the bus stops database
class SmartBusStopLearningService {
  static final SmartBusStopLearningService _instance =
      SmartBusStopLearningService._internal();
  static SmartBusStopLearningService get instance => _instance;

  SmartBusStopLearningService._internal();

  final BusStopService _busStopService = BusStopService();
  final Set<String> _pendingConfirmations = {};
  final Map<String, DetectedStop> _pendingStops = {};

  // Callback for when user confirms/rejects a stop
  Function(DetectedStop stop, bool isConfirmed)? onUserFeedback;

  /// Process a detected stop and ask user for confirmation
  Future<void> processDetectedStop(DetectedStop detectedStop) async {
    // Check if this location is already a known bus stop
    final existingStops = await _busStopService.loadBusStops();
    final isKnownStop = existingStops.any((stop) {
      final distance = Geolocator.distanceBetween(
        stop.latitude,
        stop.longitude,
        detectedStop.latitude,
        detectedStop.longitude,
      );
      return distance < 50; // Within 50 meters
    });

    if (isKnownStop) {
      // Already in database, no need to ask
      return;
    }

    // Check if this is likely a bus stop (not traffic signal, gas station, etc.)
    if (!_isPotentialBusStop(detectedStop)) {
      // Don't ask about obvious non-bus-stops
      return;
    }

    // Generate unique ID for this confirmation request
    final confirmationId = _generateConfirmationId(detectedStop);

    // Avoid duplicate confirmations
    if (_pendingConfirmations.contains(confirmationId)) {
      return;
    }

    _pendingConfirmations.add(confirmationId);
    _pendingStops[confirmationId] = detectedStop;

    // Show confirmation notification
    await _showConfirmationNotification(confirmationId, detectedStop);
  }

  /// Check if detected stop is likely a bus stop
  bool _isPotentialBusStop(DetectedStop stop) {
    // Filter out obvious non-bus-stops
    if (stop.stopType == DetectedStopType.trafficSignal) return false;
    if (stop.stopType == DetectedStopType.tollGate) return false;

    // If dwell time is too short (< 15 seconds), probably not a bus stop
    if (stop.dwellTime < 15) return false;

    // If dwell time is very long (> 10 minutes), might be rest area or gas station
    // but could still be a bus stop, so we'll ask
    if (stop.dwellTime > 600) {
      // Only ask if confidence is high
      return stop.confidence > 0.7;
    }

    // Medium dwell time (15s - 10min) - good candidate for bus stop
    return stop.confidence > 0.5;
  }

  /// Generate unique ID for confirmation
  String _generateConfirmationId(DetectedStop stop) {
    // Use location + timestamp to create unique ID
    final lat = stop.latitude.toStringAsFixed(4);
    final lng = stop.longitude.toStringAsFixed(4);
    return 'confirm_${lat}_${lng}_${stop.timestamp.millisecondsSinceEpoch}';
  }

  /// Show notification asking user to confirm if this is a bus stop
  Future<void> _showConfirmationNotification(
    String confirmationId,
    DetectedStop stop,
  ) async {
    await NotificationService.showProximityAlert(
      title: '🚏 New Stop Detected!',
      body:
          'Is this a bus stop? Stopped for ${stop.dwellTime.toStringAsFixed(0)}s\nTap to confirm or dismiss',
    );
  }

  /// Handle user's response to confirmation
  Future<void> handleUserConfirmation(
    String confirmationId,
    bool isConfirmed,
  ) async {
    final detectedStop = _pendingStops[confirmationId];
    if (detectedStop == null) {
      return; // Already processed or invalid
    }

    if (isConfirmed) {
      // User confirmed it's a bus stop - add to database
      await _addConfirmedBusStop(detectedStop);
    } else {
      // User rejected - log for ML model improvement
      await _logRejectedStop(detectedStop);
    }

    // Clean up
    _pendingConfirmations.remove(confirmationId);
    _pendingStops.remove(confirmationId);

    // Notify callback
    onUserFeedback?.call(detectedStop, isConfirmed);
  }

  /// Add confirmed bus stop to database
  Future<void> _addConfirmedBusStop(DetectedStop detectedStop) async {
    // Get next sequence number
    final existingStops = await _busStopService.loadBusStops();
    final maxSeq = existingStops.isEmpty
        ? 0
        : existingStops
            .map((s) => s.sequenceNumber)
            .reduce((a, b) => a > b ? a : b);

    // Create new bus stop
    final newStop = BusStop(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      name: await _generateStopName(detectedStop),
      latitude: detectedStop.latitude,
      longitude: detectedStop.longitude,
      description:
          'User-confirmed bus stop (detected on ${_formatDate(detectedStop.timestamp)})',
      sequenceNumber: maxSeq + 1,
    );

    // Save to database
    await _busStopService.addBusStop(newStop);

    // Show success notification
    await NotificationService.showProximityAlert(
      title: '✅ Bus Stop Added!',
      body: 'New stop "${newStop.name}" added to your bus stops list',
      playSound: true,
    );
  }

  /// Generate a name for the bus stop based on location
  Future<String> _generateStopName(DetectedStop stop) async {
    // Try to use reverse geocoding if available
    // For now, generate a simple name based on coordinates
    final lat = stop.latitude.toStringAsFixed(4);
    final lng = stop.longitude.toStringAsFixed(4);

    return 'Bus Stop at ($lat, $lng)';
  }

  /// Log rejected stop for ML model improvement
  Future<void> _logRejectedStop(DetectedStop stop) async {
    // This data can be used to improve the ML model
    // Store rejected stops in a separate database or send to analytics

    // Show feedback notification
    await NotificationService.showProximityAlert(
      title: 'Thanks for Feedback!',
      body: 'Your input helps improve stop detection accuracy',
      playSound: false,
    );

    // TODO: Implement ML model feedback loop
    // This rejected data can be used to retrain the stop classification model
  }

  /// Format date for display
  String _formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year}';
  }

  /// Clear all pending confirmations
  void clearPending() {
    _pendingConfirmations.clear();
    _pendingStops.clear();
  }

  /// Get count of pending confirmations
  int getPendingCount() {
    return _pendingConfirmations.length;
  }
}
