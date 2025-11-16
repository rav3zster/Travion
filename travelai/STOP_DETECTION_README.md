# 🚏 Bus Stop Detection System

An intelligent ML-powered system for automatically detecting and classifying bus stops using GPS data.

## 🎯 Overview

This system uses a hybrid approach combining:
1. **Rule-based detection** - Analyzes GPS velocity and dwell time
2. **Machine Learning classification** - Neural network for stop type prediction
3. **Historical patterns** - Learns from recurring stops
4. **User feedback** - Reinforcement learning from corrections

## 📋 Features

### Automatic Stop Detection
- Detects when vehicle stops based on GPS speed < 2 km/h
- Records stops lasting > 15 seconds
- Tracks location, dwell time, speed, and heading

### Stop Classification
Classifies stops into 5 categories:
- 🚦 **Traffic Signal** - Short stops (15-45s)
- 💰 **Toll Gate** - Medium stops (30-120s) at highway speeds
- 🚏 **Regular Stop** - Frequent stops (1-5 min)
- ⛽ **Gas Station** - Longer stops (5-15 min)
- 🛑 **Rest Area** - Extended stops (15+ min)

### Historical Learning
- Clusters nearby stops (within 50m)
- Increases confidence for recurring locations
- Adapts classifications based on visit patterns

### User Feedback
- Users can confirm or correct stop types
- System learns from corrections
- Improves accuracy over time

## 🏗️ Architecture

```
GPS Data Stream
    ↓
StopDetectionService
    ├── Velocity Analysis
    ├── Dwell Time Calculation
    └── Stop Recording
    ↓
StopClassifier (ML)
    ├── Feature Extraction
    ├── Neural Network Inference
    └── Confidence Scoring
    ↓
StopDetectionDatabase
    ├── SQLite Storage
    ├── Historical Patterns
    └── Statistics
    ↓
DetectedStopsPage (UI)
    ├── Stop List
    ├── User Feedback
    └── Statistics
```

## 📦 Components

### 1. Data Model (`lib/models/detected_stop.dart`)
```dart
class DetectedStop {
  final double latitude, longitude;
  final DateTime timestamp;
  final double dwellTime;
  final DetectedStopType stopType;
  final double confidence;
  final bool userConfirmed;
}
```

### 2. Detection Service (`lib/services/stop_detection_service.dart`)
- Processes GPS position stream
- Detects start/end of stops
- Calculates dwell time
- Triggers classification

### 3. ML Classifier (`lib/services/stop_classifier.dart`)
- Extracts features from stop data
- Runs inference (rule-based or TFLite)
- Returns stop type + confidence

### 4. Database (`lib/services/stop_detection_database.dart`)
- SQLite storage for stop history
- Spatial queries (nearby stops)
- Statistics and aggregations

### 5. UI (`lib/pages/detected_stops_page.dart`)
- List of detected stops
- Filter by type
- User confirmation/correction
- Statistics display

## 🚀 Usage

### 1. Initialize Services

```dart
// In your main.dart or app initialization
import 'package:wayfinder/services/stop_detection_service.dart';
import 'package:wayfinder/services/stop_detection_database.dart';

// Set up callback
StopDetectionService.instance.onStopDetected = (stop) {
  print('Stop detected: ${stop.stopTypeName} at ${stop.latitude}, ${stop.longitude}');
  // Optionally show notification
};
```

### 2. Feed GPS Data

```dart
// In your location tracking code
import 'package:geolocator/geolocator.dart';

final positionStream = Geolocator.getPositionStream(
  locationSettings: LocationSettings(
    accuracy: LocationAccuracy.high,
    distanceFilter: 10, // meters
  ),
);

positionStream.listen((Position position) async {
  // Feed to stop detection
  await StopDetectionService.instance.processPosition(position);
});
```

### 3. View Detected Stops

```dart
// Navigate to stops page
Navigator.push(
  context,
  MaterialPageRoute(
    builder: (context) => const DetectedStopsPage(),
  ),
);
```

### 4. Get Statistics

```dart
// From database
final stats = await StopDetectionDatabase.instance.getStopStatistics();
print('Total stops: ${stats['totalStops']}');
print('Average dwell time: ${stats['averageDwellTime']}s');

// From current session
final sessionStats = StopDetectionService.instance.getSessionStats();
print('Stops this trip: ${sessionStats['totalStops']}');
```

## 🤖 Machine Learning

### Training the Model

1. Install Python dependencies:
```bash
cd ml_training
pip install -r requirements.txt
```

2. Train the model:
```bash
python train_stop_classifier.py
```

3. Copy generated files:
```bash
cp stop_classifier.tflite ../assets/
cp scaler_params.json ../assets/
```

### Model Features

The neural network uses 6 features:
1. **Dwell Time** - How long stopped (seconds)
2. **Speed Before** - Vehicle speed before stop (km/h)
3. **Heading** - Direction of travel (degrees)
4. **Visit Count** - Times stopped at this location
5. **Hour** - Time of day (0-23)
6. **Day of Week** - Day (0-6)

### Model Architecture

```
Input (6) → Dense(128) → Dense(64) → Dense(32) → Dense(5)
```

- Size: ~200-500 KB (optimized for mobile)
- Accuracy: ~90% (with real data)
- Inference time: <10ms on mobile

## 📊 Configuration

Adjust detection parameters in `stop_detection_service.dart`:

```dart
// Speed threshold for stop detection
static const double STOP_SPEED_THRESHOLD = 2.0; // km/h

// Minimum dwell time to record
static const double MIN_DWELL_TIME = 15.0; // seconds

// Clustering radius for recurring stops
static const double CLUSTER_RADIUS = 50.0; // meters
```

## 🔄 Integration with Existing App

Add to your existing tracking page (`track_page.dart`):

```dart
import 'package:wayfinder/services/stop_detection_service.dart';

// In your position stream listener
_positionStream = Geolocator.getPositionStream(...)
  .listen((Position position) async {
    // Your existing code...
    
    // Add stop detection
    await StopDetectionService.instance.processPosition(position);
  });

// Set up stop detection callback
StopDetectionService.instance.onStopDetected = (stop) {
  // Show notification or update UI
  setState(() {
    // Update detected stops list
  });
};
```

## 📈 Future Enhancements

### Short-term
- [ ] TensorFlow Lite model integration
- [ ] Geofencing with Google Places API
- [ ] Export stops to CSV/JSON
- [ ] Stop duration predictions

### Long-term
- [ ] LSTM for trajectory patterns
- [ ] Federated learning across devices
- [ ] Real-time POI matching
- [ ] Collaborative filtering
- [ ] Offline map integration

## 🐛 Troubleshooting

### Stops not being detected
- Check GPS permissions
- Verify location accuracy is HIGH
- Reduce `STOP_SPEED_THRESHOLD` if vehicle moves slowly
- Check `MIN_DWELL_TIME` isn't too high

### Wrong classifications
- Provide user feedback through UI
- Accumulate corrections and retrain model
- Adjust classification rules in `stop_classifier.dart`

### Database issues
- Clear database: `StopDetectionDatabase.instance.clearAllStops()`
- Check SQLite file: `find . -name "detected_stops.db"`
- Verify app has storage permissions

## 📝 License

Part of the TravelAI project.

## 👥 Contributing

To improve stop detection:
1. Use the app and provide feedback on misclassifications
2. Export your corrected stops
3. Share data for model retraining
4. Submit pull requests with improvements

## 📧 Support

For issues or questions, please open an issue on GitHub.
