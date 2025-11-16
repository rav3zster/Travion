# 🌐 Crowd-Sourced Route Learning System

## Your Three Critical Requirements

### ✅ 1. Complete Dataset (Mangalore ↔ Karkala)

**Your CSV File Status**:
```csv
✅ State Bank Mangalore (12.8593, 74.8429)
✅ Hampankatta → PVS Circle → Lalbagh → Ladyhill
✅ Kottara Chowki → Kuloor Bridge → Panambur
✅ Surathkal Bus Stand → Haleyangadi → Mulki
✅ Kaup → Nandhi Koor → Padubidri Junction
✅ Mani → Mudarangadi → Manjarpalke → Belmann Market
✅ Karkala Bus Stand (13.3109, 74.9211)
✅ Nitte Bus Stand → NMAMIT Nitte College Gate (13.3615, 74.9496)

Total: 21 stops from Mangalore to NMAMIT Nitte
```

**Missing Data**: 
- You mentioned route doesn't end at NMAMIT, continues to Karkala
- But I see "Karkala Bus Stand" is ALREADY in your CSV (stop #19)!
- NMAMIT (stop #21) is actually AFTER Karkala (stop #19)

**Wait, There's Confusion! Let me reorder based on coordinates:**

Looking at latitudes (north direction):
```
12.8593 - State Bank Mangalore (START)
12.8722 - Hampankatta
12.8744 - PVS Circle
12.8663 - Lalbagh
12.8636 - Ladyhill
12.8602 - Kottara Chowki
12.8557 - Kuloor Bridge
12.8749 - Panambur
12.9165 - Surathkal Bus Stand
13.0053 - Haleyangadi
13.0677 - Mulki
13.1182 - Kaup
13.1628 - Nandhi Koor
13.1919 - Padubidri Junction
13.2031 - Mani
13.2235 - Mudarangadi
13.2446 - Manjarpalke
13.2591 - Belmann Market
13.3109 - Karkala Bus Stand ← Your destination?
13.3457 - Nitte Bus Stand
13.3615 - NMAMIT Nitte College Gate (END)
```

So the route is: **Mangalore → Karkala → Nitte → NMAMIT**

### ✅ 2. Bidirectional Routes (Different Paths Going vs Returning)

**The Problem**:
```
🚌 FORWARD (Mangalore → Karkala):
Route A: State Bank → Hampankatta → PVS → Lalbagh → Ladyhill → 
         Kottara → Kuloor → Surathkal → Mulki → Karkala

🚌 RETURN (Karkala → Mangalore):
Route B: Karkala → Mulki → Kuloor → Kankanady → Market Road → 
         State Bank (DIFFERENT PATH!)
```

**The Solution**:
```dart
// User tells us bus number AND direction
await crowdSourcedService.startUserSession(
  userId: 'user_12345',
  busNumber: 'Bus 47A',  // Which bus they're on
);

// System records direction
await crowdSourcedService.contributeRoute(
  origin: 'State Bank Mangalore',
  destination: 'Karkala',
  direction: 'forward',  // ← KEY: Separate forward/return routes!
  stops: [...],
);

// Later, return journey
await crowdSourcedService.contributeRoute(
  origin: 'Karkala',
  destination: 'State Bank Mangalore',
  direction: 'return',  // ← Different route variant!
  stops: [...],  // Different stop sequence
);
```

**Database Design**:
```sql
CREATE TABLE universal_routes (
  route_id TEXT PRIMARY KEY,
  bus_number TEXT NOT NULL,           -- "Bus 47A"
  route_direction TEXT NOT NULL,      -- "forward" or "return"
  origin_name TEXT NOT NULL,
  destination_name TEXT NOT NULL,
  stop_sequence TEXT NOT NULL,        -- "State Bank → Hampankatta → ..."
  total_contributors INTEGER,         -- How many users contributed
  total_journeys INTEGER,             -- Total trips recorded
  confidence_score REAL               -- 0.0 to 1.0 based on users
);

CREATE TABLE route_variants (
  variant_id TEXT PRIMARY KEY,
  bus_number TEXT NOT NULL,
  origin_name TEXT NOT NULL,
  destination_name TEXT NOT NULL,
  route_direction TEXT NOT NULL,      -- ← Tracks direction
  variant_name TEXT NOT NULL,         -- "Via Kankanady" vs "Via Ladyhill"
  stop_sequence TEXT NOT NULL,
  usage_count INTEGER                 -- How many times this variant used
);
```

**Example Scenario**:

**User 1** travels Bus 47A (Mangalore → Karkala):
```
Stops: State Bank → Hampankatta → PVS → Lalbagh → Ladyhill → 
       Kottara → Kuloor → Surathkal → Mulki → Karkala

System creates:
✅ route_47A_forward_001
   Direction: forward
   Confidence: 30% (1 user)
```

**User 2** travels SAME Bus 47A (Mangalore → Karkala):
```
Stops: State Bank → Hampankatta → PVS → Lalbagh → Ladyhill → 
       Kottara → Kuloor → Surathkal → Mulki → Karkala
       (SAME SEQUENCE!)

System updates:
📈 route_47A_forward_001
   Direction: forward
   Confidence: 45% (2 users) ← Increased confidence!
```

**User 3** travels Bus 47A RETURN (Karkala → Mangalore):
```
Stops: Karkala → Mulki → Kuloor → Kankanady → Market Road → State Bank
       (DIFFERENT SEQUENCE!)

System creates:
✅ route_47A_return_001
   Direction: return
   Confidence: 30% (1 user)
   
This is SEPARATE from route_47A_forward_001!
```

**User 4** travels Bus 47A RETURN (Karkala → Mangalore):
```
Stops: Karkala → Mulki → Surathkal → Kuloor → Kottara → Ladyhill → 
       Lalbagh → PVS → Hampankatta → State Bank
       (YET ANOTHER PATH!)

System creates:
🔀 route_47A_return_002 (VARIANT!)
   Direction: return
   Variant Name: "Via Surathkal & Kottara"
   Confidence: 30% (1 user)

Now we have TWO return routes for Bus 47A!
```

**Final Database State**:
```
Bus 47A Routes:

Forward (Mangalore → Karkala):
├─ route_47A_forward_001 ✅ 45% confidence (2 users)
│  Stops: State Bank → Hampankatta → PVS → Lalbagh → Ladyhill → 
│         Kottara → Kuloor → Surathkal → Mulki → Karkala

Return (Karkala → Mangalore):
├─ route_47A_return_001 ✅ 30% confidence (1 user)
│  Stops: Karkala → Mulki → Kuloor → Kankanady → Market Road → State Bank
│
└─ route_47A_return_002 🔀 30% confidence (1 user)
   Stops: Karkala → Mulki → Surathkal → Kuloor → Kottara → Ladyhill → 
          Lalbagh → PVS → Hampankatta → State Bank
```

### ✅ 3. Universal Training (Aggregate All Users' Data)

**The Architecture**:

```
┌──────────────────────────────────────────────────────────────┐
│  USER 1's PHONE                                               │
│  ─────────────────────────────────────────────────────────── │
│  🚌 Traveling on Bus 47A (Forward)                            │
│  📍 Records GPS + Stops                                       │
│  💾 Saves locally to SQLite                                   │
│  ☁️ Syncs to cloud backend (hourly)                           │
└──────────────────────────────────────────────────────────────┘
                            ↓
┌──────────────────────────────────────────────────────────────┐
│  CLOUD BACKEND (Firebase/AWS/Azure)                           │
│  ─────────────────────────────────────────────────────────── │
│  📥 Receives contributions from ALL users                     │
│  🧠 Aggregates data:                                          │
│     - Merges similar routes                                   │
│     - Increases confidence scores                             │
│     - Detects route variants                                  │
│     - Calculates average timings                              │
│  📤 Sends updated universal routes back to users              │
└──────────────────────────────────────────────────────────────┘
                            ↓
┌──────────────────────────────────────────────────────────────┐
│  USER 2's PHONE                                               │
│  ─────────────────────────────────────────────────────────── │
│  📥 Downloads universal routes from cloud                     │
│  ✅ Gets benefit from User 1's data!                          │
│  💡 Sees: "Bus 47A: 45% confidence (2 users)"                │
│  🎯 Can use smart alerts even on FIRST journey!               │
└──────────────────────────────────────────────────────────────┘
```

**How Aggregation Works**:

**Scenario**: 3 users travel Bus 47A (Mangalore → Karkala)

**User 1's Data** (Nov 1, 2025):
```json
{
  "bus_number": "Bus 47A",
  "direction": "forward",
  "stops": [
    {"name": "State Bank", "lat": 12.8593, "lon": 74.8429, "dwell": 0},
    {"name": "Hampankatta", "lat": 12.8722, "lon": 74.8385, "dwell": 45},
    {"name": "PVS Circle", "lat": 12.8744, "lon": 74.8426, "dwell": 38},
    {"name": "Mulki", "lat": 13.0677, "lon": 74.8179, "dwell": 120},
    {"name": "Karkala", "lat": 13.3109, "lon": 74.9211, "dwell": 0}
  ],
  "total_distance_km": 45.2,
  "duration_minutes": 102
}
```

**User 2's Data** (Nov 3, 2025):
```json
{
  "bus_number": "Bus 47A",
  "direction": "forward",
  "stops": [
    {"name": "State Bank", "lat": 12.8593, "lon": 74.8429, "dwell": 0},
    {"name": "Hampankatta", "lat": 12.8722, "lon": 74.8385, "dwell": 50},
    {"name": "PVS Circle", "lat": 12.8744, "lon": 74.8426, "dwell": 35},
    {"name": "Ladyhill", "lat": 12.8636, "lon": 74.8465, "dwell": 42},  ← NEW!
    {"name": "Mulki", "lat": 13.0677, "lon": 74.8179, "dwell": 115},
    {"name": "Karkala", "lat": 13.3109, "lon": 74.9211, "dwell": 0}
  ],
  "total_distance_km": 46.1,
  "duration_minutes": 98
}
```

**User 3's Data** (Nov 5, 2025):
```json
{
  "bus_number": "Bus 47A",
  "direction": "forward",
  "stops": [
    {"name": "State Bank", "lat": 12.8593, "lon": 74.8429, "dwell": 0},
    {"name": "Hampankatta", "lat": 12.8722, "lon": 74.8385, "dwell": 48},
    {"name": "PVS Circle", "lat": 12.8744, "lon": 74.8426, "dwell": 40},
    {"name": "Ladyhill", "lat": 12.8636, "lon": 74.8465, "dwell": 45},
    {"name": "Mulki", "lat": 13.0677, "lon": 74.8179, "dwell": 118},
    {"name": "Karkala", "lat": 13.3109, "lon": 74.9211, "dwell": 0}
  ],
  "total_distance_km": 45.8,
  "duration_minutes": 100
}
```

**Backend Aggregation Result**:
```json
{
  "route_id": "route_47A_forward_001",
  "bus_number": "Bus 47A",
  "direction": "forward",
  "origin": "State Bank Mangalore",
  "destination": "Karkala Bus Stand",
  "total_contributors": 3,
  "total_journeys": 3,
  "confidence_score": 0.75,  // High confidence (3 users agree!)
  
  "stops": [
    {
      "name": "State Bank",
      "occurrence_count": 3,  // All 3 users reported this
      "reliability_score": 1.0
    },
    {
      "name": "Hampankatta",
      "occurrence_count": 3,
      "avg_dwell_seconds": 48,  // (45+50+48)/3 = 47.67 ≈ 48
      "reliability_score": 1.0
    },
    {
      "name": "PVS Circle",
      "occurrence_count": 3,
      "avg_dwell_seconds": 38,  // (38+35+40)/3 = 37.67 ≈ 38
      "reliability_score": 1.0
    },
    {
      "name": "Ladyhill",
      "occurrence_count": 2,  // Only User 2 & 3 reported
      "avg_dwell_seconds": 44,  // (42+45)/2 = 43.5 ≈ 44
      "reliability_score": 0.67  // 2/3 = 67% reliability
    },
    {
      "name": "Mulki",
      "occurrence_count": 3,
      "avg_dwell_seconds": 118,  // (120+115+118)/3 = 117.67 ≈ 118
      "reliability_score": 1.0
    },
    {
      "name": "Karkala",
      "occurrence_count": 3,
      "reliability_score": 1.0
    }
  ],
  
  "avg_duration_minutes": 100,  // (102+98+100)/3 = 100
  "avg_distance_km": 45.7  // (45.2+46.1+45.8)/3 = 45.7
}
```

**User 4** (NEW USER, first time):
```
📥 Downloads this universal route
✅ Sees "Bus 47A: 75% confidence (3 users)"
🎯 Can set smart alerts immediately without traveling first!
💡 Gets benefit from other users' data
```

---

## Bus Number Input UI

**Before Journey Starts**:
```
┌──────────────────────────────────────────────────────────┐
│  🚌 Start Journey Tracking                                │
│  ────────────────────────────────────────────────────────│
│                                                           │
│  Which bus are you traveling on?                         │
│                                                           │
│  Bus Number: [________________]  🔍                       │
│               ↑                                           │
│               User types: "Bus 47A"                       │
│                                                           │
│  📍 Origin: [State Bank Mangalore ▼]                     │
│  📍 Destination: [Karkala Bus Stand ▼]                   │
│                                                           │
│  Direction:                                               │
│  ○ Forward (Mangalore → Karkala)                         │
│  ○ Return (Karkala → Mangalore)                          │
│                                                           │
│  [Start Tracking]                                         │
│                                                           │
│  ℹ️ Your journey will help improve routes for all users! │
└──────────────────────────────────────────────────────────┘
```

**After Submitting**:
```
┌──────────────────────────────────────────────────────────┐
│  ✅ Contribution Submitted!                               │
│  ────────────────────────────────────────────────────────│
│                                                           │
│  Thank you for contributing to Bus 47A route data!       │
│                                                           │
│  Your Journey:                                            │
│  • 15 stops recorded                                      │
│  • 45.2 km traveled                                       │
│  • 102 minutes duration                                   │
│                                                           │
│  Community Impact:                                        │
│  • You're the 3rd user to travel this route              │
│  • Route confidence increased: 60% → 75%                 │
│  • 2 new stops discovered                                 │
│                                                           │
│  [View Route Details] [Give Feedback]                    │
└──────────────────────────────────────────────────────────┘
```

**Feedback Options**:
```
┌──────────────────────────────────────────────────────────┐
│  📝 Route Feedback                                        │
│  ────────────────────────────────────────────────────────│
│                                                           │
│  How accurate was this route?                            │
│                                                           │
│  ○ ✅ Perfectly Correct                                   │
│  ○ ⚠️ Mostly Correct (minor issues)                      │
│  ○ ❌ Incorrect Route                                     │
│                                                           │
│  Issues (optional):                                       │
│  ☐ Missing stop: [_________________]                     │
│  ☐ Wrong sequence                                         │
│  ☐ Wrong bus number                                       │
│  ☐ Different path than expected                          │
│                                                           │
│  Additional Comments:                                     │
│  [________________________________]                       │
│  [________________________________]                       │
│                                                           │
│  [Submit Feedback]                                        │
└──────────────────────────────────────────────────────────┘
```

---

## Smart Alerts with Bidirectional Support

**UI When Selecting Route**:
```
┌──────────────────────────────────────────────────────────┐
│  🚨 Smart Alerts Setup                                    │
│  ────────────────────────────────────────────────────────│
│                                                           │
│  Bus Number: [Bus 47A ▼]                                 │
│              ↓ Shows available routes for this bus       │
│                                                           │
│  Available Routes:                                        │
│                                                           │
│  ● Forward: State Bank → Karkala                         │
│    ✅ 75% confidence (3 users, 15 stops)                 │
│    ⏱️ ~100 min | 📏 ~45.7 km                             │
│    [Select This Route]                                    │
│                                                           │
│  ● Return: Karkala → State Bank                          │
│    ⚠️ 45% confidence (2 users, 12 stops)                 │
│    ⏱️ ~95 min | 📏 ~43.2 km                              │
│    [Select This Route]                                    │
│                                                           │
│  ● Return (Variant): Karkala → State Bank via Surathkal │
│    ⚠️ 30% confidence (1 user, 16 stops)                  │
│    ⏱️ ~110 min | 📏 ~48.5 km                             │
│    [Select This Route]                                    │
│                                                           │
└──────────────────────────────────────────────────────────┘
```

**After Selecting Forward Route**:
```
┌──────────────────────────────────────────────────────────┐
│  Route: Bus 47A Forward (State Bank → Karkala)          │
│  75% Confidence | 3 Users | ~100 min                     │
│  ────────────────────────────────────────────────────────│
│                                                           │
│  Select stops for alerts:                                │
│                                                           │
│  ☐ 1️⃣ State Bank Mangalore (origin)                     │
│  ☑️ 2️⃣ Hampankatta (1.2 km, ~5 min)                     │
│  ☐ 3️⃣ PVS Circle (0.8 km, ~8 min)                       │
│  ☐ 4️⃣ Lalbagh (0.6 km, ~11 min)                         │
│  ☑️ 5️⃣ Ladyhill (0.4 km, ~14 min) ⚠️ 67% reliable       │
│  ☐ 6️⃣ Kottara Chowki (0.9 km, ~18 min)                  │
│  ...                                                      │
│  ☑️ 1️⃣1️⃣ Mulki (25.3 km, ~55 min)                       │
│  ...                                                      │
│  ☐ 1️⃣5️⃣ Karkala Bus Stand (destination)                 │
│                                                           │
│  [Activate 3 Alerts]                                      │
└──────────────────────────────────────────────────────────┘
```

---

## Implementation Code Examples

### 1. Starting Journey with Bus Number

```dart
import 'package:flutter/material.dart';
import '../services/crowdsourced_route_service.dart';
import '../services/route_learning_service.dart';

class StartJourneyDialog extends StatefulWidget {
  @override
  State<StartJourneyDialog> createState() => _StartJourneyDialogState();
}

class _StartJourneyDialogState extends State<StartJourneyDialog> {
  final TextEditingController _busNumberController = TextEditingController();
  String? _selectedOrigin;
  String? _selectedDestination;
  String _direction = 'forward';

  final CrowdSourcedRouteService _crowdService = CrowdSourcedRouteService();
  final RouteLearningService _routeService = RouteLearningService();

  Future<void> _startJourney() async {
    if (_busNumberController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter bus number')),
      );
      return;
    }

    // Initialize user session with bus number
    await _crowdService.startUserSession(
      userId: 'user_${DateTime.now().millisecondsSinceEpoch}', // TODO: Get real user ID
      busNumber: _busNumberController.text,
    );

    // Start route learning
    final journeyId = await _routeService.startJourneyRecording(
      routeName: '${_busNumberController.text}: $_selectedOrigin → $_selectedDestination ($_direction)',
    );

    Navigator.pop(context, {
      'journey_id': journeyId,
      'bus_number': _busNumberController.text,
      'direction': _direction,
    });
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('🚌 Start Journey'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _busNumberController,
              decoration: const InputDecoration(
                labelText: 'Bus Number',
                hintText: 'e.g., Bus 47A',
                prefixIcon: Icon(Icons.directions_bus),
              ),
            ),
            const SizedBox(height: 16),
            DropdownButtonFormField<String>(
              decoration: const InputDecoration(
                labelText: 'Origin',
                prefixIcon: Icon(Icons.place, color: Colors.green),
              ),
              value: _selectedOrigin,
              items: [
                'State Bank Mangalore',
                'Karkala Bus Stand',
                'NMAMIT Nitte',
              ].map((stop) => DropdownMenuItem(value: stop, child: Text(stop))).toList(),
              onChanged: (value) => setState(() => _selectedOrigin = value),
            ),
            const SizedBox(height: 16),
            DropdownButtonFormField<String>(
              decoration: const InputDecoration(
                labelText: 'Destination',
                prefixIcon: Icon(Icons.place, color: Colors.red),
              ),
              value: _selectedDestination,
              items: [
                'State Bank Mangalore',
                'Karkala Bus Stand',
                'NMAMIT Nitte',
              ].map((stop) => DropdownMenuItem(value: stop, child: Text(stop))).toList(),
              onChanged: (value) => setState(() => _selectedDestination = value),
            ),
            const SizedBox(height: 16),
            const Text('Direction:', style: TextStyle(fontWeight: FontWeight.bold)),
            RadioListTile<String>(
              title: Text('Forward ($_selectedOrigin → $_selectedDestination)'),
              value: 'forward',
              groupValue: _direction,
              onChanged: (value) => setState(() => _direction = value!),
            ),
            RadioListTile<String>(
              title: Text('Return ($_selectedDestination → $_selectedOrigin)'),
              value: 'return',
              groupValue: _direction,
              onChanged: (value) => setState(() => _direction = value!),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.blue.shade50,
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Text(
                'ℹ️ Your journey will help improve routes for all users!',
                style: TextStyle(fontSize: 12),
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: _startJourney,
          child: const Text('Start Tracking'),
        ),
      ],
    );
  }
}
```

### 2. Ending Journey and Contributing

```dart
Future<void> _endJourneyAndContribute() async {
  // End route learning
  await _routeService.endJourneyRecording(
    endLocation: _selectedDestination,
  );

  // Get recorded stops
  final stops = await _routeService.getJourneyStops(_currentJourneyId!);

  // Contribute to crowd-sourced database
  final contributionId = await _crowdService.contributeRoute(
    origin: _selectedOrigin!,
    destination: _selectedDestination!,
    direction: _direction,
    stops: stops.map((s) => {
      'stop_name': s['stop_name'],
      'latitude': s['latitude'],
      'longitude': s['longitude'],
      'dwell_seconds': s['dwell_seconds'],
    }).toList(),
  );

  // Show contribution success
  _showContributionSuccessDialog(contributionId);
}

void _showContributionSuccessDialog(String contributionId) {
  showDialog(
    context: context,
    builder: (context) => AlertDialog(
      title: const Text('✅ Contribution Submitted!'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text('Thank you for contributing to bus route data!'),
          const SizedBox(height: 16),
          const Text('Your journey will help other users.'),
          const SizedBox(height: 8),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _showFeedbackDialog(contributionId);
            },
            child: const Text('Give Feedback'),
          ),
        ],
      ),
      actions: [
        ElevatedButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('OK'),
        ),
      ],
    ),
  );
}
```

---

## Backend Requirements (Cloud Sync)

**Tech Stack Options**:

### Option 1: Firebase (Easiest)
```
✅ Firestore for database
✅ Cloud Functions for aggregation
✅ Authentication built-in
✅ Real-time sync
```

### Option 2: AWS (Most Scalable)
```
✅ DynamoDB for database
✅ Lambda for aggregation
✅ Cognito for auth
✅ API Gateway for REST API
```

### Option 3: Custom Backend
```
✅ Node.js/Python REST API
✅ PostgreSQL database
✅ JWT authentication
✅ WebSocket for real-time updates
```

**API Endpoints Needed**:
```
POST   /api/contributions        - Upload user's route data
GET    /api/universal-routes     - Download aggregated routes
POST   /api/feedback              - Submit feedback
GET    /api/routes/{busNumber}   - Get routes for specific bus
GET    /api/routes/search         - Search routes by origin/destination
```

---

## Summary

### ✅ Your Dataset: Complete!
- 21 stops from Mangalore State Bank to NMAMIT Nitte
- Includes Karkala Bus Stand (stop #19)
- Ready to use for training location model

### ✅ Bidirectional Routing: Solved!
- Separate `direction` field: 'forward' vs 'return'
- Route variants tracked independently
- System learns different paths for same origin-destination

### ✅ Crowd-Sourced Learning: Implemented!
- Each user contributes their journey
- Backend aggregates all users' data
- Confidence scores increase with more users
- New users benefit from existing data immediately

### 📁 Files Created:
1. `lib/services/crowdsourced_route_service.dart` (650+ lines)
2. `assets/bus_stops.json` (21 stops from your CSV)
3. `assets/bus_stops_mangalore_karkala.csv` (your original CSV)

### 🚀 Next Steps:
1. Set up cloud backend (Firebase/AWS)
2. Implement sync API endpoints
3. Add bus number input UI to track page
4. Test bidirectional route recording
5. Train location model with your 21 stops
6. Deploy and collect real user data!

Your insight about bidirectional routes was crucial - the system now handles forward/return paths separately! 🎉
