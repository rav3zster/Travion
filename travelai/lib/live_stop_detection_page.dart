import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'dart:async';
import 'models/detected_stop.dart';
import 'services/stop_detection_service.dart';
import 'widgets/stop_classification_dialog.dart';

/// Live GPS-based stop detection with user feedback
class LiveStopDetectionPage extends StatefulWidget {
  const LiveStopDetectionPage({super.key});

  @override
  State<LiveStopDetectionPage> createState() => _LiveStopDetectionPageState();
}

class _LiveStopDetectionPageState extends State<LiveStopDetectionPage> {
  final StopDetectionService _stopService = StopDetectionService.instance;

  StreamSubscription<Position>? _positionStream;
  Position? _currentPosition;
  bool _isTracking = false;
  bool _isStationary = false;
  DateTime? _stopStartTime;
  int _currentDwellSeconds = 0;
  Timer? _dwellTimer;

  List<DetectedStop> _detectedStops = [];
  String _statusMessage = 'Ready to track';

  @override
  void initState() {
    super.initState();
    _setupStopDetectionCallbacks();
  }

  @override
  void dispose() {
    _stopTracking();
    _dwellTimer?.cancel();
    super.dispose();
  }

  void _setupStopDetectionCallbacks() {
    _stopService.onStopNeedsClassification = (DetectedStop stop) {
      // Show dialog to user for classification
      _showClassificationDialog(stop);
    };
  }

  Future<void> _startTracking() async {
    // Check location permission
    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        _showError('Location permission denied');
        return;
      }
    }

    setState(() {
      _isTracking = true;
      _statusMessage = 'Tracking started...';
    });

    // Start listening to position updates
    _positionStream = Geolocator.getPositionStream(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: 5, // Update every 5 meters
      ),
    ).listen(
      (Position position) {
        _updatePosition(position);
      },
      onError: (error) {
        _showError('GPS Error: $error');
      },
    );
  }

  void _stopTracking() {
    _positionStream?.cancel();
    _positionStream = null;
    _dwellTimer?.cancel();
    _dwellTimer = null;

    setState(() {
      _isTracking = false;
      _isStationary = false;
      _stopStartTime = null;
      _currentDwellSeconds = 0;
      _statusMessage = 'Tracking stopped';
    });
  }

  void _updatePosition(Position position) {
    setState(() {
      _currentPosition = position;
    });

    // Process position through stop detection service
    _stopService.processPosition(position);

    // Update UI state
    final speedMs = position.speed;
    if (speedMs < 0.5) {
      // Stationary
      if (!_isStationary) {
        setState(() {
          _isStationary = true;
          _stopStartTime = DateTime.now();
          _currentDwellSeconds = 0;
          _statusMessage = 'Vehicle stopped - Timer started';
        });

        // Start dwell timer
        _dwellTimer = Timer.periodic(Duration(seconds: 1), (timer) {
          if (_stopStartTime != null) {
            setState(() {
              _currentDwellSeconds =
                  DateTime.now().difference(_stopStartTime!).inSeconds;
              _statusMessage =
                  'Stopped for ${_currentDwellSeconds}s (${_getDwellCategory()})';
            });
          }
        });
      }
    } else {
      // Moving
      if (_isStationary) {
        _dwellTimer?.cancel();
        setState(() {
          _isStationary = false;
          _stopStartTime = null;
          _currentDwellSeconds = 0;
          _statusMessage =
              'Vehicle moving (${(speedMs * 3.6).toStringAsFixed(1)} km/h)';
        });
      } else {
        setState(() {
          _statusMessage =
              'Vehicle moving (${(speedMs * 3.6).toStringAsFixed(1)} km/h)';
        });
      }
    }
  }

  String _getDwellCategory() {
    if (_currentDwellSeconds < 10) {
      return 'Too short';
    } else if (_currentDwellSeconds <= 60) {
      return '🚌 Bus stop range';
    } else if (_currentDwellSeconds <= 120) {
      return '💰 Toll gate range';
    } else if (_currentDwellSeconds <= 300) {
      return '⛽ Fuel stop range';
    } else {
      return '🍽️ Rest area range';
    }
  }

  void _showClassificationDialog(DetectedStop stop) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => StopClassificationDialog(
        stop: stop,
        onClassified: (DetectedStopType type) {
          _handleUserClassification(stop, type);
        },
      ),
    );
  }

  void _handleUserClassification(DetectedStop stop, DetectedStopType type) {
    // Update classification in database
    _stopService.updateStopClassification(stop, type);

    // Update UI
    setState(() {
      _detectedStops = List.from(_stopService.detectedStops);
      _statusMessage = 'Stop classified as ${_getStopTypeName(type)}';
    });

    // Show confirmation
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('✅ Classified as ${_getStopTypeName(type)}'),
        backgroundColor: Colors.green,
        duration: Duration(seconds: 2),
      ),
    );
  }

  String _getStopTypeName(DetectedStopType type) {
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
        return 'Rest Area';
      case DetectedStopType.unknown:
        return 'Unknown';
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Live Stop Detection'),
        backgroundColor: Colors.deepPurple,
      ),
      body: Column(
        children: [
          // Status card
          Container(
            width: double.infinity,
            padding: EdgeInsets.all(16),
            color: _isTracking
                ? (_isStationary ? Colors.orange.shade50 : Colors.green.shade50)
                : Colors.grey.shade100,
            child: Column(
              children: [
                Icon(
                  _isStationary
                      ? Icons.stop_circle
                      : (_isTracking ? Icons.navigation : Icons.gps_off),
                  size: 48,
                  color: _isStationary
                      ? Colors.orange
                      : (_isTracking ? Colors.green : Colors.grey),
                ),
                SizedBox(height: 12),
                Text(
                  _statusMessage,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                  textAlign: TextAlign.center,
                ),
                if (_isStationary && _currentDwellSeconds >= 10)
                  Padding(
                    padding: EdgeInsets.only(top: 8),
                    child: Text(
                      'Will ask for classification when bus moves',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey.shade600,
                        fontStyle: FontStyle.italic,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                if (_currentPosition != null)
                  Padding(
                    padding: EdgeInsets.only(top: 8),
                    child: Text(
                      'Speed: ${(_currentPosition!.speed * 3.6).toStringAsFixed(1)} km/h | Accuracy: ${_currentPosition!.accuracy.toStringAsFixed(1)}m',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey.shade600,
                      ),
                    ),
                  ),
              ],
            ),
          ),

          // Control buttons
          Padding(
            padding: EdgeInsets.all(16),
            child: Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: _isTracking ? null : _startTracking,
                    icon: Icon(Icons.play_arrow),
                    label: Text('Start Tracking'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green,
                      foregroundColor: Colors.white,
                      padding: EdgeInsets.symmetric(vertical: 12),
                    ),
                  ),
                ),
                SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: _isTracking ? _stopTracking : null,
                    icon: Icon(Icons.stop),
                    label: Text('Stop Tracking'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.red,
                      foregroundColor: Colors.white,
                      padding: EdgeInsets.symmetric(vertical: 12),
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Detected stops list
          Expanded(
            child: _detectedStops.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.location_searching,
                            size: 64, color: Colors.grey.shade400),
                        SizedBox(height: 16),
                        Text(
                          'No stops detected yet',
                          style: TextStyle(
                            fontSize: 16,
                            color: Colors.grey.shade600,
                          ),
                        ),
                        SizedBox(height: 8),
                        Text(
                          'Start tracking to detect stops',
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.grey.shade500,
                          ),
                        ),
                      ],
                    ),
                  )
                : ListView.builder(
                    padding: EdgeInsets.symmetric(horizontal: 16),
                    itemCount: _detectedStops.length,
                    itemBuilder: (context, index) {
                      final stop = _detectedStops[index];
                      return _buildStopCard(stop, index + 1);
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildStopCard(DetectedStop stop, int number) {
    final icon = _getStopTypeIcon(stop.stopType);
    final color = _getStopTypeColor(stop.stopType);

    return Card(
      margin: EdgeInsets.only(bottom: 12),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: color.withOpacity(0.2),
          child: Icon(icon, color: color, size: 20),
        ),
        title: Text(
          '${_getStopTypeName(stop.stopType)}',
          style: TextStyle(fontWeight: FontWeight.w600),
        ),
        subtitle: Text(
          'Duration: ${stop.dwellTime.toStringAsFixed(0)}s | Confidence: ${(stop.confidence * 100).toStringAsFixed(0)}%',
        ),
        trailing: Text(
          '#$number',
          style: TextStyle(
            color: Colors.grey.shade600,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }

  IconData _getStopTypeIcon(DetectedStopType type) {
    switch (type) {
      case DetectedStopType.regularStop:
        return Icons.directions_bus;
      case DetectedStopType.trafficSignal:
        return Icons.traffic;
      case DetectedStopType.tollGate:
        return Icons.toll;
      case DetectedStopType.gasStation:
        return Icons.local_gas_station;
      case DetectedStopType.restArea:
        return Icons.restaurant;
      case DetectedStopType.unknown:
        return Icons.help_outline;
    }
  }

  Color _getStopTypeColor(DetectedStopType type) {
    switch (type) {
      case DetectedStopType.regularStop:
        return Colors.green;
      case DetectedStopType.trafficSignal:
        return Colors.red;
      case DetectedStopType.tollGate:
        return Colors.orange;
      case DetectedStopType.gasStation:
        return Colors.blue;
      case DetectedStopType.restArea:
        return Colors.purple;
      case DetectedStopType.unknown:
        return Colors.grey;
    }
  }
}
