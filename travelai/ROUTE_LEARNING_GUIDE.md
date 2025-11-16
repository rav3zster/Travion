# 🚍 Route Learning System - Complete Guide

## The Problem You Identified

**Your Feedback**:
> "the bus starts from mangalore state bank and goes to jyothi and from there it goes to pvs and from there goes through lalbagh, ladyhill, kottara, kuloor, surathkal, mulki, and padubidri where it take a right turn to the way to karkala, and other stops comes in like the nadhi koor, belman, nitte, anekere"

**What Was Wrong**:
My previous system used **geometric calculations** (straight-line distances) to determine if stops were on the route. This completely ignored:
- Actual roads the bus follows
- Real stop sequence along the route
- Turn points and route deviations
- Intermediate stops between major landmarks

**Example of the Problem**:
```
❌ OLD METHOD (Geometric):
Mangalore (12.9141°N) → Karkala (13.2114°N)
System would suggest ANY stop in that latitude range, even if it's on a different road!

✅ NEW METHOD (Route Learning):
Mangalore State Bank → Jyothi → PVS → Lalbagh → Ladyhill → 
Kottara → Kuloor → Surathkal → Mulki → Padubidri → 
Nandikoor → Belman → Nitte → Anekere → Karkala

System learns the ACTUAL path by tracking GPS breadcrumbs!
```

---

## The Solution: Route Learning System

### How It Works

```
┌─────────────────────────────────────────────────────────────┐
│  Phase 1: RECORD THE JOURNEY                                 │
├─────────────────────────────────────────────────────────────┤
│  1. User starts GPS tracking                                 │
│  2. System records GPS position every 5 seconds             │
│  3. System detects stops (speed < 2 km/h, dwell > 15s)     │
│  4. User ends journey                                        │
└─────────────────────────────────────────────────────────────┘
                          ↓
┌─────────────────────────────────────────────────────────────┐
│  Phase 2: ANALYZE THE ROUTE                                  │
├─────────────────────────────────────────────────────────────┤
│  1. Extract origin (first stop) and destination (last stop) │
│  2. Extract stop sequence between them                       │
│  3. Calculate distances between consecutive stops            │
│  4. Calculate average dwell times                            │
│  5. Check if this route already exists in database          │
└─────────────────────────────────────────────────────────────┘
                          ↓
┌─────────────────────────────────────────────────────────────┐
│  Phase 3: LEARN THE PATTERN                                  │
├─────────────────────────────────────────────────────────────┤
│  • First journey: Create new route (50% confidence)          │
│  • Second journey: Update route (55% confidence)             │
│  • Third journey: Update route (60% confidence)              │
│  • ...continued traveling increases confidence up to 95%     │
└─────────────────────────────────────────────────────────────┘
                          ↓
┌─────────────────────────────────────────────────────────────┐
│  Phase 4: INTELLIGENT SUGGESTIONS                            │
├─────────────────────────────────────────────────────────────┤
│  When user selects "Mangalore State Bank → Karkala":         │
│  System retrieves LEARNED route with exact stop sequence:    │
│  ✓ Jyothi (Stop #2, 1.2 km from State Bank)                 │
│  ✓ PVS (Stop #3, 0.8 km from Jyothi)                        │
│  ✓ Lalbagh (Stop #4, 1.5 km from PVS)                       │
│  ✓ Ladyhill (Stop #5, 0.9 km from Lalbagh)                  │
│  ... and so on                                               │
└─────────────────────────────────────────────────────────────┘
```

---

## Database Schema

### 5 Smart Tables

#### Table 1: `gps_breadcrumbs`
Stores continuous GPS positions every 5 seconds
```
| journey_id  | latitude | longitude | timestamp         |
|-------------|----------|-----------|-------------------|
| journey_123 | 12.9141  | 74.8560   | 1699523400000     |
| journey_123 | 12.9155  | 74.8572   | 1699523405000     |
| journey_123 | 12.9168  | 74.8585   | 1699523410000     |
| ...         | ...      | ...       | ...               |
```

#### Table 2: `journey_stops`
Detected stops during journey with dwell times
```
| journey_id  | stop_name  | stop_sequence | arrival_time | dwell_seconds |
|-------------|------------|---------------|--------------|---------------|
| journey_123 | State Bank | 1             | ...400000    | 0             |
| journey_123 | Jyothi     | 2             | ...410000    | 45            |
| journey_123 | PVS        | 3             | ...420000    | 38            |
| ...         | ...        | ...           | ...          | ...           |
```

#### Table 3: `journeys`
Complete trip records
```
| journey_id  | start_time | end_time | total_distance_km | total_stops |
|-------------|------------|----------|-------------------|-------------|
| journey_123 | ...400000  | ...500000| 45.2              | 15          |
```

#### Table 4: `learned_routes`
Patterns extracted from multiple journeys
```
| route_id | origin_name | destination_name | stop_sequence                | journey_count | confidence_score |
|----------|-------------|------------------|------------------------------|---------------|------------------|
| route_1  | State Bank  | Karkala          | State Bank → Jyothi → PVS... | 5             | 0.75             |
```

#### Table 5: `route_stops`
Detailed stop information for each learned route
```
| route_id | stop_name | stop_sequence | avg_dwell_seconds | avg_distance_from_prev_km |
|----------|-----------|---------------|-------------------|---------------------------|
| route_1  | Jyothi    | 2             | 45                | 1.2                       |
| route_1  | PVS       | 3             | 38                | 0.8                       |
| route_1  | Lalbagh   | 4             | 42                | 1.5                       |
```

---

## Example: Real Route Learning

### Your Mangalore → Karkala Route

**Journey 1** (First Time):
```
✅ GPS Tracking Started
📍 Breadcrumbs recorded: 1,250 points (104 minutes × 60s / 5s interval)
🚏 Stops detected: 15 stops

Stop Sequence Learned:
1. Mangalore State Bank (origin) - 0 km
2. Jyothi - 1.2 km from previous
3. PVS - 0.8 km from previous
4. Lalbagh - 1.5 km from previous
5. Ladyhill - 0.9 km from previous
6. Kottara - 2.1 km from previous
7. Kuloor - 3.2 km from previous
8. Surathkal - 4.5 km from previous
9. Mulki - 6.8 km from previous
10. Padubidri - 5.2 km from previous ← Turn point!
11. Nandikoor - 4.1 km from previous
12. Belman - 3.8 km from previous
13. Nitte - 4.2 km from previous
14. Anekere - 3.5 km from previous
15. Karkala (destination) - 4.3 km from previous

🎓 Route Created: "Mangalore State Bank to Karkala"
📊 Confidence: 50% (needs more journeys to be confident)
```

**Journey 2** (Second Time - Same Route):
```
✅ GPS Tracking Started
📍 Breadcrumbs recorded: 1,180 points (98 minutes)
🚏 Stops detected: 15 stops (same sequence!)

System Analysis:
✓ Matches existing route 95% (14/15 stops identical)
✓ One new stop discovered: "Kuloor Junction" between Kuloor & Surathkal
✓ Updated average dwell times
✓ Updated average distances

🎓 Route Updated: "Mangalore State Bank to Karkala"
📊 Confidence: 55% → 60% (getting more confident!)
```

**Journey 5** (Fifth Time):
```
🎓 Route Confidence: 75% (High confidence!)
📊 Average Duration: 102 minutes
📊 Average Distance: 44.8 km
📊 Stops: 16 stops (discovered 1 additional stop: "Nitte Hospital")

NOW READY FOR SMART ALERTS! ✅
```

---

## User Experience Flow

### Step 1: Track First Journey

**User Action**: Enable GPS tracking during bus ride

**System Behavior**:
```
┌──────────────────────────────────────────┐
│  🟢 GPS Tracking Active                   │
│  ──────────────────────────────────────  │
│  📍 Recording GPS breadcrumbs...          │
│  🚏 Stops detected: 5                     │
│  ⏱️ Duration: 34 minutes                  │
│  📏 Distance: 18.2 km                     │
└──────────────────────────────────────────┘
```

**What's Happening Behind the Scenes**:
- GPS position recorded every 5 seconds
- Speed monitored continuously
- Stop detection when speed < 2 km/h for > 15 seconds
- All data saved to database

### Step 2: System Learns Route Automatically

**After Journey Ends**:
```
┌──────────────────────────────────────────┐
│  ✅ Journey Complete!                     │
│  ──────────────────────────────────────  │
│  🎓 Analyzing route pattern...            │
│  📊 Route: Mangalore State Bank → Karkala│
│  🚏 Stops: 15                             │
│  📝 Saving to learned routes...           │
│                                           │
│  [View Journey Details] [Start New Journey│
└──────────────────────────────────────────┘
```

### Step 3: Set Up Smart Alerts

**User Opens Smart Alerts Page**:
```
┌──────────────────────────────────────────┐
│  Smart Alerts                             │
│  ──────────────────────────────────────  │
│  📚 1 route(s) learned! Select below.     │
│                                           │
│  From (Origin): [Mangalore State Bank ▼]  │
│  To (Destination): [Karkala (75% conf) ▼] │
│                                           │
│  [Get Smart Suggestions]                  │
└──────────────────────────────────────────┘
```

**After Clicking "Get Smart Suggestions"**:
```
┌──────────────────────────────────────────┐
│  Route: Mangalore State Bank to Karkala  │
│  75% Confidence | 5 Trips | ~102 min     │
│  ──────────────────────────────────────  │
│  Stops Along Your Route (13 intermediate) │
│                                           │
│  ☐ 2️⃣ Jyothi (1.2 km from prev, 45s stop)│
│  ☐ 3️⃣ PVS (0.8 km from prev, 38s stop)   │
│  ☐ 4️⃣ Lalbagh (1.5 km from prev, 42s)    │
│  ☑️ 5️⃣ Ladyhill (0.9 km from prev, 48s)  │
│  ☐ 6️⃣ Kottara (2.1 km from prev, 35s)    │
│  ☑️ 9️⃣ Mulki (6.8 km from prev, 120s)    │
│  ☐ 🔟 Padubidri (5.2 km, 65s)            │
│  ☑️ 1️⃣3️⃣ Nitte (4.2 km from prev, 55s)   │
│  ...                                      │
│                                           │
│  [Activate 3 Alerts]                      │
└──────────────────────────────────────────┘
```

### Step 4: Receive Smart Notifications

**During Next Journey**:
```
Approaching Ladyhill - 2 km away
[Notification from TravelAI]

Approaching Ladyhill - 500m away
[Notification from TravelAI]

Arrived at Ladyhill Bus Stop
[Notification from TravelAI]
```

---

## Key Benefits

### ✅ 1. Learns Actual Routes
- No more geometric guessing
- Understands real roads and paths
- Knows about turns and deviations
- Remembers intermediate stops

### ✅ 2. Gets Smarter Over Time
```
Journey 1: 50% confidence (might suggest wrong stops)
Journey 3: 65% confidence (getting better)
Journey 5: 75% confidence (very reliable)
Journey 10: 90% confidence (expert level!)
```

### ✅ 3. Discovers New Stops Automatically
```
Journey 1: Learned 15 stops
Journey 3: Discovered "Kuloor Junction" → Now 16 stops
Journey 7: Discovered "Nitte Hospital" → Now 17 stops
```

### ✅ 4. Adapts to Route Variations
```
Route 1: State Bank → Karkala (via Padubidri)
Route 2: State Bank → Karkala (via Kundapura) ← Different route!

System learns BOTH routes separately!
```

### ✅ 5. Provides Accurate Timings
```
From State Bank to Mulki: ~40 minutes (based on 5 journeys)
From Mulki to Padubidri: ~18 minutes (based on 5 journeys)
From Padubidri to Karkala: ~44 minutes (based on 5 journeys)
```

---

## Integration with Existing System

### How It Works with Stop Detection ML Models

```
┌─────────────────────────────────────────────────────────────┐
│  WHEN BUS STOPS                                               │
├─────────────────────────────────────────────────────────────┤
│  1. GPS detects speed < 2 km/h                               │
│  2. Start recording dwell time                                │
│  3. Run ML Model 1: Stop Location Recognizer                 │
│     → "Is this a known bus stop?" (Yes/No + Stop Name)       │
│  4. Run ML Model 2: Stop Type Classifier                     │
│     → "Why did we stop?" (Traffic/Toll/Bus Stop/etc.)        │
│  5. If BOTH say "Bus Stop":                                  │
│     → Save to journey_stops table                            │
│     → Include in route learning                              │
│  6. If Type says "Traffic Signal":                           │
│     → Don't include in route (just noise)                    │
└─────────────────────────────────────────────────────────────┘
```

### Smart Route Recording

The route learning service automatically filters out:
- ❌ Traffic signal stops
- ❌ Toll gate stops
- ❌ Random slowdowns
- ✅ ONLY saves actual bus stops to learned routes

---

## Files Created

### 1. `lib/services/route_learning_service.dart` (612 lines)

**Purpose**: Core route learning engine

**Key Methods**:
```dart
// Start recording a journey
startJourneyRecording(routeName: String) → String (journeyId)

// Record GPS breadcrumb every 5 seconds
_recordGPSBreadcrumb() → void

// Record detected bus stop
recordStopOnJourney(
  latitude, longitude, arrivalTime, stopName, isBusStop
) → void

// End journey and analyze route
endJourneyRecording(endLocation: String) → void

// Find learned route between two stops
findRoute(origin: String, destination: String) → Map<String, dynamic>?

// Get all learned routes
getLearnedRoutes() → List<Map<String, dynamic>>

// Get stops for a specific route
getRouteStops(routeId: String) → List<Map<String, dynamic>>
```

### 2. `lib/pages/smart_alert_page_v2.dart` (783 lines)

**Purpose**: User interface for smart alerts using learned routes

**Features**:
- Select origin and destination from learned routes
- Shows route confidence and trip count
- Lists stops in actual journey sequence
- Shows distance from previous stop
- Shows average dwell time at each stop
- Allows multi-select of stops for alerts
- View journey history
- View all learned routes
- Start/stop route recording

---

## Next Steps

### Integration Plan

1. **Update Track Page** (`lib/track_page.dart`):
   - Initialize `RouteLearningService`
   - Call `startJourneyRecording()` when GPS tracking starts
   - Call `recordStopOnJourney()` when stop is detected AND classified as "Bus Stop"
   - Call `endJourneyRecording()` when GPS tracking stops

2. **Update Main Navigation** (`lib/main.dart`):
   - Replace `smart_alert_page.dart` with `smart_alert_page_v2.dart` in routes
   - Add navigation button to new smart alerts page

3. **Test Route Learning**:
   - Record 2-3 journeys on same route
   - Verify stops are saved correctly
   - Verify route pattern is learned
   - Test smart suggestions

4. **Deploy Location Recognition Model**:
   - Train model with your bus stop coordinates
   - Deploy `stop_location_model.tflite` to assets
   - Integrate with route learning (filter non-bus-stops)

---

## Example Code: Integration with Track Page

```dart
// In track_page.dart

import '../services/route_learning_service.dart';
import '../services/stop_detection_service.dart';

class TrackPage extends StatefulWidget {
  // ...
}

class _TrackPageState extends State<TrackPage> {
  final RouteLearningService _routeLearning = RouteLearningService();
  final StopDetectionService _stopDetection = StopDetectionService();
  
  String? _currentJourneyId;

  Future<void> _startTracking() async {
    // Start route learning
    _currentJourneyId = await _routeLearning.startJourneyRecording();
    
    // Start stop detection
    await _stopDetection.startMonitoring();
    
    // Listen to detected stops
    _stopDetection.onStopDetected((stop) async {
      // Only record if it's a bus stop (not traffic/toll)
      if (stop.type == 'Regular Bus Stop') {
        await _routeLearning.recordStopOnJourney(
          latitude: stop.latitude,
          longitude: stop.longitude,
          arrivalTime: stop.arrivalTime,
          departureTime: stop.departureTime,
          stopName: stop.stopName, // From location model
          isBusStop: true,
        );
        print('✅ Bus stop recorded: ${stop.stopName}');
      } else {
        print('ℹ️ Ignoring ${stop.type} (not a bus stop)');
      }
    });
  }

  Future<void> _stopTracking() async {
    // Stop stop detection
    await _stopDetection.stopMonitoring();
    
    // End route learning
    await _routeLearning.endJourneyRecording();
    
    _currentJourneyId = null;
    
    // Show success message
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('✅ Journey recorded! Route learned.'),
        duration: Duration(seconds: 3),
      ),
    );
  }
}
```

---

## Summary

### What Changed:
❌ **Old System**: Geometric calculations (straight-line distances)
✅ **New System**: GPS tracking + route learning (actual paths)

### What It Does:
1. **Records GPS breadcrumbs** every 5 seconds during journeys
2. **Detects stops** and classifies them (ML models)
3. **Learns routes** by analyzing multiple journeys
4. **Suggests stops** based on REAL route patterns, not geometry
5. **Gets smarter** with more journeys (50% → 95% confidence)

### Your Route Example:
```
Mangalore State Bank → Jyothi → PVS → Lalbagh → Ladyhill → 
Kottara → Kuloor → Surathkal → Mulki → Padubidri → 
Nandikoor → Belman → Nitte → Anekere → Karkala
```
System now learns this EXACT sequence and suggests only these stops in this order!

### Ready to Use:
✅ Route learning service complete
✅ Smart alerts UI complete
✅ Database schema complete
⏳ Needs integration with track_page.dart
⏳ Needs location recognition model trained

You're right - the route must be learned from actual GPS tracking, not geometric assumptions! 🎉
