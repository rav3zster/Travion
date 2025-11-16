# Critical Fixes Plan for TravelAI App

## Issues Identified by User

1. ❌ Test Stop Detection uses **static GPS** instead of live tracking
2. ❌ No **background GPS tracking service** running continuously
3. ❌ Start Tracking page: **no manual coordinate entry** option
4. ❌ **Tracking state not persisted** when leaving page (alarms get lost)
5. ❌ **Notifications/alarms not working** properly
6. ❌ **No backend** for data synchronization

---

## 🔧 FIX 1: Live GPS Tracking in Test Stop Detection

### Current Problem
- Uses simulated GPS coordinates in a loop
- No real-time location tracking
- Can't test in actual bus journeys

### Solution
**File:** `lib/test_stop_detection.dart`

**Changes:**
1. Add `StreamSubscription<Position>?` for live GPS stream
2. Create `_startLiveTracking()` method that:
   - Requests location permissions
   - Starts `Geolocator.getPositionStream()` with high accuracy
   - Processes each position through `StopDetectionService`
3. Add `_processLivePosition()` to detect when bus becomes stationary
4. Apply classifier model when speed < 0.5 m/s for >15 seconds
5. Keep simulation mode as fallback for testing

**Code Structure:**
```dart
// Add state variables
StreamSubscription<Position>? _positionStreamSub;
bool _isLiveTracking = false;
Position? _lastPosition;
bool _isStationary = false;

// Live tracking method
Future<void> _startLiveTracking() async {
  // Check permissions
  // Start position stream with LocationSettings(
  //   accuracy: LocationAccuracy.high,
  //   distanceFilter: 5 meters
  // )
  // Process each position
}

void _processLivePosition(Position position) {
  _detectionService.processPosition(position);
  // Update UI with speed, location
  // Detect stationary state
  // Apply classifier when stopped
}
```

---

## 🔧 FIX 2: Background GPS Tracking Service

### Current Problem
- GPS tracking stops when app is minimized
- No persistent tracking service
- Can't detect stops in background

### Solution
**New File:** `lib/services/background_tracking_service.dart`

**Implementation:**
1. Use **WorkManager** or **flutter_background_service** package
2. Create singleton service that:
   - Starts on app launch
   - Runs in background even when app is minimized
   - Uses `Geolocator.getPositionStream()` with background mode
3. Persist tracking state in SharedPreferences
4. Show persistent notification while tracking
5. Integrate with `StopDetectionService` for real-time stop detection

**Required Permissions (Android):**
```xml
<!-- AndroidManifest.xml -->
<uses-permission android:name="android.permission.ACCESS_FINE_LOCATION" />
<uses-permission android:name="android.permission.ACCESS_COARSE_LOCATION" />
<uses-permission android:name="android.permission.ACCESS_BACKGROUND_LOCATION" />
<uses-permission android:name="android.permission.FOREGROUND_SERVICE" />
<uses-permission android:name="android.permission.FOREGROUND_SERVICE_LOCATION" />
```

**Package to Add:**
```yaml
# pubspec.yaml
dependencies:
  flutter_background_service: ^5.0.0
  flutter_background_service_android: ^6.2.0
```

---

## 🔧 FIX 3: Manual Coordinate Entry in Start Tracking

### Current Problem
- Only location name search available
- Some places not found by geocoding API
- No way to enter exact coordinates

### Solution
**File:** `lib/track_page.dart`

**Changes:**
1. Add "Use Coordinates" toggle button
2. Show/hide coordinate input fields based on toggle
3. Add two TextField widgets:
   - Latitude input (with validation: -90 to 90)
   - Longitude input (with validation: -180 to 180)
4. Update `_setDestination()` to handle manual coordinates
5. Add input validation with error messages

**UI Mockup:**
```dart
// Add after destination search field
Row(
  children: [
    Switch(
      value: _useManualCoordinates,
      onChanged: (val) => setState(() => _useManualCoordinates = val),
    ),
    Text('Use Manual Coordinates'),
  ],
),
if (_useManualCoordinates) ...[
  TextField(
    controller: _latitudeController,
    keyboardType: TextInputType.numberWithOptions(decimal: true, signed: true),
    decoration: InputDecoration(
      labelText: 'Latitude (-90 to 90)',
      hintText: '12.9716',
    ),
    inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9.-]'))],
  ),
  TextField(
    controller: _longitudeController,
    // Similar for longitude
  ),
]
```

---

## 🔧 FIX 4: Persist Tracking State

### Current Problem
- When leaving TrackPage, tracking stops
- Alarms and notifications are cancelled in `dispose()`
- No way to restore previous tracking session

### Solution
**Files:** 
- `lib/track_page.dart`
- `lib/services/tracking_state_service.dart` (NEW)

**Implementation:**

### A. Create Tracking State Service
```dart
class TrackingStateService {
  static const String _keyIsTracking = 'is_tracking';
  static const String _keyDestLat = 'dest_lat';
  static const String _keyDestLng = 'dest_lng';
  static const String _keyDestName = 'dest_name';
  static const String _keyAlertDistances = 'alert_distances';
  static const String _keyAlertRadius = 'alert_radius';
  
  Future<void> saveTrackingState({
    required Position destination,
    required String destinationName,
    required List<double> alertDistances,
    required double alertRadius,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_keyIsTracking, true);
    await prefs.setDouble(_keyDestLat, destination.latitude);
    await prefs.setDouble(_keyDestLng, destination.longitude);
    await prefs.setString(_keyDestName, destinationName);
    await prefs.setString(_keyAlertDistances, jsonEncode(alertDistances));
    await prefs.setDouble(_keyAlertRadius, alertRadius);
  }
  
  Future<Map<String, dynamic>?> loadTrackingState() async {
    final prefs = await SharedPreferences.getInstance();
    if (!prefs.getBool(_keyIsTracking, defaultValue: false)) return null;
    
    return {
      'destinationLat': prefs.getDouble(_keyDestLat),
      'destinationLng': prefs.getDouble(_keyDestLng),
      'destinationName': prefs.getString(_keyDestName),
      'alertDistances': jsonDecode(prefs.getString(_keyAlertDistances) ?? '[]'),
      'alertRadius': prefs.getDouble(_keyAlertRadius),
    };
  }
  
  Future<void> clearTrackingState() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_keyIsTracking, false);
  }
}
```

### B. Update TrackPage

**In `initState()`:**
```dart
@override
void initState() {
  super.initState();
  _busStopService.loadBusStops();
  _notificationService.initialize();
  _restoreTrackingState(); // NEW
}

Future<void> _restoreTrackingState() async {
  final state = await TrackingStateService().loadTrackingState();
  if (state != null) {
    // Show dialog: "Resume previous tracking?"
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Resume Tracking?'),
        content: Text('You have an active tracking session to ${state['destinationName']}'),
        actions: [
          TextButton(
            onPressed: () {
              TrackingStateService().clearTrackingState();
              Navigator.pop(ctx);
            },
            child: Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              _restoreSession(state);
              Navigator.pop(ctx);
            },
            child: Text('Resume'),
          ),
        ],
      ),
    );
  }
}
```

**In `dispose()`:**
```dart
@override
void dispose() {
  // DON'T cancel subscriptions/notifications if tracking is active
  if (_destinationPosition != null) {
    TrackingStateService().saveTrackingState(
      destination: _destinationPosition!,
      destinationName: _destinationController.text,
      alertDistances: _alertDistances,
      alertRadius: _alertRadius,
    );
    // KEEP tracking running in background service
  } else {
    _positionStreamSub?.cancel();
    NotificationService.cancelAll();
  }
  
  _destinationController.dispose();
  _destinationFocusNode.dispose();
  _alertsController.dispose();
  _radiusController.dispose();
  super.dispose();
}
```

---

## 🔧 FIX 5: Fix Notifications/Alarms

### Current Problem
- Notifications not triggering at correct distances
- Alarms not working
- Background location updates not calling notification methods

### Root Cause Analysis
Need to check:
1. Are notifications initialized properly?
2. Are permissions granted (POST_NOTIFICATIONS on Android 13+)?
3. Is `NotificationService.showProximityAlert()` being called?
4. Are notification channels configured correctly?

### Solution
**File:** `lib/services/notification_service.dart`

**Debug Steps:**
1. Add logging to every notification method
2. Verify Android notification channel creation
3. Check notification permissions:

```dart
// Add to NotificationService
static Future<bool> checkNotificationPermissions() async {
  if (Platform.isAndroid) {
    final androidInfo = await DeviceInfoPlugin().androidInfo;
    if (androidInfo.version.sdkInt >= 33) {
      // Android 13+ requires explicit permission
      final status = await Permission.notification.status;
      if (!status.isGranted) {
        final result = await Permission.notification.request();
        return result.isGranted;
      }
    }
  }
  return true;
}
```

4. Ensure alarm notification uses proper flags:

```dart
static Future<void> showAlarmNotification({
  required String title,
  required String body,
  required int distance,
}) async {
  const AndroidNotificationDetails androidDetails = AndroidNotificationDetails(
    'alarm_channel',
    'Alarms',
    channelDescription: 'Critical destination arrival alarms',
    importance: Importance.max,
    priority: Priority.max,
    playSound: true,
    enableVibration: true,
    vibrationPattern: Int64List.fromList([0, 1000, 500, 1000]),
    fullScreenIntent: true, // CRITICAL for alarm behavior
    category: AndroidNotificationCategory.alarm,
    sound: RawResourceAndroidNotificationSound('alarm_sound'),
  );

  const NotificationDetails details = NotificationDetails(android: androidDetails);

  await _notifications.show(
    9999, // Fixed ID for alarm
    title,
    body,
    details,
  );
}
```

5. Test notification in `TrackPage._triggerProximityAlert()`:

```dart
Future<void> _triggerProximityAlert(int radiusMeters, int distanceMeters) async {
  print('🔔 Triggering alert: radius=$radiusMeters, distance=$distanceMeters'); // DEBUG
  
  final title = '🎯 Destination Alert!';
  final body = 'You\'re $distanceMeters meters close to your destination';

  if (_alertType == 'alarm') {
    print('🚨 Showing ALARM notification'); // DEBUG
    await NotificationService.showAlarmNotification(
      title: title,
      body: body,
      distance: distanceMeters,
    );
    HapticFeedback.heavyImpact();
  } else {
    print('🔔 Showing NORMAL notification'); // DEBUG
    await NotificationService.showProximityAlert(
      title: title,
      body: body,
      distance: distanceMeters,
      playSound: true,
    );
    HapticFeedback.mediumImpact();
  }
}
```

### Required Permissions
```xml
<!-- AndroidManifest.xml -->
<uses-permission android:name="android.permission.POST_NOTIFICATIONS"/>
<uses-permission android:name="android.permission.USE_FULL_SCREEN_INTENT"/>
<uses-permission android:name="android.permission.VIBRATE"/>
```

### Required Package
```yaml
# pubspec.yaml
dependencies:
  permission_handler: ^11.0.0
```

---

## 🔧 FIX 6: Backend Architecture

### Current Problem
- All data stored locally (SharedPreferences, SQLite)
- No user accounts
- No data synchronization across devices
- No collaborative bus stop learning

### Proposed Backend Solution

### Technology Stack
- **Backend Framework:** Node.js + Express OR FastAPI (Python)
- **Database:** PostgreSQL (for structured data) + PostGIS (for geospatial queries)
- **Authentication:** Firebase Auth OR JWT
- **Real-time:** WebSockets (Socket.IO)
- **Cloud:** AWS/Google Cloud/Azure
- **Storage:** AWS S3 for ML models

### API Endpoints

#### 1. Authentication
```
POST /api/auth/register
POST /api/auth/login
POST /api/auth/logout
GET /api/auth/profile
```

#### 2. Bus Stops
```
GET /api/bus-stops?lat=12.9716&lng=77.5946&radius=5000
POST /api/bus-stops (add new stop)
PUT /api/bus-stops/:id (update stop)
DELETE /api/bus-stops/:id
GET /api/bus-stops/:id/verify (get community verification status)
POST /api/bus-stops/:id/verify (vote to verify)
```

#### 3. Smart Learning
```
POST /api/learning/detected-stop (report detected stop)
POST /api/learning/confirm (user confirmed stop)
POST /api/learning/reject (user rejected stop)
GET /api/learning/suggestions (get ML-suggested stops for area)
```

#### 4. Trip History
```
GET /api/trips
POST /api/trips (start new trip)
PUT /api/trips/:id (complete trip)
POST /api/trips/:id/waypoints (batch upload waypoints)
GET /api/trips/:id/details
DELETE /api/trips/:id
```

#### 5. Offline Cache Sync
```
POST /api/cache/routes (upload cached routes)
GET /api/cache/routes?origin=&dest= (download cached route)
POST /api/cache/sync (bulk sync offline data when online)
```

### Database Schema (PostgreSQL + PostGIS)

```sql
-- Users table
CREATE TABLE users (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  email VARCHAR(255) UNIQUE NOT NULL,
  username VARCHAR(100) UNIQUE NOT NULL,
  password_hash VARCHAR(255) NOT NULL,
  created_at TIMESTAMP DEFAULT NOW(),
  last_login TIMESTAMP
);

-- Bus stops table with PostGIS geometry
CREATE TABLE bus_stops (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  name VARCHAR(255) NOT NULL,
  location GEOMETRY(Point, 4326) NOT NULL, -- PostGIS point
  description TEXT,
  sequence_number INTEGER,
  created_by UUID REFERENCES users(id),
  created_at TIMESTAMP DEFAULT NOW(),
  verification_count INTEGER DEFAULT 0,
  rejection_count INTEGER DEFAULT 0,
  confidence_score DECIMAL(3,2) DEFAULT 0.5
);

-- Create spatial index for fast proximity queries
CREATE INDEX idx_bus_stops_location ON bus_stops USING GIST(location);

-- Detected stops (for ML training)
CREATE TABLE detected_stops (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID REFERENCES users(id),
  location GEOMETRY(Point, 4326) NOT NULL,
  dwell_time DECIMAL(10,2) NOT NULL,
  stop_type VARCHAR(50),
  confidence DECIMAL(3,2),
  timestamp TIMESTAMP NOT NULL,
  user_confirmed BOOLEAN,
  added_to_database BOOLEAN DEFAULT FALSE
);

-- Trips table
CREATE TABLE trips (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID REFERENCES users(id),
  start_location GEOMETRY(Point, 4326) NOT NULL,
  end_location GEOMETRY(Point, 4326),
  start_time TIMESTAMP NOT NULL,
  end_time TIMESTAMP,
  distance DECIMAL(10,2),
  duration INTEGER, -- seconds
  bus_number VARCHAR(50),
  is_completed BOOLEAN DEFAULT FALSE
);

-- Trip waypoints
CREATE TABLE trip_waypoints (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  trip_id UUID REFERENCES trips(id) ON DELETE CASCADE,
  location GEOMETRY(Point, 4326) NOT NULL,
  timestamp TIMESTAMP NOT NULL,
  speed DECIMAL(10,2),
  accuracy DECIMAL(10,2)
);

-- Cached routes
CREATE TABLE cached_routes (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID REFERENCES users(id),
  origin GEOMETRY(Point, 4326) NOT NULL,
  destination GEOMETRY(Point, 4326) NOT NULL,
  route_data JSONB NOT NULL, -- Store polyline, instructions, etc.
  distance DECIMAL(10,2),
  duration INTEGER,
  cached_at TIMESTAMP DEFAULT NOW()
);
```

### Geospatial Queries (PostGIS)

**Find nearby bus stops:**
```sql
SELECT 
  id, 
  name,
  ST_Distance(
    location::geography,
    ST_SetSRID(ST_MakePoint($longitude, $latitude), 4326)::geography
  ) as distance_meters
FROM bus_stops
WHERE ST_DWithin(
  location::geography,
  ST_SetSRID(ST_MakePoint($longitude, $latitude), 4326)::geography,
  $radius_meters
)
ORDER BY distance_meters
LIMIT 10;
```

**Check if detected stop is near existing stop:**
```sql
SELECT EXISTS(
  SELECT 1
  FROM bus_stops
  WHERE ST_DWithin(
    location::geography,
    ST_SetSRID(ST_MakePoint($longitude, $latitude), 4326)::geography,
    50 -- 50 meters
  )
) as is_duplicate;
```

### Real-time Features (WebSocket)

**Server-side (Node.js + Socket.IO):**
```javascript
io.on('connection', (socket) => {
  console.log('User connected:', socket.id);
  
  // User shares live location
  socket.on('location:update', async (data) => {
    const { userId, lat, lng, speed } = data;
    
    // Broadcast to nearby users (for collaborative features)
    socket.broadcast.emit('nearby:user-moving', {
      userId,
      location: { lat, lng },
      speed
    });
    
    // Check for nearby stops and alert
    const nearbyStops = await findNearbyStops(lat, lng, 100);
    if (nearbyStops.length > 0) {
      socket.emit('bus-stop:nearby', nearbyStops);
    }
  });
  
  // User confirms bus stop
  socket.on('bus-stop:confirm', async (data) => {
    const { stopId, userId } = data;
    await incrementVerificationCount(stopId);
    
    // Broadcast to all users in the area
    io.emit('bus-stop:verified', {
      stopId,
      verificationCount: await getVerificationCount(stopId)
    });
  });
});
```

**Client-side (Flutter):**
```dart
import 'package:socket_io_client/socket_io_client.dart' as IO;

class RealtimeService {
  late IO.Socket socket;
  
  void connect() {
    socket = IO.io('https://your-backend.com', <String, dynamic>{
      'transports': ['websocket'],
      'autoConnect': false,
    });
    
    socket.connect();
    
    socket.on('bus-stop:nearby', (data) {
      // Show notification for nearby bus stop
      NotificationService.showProximityAlert(
        title: 'Bus Stop Nearby',
        body: 'Approaching ${data['name']}',
        distance: data['distance'],
      );
    });
    
    socket.on('bus-stop:verified', (data) {
      // Update local database
      BusStopService.instance.updateVerificationCount(
        data['stopId'],
        data['verificationCount'],
      );
    });
  }
  
  void sendLocationUpdate(Position position) {
    socket.emit('location:update', {
      'userId': currentUserId,
      'lat': position.latitude,
      'lng': position.longitude,
      'speed': position.speed,
    });
  }
}
```

### ML Model Training Pipeline

**Server-side:**
1. Collect confirmed/rejected stops from all users
2. Extract features: dwell time, time of day, location type, user behavior patterns
3. Train classification model (Random Forest or Neural Network)
4. Deploy updated model to S3
5. Notify apps to download new model

**Client-side:**
1. Periodic check for model updates (daily)
2. Download new `.tflite` model if available
3. Replace old model in assets
4. Use new model for stop detection

---

## Implementation Priority

### Phase 1: Critical Fixes (Week 1)
1. ✅ **Live GPS in Test Detection** (2 days)
2. ✅ **Manual Coordinate Entry** (1 day)
3. ✅ **Fix Notifications** (2 days)

### Phase 2: Persistence (Week 2)
4. ✅ **Tracking State Persistence** (3 days)
5. ✅ **Background Service** (4 days)

### Phase 3: Backend (Week 3-4)
6. ✅ **Backend API Development** (7 days)
7. ✅ **Database Setup with PostGIS** (2 days)
8. ✅ **Authentication** (2 days)
9. ✅ **Real-time Features** (3 days)

### Phase 4: Integration (Week 5)
10. ✅ **Connect App to Backend** (5 days)
11. ✅ **Sync Local Data** (2 days)
12. ✅ **Testing & Bug Fixes** (3 days)

---

## Next Steps

1. **Review this plan** and confirm priorities
2. **Set up development environment** for backend
3. **Start with Phase 1** fixes immediately
4. **Test each fix** on real device with GPS
5. **Iterate based on test results**

Would you like me to start implementing any specific fix first?
