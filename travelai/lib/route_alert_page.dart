import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:flutter_polyline_points/flutter_polyline_points.dart';
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';
import 'package:mappls_gl/mappls_gl.dart' as mappls;
import 'mapmyindia_config.dart';
import 'eat_utils.dart';

class RouteAlertPage extends StatefulWidget {
  const RouteAlertPage({super.key});

  @override
  State<RouteAlertPage> createState() => _RouteAlertPageState();
}

class _RouteAlertPageState extends State<RouteAlertPage> {
  mappls.MapplsMapController? _mapController;
  mappls.LatLng? _originLatLng;
  mappls.LatLng? _destLatLng;
  List<mappls.LatLng> _routePoints = [];
  Position? _currentPosition;
  final TextEditingController _destinationController = TextEditingController();
  String _alert = '';
  String _distanceText = '';
  String _eatText = '';
  bool _isLoading = false;
  bool _showLiveTracking = false;
  mappls.Symbol? _liveLocationSymbol;

  @override
  void initState() {
    Geolocator.getPositionStream().listen((Position position) async {
      if (_showLiveTracking && _mapController != null) {
        setState(() {
          _currentPosition = position;
        });
        final liveLatLng = mappls.LatLng(position.latitude, position.longitude);
        if (_liveLocationSymbol != null) {
          _mapController!.updateSymbol(
              _liveLocationSymbol!, mappls.SymbolOptions(geometry: liveLatLng));
        } else {
          _liveLocationSymbol =
              await _mapController!.addSymbol(mappls.SymbolOptions(
            geometry: liveLatLng,
            iconImage: "assets/origin.png",
          ));
        }
        _mapController!
            .animateCamera(mappls.CameraUpdate.newLatLng(liveLatLng));
      }
    });
    super.initState();
    _getCurrentLocation();
  }

  Future<void> _getCurrentLocation() async {
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      setState(() => _alert = 'Location services are disabled.');
      return;
    }

    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        setState(() => _alert = 'Location permissions are denied.');
        return;
      }
    }

    if (permission == LocationPermission.deniedForever) {
      setState(() => _alert = 'Location permissions are permanently denied.');
      return;
    }

    // Get position and update state together
    Position position = await Geolocator.getCurrentPosition();
    if (mounted) {
      setState(() {
        _currentPosition = position;
        _originLatLng = mappls.LatLng(position.latitude, position.longitude);
        _alert = '';
      });
    }
  }

  Future<void> _getRouteFromMapmyIndia() async {
    if (_originLatLng == null || _destLatLng == null) return;

    const String restApiKey = MapmyIndiaConfig.restMapSdkKey;
    if (restApiKey.isEmpty || restApiKey == 'YOUR_MAPPLS_REST_KEY') {
      setState(() {
        _alert =
            'MapmyIndia/Mappls SDK key missing! Please set your REST API key in mapmyindia_config.dart.';
        _distanceText = '';
        _eatText = '';
      });
      return;
    }

    final String originCoords =
        "${_originLatLng!.longitude},${_originLatLng!.latitude}";
    final String destCoords =
        "${_destLatLng!.longitude},${_destLatLng!.latitude}";

    final url = Uri.parse(
        'https://apis.mappls.com/advancedmaps/v1/$restApiKey/route_adv/driving/$originCoords;$destCoords?geometries=polyline');

    try {
      final response = await http.get(url);
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final route = data['routes'][0];
        final distance = route['distance']; // in meters
        final duration = route['duration']; // in seconds
        final geometry = route['geometry'];

        // Decode the polyline
        PolylinePoints polylinePoints = PolylinePoints();
        List<PointLatLng> decodedResult =
            polylinePoints.decodePolyline(geometry);
        _routePoints = decodedResult
            .map((point) => mappls.LatLng(point.latitude, point.longitude))
            .toList();

        // Update UI with actual route data
        setState(() {
          _distanceText =
              'Distance: ${(distance / 1000).toStringAsFixed(2)} km';
          _eatText =
              'Estimated Duration: ${(duration / 60).toStringAsFixed(0)} mins';
          _alert = 'Route fetched successfully!';
        });

        _drawRouteOnMap();
      } else {
        setState(() => _alert = 'Error fetching route: ${response.body}');
      }
    } catch (e) {
      setState(() => _alert = 'Error: $e');
    }
  }

  void _drawRouteOnMap() {
    if (_mapController == null || _routePoints.isEmpty) return;

    _mapController!.clearSymbols();
    _mapController!.clearLines();

    _mapController!.addSymbol(mappls.SymbolOptions(
      geometry: _originLatLng!,
      iconImage: "assets/origin.png",
    ));
    _mapController!.addSymbol(mappls.SymbolOptions(
      geometry: _destLatLng!,
      iconImage: "assets/destination.png",
    ));
    _mapController!.addLine(mappls.LineOptions(
      geometry: _routePoints,
      lineColor: "#0000FF",
      lineWidth: 5.0,
    ));

    // Animate camera to fit the route
    final bounds = mappls.LatLngBounds(
      southwest: _routePoints.reduce((a, b) => mappls.LatLng(
          a.latitude < b.latitude ? a.latitude : b.latitude,
          a.longitude < b.longitude ? a.longitude : b.longitude)),
      northeast: _routePoints.reduce((a, b) => mappls.LatLng(
          a.latitude > b.latitude ? a.latitude : b.latitude,
          a.longitude > b.longitude ? a.longitude : b.longitude)),
    );
    _mapController!.animateCamera(mappls.CameraUpdate.newLatLngBounds(bounds,
        top: 40, bottom: 40, left: 40, right: 40));
  }

  void _findRoute() async {
    final String destinationName = _destinationController.text.trim();
    if (destinationName.isEmpty) {
      setState(() => _alert = 'Please enter a destination name.');
      return;
    }
    if (_currentPosition == null) {
      setState(() => _alert = 'Current location not available.');
      return;
    }

    setState(() => _isLoading = true);

    try {
      List<Location> locations = await locationFromAddress(destinationName);
      if (locations.isNotEmpty) {
        final dest = locations.first;
        _destLatLng = mappls.LatLng(dest.latitude, dest.longitude);

        // Show current progress and details immediately after destination is set
        double distance = Geolocator.distanceBetween(
          _currentPosition!.latitude,
          _currentPosition!.longitude,
          dest.latitude,
          dest.longitude,
        );
        setState(() {
          _distanceText =
              'Current Distance: ${(distance / 1000).toStringAsFixed(2)} km';
          _eatText =
              'Estimated Arrival Time: ${calculateEAT(distance, _currentPosition!.speed)}';
          _alert = 'Destination set. Fetching route...';
          _routePoints = [_originLatLng!, _destLatLng!];
        });
        await _getRouteFromMapmyIndia();
        // Do not auto-navigate to live map. Show info on current page.
      } else {
        setState(() => _alert = 'Destination not found.');
      }
    } catch (e) {
      setState(() => _alert = 'Error finding destination: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  @override
  void dispose() {
    _destinationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Route Alert (Online/Offline)')),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // --- UI Card for Controls ---
              Card(
                elevation: 4,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // Current Location Section with live tracking toggle
                      Row(
                        children: [
                          const Icon(Icons.my_location,
                              color: Colors.blueAccent),
                          const SizedBox(width: 8),
                          const Text('Current Location:',
                              style: TextStyle(fontWeight: FontWeight.bold)),
                          const Spacer(),
                          Switch(
                            value: _showLiveTracking,
                            onChanged: (val) {
                              setState(() {
                                _showLiveTracking = val;
                              });
                              if (val &&
                                  _originLatLng != null &&
                                  _destLatLng != null &&
                                  _routePoints.isNotEmpty) {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (context) => RouteTrackingPage(
                                      origin: _originLatLng!,
                                      destination: _destLatLng!,
                                      routePoints: _routePoints,
                                    ),
                                  ),
                                );
                              }
                            },
                          ),
                          const Text('Live',
                              style: TextStyle(fontWeight: FontWeight.bold)),
                        ],
                      ),
                      Padding(
                        padding: const EdgeInsets.only(top: 4.0, bottom: 8.0),
                        child: _currentPosition == null
                            ? const Text('Detecting...',
                                style: TextStyle(color: Colors.grey))
                            : Text(
                                'Lat: ${_currentPosition!.latitude.toStringAsFixed(5)}, Lng: ${_currentPosition!.longitude.toStringAsFixed(5)}',
                                style: const TextStyle(
                                    fontSize: 16, color: Colors.black87)),
                      ),
                      const Divider(),
                      // Destination Input
                      TextField(
                        controller: _destinationController,
                        decoration: const InputDecoration(
                            labelText: 'Destination',
                            hintText: 'Enter destination'),
                      ),
                      const SizedBox(height: 12),
                      // Find Route Button
                      ElevatedButton.icon(
                        icon: const Icon(Icons.alt_route),
                        onPressed: _isLoading ? null : _findRoute,
                        label: Text(_isLoading
                            ? 'Finding...'
                            : 'Find Route & Set Alerts'),
                        style: ElevatedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 24, vertical: 12),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              // Info Texts
              const Divider(),
              if (_alert.isNotEmpty)
                Padding(
                    padding: const EdgeInsets.only(top: 8.0),
                    child: Text(_alert,
                        style: TextStyle(
                            color: _alert.toLowerCase().contains('error') ||
                                    _alert.toLowerCase().contains('missing')
                                ? Colors.red
                                : Colors.green,
                            fontWeight: FontWeight.bold))),
              if (_distanceText.isNotEmpty)
                Padding(
                    padding: const EdgeInsets.only(top: 8.0),
                    child: Text(_distanceText,
                        style: const TextStyle(fontSize: 18))),
              if (_eatText.isNotEmpty)
                Padding(
                    padding: const EdgeInsets.only(top: 4.0),
                    child:
                        Text(_eatText, style: const TextStyle(fontSize: 18))),
              // Show live/detailed info after destination is set, if not opted for live map
              if (_destLatLng != null &&
                  !_showLiveTracking &&
                  _currentPosition != null)
                Card(
                  margin: const EdgeInsets.symmetric(vertical: 12),
                  elevation: 2,
                  child: Padding(
                    padding: const EdgeInsets.all(12.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Current Coordinates:',
                            style: TextStyle(fontWeight: FontWeight.bold)),
                        Text(
                            'Lat: ${_currentPosition!.latitude.toStringAsFixed(6)}, Lng: ${_currentPosition!.longitude.toStringAsFixed(6)}'),
                        const Text('Destination Coordinates:',
                            style: TextStyle(fontWeight: FontWeight.bold)),
                        Text(
                            'Lat: ${_destLatLng!.latitude.toStringAsFixed(6)}, Lng: ${_destLatLng!.longitude.toStringAsFixed(6)}'),
                        const SizedBox(height: 8),
                        Text(
                            'Live Speed: ${(_currentPosition!.speed * 3.6).toStringAsFixed(1)} km/h'),
                        Text(
                            'Accuracy: ${_currentPosition!.accuracy.toStringAsFixed(1)} m'),
                        Text(
                            'Altitude: ${_currentPosition!.altitude.toStringAsFixed(1)} m'),
                        Text(
                            'Heading: ${_currentPosition!.heading.toStringAsFixed(1)}°'),
                        const SizedBox(height: 8),
                        Builder(
                          builder: (context) {
                            double remainingDistanceKm;
                            int eatMinutes = 0;
                            int eatHours = 0;
                            String eatText = 'Estimated Arrival Time: --';
                            // If user hasn't started (speed < 1 km/h), show full route distance and EAT from route API
                            if (_currentPosition!.speed < 1.0 &&
                                _distanceText.isNotEmpty) {
                              final match = RegExp(r'Distance: ([\d\.]+) km')
                                  .firstMatch(_distanceText);
                              remainingDistanceKm = match != null
                                  ? double.tryParse(match.group(1) ?? '') ?? 0.0
                                  : 0.0;
                              final durationMatch =
                                  RegExp(r'Estimated Duration: ([\d]+) mins')
                                      .firstMatch(_eatText);
                              if (durationMatch != null) {
                                eatMinutes = int.tryParse(
                                        durationMatch.group(1) ?? '') ??
                                    0;
                                eatHours = (eatMinutes / 60).floor();
                                eatMinutes = eatMinutes % 60;
                                eatText =
                                    'Estimated Arrival Time: ${eatHours}h ${eatMinutes}m';
                              }
                            } else {
                              // Use device sensor speed for live EAT and remaining distance
                              remainingDistanceKm = Geolocator.distanceBetween(
                                    _currentPosition!.latitude,
                                    _currentPosition!.longitude,
                                    _destLatLng!.latitude,
                                    _destLatLng!.longitude,
                                  ) /
                                  1000.0;
                              double liveSpeed =
                                  _currentPosition!.speed * 3.6; // m/s to km/h
                              if (liveSpeed > 0) {
                                double eatSeconds =
                                    (remainingDistanceKm / liveSpeed) *
                                        3600; // hours to seconds
                                eatHours = (eatSeconds / 3600).floor();
                                eatMinutes = ((eatSeconds % 3600) / 60).floor();
                                eatText =
                                    'Estimated Arrival Time: ${eatHours}h ${eatMinutes}m';
                              }
                            }
                            return Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                    'Remaining Distance: ${remainingDistanceKm.toStringAsFixed(2)} km'),
                                Text(eatText),
                              ],
                            );
                          },
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

// --- RouteTrackingPage ---
class RouteTrackingPage extends StatefulWidget {
  final mappls.LatLng origin;
  final mappls.LatLng destination;
  final List<mappls.LatLng> routePoints;
  const RouteTrackingPage({
    required this.origin,
    required this.destination,
    required this.routePoints,
    super.key,
  });

  @override
  State<RouteTrackingPage> createState() => _RouteTrackingPageState();
}

class _RouteTrackingPageState extends State<RouteTrackingPage> {
  mappls.MapplsMapController? _mapController;
  bool _showLiveTracking = true;
  Position? _currentPosition;
  mappls.Symbol? _liveLocationSymbol;
  Stream<Position>? _positionStream;
  double _liveSpeed = 0.0;
  double _liveAccuracy = 0.0;
  String _liveEat = '';

  @override
  void initState() {
    super.initState();
    _startLiveTracking();
  }

  void _startLiveTracking() {
    _positionStream = Geolocator.getPositionStream();
    _positionStream!.listen((Position position) async {
      if (_showLiveTracking && _mapController != null) {
        setState(() {
          _currentPosition = position;
          _liveSpeed = position.speed;
          _liveAccuracy = position.accuracy;
          _liveEat = _calculateLiveEat();
        });
        final liveLatLng = mappls.LatLng(position.latitude, position.longitude);
        if (_liveLocationSymbol != null) {
          _mapController!.updateSymbol(
              _liveLocationSymbol!, mappls.SymbolOptions(geometry: liveLatLng));
        } else {
          _liveLocationSymbol =
              await _mapController!.addSymbol(mappls.SymbolOptions(
            geometry: liveLatLng,
            iconImage: "assets/origin.png",
          ));
        }
        _mapController!
            .animateCamera(mappls.CameraUpdate.newLatLng(liveLatLng));
      }
    });
  }

  String _calculateLiveEat() {
    if (_currentPosition == null) return '';
    final double distance = Geolocator.distanceBetween(
      _currentPosition!.latitude,
      _currentPosition!.longitude,
      widget.destination.latitude,
      widget.destination.longitude,
    );
    if (_liveSpeed > 0) {
      final etaMinutes = (distance / _liveSpeed) / 60;
      return 'ETA: ${etaMinutes.toStringAsFixed(1)} min';
    } else {
      return 'ETA: --';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Live Route Tracking')),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Row(
              children: [
                const Icon(Icons.my_location, color: Colors.blueAccent),
                const SizedBox(width: 8),
                const Text('Live Tracking:',
                    style: TextStyle(fontWeight: FontWeight.bold)),
                const Spacer(),
                Switch(
                  value: _showLiveTracking,
                  onChanged: (val) {
                    setState(() {
                      _showLiveTracking = val;
                    });
                    // Restart stream to reflect toggle
                    if (_showLiveTracking) {
                      _startLiveTracking();
                    }
                  },
                ),
                const Text('Live',
                    style: TextStyle(fontWeight: FontWeight.bold)),
              ],
            ),
          ),
          // Additional Info Card
          if (_currentPosition != null)
            Card(
              margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              elevation: 2,
              child: Padding(
                padding: const EdgeInsets.all(12.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Speed: ${(_liveSpeed * 3.6).toStringAsFixed(1)} km/h',
                        style: const TextStyle(fontSize: 16)),
                    Text(_liveEat, style: const TextStyle(fontSize: 16)),
                    Text('Accuracy: ${_liveAccuracy.toStringAsFixed(1)} m',
                        style: const TextStyle(fontSize: 16)),
                  ],
                ),
              ),
            ),
          Expanded(
            child: mappls.MapplsMap(
              initialCameraPosition: mappls.CameraPosition(
                target: widget.origin,
                zoom: 13,
              ),
              onMapCreated: (controller) {
                _mapController = controller;
                // Draw route
                controller.addLine(mappls.LineOptions(
                  geometry: widget.routePoints,
                  lineColor: "#0000FF",
                  lineWidth: 5.0,
                ));
                // Add origin and destination markers
                controller.addSymbol(mappls.SymbolOptions(
                  geometry: widget.origin,
                  iconImage: "assets/origin.png",
                ));
                controller.addSymbol(mappls.SymbolOptions(
                  geometry: widget.destination,
                  iconImage: "assets/destination.png",
                ));
              },
            ),
          ),
        ],
      ),
    );
  }
}
