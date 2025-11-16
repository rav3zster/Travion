# Bus Stop Classification ML Model

This directory contains the machine learning model training scripts for bus stop classification.

## Features

The model uses the following features to classify stops:
- **Dwell Time**: How long the vehicle was stopped (seconds)
- **Speed Before Stop**: Vehicle speed before stopping (km/h)
- **Heading**: Direction of travel (degrees)
- **Visit Count**: Number of times stopped at this location
- **Time of Day**: Hour (0-23)
- **Day of Week**: Day (0-6)

## Stop Types

The model classifies stops into 5 categories:
1. **Traffic Signal** - Short stops (15-45s) at city speeds
2. **Toll Gate** - Medium stops (30-120s) at highway speeds
3. **Regular Stop** - Medium stops (1-5 min) with high frequency
4. **Gas Station** - Longer stops (5-15 min)
5. **Rest Area** - Very long stops (15+ min)

## Setup

1. Install Python dependencies:
```bash
pip install -r requirements.txt
```

2. Train the model:
```bash
python train_stop_classifier.py
```

This will generate:
- `stop_classifier.tflite` - Optimized model for mobile (200-500 KB)
- `stop_classifier_full.h5` - Full Keras model for analysis
- `scaler_params.json` - Feature normalization parameters

## Integration with Flutter

1. Copy generated files to Flutter project:
```bash
cp stop_classifier.tflite ../assets/
cp scaler_params.json ../assets/
```

2. Update `pubspec.yaml`:
```yaml
flutter:
  assets:
    - assets/stop_classifier.tflite
    - assets/scaler_params.json
```

3. The model is automatically loaded by `StopClassifier` service

## Model Architecture

```
Input (6 features)
    ↓
Dense(128) + ReLU + Dropout(0.3) + BatchNorm
    ↓
Dense(64) + ReLU + Dropout(0.2) + BatchNorm
    ↓
Dense(32) + ReLU + Dropout(0.2)
    ↓
Dense(5) + Softmax
    ↓
Output (5 stop types)
```

## Performance

With synthetic data:
- **Training Accuracy**: ~95%
- **Validation Accuracy**: ~92%
- **Test Accuracy**: ~90%

With real GPS data, accuracy will improve with more training samples.

## Collecting Real Data

To improve the model with real data:

1. Export stops from SQLite database:
```dart
final stops = await StopDetectionDatabase.instance.getAllStops();
```

2. User confirms/corrects stop types in the app

3. Export to CSV for retraining:
```python
df = pd.read_csv('real_stops.csv')
# Retrain model with real data
```

## Reinforcement Learning (Future)

The system is designed for reinforcement learning:

1. **Reward Function**: User confirmation/correction
2. **State**: GPS features + historical patterns
3. **Action**: Classify stop type
4. **Learning**: Update model weights based on feedback

Implementation options:
- Online learning with gradient descent
- Batch retraining with accumulated feedback
- Federated learning across multiple devices

## Advanced Features (TODO)

- [ ] LSTM for trajectory pattern recognition
- [ ] Geofencing with known POIs (Google Places API)
- [ ] Collaborative filtering (learn from other users)
- [ ] Transfer learning from pre-trained models
- [ ] Explainable AI (feature importance visualization)
