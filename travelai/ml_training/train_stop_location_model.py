"""
Bus Stop Location Recognition Model

This model learns the GPS coordinates of known bus stops
and predicts if a new GPS location is near a known stop.

Input: Your dataset of bus stop coordinates
Output: Is this location a known bus stop? (Yes/No + confidence)
"""

import numpy as np
import pandas as pd
from sklearn.model_selection import train_test_split
from sklearn.preprocessing import StandardScaler
from sklearn.neighbors import NearestNeighbors
import tensorflow as tf
from tensorflow import keras
from tensorflow.keras import layers
import json

def load_your_bus_stops(csv_path):
    """
    Load your bus stop coordinate dataset
    
    Expected CSV format:
    stop_id, latitude, longitude, stop_name, stop_type (optional)
    
    Example:
    1, 28.6139, 77.2090, "Connaught Place", "regular"
    2, 28.6517, 77.2219, "Red Fort", "regular"
    """
    df = pd.read_csv(csv_path)
    
    # Ensure required columns exist
    required_cols = ['latitude', 'longitude']
    if not all(col in df.columns for col in required_cols):
        raise ValueError(f"CSV must contain: {required_cols}")
    
    return df

def create_training_data(bus_stops_df, negative_samples_per_stop=5):
    """
    Create training data from known bus stops
    
    Positive samples: Actual bus stop locations + small GPS noise
    Negative samples: Random locations NOT near bus stops
    """
    positive_data = []
    negative_data = []
    
    # Get bounding box of all stops
    lat_min, lat_max = bus_stops_df['latitude'].min(), bus_stops_df['latitude'].max()
    lon_min, lon_max = bus_stops_df['longitude'].min(), bus_stops_df['longitude'].max()
    
    # Expand boundaries by 10%
    lat_range = lat_max - lat_min
    lon_range = lon_max - lon_min
    lat_min -= lat_range * 0.1
    lat_max += lat_range * 0.1
    lon_min -= lon_range * 0.1
    lon_max += lon_range * 0.1
    
    # Create positive samples (actual stops + GPS noise)
    for _, stop in bus_stops_df.iterrows():
        # Original location
        positive_data.append({
            'latitude': stop['latitude'],
            'longitude': stop['longitude'],
            'is_bus_stop': 1
        })
        
        # Add variations with GPS noise (simulates real-world GPS error)
        for _ in range(3):
            # GPS noise: ~10-30 meters (roughly 0.0001-0.0003 degrees)
            lat_noise = np.random.normal(0, 0.0002)
            lon_noise = np.random.normal(0, 0.0002)
            
            positive_data.append({
                'latitude': stop['latitude'] + lat_noise,
                'longitude': stop['longitude'] + lon_noise,
                'is_bus_stop': 1
            })
    
    # Create negative samples (random locations far from stops)
    n_negatives = len(bus_stops_df) * negative_samples_per_stop
    
    for _ in range(n_negatives):
        # Generate random location
        lat = np.random.uniform(lat_min, lat_max)
        lon = np.random.uniform(lon_min, lon_max)
        
        # Check if it's far enough from all bus stops (> 100 meters)
        min_distance = min(
            haversine_distance(lat, lon, stop['latitude'], stop['longitude'])
            for _, stop in bus_stops_df.iterrows()
        )
        
        # Only add if far from all stops
        if min_distance > 0.1:  # > 100 meters
            negative_data.append({
                'latitude': lat,
                'longitude': lon,
                'is_bus_stop': 0
            })
    
    # Combine and shuffle
    all_data = pd.DataFrame(positive_data + negative_data)
    all_data = all_data.sample(frac=1).reset_index(drop=True)
    
    return all_data

def haversine_distance(lat1, lon1, lat2, lon2):
    """
    Calculate distance between two GPS points in kilometers
    """
    R = 6371  # Earth's radius in km
    
    lat1, lon1, lat2, lon2 = map(np.radians, [lat1, lon1, lat2, lon2])
    dlat = lat2 - lat1
    dlon = lon2 - lon1
    
    a = np.sin(dlat/2)**2 + np.cos(lat1) * np.cos(lat2) * np.sin(dlon/2)**2
    c = 2 * np.arcsin(np.sqrt(a))
    
    return R * c

def create_location_model():
    """
    Create neural network for bus stop recognition
    """
    model = keras.Sequential([
        layers.Input(shape=(2,)),  # lat, lon
        
        layers.Dense(64, activation='relu'),
        layers.Dropout(0.3),
        layers.BatchNormalization(),
        
        layers.Dense(32, activation='relu'),
        layers.Dropout(0.2),
        
        layers.Dense(16, activation='relu'),
        
        layers.Dense(1, activation='sigmoid')  # Binary: is_bus_stop
    ])
    
    model.compile(
        optimizer='adam',
        loss='binary_crossentropy',
        metrics=['accuracy', keras.metrics.Precision(), keras.metrics.Recall()]
    )
    
    return model

def train_location_model(csv_path):
    """
    Main training function
    """
    print(f"Loading bus stops from {csv_path}...")
    bus_stops = load_your_bus_stops(csv_path)
    print(f"Loaded {len(bus_stops)} bus stops")
    
    print("\nCreating training data...")
    training_data = create_training_data(bus_stops)
    print(f"Generated {len(training_data)} training samples")
    print(f"  Positive (bus stops): {training_data['is_bus_stop'].sum()}")
    print(f"  Negative (not stops): {(~training_data['is_bus_stop'].astype(bool)).sum()}")
    
    # Prepare data
    X = training_data[['latitude', 'longitude']].values
    y = training_data['is_bus_stop'].values
    
    # Split
    X_train, X_test, y_train, y_test = train_test_split(
        X, y, test_size=0.2, random_state=42, stratify=y
    )
    
    # Normalize
    scaler = StandardScaler()
    X_train = scaler.fit_transform(X_train)
    X_test = scaler.transform(X_test)
    
    # Save scaler and bus stops
    model_metadata = {
        'scaler_mean': scaler.mean_.tolist(),
        'scaler_scale': scaler.scale_.tolist(),
        'num_bus_stops': len(bus_stops),
        'bus_stops': bus_stops.to_dict('records')
    }
    
    with open('stop_location_metadata.json', 'w') as f:
        json.dump(model_metadata, f, indent=2)
    
    print("\nTraining model...")
    model = create_location_model()
    
    history = model.fit(
        X_train, y_train,
        validation_split=0.2,
        epochs=50,
        batch_size=32,
        callbacks=[
            keras.callbacks.EarlyStopping(patience=10, restore_best_weights=True),
            keras.callbacks.ReduceLROnPlateau(factor=0.5, patience=5)
        ],
        verbose=1
    )
    
    # Evaluate
    print("\nEvaluating...")
    results = model.evaluate(X_test, y_test)
    print(f"Test accuracy: {results[1]:.4f}")
    print(f"Test precision: {results[2]:.4f}")
    print(f"Test recall: {results[3]:.4f}")
    
    # Convert to TFLite
    print("\nConverting to TFLite...")
    converter = tf.lite.TFLiteConverter.from_keras_model(model)
    converter.optimizations = [tf.lite.Optimize.DEFAULT]
    tflite_model = converter.convert()
    
    with open('stop_location_model.tflite', 'wb') as f:
        f.write(tflite_model)
    
    print(f"Model saved! Size: {len(tflite_model) / 1024:.2f} KB")
    
    print("\n✅ Training complete!")
    print("\nNext steps:")
    print("1. Copy 'stop_location_model.tflite' to Flutter assets/")
    print("2. Copy 'stop_location_metadata.json' to Flutter assets/")
    print("3. Update Flutter code to use location recognition")

if __name__ == "__main__":
    # USAGE: Replace with your CSV file path
    CSV_PATH = "your_bus_stops.csv"
    
    # Check if file exists
    import os
    if not os.path.exists(CSV_PATH):
        print(f"❌ Error: File '{CSV_PATH}' not found!")
        print("\nPlease create a CSV file with your bus stop data:")
        print("Format: stop_id, latitude, longitude, stop_name")
        print("\nExample:")
        print("1, 28.6139, 77.2090, 'Connaught Place'")
        print("2, 28.6517, 77.2219, 'Red Fort'")
    else:
        train_location_model(CSV_PATH)
