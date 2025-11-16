import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import 'package:path_provider/path_provider.dart';
import 'dart:io';
import 'dart:math' as Math;
import '../models/detected_stop.dart';

/// Database service for managing detected stops
class StopDetectionDatabase {
  static final StopDetectionDatabase instance = StopDetectionDatabase._init();
  static Database? _database;

  StopDetectionDatabase._init();

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDB('detected_stops.db');
    return _database!;
  }

  Future<Database> _initDB(String filePath) async {
    final Directory dbPath = await getApplicationDocumentsDirectory();
    final path = join(dbPath.path, filePath);

    return await openDatabase(
      path,
      version: 1,
      onCreate: _createDB,
    );
  }

  Future<void> _createDB(Database db, int version) async {
    const idType = 'INTEGER PRIMARY KEY AUTOINCREMENT';
    const doubleType = 'REAL NOT NULL';
    const textType = 'TEXT NOT NULL';
    const intType = 'INTEGER NOT NULL';
    const boolType = 'INTEGER NOT NULL DEFAULT 0';

    // Main detected stops table
    await db.execute('''
      CREATE TABLE detected_stops (
        id $idType,
        latitude $doubleType,
        longitude $doubleType,
        timestamp $textType,
        dwell_time $doubleType,
        stop_type $intType,
        confidence $doubleType,
        user_confirmed $boolType,
        notes TEXT,
        visit_count $intType DEFAULT 1,
        speed REAL,
        heading REAL
      )
    ''');

    // Create indices for efficient querying
    await db.execute('''
      CREATE INDEX idx_timestamp ON detected_stops(timestamp DESC)
    ''');

    await db.execute('''
      CREATE INDEX idx_location ON detected_stops(latitude, longitude)
    ''');

    await db.execute('''
      CREATE INDEX idx_stop_type ON detected_stops(stop_type)
    ''');

    // Create table for stop clustering (to identify recurring stops)
    await db.execute('''
      CREATE TABLE stop_clusters (
        id $idType,
        center_latitude $doubleType,
        center_longitude $doubleType,
        radius $doubleType,
        stop_type $intType,
        visit_count $intType DEFAULT 1,
        first_visit $textType,
        last_visit $textType,
        avg_dwell_time $doubleType,
        confidence $doubleType
      )
    ''');

    print('Database tables created successfully');
  }

  /// Insert a new detected stop
  Future<DetectedStop> insertStop(DetectedStop stop) async {
    final db = await instance.database;
    final id = await db.insert('detected_stops', stop.toMap());
    return stop.copyWith(id: id);
  }

  /// Get all detected stops
  Future<List<DetectedStop>> getAllStops() async {
    final db = await instance.database;
    const orderBy = 'timestamp DESC';
    final result = await db.query('detected_stops', orderBy: orderBy);
    return result.map((json) => DetectedStop.fromMap(json)).toList();
  }

  /// Get recent stops (last N days)
  Future<List<DetectedStop>> getRecentStops(int days) async {
    final db = await instance.database;
    final cutoffDate = DateTime.now().subtract(Duration(days: days));

    final result = await db.query(
      'detected_stops',
      where: 'timestamp >= ?',
      whereArgs: [cutoffDate.toIso8601String()],
      orderBy: 'timestamp DESC',
    );

    return result.map((json) => DetectedStop.fromMap(json)).toList();
  }

  /// Get stops by type
  Future<List<DetectedStop>> getStopsByType(DetectedStopType type) async {
    final db = await instance.database;

    final result = await db.query(
      'detected_stops',
      where: 'stop_type = ?',
      whereArgs: [type.index],
      orderBy: 'timestamp DESC',
    );

    return result.map((json) => DetectedStop.fromMap(json)).toList();
  }

  /// Find stops near a location (within radius in meters)
  Future<List<DetectedStop>> getStopsNearLocation(
    double latitude,
    double longitude,
    double radiusMeters,
  ) async {
    final db = await instance.database;

    // Simple bounding box query (approximation)
    // 1 degree latitude ≈ 111km
    // 1 degree longitude ≈ 111km * cos(latitude)
    final latDelta = radiusMeters / 111000;
    final lngDelta =
        radiusMeters / (111000 * 0.866); // Approximate for mid-latitudes

    final result = await db.query(
      'detected_stops',
      where: '''
        latitude BETWEEN ? AND ?
        AND longitude BETWEEN ? AND ?
      ''',
      whereArgs: [
        latitude - latDelta,
        latitude + latDelta,
        longitude - lngDelta,
        longitude + lngDelta,
      ],
      orderBy: 'timestamp DESC',
    );

    // Filter by actual distance
    final stops = result.map((json) => DetectedStop.fromMap(json)).toList();
    return stops.where((stop) {
      final distance = _calculateDistance(
        latitude,
        longitude,
        stop.latitude,
        stop.longitude,
      );
      return distance <= radiusMeters;
    }).toList();
  }

  /// Update a stop (e.g., user confirmation, notes)
  Future<int> updateStop(DetectedStop stop) async {
    final db = await instance.database;
    return db.update(
      'detected_stops',
      stop.toMap(),
      where: 'id = ?',
      whereArgs: [stop.id],
    );
  }

  /// Delete a stop
  Future<int> deleteStop(int id) async {
    final db = await instance.database;
    return db.delete(
      'detected_stops',
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  /// Get statistics about stops
  Future<Map<String, dynamic>> getStopStatistics() async {
    final db = await instance.database;

    // Total stops
    final totalResult =
        await db.rawQuery('SELECT COUNT(*) as count FROM detected_stops');
    final total = Sqflite.firstIntValue(totalResult) ?? 0;

    // Stops by type
    final typeResult = await db.rawQuery('''
      SELECT stop_type, COUNT(*) as count 
      FROM detected_stops 
      GROUP BY stop_type
    ''');

    // Average dwell time
    final dwellResult =
        await db.rawQuery('SELECT AVG(dwell_time) as avg FROM detected_stops');
    final avgDwell = (dwellResult.first['avg'] as num?)?.toDouble() ?? 0.0;

    // Most visited location (simplified)
    final visitResult = await db.rawQuery('''
      SELECT latitude, longitude, COUNT(*) as visits 
      FROM detected_stops 
      GROUP BY ROUND(latitude, 4), ROUND(longitude, 4)
      ORDER BY visits DESC
      LIMIT 1
    ''');

    return {
      'totalStops': total,
      'stopsByType': typeResult,
      'averageDwellTime': avgDwell,
      'mostVisited': visitResult.isNotEmpty ? visitResult.first : null,
    };
  }

  /// Clear all stops (for testing or reset)
  Future<int> clearAllStops() async {
    final db = await instance.database;
    return db.delete('detected_stops');
  }

  /// Calculate distance between two points using Haversine formula
  double _calculateDistance(
      double lat1, double lon1, double lat2, double lon2) {
    const double earthRadius = 6371000; // meters

    final dLat = _degreesToRadians(lat2 - lat1);
    final dLon = _degreesToRadians(lon2 - lon1);

    final a = Math.sin(dLat / 2) * Math.sin(dLat / 2) +
        Math.cos(_degreesToRadians(lat1)) *
            Math.cos(_degreesToRadians(lat2)) *
            Math.sin(dLon / 2) *
            Math.sin(dLon / 2);

    final c = 2 * Math.atan2(Math.sqrt(a), Math.sqrt(1 - a));
    return earthRadius * c;
  }

  double _degreesToRadians(double degrees) {
    return degrees * Math.pi / 180;
  }

  /// Close database connection
  Future<void> close() async {
    final db = await instance.database;
    await db.close();
  }
}
