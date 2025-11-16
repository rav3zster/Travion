import 'package:flutter/material.dart';
import 'dart:convert';
import 'dart:math' as math;
import 'package:flutter/services.dart' show rootBundle;

/// Intelligent Route-Based Alert System
/// Suggests stops based on journey route (Origin → Destination)
class SmartAlertPage extends StatefulWidget {
  const SmartAlertPage({Key? key}) : super(key: key);

  @override
  State<SmartAlertPage> createState() => _SmartAlertPageState();
}

class _SmartAlertPageState extends State<SmartAlertPage> {
  // User input
  String? selectedOrigin;
  String? selectedDestination;

  // Stop suggestions
  List<BusStop> allStops = [];
  List<BusStop> suggestedStops = [];
  Set<String> selectedAlerts = {};

  // UI state
  bool isLoading = false;
  bool showSuggestions = false;
  bool manualMode = false;

  @override
  void initState() {
    super.initState();
    _loadBusStops();
  }

  Future<void> _loadBusStops() async {
    setState(() => isLoading = true);

    try {
      // Load from assets (you'll create this file with your data)
      final String jsonString =
          await rootBundle.loadString('assets/bus_stops.json');
      final List<dynamic> jsonData = json.decode(jsonString);

      allStops = jsonData.map((json) => BusStop.fromJson(json)).toList();
    } catch (e) {
      // If file doesn't exist, use empty list
      print('No bus_stops.json found: $e');
      allStops = [];
    }

    setState(() => isLoading = false);
  }

  void _generateSuggestions() {
    if (selectedOrigin == null || selectedDestination == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Please select both origin and destination')),
      );
      return;
    }

    setState(() {
      isLoading = true;
      suggestedStops = [];
    });

    // Find origin and destination stops
    final origin = allStops.firstWhere(
      (s) => s.name == selectedOrigin,
      orElse: () => allStops.first,
    );
    final destination = allStops.firstWhere(
      (s) => s.name == selectedDestination,
      orElse: () => allStops.last,
    );

    // Filter stops along the route
    suggestedStops = _findStopsBetween(origin, destination);

    setState(() {
      isLoading = false;
      showSuggestions = true;
    });
  }

  List<BusStop> _findStopsBetween(BusStop origin, BusStop destination) {
    List<BusStop> candidates = [];

    // Check each stop
    for (var stop in allStops) {
      // Skip origin and destination
      if (stop.name == origin.name || stop.name == destination.name) {
        continue;
      }

      // Check if stop is on route
      if (_isOnRoute(stop, origin, destination)) {
        final distFromOrigin = _calculateDistance(
          origin.latitude,
          origin.longitude,
          stop.latitude,
          stop.longitude,
        );

        // Calculate ETA (assuming 40 km/h average speed)
        final travelTimeMinutes = (distFromOrigin / 40 * 60).round();
        final eta = DateTime.now().add(Duration(minutes: travelTimeMinutes));

        stop.distanceFromOrigin = distFromOrigin;
        stop.estimatedArrival = eta;
        candidates.add(stop);
      }
    }

    // Sort by distance from origin
    candidates
        .sort((a, b) => a.distanceFromOrigin!.compareTo(b.distanceFromOrigin!));

    return candidates;
  }

  bool _isOnRoute(BusStop point, BusStop origin, BusStop destination) {
    // Check if point lies approximately on route
    final dOrigin = _calculateDistance(
      origin.latitude,
      origin.longitude,
      point.latitude,
      point.longitude,
    );
    final dDest = _calculateDistance(
      point.latitude,
      point.longitude,
      destination.latitude,
      destination.longitude,
    );
    final dDirect = _calculateDistance(
      origin.latitude,
      origin.longitude,
      destination.latitude,
      destination.longitude,
    );

    // Point should be between origin and destination
    final totalDistance = dOrigin + dDest;
    final deviation = totalDistance - dDirect;

    // Allow 5km deviation
    return deviation < 5.0;
  }

  double _calculateDistance(
      double lat1, double lon1, double lat2, double lon2) {
    // Haversine formula
    const R = 6371; // Earth radius in km
    final dLat = _toRadians(lat2 - lat1);
    final dLon = _toRadians(lon2 - lon1);

    final a = math.sin(dLat / 2) * math.sin(dLat / 2) +
        math.cos(_toRadians(lat1)) *
            math.cos(_toRadians(lat2)) *
            math.sin(dLon / 2) *
            math.sin(dLon / 2);

    final c = 2 * math.asin(math.sqrt(a));
    return R * c;
  }

  double _toRadians(double degrees) => degrees * math.pi / 180;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Smart Alert System'),
        backgroundColor: Colors.deepPurple,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _buildInstructionCard(),
            const SizedBox(height: 20),
            _buildRouteSelector(),
            const SizedBox(height: 16),
            _buildActionButtons(),
            if (showSuggestions) ...[
              const SizedBox(height: 24),
              _buildSuggestedStops(),
            ],
          ],
        ),
      ),
      floatingActionButton: selectedAlerts.isNotEmpty
          ? FloatingActionButton.extended(
              onPressed: _activateAlerts,
              icon: const Icon(Icons.notifications_active),
              label: Text('Activate ${selectedAlerts.length} Alerts'),
              backgroundColor: Colors.green,
            )
          : null,
    );
  }

  Widget _buildInstructionCard() {
    return Card(
      color: Colors.deepPurple.shade50,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: const [
                Icon(Icons.lightbulb, color: Colors.deepPurple),
                SizedBox(width: 8),
                Text(
                  'How it works',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.deepPurple,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            const Text(
              '1️⃣ Select your journey route (Origin → Destination)\n'
              '2️⃣ System suggests ONLY relevant stops along your route\n'
              '3️⃣ Choose which stops you want alerts for\n'
              '4️⃣ Get notified when approaching selected stops',
              style: TextStyle(height: 1.5),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRouteSelector() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Journey Route',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),

            // Origin selector
            DropdownButtonFormField<String>(
              decoration: const InputDecoration(
                labelText: 'From (Origin)',
                prefixIcon: Icon(Icons.trip_origin),
                border: OutlineInputBorder(),
              ),
              value: selectedOrigin,
              items: allStops.map((stop) {
                return DropdownMenuItem(
                  value: stop.name,
                  child: Text(stop.name),
                );
              }).toList(),
              onChanged: (value) {
                setState(() => selectedOrigin = value);
              },
            ),

            const SizedBox(height: 16),

            // Destination selector
            DropdownButtonFormField<String>(
              decoration: const InputDecoration(
                labelText: 'To (Destination)',
                prefixIcon: Icon(Icons.location_on),
                border: OutlineInputBorder(),
              ),
              value: selectedDestination,
              items: allStops.map((stop) {
                return DropdownMenuItem(
                  value: stop.name,
                  child: Text(stop.name),
                );
              }).toList(),
              onChanged: (value) {
                setState(() => selectedDestination = value);
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActionButtons() {
    return Column(
      children: [
        ElevatedButton.icon(
          onPressed: _generateSuggestions,
          icon: const Icon(Icons.auto_awesome),
          label: const Text('Suggest Stops for This Route'),
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.deepPurple,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(vertical: 16),
            minimumSize: const Size.fromHeight(50),
          ),
        ),
        const SizedBox(height: 8),
        OutlinedButton.icon(
          onPressed: () {
            setState(() => manualMode = true);
            // Show all stops for manual selection
          },
          icon: const Icon(Icons.edit_location),
          label: const Text('Choose Stops Manually'),
          style: OutlinedButton.styleFrom(
            padding: const EdgeInsets.symmetric(vertical: 16),
            minimumSize: const Size.fromHeight(50),
          ),
        ),
      ],
    );
  }

  Widget _buildSuggestedStops() {
    if (suggestedStops.isEmpty) {
      return Card(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            children: const [
              Icon(Icons.info_outline, size: 48, color: Colors.grey),
              SizedBox(height: 16),
              Text(
                'No stops found on this route',
                style: TextStyle(fontSize: 16, color: Colors.grey),
              ),
            ],
          ),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Suggested Stops (${suggestedStops.length})',
          style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        const Text(
          'Select stops where you want to be alerted',
          style: TextStyle(color: Colors.grey),
        ),
        const SizedBox(height: 16),
        ...suggestedStops.asMap().entries.map((entry) {
          final index = entry.key;
          final stop = entry.value;
          final isSelected = selectedAlerts.contains(stop.name);

          return Card(
            margin: const EdgeInsets.only(bottom: 12),
            color: isSelected ? Colors.deepPurple.shade50 : null,
            child: CheckboxListTile(
              value: isSelected,
              onChanged: (checked) {
                setState(() {
                  if (checked == true) {
                    selectedAlerts.add(stop.name);
                  } else {
                    selectedAlerts.remove(stop.name);
                  }
                });
              },
              title: Text(
                '${index + 1}. ${stop.name}',
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              subtitle: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      const Icon(Icons.straighten,
                          size: 16, color: Colors.grey),
                      const SizedBox(width: 4),
                      Text(
                          '${stop.distanceFromOrigin?.toStringAsFixed(1)} km from start'),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      const Icon(Icons.access_time,
                          size: 16, color: Colors.grey),
                      const SizedBox(width: 4),
                      Text('ETA: ${_formatTime(stop.estimatedArrival)}'),
                    ],
                  ),
                ],
              ),
              secondary: CircleAvatar(
                backgroundColor: isSelected ? Colors.deepPurple : Colors.grey,
                child: Text(
                  '${index + 1}',
                  style: const TextStyle(color: Colors.white),
                ),
              ),
            ),
          );
        }).toList(),
      ],
    );
  }

  String _formatTime(DateTime? time) {
    if (time == null) return 'Unknown';
    final hour = time.hour % 12 == 0 ? 12 : time.hour % 12;
    final period = time.hour >= 12 ? 'PM' : 'AM';
    return '$hour:${time.minute.toString().padLeft(2, '0')} $period';
  }

  void _activateAlerts() {
    // Save alerts and start monitoring
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Alerts Activated!'),
        content: Text(
          'You will be notified when approaching:\n\n' +
              selectedAlerts.map((name) => '• $name').join('\n'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }
}

class BusStop {
  final String id;
  final String name;
  final double latitude;
  final double longitude;
  double? distanceFromOrigin;
  DateTime? estimatedArrival;

  BusStop({
    required this.id,
    required this.name,
    required this.latitude,
    required this.longitude,
    this.distanceFromOrigin,
    this.estimatedArrival,
  });

  factory BusStop.fromJson(Map<String, dynamic> json) {
    return BusStop(
      id: json['stop_id']?.toString() ?? '',
      name: json['stop_name'] ?? '',
      latitude: (json['latitude'] ?? 0.0).toDouble(),
      longitude: (json['longitude'] ?? 0.0).toDouble(),
    );
  }
}
