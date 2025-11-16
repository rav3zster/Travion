import 'dart:convert';
import 'package:geolocator/geolocator.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/bus_stop.dart';

/// Service to manage bus stops and proximity detection
class BusStopService {
  static const String _busStopsKey = 'bus_stops';

  // Distance in meters to trigger alert (default 500m)
  final double alertDistance;

  // Track which stops have already been alerted in current trip
  final Set<String> _alertedStopsInTrip = {};

  BusStopService({this.alertDistance = 500.0});

  /// Get sample bus stops for Mangalore to NMAMIT route
  static List<BusStop> getSampleBusStops() {
    return [
      BusStop(
        id: '1',
        name: 'Mangalore Central Bus Stand',
        latitude: 12.8698,
        longitude: 74.8428,
        description: 'Starting point - Main bus stand',
        sequenceNumber: 1,
      ),
      BusStop(
        id: '2',
        name: 'Hampankatta Circle',
        latitude: 12.8731,
        longitude: 74.8430,
        description: 'Major junction in city center',
        sequenceNumber: 2,
      ),
      BusStop(
        id: '3',
        name: 'Kottara Chowki',
        latitude: 12.8988,
        longitude: 74.8563,
        description: 'Important stop near Kottara',
        sequenceNumber: 3,
      ),
      BusStop(
        id: '4',
        name: 'Surathkal Junction',
        latitude: 13.0067,
        longitude: 74.7955,
        description: 'NITK Surathkal area',
        sequenceNumber: 4,
      ),
      BusStop(
        id: '5',
        name: 'Katipalla',
        latitude: 13.0847,
        longitude: 74.7969,
        description: 'Midway stop',
        sequenceNumber: 5,
      ),
      BusStop(
        id: '6',
        name: 'Nitte Junction',
        latitude: 13.1831,
        longitude: 74.9503,
        description: 'Junction near Nitte',
        sequenceNumber: 6,
      ),
      BusStop(
        id: '7',
        name: 'NMAMIT College',
        latitude: 13.1853,
        longitude: 74.9495,
        description: 'Destination - NMAM Institute of Technology',
        sequenceNumber: 7,
      ),
    ];
  }

  /// Save bus stops to local storage
  Future<void> saveBusStops(List<BusStop> stops) async {
    final prefs = await SharedPreferences.getInstance();
    final stopsJson = stops.map((stop) => stop.toJson()).toList();
    await prefs.setString(_busStopsKey, jsonEncode(stopsJson));
  }

  /// Load bus stops from local storage
  Future<List<BusStop>> loadBusStops() async {
    final prefs = await SharedPreferences.getInstance();
    final stopsJson = prefs.getString(_busStopsKey);

    if (stopsJson == null || stopsJson.isEmpty) {
      // Return sample stops if none saved
      return getSampleBusStops();
    }

    final List<dynamic> decoded = jsonDecode(stopsJson);
    return decoded.map((json) => BusStop.fromJson(json)).toList();
  }

  /// Add a new bus stop
  Future<void> addBusStop(BusStop stop) async {
    final stops = await loadBusStops();
    stops.add(stop);
    await saveBusStops(stops);
  }

  /// Remove a bus stop
  Future<void> removeBusStop(String stopId) async {
    final stops = await loadBusStops();
    stops.removeWhere((stop) => stop.id == stopId);
    await saveBusStops(stops);
  }

  /// Calculate distance between two coordinates in meters
  double calculateDistance(double lat1, double lon1, double lat2, double lon2) {
    return Geolocator.distanceBetween(lat1, lon1, lat2, lon2);
  }

  /// Check if current position is near any bus stop
  /// Returns list of nearby stops that should trigger alerts
  Future<List<BusStopAlert>> checkNearbyStops(Position currentPosition) async {
    final stops = await loadBusStops();
    final List<BusStopAlert> nearbyStops = [];

    for (final stop in stops) {
      // Skip if already alerted for this stop in current trip
      if (_alertedStopsInTrip.contains(stop.id)) {
        continue;
      }

      final distance = calculateDistance(
        currentPosition.latitude,
        currentPosition.longitude,
        stop.latitude,
        stop.longitude,
      );

      if (distance <= alertDistance) {
        nearbyStops.add(BusStopAlert(
          stop: stop,
          distance: distance,
          estimatedTimeMinutes:
              _estimateArrivalTime(distance, currentPosition.speed),
        ));

        // Mark this stop as alerted
        _alertedStopsInTrip.add(stop.id);
      }
    }

    // Sort by distance
    nearbyStops.sort((a, b) => a.distance.compareTo(b.distance));
    return nearbyStops;
  }

  /// Estimate arrival time based on distance and current speed
  int _estimateArrivalTime(double distanceMeters, double speedMps) {
    if (speedMps <= 0) {
      return 0; // Can't estimate without speed
    }

    // Convert speed from m/s to km/h and calculate time
    final speedKmh = speedMps * 3.6;
    final distanceKm = distanceMeters / 1000;
    final timeHours = distanceKm / speedKmh;
    final timeMinutes = (timeHours * 60).round();

    return timeMinutes > 0 ? timeMinutes : 1;
  }

  /// Reset alerted stops for a new trip
  void resetTripAlerts() {
    _alertedStopsInTrip.clear();
  }

  /// Get next stop based on current position
  Future<BusStop?> getNextStop(Position currentPosition) async {
    final stops = await loadBusStops();
    BusStop? nextStop;
    double minDistance = double.infinity;

    for (final stop in stops) {
      if (_alertedStopsInTrip.contains(stop.id)) {
        continue; // Skip already passed stops
      }

      final distance = calculateDistance(
        currentPosition.latitude,
        currentPosition.longitude,
        stop.latitude,
        stop.longitude,
      );

      if (distance < minDistance) {
        minDistance = distance;
        nextStop = stop;
      }
    }

    return nextStop;
  }
}

/// Alert data for a nearby bus stop
class BusStopAlert {
  final BusStop stop;
  final double distance; // in meters
  final int estimatedTimeMinutes;

  BusStopAlert({
    required this.stop,
    required this.distance,
    required this.estimatedTimeMinutes,
  });

  String get distanceText {
    if (distance < 1000) {
      return '${distance.round()} m';
    } else {
      return '${(distance / 1000).toStringAsFixed(1)} km';
    }
  }
}
