import 'dart:async';
import 'dart:convert';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import 'package:http/http.dart' as http;

/// Crowd-Sourced Route Learning Service
/// Aggregates route data from ALL users to build universal route knowledge
class CrowdSourcedRouteService {
  static Database? _database;

  // Cloud sync settings (TODO: Replace with your actual backend)
  static const String BACKEND_URL = 'https://your-api.com';
  static const Duration syncInterval = Duration(hours: 1);

  Timer? _syncTimer;
  String? _userId; // Unique device/user identifier
  String? _currentBusNumber; // Which bus the user is traveling in

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDatabase();
    return _database!;
  }

  Future<Database> _initDatabase() async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, 'crowdsourced_routes.db');

    return await openDatabase(
      path,
      version: 1,
      onCreate: (db, version) async {
        // Table 1: User Contributions (tracks what this user has contributed)
        await db.execute('''
          CREATE TABLE user_contributions (
            contribution_id TEXT PRIMARY KEY,
            user_id TEXT NOT NULL,
            bus_number TEXT NOT NULL,
            route_direction TEXT NOT NULL,
            origin_name TEXT NOT NULL,
            destination_name TEXT NOT NULL,
            timestamp INTEGER NOT NULL,
            total_stops INTEGER DEFAULT 0,
            total_distance_km REAL,
            is_synced INTEGER DEFAULT 0,
            sync_timestamp INTEGER
          )
        ''');

        // Table 2: Contributed Route Stops
        await db.execute('''
          CREATE TABLE contributed_stops (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            contribution_id TEXT NOT NULL,
            stop_name TEXT NOT NULL,
            latitude REAL NOT NULL,
            longitude REAL NOT NULL,
            stop_sequence INTEGER NOT NULL,
            dwell_seconds INTEGER,
            timestamp INTEGER NOT NULL,
            FOREIGN KEY (contribution_id) REFERENCES user_contributions(contribution_id)
          )
        ''');

        // Table 3: Universal Routes (aggregated from all users)
        await db.execute('''
          CREATE TABLE universal_routes (
            route_id TEXT PRIMARY KEY,
            bus_number TEXT NOT NULL,
            route_direction TEXT NOT NULL,
            origin_name TEXT NOT NULL,
            destination_name TEXT NOT NULL,
            stop_sequence TEXT NOT NULL,
            total_contributors INTEGER DEFAULT 1,
            total_journeys INTEGER DEFAULT 1,
            confidence_score REAL DEFAULT 0.5,
            last_updated INTEGER NOT NULL,
            avg_duration_minutes INTEGER,
            avg_distance_km REAL
          )
        ''');

        // Table 4: Universal Route Stops (aggregated stop data)
        await db.execute('''
          CREATE TABLE universal_route_stops (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            route_id TEXT NOT NULL,
            stop_name TEXT NOT NULL,
            latitude REAL NOT NULL,
            longitude REAL NOT NULL,
            stop_sequence INTEGER NOT NULL,
            occurrence_count INTEGER DEFAULT 1,
            avg_dwell_seconds INTEGER,
            avg_distance_from_prev_km REAL,
            reliability_score REAL DEFAULT 0.5,
            FOREIGN KEY (route_id) REFERENCES universal_routes(route_id)
          )
        ''');

        // Table 5: Route Variants (handles different paths for same origin-destination)
        await db.execute('''
          CREATE TABLE route_variants (
            variant_id TEXT PRIMARY KEY,
            bus_number TEXT NOT NULL,
            origin_name TEXT NOT NULL,
            destination_name TEXT NOT NULL,
            route_direction TEXT NOT NULL,
            variant_name TEXT NOT NULL,
            stop_sequence TEXT NOT NULL,
            distinguishing_stops TEXT NOT NULL,
            usage_count INTEGER DEFAULT 1,
            last_used INTEGER NOT NULL
          )
        ''');

        // Table 6: User Feedback on Routes
        await db.execute('''
          CREATE TABLE route_feedback (
            feedback_id TEXT PRIMARY KEY,
            user_id TEXT NOT NULL,
            route_id TEXT NOT NULL,
            feedback_type TEXT NOT NULL,
            feedback_text TEXT,
            timestamp INTEGER NOT NULL,
            is_synced INTEGER DEFAULT 0
          )
        ''');
      },
    );
  }

  /// Initialize user session with bus information
  Future<void> startUserSession({
    required String userId,
    required String busNumber,
  }) async {
    _userId = userId;
    _currentBusNumber = busNumber;

    // Start periodic sync with backend
    _syncTimer?.cancel();
    _syncTimer = Timer.periodic(syncInterval, (_) => _syncWithBackend());
  }

  /// Record a user's journey contribution
  Future<String> contributeRoute({
    required String origin,
    required String destination,
    required String direction, // 'forward' or 'return'
    required List<Map<String, dynamic>> stops,
  }) async {
    if (_userId == null || _currentBusNumber == null) {
      throw Exception(
          'User session not initialized. Call startUserSession() first.');
    }

    final db = await database;
    final contributionId =
        'contrib_${DateTime.now().millisecondsSinceEpoch}_$_userId';

    // Calculate total distance
    double totalDistance = 0.0;
    for (int i = 1; i < stops.length; i++) {
      totalDistance += _calculateDistance(
        stops[i - 1]['latitude'],
        stops[i - 1]['longitude'],
        stops[i]['latitude'],
        stops[i]['longitude'],
      );
    }

    // Save contribution
    await db.insert('user_contributions', {
      'contribution_id': contributionId,
      'user_id': _userId,
      'bus_number': _currentBusNumber,
      'route_direction': direction,
      'origin_name': origin,
      'destination_name': destination,
      'timestamp': DateTime.now().millisecondsSinceEpoch,
      'total_stops': stops.length,
      'total_distance_km': totalDistance / 1000,
      'is_synced': 0,
    });

    // Save contributed stops
    for (int i = 0; i < stops.length; i++) {
      final stop = stops[i];
      await db.insert('contributed_stops', {
        'contribution_id': contributionId,
        'stop_name': stop['stop_name'],
        'latitude': stop['latitude'],
        'longitude': stop['longitude'],
        'stop_sequence': i + 1,
        'dwell_seconds': stop['dwell_seconds'],
        'timestamp': DateTime.now().millisecondsSinceEpoch,
      });
    }

    print('✅ Route contribution saved: $contributionId');
    print('   Bus: $_currentBusNumber | Direction: $direction');
    print('   $origin → $destination (${stops.length} stops)');

    // Merge with universal routes
    await _mergeIntoUniversalRoutes(
      contributionId: contributionId,
      busNumber: _currentBusNumber!,
      direction: direction,
      origin: origin,
      destination: destination,
      stops: stops,
    );

    return contributionId;
  }

  /// Merge user contribution into universal route knowledge
  Future<void> _mergeIntoUniversalRoutes({
    required String contributionId,
    required String busNumber,
    required String direction,
    required String origin,
    required String destination,
    required List<Map<String, dynamic>> stops,
  }) async {
    final db = await database;

    // Generate stop sequence string
    final stopSequence = stops.map((s) => s['stop_name'] as String).join(' → ');

    // Check if this exact route exists
    final existingRoutes = await db.query(
      'universal_routes',
      where:
          'bus_number = ? AND route_direction = ? AND origin_name = ? AND destination_name = ?',
      whereArgs: [busNumber, direction, origin, destination],
    );

    String routeId;

    if (existingRoutes.isEmpty) {
      // NEW ROUTE - Create it
      routeId =
          'route_${busNumber}_${direction}_${DateTime.now().millisecondsSinceEpoch}';

      await db.insert('universal_routes', {
        'route_id': routeId,
        'bus_number': busNumber,
        'route_direction': direction,
        'origin_name': origin,
        'destination_name': destination,
        'stop_sequence': stopSequence,
        'total_contributors': 1,
        'total_journeys': 1,
        'confidence_score': 0.3, // Low confidence (single user)
        'last_updated': DateTime.now().millisecondsSinceEpoch,
      });

      print('🆕 Created new universal route: $routeId');
    } else {
      // EXISTING ROUTE - Find best match
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

      if (maxSimilarity > 60 && bestMatchId != null) {
        // SIMILAR ROUTE - Update it
        routeId = bestMatchId;
        final existingRoute =
            existingRoutes.firstWhere((r) => r['route_id'] == bestMatchId);

        final totalJourneys = (existingRoute['total_journeys'] as int) + 1;
        final totalContributors =
            (existingRoute['total_contributors'] as int) + 1;

        // Increase confidence (more users = more confidence)
        final newConfidence =
            _calculateConfidence(totalJourneys, totalContributors);

        await db.update(
          'universal_routes',
          {
            'total_journeys': totalJourneys,
            'total_contributors': totalContributors,
            'confidence_score': newConfidence,
            'last_updated': DateTime.now().millisecondsSinceEpoch,
            // Update stop sequence if new contribution has more stops
            'stop_sequence': stops.length >
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

        print('📈 Updated universal route: $routeId');
        print(
            '   Confidence: ${(newConfidence * 100).toStringAsFixed(0)}% ($totalJourneys journeys, $totalContributors users)');
      } else {
        // DIFFERENT VARIANT - Create new variant
        routeId =
            'route_${busNumber}_${direction}_variant_${DateTime.now().millisecondsSinceEpoch}';

        await db.insert('universal_routes', {
          'route_id': routeId,
          'bus_number': busNumber,
          'route_direction': direction,
          'origin_name': origin,
          'destination_name': destination,
          'stop_sequence': stopSequence,
          'total_contributors': 1,
          'total_journeys': 1,
          'confidence_score': 0.3,
          'last_updated': DateTime.now().millisecondsSinceEpoch,
        });

        // Save as route variant
        await _saveRouteVariant(
          busNumber: busNumber,
          origin: origin,
          destination: destination,
          direction: direction,
          stopSequence: stopSequence,
          stops: stops,
        );

        print('🔀 Created route variant: $routeId');
      }
    }

    // Update universal route stops
    await _updateUniversalRouteStops(routeId, stops);
  }

  /// Save route variant for bidirectional routes
  Future<void> _saveRouteVariant({
    required String busNumber,
    required String origin,
    required String destination,
    required String direction,
    required String stopSequence,
    required List<Map<String, dynamic>> stops,
  }) async {
    final db = await database;

    // Find distinguishing stops (stops that make this variant unique)
    final distinguishingStops = stops
        .where((s) => !['State Bank', 'Bus Stand', 'Junction']
            .any((common) => (s['stop_name'] as String).contains(common)))
        .take(3)
        .map((s) => s['stop_name'] as String)
        .join(', ');

    final variantName = 'Via $distinguishingStops';
    final variantId = 'variant_${DateTime.now().millisecondsSinceEpoch}';

    await db.insert('route_variants', {
      'variant_id': variantId,
      'bus_number': busNumber,
      'origin_name': origin,
      'destination_name': destination,
      'route_direction': direction,
      'variant_name': variantName,
      'stop_sequence': stopSequence,
      'distinguishing_stops': distinguishingStops,
      'usage_count': 1,
      'last_used': DateTime.now().millisecondsSinceEpoch,
    });

    print('💡 Saved variant: "$variantName"');
  }

  /// Update universal route stops with aggregated data
  Future<void> _updateUniversalRouteStops(
      String routeId, List<Map<String, dynamic>> stops) async {
    final db = await database;

    for (int i = 0; i < stops.length; i++) {
      final stop = stops[i];
      final stopName = stop['stop_name'] as String;

      // Check if stop already exists for this route
      final existingStops = await db.query(
        'universal_route_stops',
        where: 'route_id = ? AND stop_name = ? AND stop_sequence = ?',
        whereArgs: [routeId, stopName, i + 1],
      );

      if (existingStops.isEmpty) {
        // New stop - add it
        double? distanceFromPrev;
        if (i > 0) {
          distanceFromPrev = _calculateDistance(
                stops[i - 1]['latitude'],
                stops[i - 1]['longitude'],
                stop['latitude'],
                stop['longitude'],
              ) /
              1000;
        }

        await db.insert('universal_route_stops', {
          'route_id': routeId,
          'stop_name': stopName,
          'latitude': stop['latitude'],
          'longitude': stop['longitude'],
          'stop_sequence': i + 1,
          'occurrence_count': 1,
          'avg_dwell_seconds': stop['dwell_seconds'],
          'avg_distance_from_prev_km': distanceFromPrev,
          'reliability_score': 0.5,
        });
      } else {
        // Existing stop - update averages
        final existing = existingStops[0];
        final occurrenceCount = (existing['occurrence_count'] as int) + 1;

        final existingDwell = existing['avg_dwell_seconds'] as int?;
        final newDwell = stop['dwell_seconds'] as int?;
        final avgDwell = (existingDwell != null && newDwell != null)
            ? ((existingDwell * (occurrenceCount - 1) + newDwell) /
                    occurrenceCount)
                .round()
            : newDwell ?? existingDwell;

        final reliabilityScore = _calculateReliabilityScore(occurrenceCount);

        await db.update(
          'universal_route_stops',
          {
            'occurrence_count': occurrenceCount,
            'avg_dwell_seconds': avgDwell,
            'reliability_score': reliabilityScore,
          },
          where: 'id = ?',
          whereArgs: [existing['id']],
        );
      }
    }
  }

  /// Get universal routes for a bus (handles bidirectional)
  Future<List<Map<String, dynamic>>> getUniversalRoutes({
    String? busNumber,
    String? direction,
  }) async {
    final db = await database;

    String whereClause = '';
    List<dynamic> whereArgs = [];

    if (busNumber != null) {
      whereClause = 'bus_number = ?';
      whereArgs.add(busNumber);
    }

    if (direction != null) {
      if (whereClause.isNotEmpty) whereClause += ' AND ';
      whereClause += 'route_direction = ?';
      whereArgs.add(direction);
    }

    final routes = await db.query(
      'universal_routes',
      where: whereClause.isEmpty ? null : whereClause,
      whereArgs: whereArgs.isEmpty ? null : whereArgs,
      orderBy: 'confidence_score DESC, total_journeys DESC',
    );

    return routes;
  }

  /// Get route variants for bidirectional routes
  Future<List<Map<String, dynamic>>> getRouteVariants({
    required String busNumber,
    required String origin,
    required String destination,
  }) async {
    final db = await database;

    final variants = await db.query(
      'route_variants',
      where: 'bus_number = ? AND origin_name = ? AND destination_name = ?',
      whereArgs: [busNumber, origin, destination],
      orderBy: 'usage_count DESC',
    );

    return variants;
  }

  /// Submit user feedback on a route
  Future<void> submitFeedback({
    required String routeId,
    required String
        feedbackType, // 'correct', 'incorrect', 'missing_stop', 'wrong_sequence'
    String? feedbackText,
  }) async {
    if (_userId == null) {
      throw Exception('User session not initialized');
    }

    final db = await database;
    final feedbackId =
        'feedback_${DateTime.now().millisecondsSinceEpoch}_$_userId';

    await db.insert('route_feedback', {
      'feedback_id': feedbackId,
      'user_id': _userId,
      'route_id': routeId,
      'feedback_type': feedbackType,
      'feedback_text': feedbackText,
      'timestamp': DateTime.now().millisecondsSinceEpoch,
      'is_synced': 0,
    });

    print('📝 Feedback submitted: $feedbackType');
  }

  /// Sync data with backend (cloud aggregation)
  Future<void> _syncWithBackend() async {
    final db = await database;

    try {
      // 1. Upload unsynced contributions
      final unsyncedContributions = await db.query(
        'user_contributions',
        where: 'is_synced = 0',
      );

      for (final contribution in unsyncedContributions) {
        final contributionId = contribution['contribution_id'] as String;

        // Get contributed stops
        final stops = await db.query(
          'contributed_stops',
          where: 'contribution_id = ?',
          whereArgs: [contributionId],
        );

        // Send to backend
        final response = await http.post(
          Uri.parse('$BACKEND_URL/api/contributions'),
          headers: {'Content-Type': 'application/json'},
          body: json.encode({
            'contribution': contribution,
            'stops': stops,
          }),
        );

        if (response.statusCode == 200) {
          // Mark as synced
          await db.update(
            'user_contributions',
            {
              'is_synced': 1,
              'sync_timestamp': DateTime.now().millisecondsSinceEpoch
            },
            where: 'contribution_id = ?',
            whereArgs: [contributionId],
          );
        }
      }

      // 2. Download updated universal routes from backend
      final response = await http.get(
        Uri.parse('$BACKEND_URL/api/universal-routes'),
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body) as List<dynamic>;

        for (final routeData in data) {
          await _updateLocalUniversalRoute(routeData);
        }
      }

      // 3. Upload unsynced feedback
      final unsyncedFeedback = await db.query(
        'route_feedback',
        where: 'is_synced = 0',
      );

      for (final feedback in unsyncedFeedback) {
        final response = await http.post(
          Uri.parse('$BACKEND_URL/api/feedback'),
          headers: {'Content-Type': 'application/json'},
          body: json.encode(feedback),
        );

        if (response.statusCode == 200) {
          await db.update(
            'route_feedback',
            {'is_synced': 1},
            where: 'feedback_id = ?',
            whereArgs: [feedback['feedback_id']],
          );
        }
      }

      print('☁️ Sync completed successfully');
    } catch (e) {
      print('❌ Sync failed: $e');
    }
  }

  /// Update local database with backend's universal route
  Future<void> _updateLocalUniversalRoute(
      Map<String, dynamic> routeData) async {
    final db = await database;

    final routeId = routeData['route_id'] as String;

    // Check if route exists locally
    final existing = await db.query(
      'universal_routes',
      where: 'route_id = ?',
      whereArgs: [routeId],
    );

    if (existing.isEmpty) {
      // Insert new route from backend
      await db.insert('universal_routes', routeData['route']);

      // Insert stops
      final stops = routeData['stops'] as List<dynamic>;
      for (final stop in stops) {
        await db.insert('universal_route_stops', stop);
      }
    } else {
      // Update existing route if backend version is newer
      final localTimestamp = existing[0]['last_updated'] as int;
      final backendTimestamp = routeData['route']['last_updated'] as int;

      if (backendTimestamp > localTimestamp) {
        await db.update(
          'universal_routes',
          routeData['route'],
          where: 'route_id = ?',
          whereArgs: [routeId],
        );

        // Update stops
        await db.delete('universal_route_stops',
            where: 'route_id = ?', whereArgs: [routeId]);
        final stops = routeData['stops'] as List<dynamic>;
        for (final stop in stops) {
          await db.insert('universal_route_stops', stop);
        }
      }
    }
  }

  /// Calculate confidence score based on journeys and contributors
  double _calculateConfidence(int totalJourneys, int totalContributors) {
    // More users = higher confidence
    // Formula: min(0.95, 0.3 + (contributors * 0.15) + (journeys * 0.02))
    final contributorBonus = totalContributors * 0.15;
    final journeyBonus = totalJourneys * 0.02;
    return (0.3 + contributorBonus + journeyBonus).clamp(0.0, 0.95);
  }

  /// Calculate reliability score for a stop
  double _calculateReliabilityScore(int occurrenceCount) {
    // More occurrences = more reliable
    return (0.5 + (occurrenceCount * 0.05)).clamp(0.0, 1.0);
  }

  /// Calculate sequence similarity (percentage)
  int _calculateSequenceSimilarity(String seq1, String seq2) {
    final stops1 = seq1.split(' → ').toSet();
    final stops2 = seq2.split(' → ').toSet();

    final intersection = stops1.intersection(stops2);
    final union = stops1.union(stops2);

    if (union.isEmpty) return 0;
    return ((intersection.length / union.length) * 100).round();
  }

  /// Calculate distance between GPS points (Haversine)
  double _calculateDistance(
      double lat1, double lon1, double lat2, double lon2) {
    const R = 6371000.0; // Earth radius in meters

    final phi1 = lat1 * 3.14159265359 / 180;
    final phi2 = lat2 * 3.14159265359 / 180;
    final deltaPhi = (lat2 - lat1) * 3.14159265359 / 180;
    final deltaLambda = (lon2 - lon1) * 3.14159265359 / 180;

    final a = (deltaPhi / 2) * (deltaPhi / 2) +
        phi1 * phi2 * (deltaLambda / 2) * (deltaLambda / 2);

    final c = 2 * (a / (1 - a));
    return R * c;
  }

  void dispose() {
    _syncTimer?.cancel();
  }
}
