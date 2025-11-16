import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import 'dart:convert';

/// Service to cache routes and locations for offline use
class OfflineCacheService {
  static Database? _database;

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDatabase();
    return _database!;
  }

  Future<Database> _initDatabase() async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, 'offline_cache.db');

    return await openDatabase(
      path,
      version: 1,
      onCreate: (db, version) async {
        // Cached routes for offline use
        await db.execute('''
          CREATE TABLE cached_routes (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            originName TEXT NOT NULL,
            destName TEXT NOT NULL,
            originLat REAL NOT NULL,
            originLng REAL NOT NULL,
            destLat REAL NOT NULL,
            destLng REAL NOT NULL,
            routeData TEXT NOT NULL,
            distance REAL,
            duration INTEGER,
            cachedAt TEXT NOT NULL,
            lastUsedAt TEXT
          )
        ''');

        // Cached locations (favorite places)
        await db.execute('''
          CREATE TABLE cached_locations (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            name TEXT NOT NULL UNIQUE,
            latitude REAL NOT NULL,
            longitude REAL NOT NULL,
            category TEXT,
            address TEXT,
            cachedAt TEXT NOT NULL
          )
        ''');

        // Create index for faster queries
        await db.execute(
            'CREATE INDEX idx_cached_routes_names ON cached_routes(originName, destName)');
      },
    );
  }

  /// Cache a route for offline use
  Future<void> cacheRoute({
    required String originName,
    required String destName,
    required double originLat,
    required double originLng,
    required double destLat,
    required double destLng,
    required List<Map<String, dynamic>> routePoints,
    double? distance,
    int? duration,
  }) async {
    final db = await database;

    // Check if route already exists
    final existing = await db.query(
      'cached_routes',
      where: 'originName = ? AND destName = ?',
      whereArgs: [originName, destName],
    );

    final routeData = jsonEncode(routePoints);

    if (existing.isNotEmpty) {
      // Update existing
      await db.update(
        'cached_routes',
        {
          'originLat': originLat,
          'originLng': originLng,
          'destLat': destLat,
          'destLng': destLng,
          'routeData': routeData,
          'distance': distance,
          'duration': duration,
          'cachedAt': DateTime.now().toIso8601String(),
          'lastUsedAt': DateTime.now().toIso8601String(),
        },
        where: 'id = ?',
        whereArgs: [existing.first['id']],
      );
    } else {
      // Insert new
      await db.insert('cached_routes', {
        'originName': originName,
        'destName': destName,
        'originLat': originLat,
        'originLng': originLng,
        'destLat': destLat,
        'destLng': destLng,
        'routeData': routeData,
        'distance': distance,
        'duration': duration,
        'cachedAt': DateTime.now().toIso8601String(),
        'lastUsedAt': DateTime.now().toIso8601String(),
      });
    }
  }

  /// Get cached route
  Future<Map<String, dynamic>?> getCachedRoute(
      String originName, String destName) async {
    final db = await database;
    final results = await db.query(
      'cached_routes',
      where: 'originName = ? AND destName = ?',
      whereArgs: [originName, destName],
    );

    if (results.isEmpty) return null;

    final route = results.first;

    // Update last used time
    await db.update(
      'cached_routes',
      {'lastUsedAt': DateTime.now().toIso8601String()},
      where: 'id = ?',
      whereArgs: [route['id']],
    );

    return {
      'originName': route['originName'],
      'destName': route['destName'],
      'originLat': route['originLat'],
      'originLng': route['originLng'],
      'destLat': route['destLat'],
      'destLng': route['destLng'],
      'routePoints': jsonDecode(route['routeData'] as String),
      'distance': route['distance'],
      'duration': route['duration'],
      'cachedAt': DateTime.parse(route['cachedAt'] as String),
    };
  }

  /// Get all cached routes
  Future<List<Map<String, dynamic>>> getAllCachedRoutes() async {
    final db = await database;
    final results = await db.query('cached_routes', orderBy: 'lastUsedAt DESC');

    return results.map((route) {
      return {
        'id': route['id'],
        'originName': route['originName'],
        'destName': route['destName'],
        'distance': route['distance'],
        'duration': route['duration'],
        'cachedAt': DateTime.parse(route['cachedAt'] as String),
        'lastUsedAt': route['lastUsedAt'] != null
            ? DateTime.parse(route['lastUsedAt'] as String)
            : null,
      };
    }).toList();
  }

  /// Cache a location
  Future<void> cacheLocation({
    required String name,
    required double latitude,
    required double longitude,
    String? category,
    String? address,
  }) async {
    final db = await database;

    await db.insert(
      'cached_locations',
      {
        'name': name,
        'latitude': latitude,
        'longitude': longitude,
        'category': category,
        'address': address,
        'cachedAt': DateTime.now().toIso8601String(),
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  /// Get cached location by name
  Future<Map<String, dynamic>?> getCachedLocation(String name) async {
    final db = await database;
    final results = await db.query(
      'cached_locations',
      where: 'name = ?',
      whereArgs: [name],
    );

    if (results.isEmpty) return null;
    return results.first;
  }

  /// Search cached locations
  Future<List<Map<String, dynamic>>> searchCachedLocations(String query) async {
    final db = await database;
    final results = await db.query(
      'cached_locations',
      where: 'name LIKE ?',
      whereArgs: ['%$query%'],
      orderBy: 'name ASC',
      limit: 10,
    );

    return results;
  }

  /// Get all cached locations
  Future<List<Map<String, dynamic>>> getAllCachedLocations() async {
    final db = await database;
    return await db.query('cached_locations', orderBy: 'name ASC');
  }

  /// Delete old cached routes (older than 30 days)
  Future<void> cleanOldCache() async {
    final db = await database;
    final cutoffDate =
        DateTime.now().subtract(const Duration(days: 30)).toIso8601String();

    await db.delete(
      'cached_routes',
      where: 'cachedAt < ? AND (lastUsedAt IS NULL OR lastUsedAt < ?)',
      whereArgs: [cutoffDate, cutoffDate],
    );
  }

  /// Get cache statistics
  Future<Map<String, int>> getCacheStatistics() async {
    final db = await database;
    final routeCount = Sqflite.firstIntValue(
            await db.rawQuery('SELECT COUNT(*) FROM cached_routes')) ??
        0;
    final locationCount = Sqflite.firstIntValue(
            await db.rawQuery('SELECT COUNT(*) FROM cached_locations')) ??
        0;

    return {
      'cachedRoutes': routeCount,
      'cachedLocations': locationCount,
    };
  }

  /// Clear all cache
  Future<void> clearAllCache() async {
    final db = await database;
    await db.delete('cached_routes');
    await db.delete('cached_locations');
  }
}
