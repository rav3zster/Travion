import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';
import 'dart:async';
import 'package:flutter/services.dart';
import 'eat_utils.dart';
import 'services/notification_service.dart';

class TrackPage extends StatefulWidget {
  const TrackPage({super.key});

  @override
  State<TrackPage> createState() => _TrackPageState();
}

class _TrackPageState extends State<TrackPage> {
  void _parseAlertDistances() {
    final input = _alertsController.text;
    final parts = input.split(',');
    _alertDistances = parts
        .map((e) => double.tryParse(e.trim()))
        .where((e) => e != null && e > 0)
        .map((e) => e!)
        .toList();
    _alertDistances.sort((a, b) => b.compareTo(a)); // Descending order
  }

  void _updateAlertRadius() {
    final radiusInput = _radiusController.text.trim();
    if (radiusInput.isNotEmpty) {
      final parsedRadius = double.tryParse(radiusInput);
      if (parsedRadius != null && parsedRadius > 0) {
        setState(() {
          _alertRadius = parsedRadius;
        });
      }
    }
  }

  Position? _currentPosition;
  Position? _destinationPosition;
  String _alert = '';
  final TextEditingController _alertsController =
      TextEditingController(text: '500,300,100');
  List<double> _alertDistances = [500, 300, 100];
  String _distanceText = '';
  String _eatText = '';
  final TextEditingController _destinationController = TextEditingController();
  StreamSubscription<Position>? _positionStreamSub;

  // Alert type and settings
  String _alertType = 'notification'; // 'notification' or 'alarm'
  double _alertRadius = 200.0; // Default radius in meters
  Set<double> _triggeredAlerts = {}; // Track which alerts have been triggered
  final TextEditingController _radiusController =
      TextEditingController(text: '200');

  @override
  void initState() {
    super.initState();
    _getCurrentLocation();
    NotificationService.initialize(); // Initialize notification service
  }

  @override
  void dispose() {
    _positionStreamSub?.cancel();
    _destinationController.dispose();
    _alertsController.dispose();
    _radiusController.dispose();
    NotificationService.cancelAll(); // Cancel all notifications on dispose
    super.dispose();
  }

  Future<void> _getCurrentLocation() async {
    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        if (mounted) {
          setState(() {
            _alert = 'Location services are disabled.';
          });
        }
        return;
      }
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          if (mounted) {
            setState(() {
              _alert = 'Location permissions are denied.';
            });
          }
          return;
        }
      }
      if (permission == LocationPermission.deniedForever) {
        if (mounted) {
          setState(() {
            _alert = 'Location permissions are permanently denied.';
          });
        }
        return;
      }
      Position position = await Geolocator.getCurrentPosition();
      if (mounted) {
        setState(() {
          _currentPosition = position;
          _alert = '';
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _alert = 'Error getting location: $e';
        });
      }
    }
  }

  Future<void> _setDestination() async {
    String destinationName = _destinationController.text.trim();
    if (destinationName.isEmpty) {
      if (mounted) {
        setState(() {
          _alert = 'Please enter a destination name.';
        });
      }
      return;
    }

    // Parse the custom radius (always update it when setting destination)
    _updateAlertRadius();

    try {
      List<Location> locations = await locationFromAddress(destinationName);
      if (locations.isNotEmpty) {
        Location loc = locations.first;
        if (mounted) {
          setState(() {
            _destinationPosition = Position(
              latitude: loc.latitude,
              longitude: loc.longitude,
              timestamp: DateTime.now(),
              accuracy: 0.0,
              altitude: 0.0,
              heading: 0.0,
              speed: 0.0,
              speedAccuracy: 0.0,
              altitudeAccuracy: 0.0,
              headingAccuracy: 0.0,
            );
            _alert =
                'Destination set at: Lat ${loc.latitude}, Lng ${loc.longitude}';
            _triggeredAlerts
                .clear(); // Reset triggered alerts for new destination
          });
        }
        _parseAlertDistances();
        _startMonitoring();
      } else {
        if (mounted) {
          setState(() {
            _alert = 'Destination not found.';
          });
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _alert = 'Error finding destination: $e';
        });
      }
    }
  }

  void _startMonitoring() {
    _positionStreamSub?.cancel();

    // Configure location settings for better accuracy
    const locationSettings = LocationSettings(
      accuracy: LocationAccuracy.high,
      distanceFilter: 10, // Update every 10 meters
    );

    _positionStreamSub = Geolocator.getPositionStream(
      locationSettings: locationSettings,
    ).listen((Position position) async {
      if (_destinationPosition != null) {
        double distance = Geolocator.distanceBetween(
          position.latitude,
          position.longitude,
          _destinationPosition!.latitude,
          _destinationPosition!.longitude,
        );
        String distanceStr = '';
        if (distance < 1000) {
          distanceStr = '${distance.toStringAsFixed(1)} m';
        } else {
          distanceStr = '${(distance / 1000).toStringAsFixed(2)} km';
        }
        String eatStr = '';
        if (position.speed > 0) {
          eatStr = calculateEAT(distance, position.speed);
        } else {
          eatStr = 'N/A';
        }

        // Check for alert distances and trigger notifications/alarms
        String alertMsg = '';
        for (double d in _alertDistances) {
          if (distance <= d && !_triggeredAlerts.contains(d)) {
            alertMsg =
                'You are within ${d.toInt()} meters of your destination!';
            _triggeredAlerts.add(d); // Mark this alert as triggered

            // Trigger notification or alarm based on user preference
            await _triggerProximityAlert(d.toInt(), distance.toInt());
            break;
          }
        }

        // Also check for the custom radius alert
        if (distance <= _alertRadius &&
            !_triggeredAlerts.contains(_alertRadius)) {
          alertMsg =
              'You are ${distance.toInt()} meters close to your destination!';
          _triggeredAlerts.add(_alertRadius);
          await _triggerProximityAlert(_alertRadius.toInt(), distance.toInt());
        }

        if (mounted) {
          setState(() {
            _currentPosition = position;
            _distanceText = 'Distance to destination: $distanceStr';
            _eatText = 'Estimated Arrival Time: $eatStr';
            _alert = alertMsg;
          });
        }
      }
    });
  }

  /// Trigger proximity alert (notification or alarm)
  Future<void> _triggerProximityAlert(
      int radiusMeters, int distanceMeters) async {
    try {
      final title = '🎯 Destination Alert!';
      final body = 'You\'re $distanceMeters meters close to your destination';

      if (_alertType == 'alarm') {
        // Trigger device alarm with vibration and sound
        await NotificationService.showAlarmNotification(
          title: title,
          body: body,
          distance: distanceMeters,
        );

        // Also vibrate the device
        HapticFeedback.heavyImpact();
        await Future.delayed(const Duration(milliseconds: 500));
        HapticFeedback.heavyImpact();
      } else {
        // Show notification
        await NotificationService.showProximityAlert(
          title: title,
          body: body,
          distance: distanceMeters,
          playSound: true,
        );

        // Light haptic feedback
        HapticFeedback.mediumImpact();
      }
    } catch (e) {
      debugPrint('Error triggering alert: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Track Destination')),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Card(
                elevation: 4,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Row(
                        children: [
                          Icon(Icons.my_location, color: Colors.blueAccent),
                          SizedBox(width: 8),
                          Text('Current Location:',
                              style: TextStyle(fontWeight: FontWeight.bold)),
                        ],
                      ),
                      Text(_currentPosition != null
                          ? 'Lat: ${_currentPosition!.latitude}, Lng: ${_currentPosition!.longitude}'
                          : 'Fetching...'),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 20),
              Card(
                elevation: 4,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Row(
                        children: [
                          Icon(Icons.place, color: Colors.green),
                          SizedBox(width: 8),
                          Text('Destination:',
                              style: TextStyle(fontWeight: FontWeight.bold)),
                        ],
                      ),
                      TextField(
                        controller: _destinationController,
                        decoration: const InputDecoration(
                          labelText:
                              'Enter destination (e.g. Taj Mahal, New Delhi)',
                          hintText: 'Type a place name or address',
                        ),
                      ),
                      const SizedBox(height: 8),
                      TextField(
                        controller: _alertsController,
                        decoration: const InputDecoration(
                          labelText:
                              'Alert distances (meters, comma separated)',
                          hintText: 'e.g. 500,300,100',
                        ),
                        keyboardType: TextInputType.number,
                        onChanged: (val) => _parseAlertDistances(),
                      ),
                      const SizedBox(height: 12),

                      // Alert Radius Input
                      TextField(
                        controller: _radiusController,
                        decoration: InputDecoration(
                          labelText: 'Custom Alert Radius (meters)',
                          hintText: 'e.g. 200',
                          prefixIcon:
                              const Icon(Icons.radar, color: Colors.blue),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                          helperText:
                              'Get ${_alertType == 'alarm' ? 'ALARM' : 'notification'} at this distance',
                          helperStyle: TextStyle(
                            color: _alertType == 'alarm'
                                ? Colors.red[700]
                                : Colors.blue[700],
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        keyboardType: TextInputType.number,
                        onChanged: (val) {
                          _updateAlertRadius();
                        },
                      ),
                      const SizedBox(height: 8),

                      // Show current active radius
                      if (_alertRadius > 0)
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: _alertType == 'alarm'
                                ? Colors.red[50]
                                : Colors.green[50],
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(
                              color: _alertType == 'alarm'
                                  ? Colors.red[300]!
                                  : Colors.green[300]!,
                            ),
                          ),
                          child: Row(
                            children: [
                              Icon(
                                _alertType == 'alarm'
                                    ? Icons.alarm
                                    : Icons.notifications_active,
                                size: 16,
                                color: _alertType == 'alarm'
                                    ? Colors.red[700]
                                    : Colors.green[700],
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  '${_alertType == 'alarm' ? 'ALARM' : 'Notification'} will trigger at ${_alertRadius.toInt()}m',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: _alertType == 'alarm'
                                        ? Colors.red[900]
                                        : Colors.green[900],
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      const SizedBox(height: 12),

                      // Alert Type Selector
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
                            const Row(
                              children: [
                                Icon(Icons.notifications_active,
                                    color: Colors.blue, size: 20),
                                SizedBox(width: 8),
                                Text(
                                  'Alert Type:',
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 14,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Row(
                              children: [
                                Expanded(
                                  child: RadioListTile<String>(
                                    title: const Row(
                                      children: [
                                        Icon(Icons.notifications, size: 18),
                                        SizedBox(width: 4),
                                        Flexible(
                                          child: Text(
                                            'Notification',
                                            style: TextStyle(fontSize: 13),
                                          ),
                                        ),
                                      ],
                                    ),
                                    subtitle: const Text(
                                      'Silent alert',
                                      style: TextStyle(fontSize: 11),
                                    ),
                                    value: 'notification',
                                    groupValue: _alertType,
                                    dense: true,
                                    contentPadding: EdgeInsets.zero,
                                    onChanged: (value) {
                                      setState(() {
                                        _alertType = value!;
                                      });
                                    },
                                  ),
                                ),
                                Expanded(
                                  child: RadioListTile<String>(
                                    title: const Row(
                                      children: [
                                        Icon(Icons.alarm,
                                            size: 18, color: Colors.red),
                                        SizedBox(width: 4),
                                        Flexible(
                                          child: Text(
                                            'Alarm',
                                            style: TextStyle(fontSize: 13),
                                          ),
                                        ),
                                      ],
                                    ),
                                    subtitle: const Text(
                                      'Loud + vibrate',
                                      style: TextStyle(fontSize: 11),
                                    ),
                                    value: 'alarm',
                                    groupValue: _alertType,
                                    dense: true,
                                    contentPadding: EdgeInsets.zero,
                                    onChanged: (value) {
                                      setState(() {
                                        _alertType = value!;
                                      });
                                    },
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 8),
                      ElevatedButton.icon(
                        icon: const Icon(Icons.search),
                        onPressed: _setDestination,
                        label: const Text('Set Destination'),
                        style: ElevatedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 24, vertical: 12),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8)),
                        ),
                      ),
                      const SizedBox(height: 8),

                      // Test button for proximity notification/alarm
                      ElevatedButton.icon(
                        icon: Icon(
                          _alertType == 'alarm'
                              ? Icons.alarm
                              : Icons.notifications,
                          size: 18,
                        ),
                        onPressed: () async {
                          // Test the selected alert type
                          await _triggerProximityAlert(
                              _alertRadius.toInt(), 50);
                          if (mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(
                                    '${_alertType == 'alarm' ? 'ALARM' : 'Notification'} triggered! Check your notification panel.'),
                                duration: const Duration(seconds: 3),
                                backgroundColor: _alertType == 'alarm'
                                    ? Colors.red[700]
                                    : Colors.blue[700],
                              ),
                            );
                          }
                        },
                        label: Text(
                          'Test ${_alertType == 'alarm' ? 'ALARM' : 'Notification'}',
                          style: const TextStyle(fontSize: 12),
                        ),
                        style: ElevatedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 16, vertical: 8),
                          backgroundColor: _alertType == 'alarm'
                              ? Colors.red[600]
                              : Colors.blue[600],
                          foregroundColor: Colors.white,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 20),
              Card(
                elevation: 4,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Row(
                        children: [
                          Icon(Icons.directions_walk, color: Colors.orange),
                          SizedBox(width: 8),
                          Text('Live Tracking:',
                              style: TextStyle(fontWeight: FontWeight.bold)),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(_distanceText, style: const TextStyle(fontSize: 18)),
                      Text(_eatText, style: const TextStyle(fontSize: 18)),
                      const SizedBox(height: 8),
                      Text(
                          'Speed: ${_currentPosition != null ? _currentPosition!.speed.toStringAsFixed(2) : 'N/A'} m/s',
                          style: const TextStyle(fontSize: 16)),
                      Text(
                          'Accuracy: ${_currentPosition != null ? _currentPosition!.accuracy.toStringAsFixed(1) : 'N/A'} m',
                          style: const TextStyle(fontSize: 16)),
                      if (_alert.isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.only(top: 8.0),
                          child: Text(_alert,
                              style: const TextStyle(
                                  color: Colors.red,
                                  fontWeight: FontWeight.bold)),
                        ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
