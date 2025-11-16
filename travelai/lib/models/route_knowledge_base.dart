import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/bus_stop.dart';

/// Represents a route with multiple bus stops
class RouteInfo {
  final String id;
  final String name;
  final String description;
  final List<BusStop> stops;
  final List<String> landmarks;
  final List<String> keywords; // For search optimization
  final double startLat;
  final double startLng;
  final double endLat;
  final double endLng;

  RouteInfo({
    required this.id,
    required this.name,
    required this.description,
    required this.stops,
    required this.landmarks,
    required this.keywords,
    required this.startLat,
    required this.startLng,
    required this.endLat,
    required this.endLng,
  });

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'description': description,
      'stops': stops.map((s) => s.toJson()).toList(),
      'landmarks': landmarks,
      'keywords': keywords,
      'startLat': startLat,
      'startLng': startLng,
      'endLat': endLat,
      'endLng': endLng,
    };
  }

  factory RouteInfo.fromJson(Map<String, dynamic> json) {
    return RouteInfo(
      id: json['id'],
      name: json['name'],
      description: json['description'],
      stops: (json['stops'] as List).map((s) => BusStop.fromJson(s)).toList(),
      landmarks: List<String>.from(json['landmarks']),
      keywords: List<String>.from(json['keywords']),
      startLat: json['startLat'],
      startLng: json['startLng'],
      endLat: json['endLat'],
      endLng: json['endLng'],
    );
  }

  /// Get full text representation for embedding
  String getFullText() {
    return '''
Route: $name
Description: $description
Landmarks: ${landmarks.join(', ')}
Stops: ${stops.map((s) => s.name).join(' -> ')}
Keywords: ${keywords.join(', ')}
''';
  }
}

/// Knowledge base for routes and stops
class RouteKnowledgeBase {
  static const String _routesKey = 'route_knowledge_base';

  /// Get predefined routes with rich context
  static List<RouteInfo> getPredefinedRoutes() {
    return [
      // Mangalore to NMAMIT route
      RouteInfo(
        id: 'route_1',
        name: 'Mangalore to NMAMIT College Nitte',
        description:
            'Main route from Mangalore city to NMAM Institute of Technology in Nitte via NH66',
        stops: [
          BusStop(
            id: '1',
            name: 'Mangalore Central Bus Stand',
            latitude: 12.8698,
            longitude: 74.8428,
            description: 'Main KSRTC bus stand in Mangalore city center',
            sequenceNumber: 1,
          ),
          BusStop(
            id: '2',
            name: 'Hampankatta Circle',
            latitude: 12.8731,
            longitude: 74.8430,
            description: 'Major junction and shopping area in Mangalore',
            sequenceNumber: 2,
          ),
          BusStop(
            id: '3',
            name: 'Kottara Chowki',
            latitude: 12.8988,
            longitude: 74.8563,
            description: 'Important junction near Kottara market area',
            sequenceNumber: 3,
          ),
          BusStop(
            id: '4',
            name: 'Surathkal Junction',
            latitude: 13.0067,
            longitude: 74.7955,
            description: 'NITK Surathkal area, major educational hub',
            sequenceNumber: 4,
          ),
          BusStop(
            id: '5',
            name: 'Katipalla',
            latitude: 13.0847,
            longitude: 74.7969,
            description: 'Junction on NH66, midway point',
            sequenceNumber: 5,
          ),
          BusStop(
            id: '6',
            name: 'Nitte Junction',
            latitude: 13.1831,
            longitude: 74.9503,
            description: 'Main junction in Nitte town, near KMC Hospital',
            sequenceNumber: 6,
          ),
          BusStop(
            id: '7',
            name: 'NMAMIT College',
            latitude: 13.1853,
            longitude: 74.9495,
            description:
                'NMAM Institute of Technology, Nitte - Engineering College',
            sequenceNumber: 7,
          ),
        ],
        landmarks: [
          'Mangalore Central',
          'KSRTC Bus Stand',
          'Hampankatta',
          'City Center Mall',
          'Kottara',
          'NITK Surathkal',
          'National Institute of Technology',
          'Katipalla Junction',
          'Nitte',
          'KMC Hospital',
          'NMAMIT',
          'Engineering College',
        ],
        keywords: [
          'mangalore',
          'nitte',
          'nmamit',
          'nmam',
          'engineering college',
          'surathkal',
          'nitk',
          'kottara',
          'hampankatta',
          'nh66',
          'national highway',
          'karnataka',
          'udupi',
          'karkala',
        ],
        startLat: 12.8698,
        startLng: 74.8428,
        endLat: 13.1853,
        endLng: 74.9495,
      ),

      // Mangalore to Udupi route
      RouteInfo(
        id: 'route_2',
        name: 'Mangalore to Udupi via NH66',
        description:
            'Coastal route from Mangalore to Udupi passing through Surathkal and Kaup',
        stops: [
          BusStop(
            id: '11',
            name: 'Mangalore Bus Stand',
            latitude: 12.8698,
            longitude: 74.8428,
            description: 'Starting point - Mangalore KSRTC',
            sequenceNumber: 1,
          ),
          BusStop(
            id: '12',
            name: 'Surathkal',
            latitude: 13.0067,
            longitude: 74.7955,
            description: 'NITK area',
            sequenceNumber: 2,
          ),
          BusStop(
            id: '13',
            name: 'Katipalla Junction',
            latitude: 13.0847,
            longitude: 74.7969,
            description: 'Major junction',
            sequenceNumber: 3,
          ),
          BusStop(
            id: '14',
            name: 'Kaup Beach',
            latitude: 13.2286,
            longitude: 74.7495,
            description: 'Famous beach and lighthouse',
            sequenceNumber: 4,
          ),
          BusStop(
            id: '15',
            name: 'Udupi Bus Stand',
            latitude: 13.3409,
            longitude: 74.7421,
            description: 'Main bus stand in Udupi city',
            sequenceNumber: 5,
          ),
        ],
        landmarks: [
          'Mangalore',
          'Surathkal Beach',
          'NITK',
          'Katipalla',
          'Kaup Beach',
          'Kaup Lighthouse',
          'Udupi',
          'Krishna Temple',
          'Service Bus Stand',
        ],
        keywords: [
          'mangalore',
          'udupi',
          'coastal',
          'beach',
          'kaup',
          'surathkal',
          'nh66',
          'temple',
          'krishna',
          'pilgrimage',
        ],
        startLat: 12.8698,
        startLng: 74.8428,
        endLat: 13.3409,
        endLng: 74.7421,
      ),
    ];
  }

  /// Save routes to local storage
  static Future<void> saveRoutes(List<RouteInfo> routes) async {
    final prefs = await SharedPreferences.getInstance();
    final routesJson = routes.map((r) => r.toJson()).toList();
    await prefs.setString(_routesKey, jsonEncode(routesJson));
  }

  /// Load routes from local storage
  static Future<List<RouteInfo>> loadRoutes() async {
    final prefs = await SharedPreferences.getInstance();
    final routesJson = prefs.getString(_routesKey);

    if (routesJson == null || routesJson.isEmpty) {
      return getPredefinedRoutes();
    }

    final List<dynamic> decoded = jsonDecode(routesJson);
    return decoded.map((json) => RouteInfo.fromJson(json)).toList();
  }

  /// Add a new route
  static Future<void> addRoute(RouteInfo route) async {
    final routes = await loadRoutes();
    routes.add(route);
    await saveRoutes(routes);
  }
}
