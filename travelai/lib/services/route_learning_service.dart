import 'dart:async';
import 'dart:math' as math;
import 'package:geolocator/geolocator.dart';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';

/// Service that learns actual bus routes by recording GPS paths and detecting stop sequences
class RouteLearningService {
  static Database? _database;
  Timer? _recordingTimer;
  bool _isRecording = false;
  String? _currentJourneyId;
  Position? _lastRecordedPosition;

  // Recording settings
  static const int recordingIntervalSeconds = 5; // Record GPS every 5 seconds
  static const double minDistanceMeters = 10.0; // Only record if moved 10m
  static const double stopProximityMeters = 100.0; // Stop detection radius

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDatabase();
    return _database!;
  }

  Future<Database> _initDatabase() async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, 'route_learning.db');

    return await openDatabase(
      path,
      version: 1,
      onCreate: (db, version) async {
        // Table 1: GPS Breadcrumbs (continuous path recording)
        await db.execute('''
          CREATE TABLE gps_breadcrumbs (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            journey_id TEXT NOT NULL,
            latitude REAL NOT NULL,
            longitude REAL NOT NULL,
            altitude REAL,
            accuracy REAL,
            speed REAL,
            heading REAL,
            timestamp INTEGER NOT NULL,
            INDEX idx_journey (journey_id)
          )
        ''');

        // Table 2: Detected Stops on Journey
        await db.execute('''
          CREATE TABLE journey_stops (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            journey_id TEXT NOT NULL,
            stop_name TEXT,
            latitude REAL NOT NULL,
            longitude REAL NOT NULL,
            arrival_time INTEGER NOT NULL,
            departure_time INTEGER,
            dwell_seconds INTEGER,
            stop_sequence INTEGER NOT NULL,
            is_bus_stop INTEGER DEFAULT 0,
            INDEX idx_journey_seq (journey_id, stop_sequence)
          )
        ''');

        // Table 3: Journeys (complete trip records)
        await db.execute('''
          CREATE TABLE journeys (
            journey_id TEXT PRIMARY KEY,
            start_location TEXT,
            end_location TEXT,
            start_time INTEGER NOT NULL,
            end_time INTEGER,
            total_distance_km REAL,
            total_stops INTEGER DEFAULT 0,
            route_name TEXT,
            is_complete INTEGER DEFAULT 0
          )
        ''');

        // Table 4: Learned Routes (patterns from multiple journeys)
        await db.execute('''
          CREATE TABLE learned_routes (
            route_id TEXT PRIMARY KEY,
            route_name TEXT NOT NULL,
            origin_name TEXT NOT NULL,
            destination_name TEXT NOT NULL,
            stop_sequence TEXT NOT NULL,
            journey_count INTEGER DEFAULT 1,
            avg_duration_minutes INTEGER,
            avg_distance_km REAL,
            last_traveled INTEGER,
            confidence_score REAL DEFAULT 0.5,
            UNIQUE(origin_name, destination_name, stop_sequence)
          )
        ''');

        // Table 5: Route Stops (detailed stop information for learned routes)
        await db.execute('''
          CREATE TABLE route_stops (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            route_id TEXT NOT NULL,
            stop_name TEXT NOT NULL,
            latitude REAL NOT NULL,
            longitude REAL NOT NULL,
            stop_sequence INTEGER NOT NULL,
            avg_dwell_seconds INTEGER,
            avg_distance_from_prev_km REAL,
            FOREIGN KEY (route_id) REFERENCES learned_routes(route_id),
            INDEX idx_route (route_id)
          )
        ''');
      },
    );
  }

  /// Start recording a new journey
  Future<String> startJourneyRecording({String? routeName}) async {
    final db = await database;

    // Generate unique journey ID
    _currentJourneyId = 'journey_${DateTime.now().millisecondsSinceEpoch}';

    // Create journey record
    await db.insert('journeys', {
      'journey_id': _currentJourneyId,
      'start_time': DateTime.now().millisecondsSinceEpoch,
      'route_name': routeName,
      'is_complete': 0,
    });

    // Start GPS recording
    _isRecording = true;
    _lastRecordedPosition = null;

    _recordingTimer = Timer.periodic(
      const Duration(seconds: recordingIntervalSeconds),
      (_) => _recordGPSBreadcrumb(),
    );

    print('✅ Started journey recording: $_currentJourneyId');
    return _currentJourneyId!;
  }

  /// Record current GPS position as breadcrumb
  Future<void> _recordGPSBreadcrumb() async {
    if (!_isRecording || _currentJourneyId == null) return;

    try {
      final position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );

      // Only record if moved significantly
      if (_lastRecordedPosition != null) {
        final distance = _calculateDistance(
          _lastRecordedPosition!.latitude,
          _lastRecordedPosition!.longitude,
          position.latitude,
          position.longitude,
        );
        if (distance < minDistanceMeters) return;
      }

      final db = await database;
      await db.insert('gps_breadcrumbs', {
        'journey_id': _currentJourneyId,
        'latitude': position.latitude,
        'longitude': position.longitude,
        'altitude': position.altitude,
        'accuracy': position.accuracy,
        'speed': position.speed,
        'heading': position.heading,
        'timestamp': position.timestamp.millisecondsSinceEpoch,
      });

      _lastRecordedPosition = position;
    } catch (e) {
      print('❌ Error recording GPS: $e');
    }
  }

  /// Record a detected stop during journey
  Future<void> recordStopOnJourney({
    required double latitude,
    required double longitude,
    required DateTime arrivalTime,
    DateTime? departureTime,
    String? stopName,
    bool isBusStop = false,
  }) async {
    if (_currentJourneyId == null) return;

    final db = await database;

    // Get current stop sequence number
    final List<Map<String, dynamic>> existingStops = await db.query(
      'journey_stops',
      where: 'journey_id = ?',
      whereArgs: [_currentJourneyId],
      orderBy: 'stop_sequence DESC',
      limit: 1,
    );

    final nextSequence = existingStops.isEmpty
        ? 1
        : (existingStops[0]['stop_sequence'] as int) + 1;

    // Calculate dwell time if departure provided
    int? dwellSeconds;
    if (departureTime != null) {
      dwellSeconds = departureTime.difference(arrivalTime).inSeconds;
    }

    await db.insert('journey_stops', {
      'journey_id': _currentJourneyId,
      'stop_name': stopName,
      'latitude': latitude,
      'longitude': longitude,
      'arrival_time': arrivalTime.millisecondsSinceEpoch,
      'departure_time': departureTime?.millisecondsSinceEpoch,
      'dwell_seconds': dwellSeconds,
      'stop_sequence': nextSequence,
      'is_bus_stop': isBusStop ? 1 : 0,
    });

    print(
        '📍 Recorded stop #$nextSequence: $stopName (${isBusStop ? "Bus Stop" : "Traffic/Other"})');
  }

  /// End current journey recording
  Future<void> endJourneyRecording({
    String? endLocation,
  }) async {
    if (_currentJourneyId == null) return;

    _isRecording = false;
    _recordingTimer?.cancel();

    final db = await database;

    // Calculate journey statistics
    final List<Map<String, dynamic>> stops = await db.query(
      'journey_stops',
      where: 'journey_id = ?',
      whereArgs: [_currentJourneyId],
      orderBy: 'stop_sequence ASC',
    );

    final List<Map<String, dynamic>> breadcrumbs = await db.query(
      'gps_breadcrumbs',
      where: 'journey_id = ?',
      whereArgs: [_currentJourneyId],
      orderBy: 'timestamp ASC',
    );

    // Calculate total distance from breadcrumbs
    double totalDistance = 0.0;
    for (int i = 1; i < breadcrumbs.length; i++) {
      totalDistance += _calculateDistance(
        breadcrumbs[i - 1]['latitude'],
        breadcrumbs[i - 1]['longitude'],
        breadcrumbs[i]['latitude'],
        breadcrumbs[i]['longitude'],
      );
    }

    // Update journey record
    await db.update(
      'journeys',
      {
        'end_location': endLocation,
        'end_time': DateTime.now().millisecondsSinceEpoch,
        'total_distance_km': totalDistance / 1000,
        'total_stops': stops.length,
        'is_complete': 1,
      },
      where: 'journey_id = ?',
      whereArgs: [_currentJourneyId],
    );

    print('🏁 Journey ended: $_currentJourneyId');
    print('   Distance: ${(totalDistance / 1000).toStringAsFixed(2)} km');
    print('   Stops: ${stops.length}');
    print('   Breadcrumbs: ${breadcrumbs.length}');

    // Analyze and learn route pattern
    await _analyzeAndLearnRoute(_currentJourneyId!);

    _currentJourneyId = null;
    _lastRecordedPosition = null;
  }

  /// Analyze completed journey and learn/update route patterns
  Future<void> _analyzeAndLearnRoute(String journeyId) async {
    final db = await database;

    // Get journey stops (only bus stops)
    final List<Map<String, dynamic>> stops = await db.query(
      'journey_stops',
      where: 'journey_id = ? AND is_bus_stop = 1',
      whereArgs: [journeyId],
      orderBy: 'stop_sequence ASC',
    );

    if (stops.length < 2) {
      print('⚠️ Not enough stops to learn route (need at least 2)');
      return;
    }

    // Extract origin, destination, and stop sequence
    final origin = stops.first['stop_name'] ?? 'Unknown Origin';
    final destination = stops.last['stop_name'] ?? 'Unknown Destination';
    final stopNames = stops
        .map((s) => s['stop_name'] as String?)
        .where((n) => n != null)
        .toList();
    final stopSequence = stopNames.join(' → ');

    print('🔍 Analyzing route: $origin → $destination');
    print('   Stop sequence: $stopSequence');

    // Check if this route already exists
    final List<Map<String, dynamic>> existingRoutes = await db.query(
      'learned_routes',
      where: 'origin_name = ? AND destination_name = ?',
      whereArgs: [origin, destination],
    );

    // Calculate journey duration
    final journeyRecord = await db.query(
      'journeys',
      where: 'journey_id = ?',
      whereArgs: [journeyId],
    );

    int? durationMinutes;
    double? distanceKm;
    if (journeyRecord.isNotEmpty) {
      final startTime = journeyRecord[0]['start_time'] as int;
      final endTime = journeyRecord[0]['end_time'] as int?;
      if (endTime != null) {
        durationMinutes = ((endTime - startTime) / 60000).round();
      }
      distanceKm = journeyRecord[0]['total_distance_km'] as double?;
    }

    String routeId;

    if (existingRoutes.isEmpty) {
      // New route - create it
      routeId = 'route_${DateTime.now().millisecondsSinceEpoch}';

      await db.insert('learned_routes', {
        'route_id': routeId,
        'route_name': '$origin to $destination',
        'origin_name': origin,
        'destination_name': destination,
        'stop_sequence': stopSequence,
        'journey_count': 1,
        'avg_duration_minutes': durationMinutes,
        'avg_distance_km': distanceKm,
        'last_traveled': DateTime.now().millisecondsSinceEpoch,
        'confidence_score': 0.5, // Initial confidence
      });

      print('✨ Created new route: $routeId');
    } else {
      // Find best matching route by comparing stop sequences
      String? bestMatchId;
      int maxSimilarity = 0;

      for (final route in existingRoutes) {
        final existingSequence = route['stop_sequence'] as String;
        final similarity =
            _calculateSequenceSimilarity(stopSequence, existingSequence);

        if (similarity > maxSimilarity) {
          maxSimilarity = similarity;
          bestMatchId = route['route_id'] as String;
        }
      }

      if (maxSimilarity > 50 && bestMatchId != null) {
        // Similar route found - update it
        routeId = bestMatchId;
        final existingRoute =
            existingRoutes.firstWhere((r) => r['route_id'] == bestMatchId);

        final journeyCount = (existingRoute['journey_count'] as int) + 1;
        final newConfidence =
            math.min(0.95, 0.5 + (journeyCount * 0.05)); // Max 95% confidence

        // Update averages
        final existingDuration = existingRoute['avg_duration_minutes'] as int?;
        final existingDistance = existingRoute['avg_distance_km'] as double?;

        int? newAvgDuration;
        if (existingDuration != null && durationMinutes != null) {
          newAvgDuration =
              ((existingDuration * (journeyCount - 1) + durationMinutes) /
                      journeyCount)
                  .round();
        } else {
          newAvgDuration = durationMinutes ?? existingDuration;
        }

        double? newAvgDistance;
        if (existingDistance != null && distanceKm != null) {
          newAvgDistance =
              (existingDistance * (journeyCount - 1) + distanceKm) /
                  journeyCount;
        } else {
          newAvgDistance = distanceKm ?? existingDistance;
        }

        await db.update(
          'learned_routes',
          {
            'journey_count': journeyCount,
            'avg_duration_minutes': newAvgDuration,
            'avg_distance_km': newAvgDistance,
            'last_traveled': DateTime.now().millisecondsSinceEpoch,
            'confidence_score': newConfidence,
            // Update stop sequence if new journey has more stops
            'stop_sequence': stopNames.length >
                    existingRoute['stop_sequence']
                        .toString()
                        .split(' → ')
                        .length
                ? stopSequence
                : existingRoute['stop_sequence'],
          },
          where: 'route_id = ?',
          whereArgs: [routeId],
        );

        print(
            '📈 Updated existing route: $routeId (Journey #$journeyCount, ${(newConfidence * 100).toStringAsFixed(0)}% confidence)');
      } else {
        // Different route with same origin/destination - create new variant
        routeId = 'route_${DateTime.now().millisecondsSinceEpoch}';

        await db.insert('learned_routes', {
          'route_id': routeId,
          'route_name':
              '$origin to $destination (via ${stops[1]['stop_name']})',
          'origin_name': origin,
          'destination_name': destination,
          'stop_sequence': stopSequence,
          'journey_count': 1,
          'avg_duration_minutes': durationMinutes,
          'avg_distance_km': distanceKm,
          'last_traveled': DateTime.now().millisecondsSinceEpoch,
          'confidence_score': 0.5,
        });

        print('🆕 Created new route variant: $routeId');
      }
    }

    // Store detailed stop information for this route
    await _updateRouteStops(routeId, stops);
  }

  /// Update route stops with detailed information
  Future<void> _updateRouteStops(
      String routeId, List<Map<String, dynamic>> stops) async {
    final db = await database;

    // Clear existing route stops
    await db.delete('route_stops', where: 'route_id = ?', whereArgs: [routeId]);

    // Insert new stops
    for (int i = 0; i < stops.length; i++) {
      final stop = stops[i];

      // Calculate distance from previous stop
      double? distanceFromPrev;
      if (i > 0) {
        distanceFromPrev = _calculateDistance(
              stops[i - 1]['latitude'],
              stops[i - 1]['longitude'],
              stop['latitude'],
              stop['longitude'],
            ) /
            1000; // Convert to km
      }

      await db.insert('route_stops', {
        'route_id': routeId,
        'stop_name': stop['stop_name'],
        'latitude': stop['latitude'],
        'longitude': stop['longitude'],
        'stop_sequence': i + 1,
        'avg_dwell_seconds': stop['dwell_seconds'],
        'avg_distance_from_prev_km': distanceFromPrev,
      });
    }
  }

  /// Get all learned routes
  Future<List<Map<String, dynamic>>> getLearnedRoutes() async {
    final db = await database;
    return await db.query(
      'learned_routes',
      orderBy: 'confidence_score DESC, last_traveled DESC',
    );
  }

  /// Get stops for a specific route
  Future<List<Map<String, dynamic>>> getRouteStops(String routeId) async {
    final db = await database;
    return await db.query(
      'route_stops',
      where: 'route_id = ?',
      whereArgs: [routeId],
      orderBy: 'stop_sequence ASC',
    );
  }

  /// Find route between origin and destination
  Future<Map<String, dynamic>?> findRoute({
    required String origin,
    required String destination,
  }) async {
    final db = await database;

    final List<Map<String, dynamic>> routes = await db.query(
      'learned_routes',
      where: 'origin_name = ? AND destination_name = ?',
      whereArgs: [origin, destination],
      orderBy: 'confidence_score DESC, journey_count DESC',
      limit: 1,
    );

    if (routes.isEmpty) return null;

    final route = routes[0];

    // Get stops for this route
    final stops = await getRouteStops(route['route_id']);
    route['stops'] = stops;

    return route;
  }

  /// Get journey history
  Future<List<Map<String, dynamic>>> getJourneyHistory({int limit = 50}) async {
    final db = await database;
    return await db.query(
      'journeys',
      where: 'is_complete = 1',
      orderBy: 'start_time DESC',
      limit: limit,
    );
  }

  /// Calculate similarity between two stop sequences (returns percentage 0-100)
  int _calculateSequenceSimilarity(String seq1, String seq2) {
    final stops1 = seq1.split(' → ').toSet();
    final stops2 = seq2.split(' → ').toSet();

    final intersection = stops1.intersection(stops2);
    final union = stops1.union(stops2);

    if (union.isEmpty) return 0;
    return ((intersection.length / union.length) * 100).round();
  }

  /// Calculate distance between two GPS points in meters (Haversine formula)
  double _calculateDistance(
      double lat1, double lon1, double lat2, double lon2) {
    const R = 6371000.0; // Earth's radius in meters

    final phi1 = lat1 * math.pi / 180;
    final phi2 = lat2 * math.pi / 180;
    final deltaPhi = (lat2 - lat1) * math.pi / 180;
    final deltaLambda = (lon2 - lon1) * math.pi / 180;

    final a = math.sin(deltaPhi / 2) * math.sin(deltaPhi / 2) +
        math.cos(phi1) *
            math.cos(phi2) *
            math.sin(deltaLambda / 2) *
            math.sin(deltaLambda / 2);

    final c = 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));

    return R * c;
  }

  /// Check if service is currently recording
  bool get isRecording => _isRecording;

  /// Get current journey ID
  String? get currentJourneyId => _currentJourneyId;

  /// Dispose resources
  void dispose() {
    _recordingTimer?.cancel();
    _isRecording = false;
  }
}
