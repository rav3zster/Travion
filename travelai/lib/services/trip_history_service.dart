import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import 'package:geolocator/geolocator.dart';

class Trip {
  final int? id;
  final String startLocation;
  final String endLocation;
  final double startLat;
  final double startLng;
  final double endLat;
  final double endLng;
  final DateTime startTime;
  final DateTime? endTime;
  final double? totalDistance;
  final int? duration; // in seconds
  final double? avgSpeed;
  final double? maxSpeed;
  final String? busNumber;
  final bool isCompleted;

  Trip({
    this.id,
    required this.startLocation,
    required this.endLocation,
    required this.startLat,
    required this.startLng,
    required this.endLat,
    required this.endLng,
    required this.startTime,
    this.endTime,
    this.totalDistance,
    this.duration,
    this.avgSpeed,
    this.maxSpeed,
    this.busNumber,
    this.isCompleted = false,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'startLocation': startLocation,
      'endLocation': endLocation,
      'startLat': startLat,
      'startLng': startLng,
      'endLat': endLat,
      'endLng': endLng,
      'startTime': startTime.toIso8601String(),
      'endTime': endTime?.toIso8601String(),
      'totalDistance': totalDistance,
      'duration': duration,
      'avgSpeed': avgSpeed,
      'maxSpeed': maxSpeed,
      'busNumber': busNumber,
      'isCompleted': isCompleted ? 1 : 0,
    };
  }

  factory Trip.fromMap(Map<String, dynamic> map) {
    return Trip(
      id: map['id'],
      startLocation: map['startLocation'],
      endLocation: map['endLocation'],
      startLat: map['startLat'],
      startLng: map['startLng'],
      endLat: map['endLat'],
      endLng: map['endLng'],
      startTime: DateTime.parse(map['startTime']),
      endTime: map['endTime'] != null ? DateTime.parse(map['endTime']) : null,
      totalDistance: map['totalDistance'],
      duration: map['duration'],
      avgSpeed: map['avgSpeed'],
      maxSpeed: map['maxSpeed'],
      busNumber: map['busNumber'],
      isCompleted: map['isCompleted'] == 1,
    );
  }
}

class TripHistoryService {
  static Database? _database;

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDatabase();
    return _database!;
  }

  Future<Database> _initDatabase() async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, 'trip_history.db');

    return await openDatabase(
      path,
      version: 1,
      onCreate: (db, version) async {
        await db.execute('''
          CREATE TABLE trips (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            startLocation TEXT NOT NULL,
            endLocation TEXT NOT NULL,
            startLat REAL NOT NULL,
            startLng REAL NOT NULL,
            endLat REAL NOT NULL,
            endLng REAL NOT NULL,
            startTime TEXT NOT NULL,
            endTime TEXT,
            totalDistance REAL,
            duration INTEGER,
            avgSpeed REAL,
            maxSpeed REAL,
            busNumber TEXT,
            isCompleted INTEGER DEFAULT 0
          )
        ''');

        await db.execute('''
          CREATE TABLE trip_waypoints (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            tripId INTEGER NOT NULL,
            latitude REAL NOT NULL,
            longitude REAL NOT NULL,
            timestamp TEXT NOT NULL,
            speed REAL,
            accuracy REAL,
            FOREIGN KEY (tripId) REFERENCES trips (id) ON DELETE CASCADE
          )
        ''');
      },
    );
  }

  // Start a new trip
  Future<int> startTrip({
    required String startLocation,
    required String endLocation,
    required Position startPosition,
    required Position endPosition,
    String? busNumber,
  }) async {
    final db = await database;
    final trip = Trip(
      startLocation: startLocation,
      endLocation: endLocation,
      startLat: startPosition.latitude,
      startLng: startPosition.longitude,
      endLat: endPosition.latitude,
      endLng: endPosition.longitude,
      startTime: DateTime.now(),
      busNumber: busNumber,
      isCompleted: false,
    );
    return await db.insert('trips', trip.toMap());
  }

  // Record waypoint during trip
  Future<void> recordWaypoint(int tripId, Position position) async {
    final db = await database;
    await db.insert('trip_waypoints', {
      'tripId': tripId,
      'latitude': position.latitude,
      'longitude': position.longitude,
      'timestamp': DateTime.now().toIso8601String(),
      'speed': position.speed,
      'accuracy': position.accuracy,
    });
  }

  // Complete a trip
  Future<void> completeTrip(int tripId) async {
    final db = await database;

    // Calculate statistics
    final waypoints = await db.query(
      'trip_waypoints',
      where: 'tripId = ?',
      whereArgs: [tripId],
      orderBy: 'timestamp ASC',
    );

    if (waypoints.isEmpty) {
      await db.update(
        'trips',
        {
          'endTime': DateTime.now().toIso8601String(),
          'isCompleted': 1,
        },
        where: 'id = ?',
        whereArgs: [tripId],
      );
      return;
    }

    double totalDistance = 0;
    double maxSpeed = 0;
    double totalSpeed = 0;
    int speedCount = 0;

    for (int i = 0; i < waypoints.length - 1; i++) {
      final current = waypoints[i];
      final next = waypoints[i + 1];

      final distance = Geolocator.distanceBetween(
        current['latitude'] as double,
        current['longitude'] as double,
        next['latitude'] as double,
        next['longitude'] as double,
      );
      totalDistance += distance;

      final speed = current['speed'] as double?;
      if (speed != null && speed > 0) {
        totalSpeed += speed;
        speedCount++;
        if (speed > maxSpeed) maxSpeed = speed;
      }
    }

    final startTime = DateTime.parse(
        (await db.query('trips', where: 'id = ?', whereArgs: [tripId]))[0]
            ['startTime'] as String);
    final endTime = DateTime.now();
    final duration = endTime.difference(startTime).inSeconds;

    await db.update(
      'trips',
      {
        'endTime': endTime.toIso8601String(),
        'totalDistance': totalDistance,
        'duration': duration,
        'avgSpeed': speedCount > 0 ? totalSpeed / speedCount : 0,
        'maxSpeed': maxSpeed,
        'isCompleted': 1,
      },
      where: 'id = ?',
      whereArgs: [tripId],
    );
  }

  // Get all trips
  Future<List<Trip>> getAllTrips() async {
    final db = await database;
    final maps = await db.query('trips', orderBy: 'startTime DESC');
    return maps.map((map) => Trip.fromMap(map)).toList();
  }

  // Get trip by ID with waypoints
  Future<Map<String, dynamic>?> getTripDetails(int tripId) async {
    final db = await database;
    final tripMaps =
        await db.query('trips', where: 'id = ?', whereArgs: [tripId]);

    if (tripMaps.isEmpty) return null;

    final trip = Trip.fromMap(tripMaps.first);
    final waypoints = await db.query(
      'trip_waypoints',
      where: 'tripId = ?',
      whereArgs: [tripId],
      orderBy: 'timestamp ASC',
    );

    return {
      'trip': trip,
      'waypoints': waypoints,
    };
  }

  // Delete trip
  Future<void> deleteTrip(int tripId) async {
    final db = await database;
    await db.delete('trips', where: 'id = ?', whereArgs: [tripId]);
  }

  // Get statistics
  Future<Map<String, dynamic>> getStatistics() async {
    final db = await database;
    final result = await db.rawQuery('''
      SELECT 
        COUNT(*) as totalTrips,
        SUM(totalDistance) as totalDistance,
        SUM(duration) as totalDuration,
        AVG(avgSpeed) as overallAvgSpeed,
        MAX(maxSpeed) as overallMaxSpeed
      FROM trips
      WHERE isCompleted = 1
    ''');

    return result.first;
  }
}
