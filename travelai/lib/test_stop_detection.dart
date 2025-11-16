import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'dart:async';
import 'services/stop_detection_service.dart';
import 'services/smart_bus_stop_learning_service.dart';
import 'services/bus_stop_service.dart';
import 'models/detected_stop.dart';
import 'widgets/bus_stop_confirmation_dialog.dart';

/// Bus Stop Collection Mode - Collect and verify bus stops using live GPS
/// Detected stops are saved locally and synced to backend for collaborative learning
class TestStopDetectionPage extends StatefulWidget {
  const TestStopDetectionPage({Key? key}) : super(key: key);

  @override
  State<TestStopDetectionPage> createState() => _TestStopDetectionPageState();
}

class _TestStopDetectionPageState extends State<TestStopDetectionPage> {
  final StopDetectionService _detectionService = StopDetectionService.instance;
  final SmartBusStopLearningService _learningService =
      SmartBusStopLearningService.instance;
  final List<String> _logs = [];
  bool _isRunning = false;
  bool _isLiveTracking = false;
  StreamSubscription<Position>? _positionStreamSub;
  DateTime? _lastMoveTime;
  bool _isStationary = false;
  String _currentSpeed = "0.0";
  String _currentLocation = "Unknown";
  int _stopsDetectedThisSession = 0;
  int _stopsConfirmedThisSession = 0;
  int _totalBusStopsInDatabase = 0;

  @override
  void initState() {
    super.initState();
    _setupStopDetection();
    _loadBusStopsCount();
  }

  Future<void> _loadBusStopsCount() async {
    final busStopService = BusStopService();
    final stops = await busStopService.loadBusStops();
    setState(() {
      _totalBusStopsInDatabase = stops.length;
    });
  }

  @override
  void dispose() {
    _positionStreamSub?.cancel();
    super.dispose();
  }

  void _setupStopDetection() {
    _detectionService.onStopDetected = (DetectedStop stop) {
      setState(() {
        _stopsDetectedThisSession++;
        _logs.add(
          '✅ Stop detected: ${stop.stopTypeName} at (${stop.latitude.toStringAsFixed(6)}, ${stop.longitude.toStringAsFixed(6)})\n'
          '   Dwell: ${stop.dwellTime.toStringAsFixed(1)}s, Confidence: ${(stop.confidence * 100).toStringAsFixed(1)}%',
        );
      });

      // Send to learning service for user confirmation
      _learningService.processDetectedStop(stop);

      // Show confirmation dialog
      _showConfirmationDialog(stop);
    };

    // Setup learning service feedback callback
    _learningService.onUserFeedback = (DetectedStop stop, bool isConfirmed) {
      setState(() {
        if (isConfirmed) {
          _stopsConfirmedThisSession++;
          _totalBusStopsInDatabase++;
        }
        _logs.add(
          isConfirmed
              ? '✅ User confirmed: ${stop.stopTypeName} is a bus stop - Added to database!'
              : '❌ User rejected: ${stop.stopTypeName} is not a bus stop',
        );
      });
    };
  }

  void _showConfirmationDialog(DetectedStop stop) {
    // Generate confirmation ID
    final confirmationId =
        'confirm_${stop.latitude.toStringAsFixed(4)}_${stop.longitude.toStringAsFixed(4)}_${stop.timestamp.millisecondsSinceEpoch}';

    // Wait a moment then show dialog
    Future.delayed(const Duration(seconds: 1), () {
      if (mounted) {
        BusStopConfirmationDialog.show(
          context,
          stop,
          confirmationId,
        );
      }
    });
  }

  void _log(String message) {
    setState(() {
      _logs.add(message);
    });
  }

  /// Start LIVE GPS tracking with stop detection
  Future<void> _startLiveTracking() async {
    // Check permissions
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      _log('❌ Location services are disabled.');
      return;
    }

    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        _log('❌ Location permissions are denied.');
        return;
      }
    }

    if (permission == LocationPermission.deniedForever) {
      _log('❌ Location permissions are permanently denied.');
      return;
    }

    setState(() {
      _isLiveTracking = true;
      _logs.clear();
    });

    _log('📍 Starting LIVE GPS tracking...');
    _log('🚌 Detecting bus stops in real-time\n');

    // Configure high-accuracy location tracking
    const locationSettings = LocationSettings(
      accuracy: LocationAccuracy.high,
      distanceFilter: 5, // Update every 5 meters
    );

    _positionStreamSub = Geolocator.getPositionStream(
      locationSettings: locationSettings,
    ).listen(
      (Position position) {
        _processLivePosition(position);
      },
      onError: (error) {
        _log('❌ Error: $error');
      },
    );
  }

  void _stopLiveTracking() {
    _positionStreamSub?.cancel();
    _positionStreamSub = null;
    setState(() {
      _isLiveTracking = false;
    });
    _log('\n⏹️ Live tracking stopped');
  }

  /// Process live GPS position and detect stops
  void _processLivePosition(Position position) {
    // Send to detection service
    _detectionService.processPosition(position);

    // Update UI with current position
    setState(() {
      _currentSpeed =
          (position.speed * 3.6).toStringAsFixed(1); // Convert m/s to km/h
      _currentLocation =
          'Lat: ${position.latitude.toStringAsFixed(6)}, Lng: ${position.longitude.toStringAsFixed(6)}';
    });

    // Detect if stationary
    bool wasStationary = _isStationary;
    _isStationary = position.speed < 0.5; // Less than 0.5 m/s = stationary

    // Log state changes
    if (_isStationary && !wasStationary) {
      _log('🛑 Vehicle stopped at $_currentLocation');
      _lastMoveTime = DateTime.now();
    } else if (!_isStationary && wasStationary) {
      if (_lastMoveTime != null) {
        final dwellSeconds =
            DateTime.now().difference(_lastMoveTime!).inSeconds;
        _log('🚀 Vehicle moving again (stopped for ${dwellSeconds}s)');
      }
    }
  }

  /// Simulate a bus journey with multiple stops
  Future<void> _runSimulation() async {
    if (_isRunning) return;

    setState(() {
      _isRunning = true;
      _logs.clear();
    });

    _log('🚌 Starting simulation...\n');

    // Simulate a bus starting at a location
    double lat = 28.6139;
    double lon = 77.2090;

    _log('📍 Bus starting at ($lat, $lon)');

    // 1. Simulate moving bus (speed ~30 km/h)
    for (int i = 0; i < 5; i++) {
      lat += 0.0005; // Move north
      Position pos = Position(
        latitude: lat,
        longitude: lon,
        timestamp: DateTime.now(),
        accuracy: 10.0,
        altitude: 0.0,
        heading: 0.0,
        speed: 8.33, // 30 km/h in m/s
        speedAccuracy: 1.0,
        altitudeAccuracy: 1.0,
        headingAccuracy: 1.0,
      );
      _detectionService.processPosition(pos);
      await Future.delayed(const Duration(milliseconds: 500));
    }

    _log('🚦 Approaching traffic signal...');

    // 2. Simulate stop at traffic signal (20 seconds)
    for (int i = 0; i < 20; i++) {
      Position pos = Position(
        latitude: lat,
        longitude: lon,
        timestamp: DateTime.now(),
        accuracy: 10.0,
        altitude: 0.0,
        heading: 0.0,
        speed: 0.0, // Stopped
        speedAccuracy: 1.0,
        altitudeAccuracy: 1.0,
        headingAccuracy: 1.0,
      );
      _detectionService.processPosition(pos);
      await Future.delayed(const Duration(seconds: 1));
    }

    _log('🟢 Traffic signal cleared, resuming journey...');

    // 3. Resume movement
    for (int i = 0; i < 10; i++) {
      lat += 0.0005;
      Position pos = Position(
        latitude: lat,
        longitude: lon,
        timestamp: DateTime.now(),
        accuracy: 10.0,
        altitude: 0.0,
        heading: 0.0,
        speed: 8.33,
        speedAccuracy: 1.0,
        altitudeAccuracy: 1.0,
        headingAccuracy: 1.0,
      );
      _detectionService.processPosition(pos);
      await Future.delayed(const Duration(milliseconds: 500));
    }

    _log('⛽ Approaching gas station...');

    // 4. Simulate gas station stop (120 seconds)
    lat += 0.001;
    lon += 0.001;
    for (int i = 0; i < 120; i++) {
      Position pos = Position(
        latitude: lat,
        longitude: lon,
        timestamp: DateTime.now(),
        accuracy: 10.0,
        altitude: 0.0,
        heading: 0.0,
        speed: 0.0,
        speedAccuracy: 1.0,
        altitudeAccuracy: 1.0,
        headingAccuracy: 1.0,
      );
      _detectionService.processPosition(pos);
      await Future.delayed(const Duration(seconds: 1));
    }

    _log('🚌 Leaving gas station...');

    // 5. Resume movement
    for (int i = 0; i < 5; i++) {
      lat += 0.0005;
      Position pos = Position(
        latitude: lat,
        longitude: lon,
        timestamp: DateTime.now(),
        accuracy: 10.0,
        altitude: 0.0,
        heading: 0.0,
        speed: 8.33,
        speedAccuracy: 1.0,
        altitudeAccuracy: 1.0,
        headingAccuracy: 1.0,
      );
      _detectionService.processPosition(pos);
      await Future.delayed(const Duration(milliseconds: 500));
    }

    _log('\n✅ Simulation complete!');
    _log('Check the detected stops in the database.');

    setState(() {
      _isRunning = false;
    });
  }

  Widget _buildStatCard({
    required IconData icon,
    required int count,
    required String label,
    required Color color,
  }) {
    return Column(
      children: [
        Icon(icon, color: color, size: 32),
        const SizedBox(height: 4),
        Text(
          count.toString(),
          style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
        Text(
          label,
          style: const TextStyle(
            fontSize: 12,
            color: Colors.grey,
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Collect Bus Stops'),
        backgroundColor: Colors.blue,
      ),
      body: Column(
        children: [
          // Statistics Card
          Container(
            color: Colors.blue.shade50,
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                const Text(
                  '📊 Bus Stop Collection Statistics',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.blue,
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    _buildStatCard(
                      icon: Icons.location_searching,
                      count: _stopsDetectedThisSession,
                      label: 'Detected',
                      color: Colors.orange,
                    ),
                    _buildStatCard(
                      icon: Icons.check_circle,
                      count: _stopsConfirmedThisSession,
                      label: 'Confirmed',
                      color: Colors.green,
                    ),
                    _buildStatCard(
                      icon: Icons.storage,
                      count: _totalBusStopsInDatabase,
                      label: 'In Database',
                      color: Colors.blue,
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  'Help build a community database of bus stops!',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.blue.shade700,
                    fontStyle: FontStyle.italic,
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),

          // Live tracking status
          if (_isLiveTracking)
            Container(
              color: Colors.green.shade50,
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  Row(
                    children: [
                      Icon(Icons.gps_fixed, color: Colors.green.shade700),
                      const SizedBox(width: 8),
                      Text(
                        'LIVE TRACKING ACTIVE',
                        style: TextStyle(
                          color: Colors.green.shade700,
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          '📍 $_currentLocation',
                          style: const TextStyle(fontSize: 12),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Text(
                        '🚗 Speed: $_currentSpeed km/h',
                        style: const TextStyle(fontSize: 12),
                      ),
                      const SizedBox(width: 16),
                      if (_isStationary)
                        Text(
                          '🛑 STOPPED',
                          style: TextStyle(
                            color: Colors.red.shade700,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                    ],
                  ),
                ],
              ),
            ),

          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              children: [
                const Text(
                  '🚌 Collect Bus Stops During Your Journey',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Turn on GPS tracking and travel on a bus. The app will detect stops automatically. Confirm which ones are bus stops to help everyone!',
                  style: TextStyle(fontSize: 13, color: Colors.grey),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 16),

                // Live tracking button
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: _isRunning
                        ? null
                        : (_isLiveTracking
                            ? _stopLiveTracking
                            : _startLiveTracking),
                    icon:
                        Icon(_isLiveTracking ? Icons.stop : Icons.my_location),
                    label: Text(_isLiveTracking
                        ? 'Stop Collecting'
                        : '🚌 Start Collecting Bus Stops'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor:
                          _isLiveTracking ? Colors.red : Colors.green,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 24, vertical: 16),
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  _isLiveTracking
                      ? 'Tracking active - detecting stops automatically...'
                      : 'Get on a bus and start tracking to collect bus stop data',
                  style: TextStyle(
                    fontSize: 12,
                    color:
                        _isLiveTracking ? Colors.green.shade700 : Colors.grey,
                    fontWeight:
                        _isLiveTracking ? FontWeight.bold : FontWeight.normal,
                  ),
                  textAlign: TextAlign.center,
                ),

                const SizedBox(height: 16),
                const Divider(),
                const SizedBox(height: 8),

                // Simulation button
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed:
                        (_isRunning || _isLiveTracking) ? null : _runSimulation,
                    icon: _isRunning
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor:
                                  AlwaysStoppedAnimation<Color>(Colors.white),
                            ),
                          )
                        : const Icon(Icons.play_arrow),
                    label: Text(
                        _isRunning ? 'Running...' : 'Test with Simulation'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blue,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 24, vertical: 16),
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  'For testing only - simulates stops without real GPS',
                  style: TextStyle(fontSize: 12, color: Colors.grey),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
          const Divider(),

          // Activity Log Header
          Container(
            color: Colors.grey.shade200,
            padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
            child: Row(
              children: [
                Icon(Icons.list_alt, size: 20, color: Colors.grey.shade700),
                const SizedBox(width: 8),
                Text(
                  'Activity Log',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Colors.grey.shade700,
                  ),
                ),
              ],
            ),
          ),

          Expanded(
            child: Container(
              color: Colors.black87,
              child: _logs.isEmpty
                  ? Center(
                      child: Text(
                        'Start tracking to see activity...',
                        style: TextStyle(
                          color: Colors.grey.shade600,
                          fontSize: 14,
                        ),
                      ),
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.all(8),
                      reverse: true, // Show latest logs at bottom
                      itemCount: _logs.length,
                      itemBuilder: (context, index) {
                        final reversedIndex = _logs.length - 1 - index;
                        return Padding(
                          padding: const EdgeInsets.symmetric(vertical: 2),
                          child: Text(
                            _logs[reversedIndex],
                            style: const TextStyle(
                              fontFamily: 'monospace',
                              fontSize: 12,
                              color: Colors.greenAccent,
                            ),
                          ),
                        );
                      },
                    ),
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          Navigator.pushNamed(context, '/detected_stops');
        },
        icon: const Icon(Icons.storage),
        label: const Text('View All Bus Stops'),
        backgroundColor: Colors.blue,
      ),
    );
  }
}
