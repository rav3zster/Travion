import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';
import 'dart:async';
import 'eat_utils.dart';

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

  @override
  void initState() {
    super.initState();
    _getCurrentLocation();
  }

  @override
  void dispose() {
    _positionStreamSub?.cancel();
    _destinationController.dispose();
    _alertsController.dispose();
    super.dispose();
  }

  Future<void> _getCurrentLocation() async {
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      setState(() {
        _alert = 'Location services are disabled.';
      });
      return;
    }
    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        setState(() {
          _alert = 'Location permissions are denied.';
        });
        return;
      }
    }
    if (permission == LocationPermission.deniedForever) {
      setState(() {
        _alert = 'Location permissions are permanently denied.';
      });
      return;
    }
    Position position = await Geolocator.getCurrentPosition();
    setState(() {
      _currentPosition = position;
      _alert = '';
    });
  }

  Future<void> _setDestination() async {
    String destinationName = _destinationController.text.trim();
    if (destinationName.isEmpty) {
      setState(() {
        _alert = 'Please enter a destination name.';
      });
      return;
    }
    try {
      List<Location> locations = await locationFromAddress(destinationName);
      if (locations.isNotEmpty) {
        Location loc = locations.first;
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
        });
        _parseAlertDistances();
        _startMonitoring();
      } else {
        setState(() {
          _alert = 'Destination not found.';
        });
      }
    } catch (e) {
      setState(() {
        _alert = 'Error finding destination: $e';
      });
    }
  }

  void _startMonitoring() {
    _positionStreamSub?.cancel();
    _positionStreamSub =
        Geolocator.getPositionStream().listen((Position position) {
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
        String alertMsg = '';
        for (double d in _alertDistances) {
          if (distance <= d) {
            alertMsg =
                'You are within ${d.toInt()} meters of your destination!';
            break;
          }
        }
        setState(() {
          _distanceText = 'Distance to destination: $distanceStr';
          _eatText = 'Estimated Arrival Time: $eatStr';
          _alert = alertMsg;
        });
      }
    });
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
