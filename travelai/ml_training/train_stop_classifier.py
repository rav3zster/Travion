"""
Bus Stop Classification Model Training Script

This script trains a neural network to classify bus stops into different types:
- Traffic Signal
- Toll Gate
- Regular Stop
- Gas Station
- Rest Area

Features used:
- Dwell time
- Speed before stop
- Heading
- Visit count (historical)
- Time of day
- Day of week
"""

import numpy as np
import pandas as pd
from sklearn.model_selection import train_test_split
from sklearn.preprocessing import StandardScaler
import tensorflow as tf
from tensorflow import keras
from tensorflow.keras import layers
import json

# Stop types
STOP_TYPES = {
    0: 'traffic_signal',
    1: 'toll_gate',
    2: 'regular_stop',
    3: 'gas_station',
    4: 'rest_area',
    5: 'unknown'
}

def generate_synthetic_data(n_samples=10000):
    """
    Generate synthetic training data based on typical stop patterns
    In production, this would be replaced with real GPS data
    """
    data = []
    
    for _ in range(n_samples):
        # Randomly select a stop type
        stop_type = np.random.choice([0, 1, 2, 3, 4])
        
        # Generate features based on stop type patterns
        if stop_type == 0:  # Traffic Signal
            dwell_time = np.random.normal(25, 10)  # 15-45 seconds
            speed_before = np.random.normal(35, 15)  # City speed
            visit_count = np.random.randint(1, 5)
            
        elif stop_type == 1:  # Toll Gate
            dwell_time = np.random.normal(60, 20)  # 30-120 seconds
            speed_before = np.random.normal(70, 20)  # Highway speed
            visit_count = np.random.randint(1, 10)
            
        elif stop_type == 2:  # Regular Stop
            dwell_time = np.random.normal(120, 40)  # 1-5 minutes
            speed_before = np.random.normal(30, 10)  # City speed
            visit_count = np.random.randint(3, 20)  # High frequency
            
        elif stop_type == 3:  # Gas Station
            dwell_time = np.random.normal(420, 180)  # 5-15 minutes
            speed_before = np.random.normal(60, 15)
            visit_count = np.random.randint(1, 8)
            
        else:  # Rest Area
            dwell_time = np.random.normal(1200, 300)  # 15-30 minutes
            speed_before = np.random.normal(70, 15)  # Highway
            visit_count = np.random.randint(1, 5)
        
        # Additional features
        heading = np.random.uniform(0, 360)
        hour = np.random.randint(0, 24)
        day_of_week = np.random.randint(0, 7)
        
        # Clip values to realistic ranges
        dwell_time = max(10, dwell_time)
        speed_before = max(0, min(120, speed_before))
        
        data.append({
            'dwell_time': dwell_time,
            'speed_before': speed_before,
            'heading': heading,
            'visit_count': visit_count,
            'hour': hour,
            'day_of_week': day_of_week,
            'stop_type': stop_type
        })
    
    return pd.DataFrame(data)

def create_model(input_shape, num_classes):
    """
    Create a neural network model for stop classification
    """
    model = keras.Sequential([
        layers.Input(shape=(input_shape,)),
        
        # Dense layers with dropout for regularization
        layers.Dense(128, activation='relu'),
        layers.Dropout(0.3),
        layers.BatchNormalization(),
        
        layers.Dense(64, activation='relu'),
        layers.Dropout(0.2),
        layers.BatchNormalization(),
        
        layers.Dense(32, activation='relu'),
        layers.Dropout(0.2),
        
        # Output layer
        layers.Dense(num_classes, activation='softmax')
    ])
    
    return model

def train_model(X_train, y_train, X_val, y_val):
    """
    Train the classification model
    """
    # Create model
    model = create_model(X_train.shape[1], len(STOP_TYPES))
    
    # Compile
    model.compile(
        optimizer=keras.optimizers.Adam(learning_rate=0.001),
        loss='sparse_categorical_crossentropy',
        metrics=['accuracy']
    )
    
    # Callbacks
    early_stopping = keras.callbacks.EarlyStopping(
        monitor='val_loss',
        patience=10,
        restore_best_weights=True
    )
    
    reduce_lr = keras.callbacks.ReduceLROnPlateau(
        monitor='val_loss',
        factor=0.5,
        patience=5,
        min_lr=0.00001
    )
    
    # Train
    history = model.fit(
        X_train, y_train,
        validation_data=(X_val, y_val),
        epochs=100,
        batch_size=32,
        callbacks=[early_stopping, reduce_lr],
        verbose=1
    )
    
    return model, history

def convert_to_tflite(model, output_path='stop_classifier.tflite'):
    """
    Convert Keras model to TensorFlow Lite format for mobile deployment
    """
    # Convert to TFLite
    converter = tf.lite.TFLiteConverter.from_keras_model(model)
    
    # Optimization for mobile
    converter.optimizations = [tf.lite.Optimize.DEFAULT]
    converter.target_spec.supported_types = [tf.float16]
    
    tflite_model = converter.convert()
    
    # Save
    with open(output_path, 'wb') as f:
        f.write(tflite_model)
    
    print(f"TFLite model saved to {output_path}")
    print(f"Model size: {len(tflite_model) / 1024:.2f} KB")

def main():
    print("Generating synthetic training data...")
    df = generate_synthetic_data(n_samples=10000)
    
    print("\nData distribution:")
    print(df['stop_type'].value_counts())
    
    # Prepare features and labels
    feature_columns = ['dwell_time', 'speed_before', 'heading', 'visit_count', 'hour', 'day_of_week']
    X = df[feature_columns].values
    y = df['stop_type'].values
    
    # Split data
    X_train, X_test, y_train, y_test = train_test_split(X, y, test_size=0.2, random_state=42, stratify=y)
    X_train, X_val, y_train, y_val = train_test_split(X_train, y_train, test_size=0.2, random_state=42, stratify=y_train)
    
    # Normalize features
    scaler = StandardScaler()
    X_train = scaler.fit_transform(X_train)
    X_val = scaler.transform(X_val)
    X_test = scaler.transform(X_test)
    
    # Save scaler parameters
    scaler_params = {
        'mean': scaler.mean_.tolist(),
        'scale': scaler.scale_.tolist(),
        'feature_names': feature_columns
    }
    
    with open('scaler_params.json', 'w') as f:
        json.dump(scaler_params, f, indent=2)
    
    print("\nTraining model...")
    model, history = train_model(X_train, y_train, X_val, y_val)
    
    # Evaluate
    print("\nEvaluating on test set...")
    test_loss, test_acc = model.evaluate(X_test, y_test)
    print(f"Test accuracy: {test_acc:.4f}")
    
    # Convert to TFLite
    print("\nConverting to TensorFlow Lite...")
    convert_to_tflite(model)
    
    # Save full model
    model.save('stop_classifier_full.h5')
    print("Full Keras model saved to stop_classifier_full.h5")
    
    # Print summary
    print("\nModel Summary:")
    model.summary()
    
    print("\n✅ Training complete!")
    print("\nNext steps:")
    print("1. Copy 'stop_classifier.tflite' to 'assets/' folder in Flutter project")
    print("2. Copy 'scaler_params.json' to 'assets/' folder")
    print("3. Update pubspec.yaml to include these assets")
    print("4. Implement TFLite inference in Flutter app")

if __name__ == "__main__":
    main()
