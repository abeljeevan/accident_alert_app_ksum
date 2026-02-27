"""
Data Preprocessing Script
Converts test_motion_data.csv format to training-ready format
"""

import pandas as pd
import numpy as np
from datetime import datetime
import os

def preprocess_motion_data():
    """
    Convert motion sensor data to accident detection format
    Input: AccX, AccY, AccZ, GyroX, GyroY, GyroZ, Class, Timestamp
    Output: Full feature set for accident detection
    """
    
    print("="*60)
    print("🔄 DATA PREPROCESSING PIPELINE")
    print("="*60)
    
    # Load raw data
    print("\n1️⃣  Loading raw data...")
    try:
        df = pd.read_csv('raw_data/combined_dataset.csv')
        print(f"   ✅ Loaded {len(df)} records")
        print(f"   Columns: {list(df.columns)}")
    except Exception as e:
        print(f"   ❌ Error loading data: {e}")
        return
    
    # Display unique classes
    print(f"\n2️⃣  Analyzing data...")
    print(f"   Unique classes: {df['Class'].unique()}")
    print(f"   Class distribution:")
    print(df['Class'].value_counts())
    
    # Feature Engineering
    print(f"\n3️⃣  Engineering features...")
    
    # Calculate impact magnitude from accelerometer
    df['impact_magnitude'] = np.sqrt(
        df['AccX']**2 + df['AccY']**2 + df['AccZ']**2
    )
    
    # Calculate rotation magnitude from gyroscope
    df['rotation_magnitude'] = np.sqrt(
        df['GyroX']**2 + df['GyroY']**2 + df['GyroZ']**2
    )
    
    # Rename columns to standard format
    df = df.rename(columns={
        'AccX': 'impact_x',
        'AccY': 'impact_y',
        'AccZ': 'impact_z',
        'GyroX': 'rotation_x',
        'GyroY': 'rotation_y',
        'GyroZ': 'rotation_z',
        'Timestamp': 'timestamp'
    })
    
    # Add derived features
    # Speed simulation (based on consecutive acceleration changes)
    df['speed_change'] = df['impact_magnitude'].diff().abs().fillna(0)
    
    # Simulate pre/post speeds (for features that need it)
    df['pre_speed'] = df['impact_magnitude'] * 2.5  # Rough estimate
    df['post_speed'] = df['pre_speed'] - df['speed_change']
    df['post_speed'] = df['post_speed'].clip(lower=0)  # Can't be negative
    
    # Calculate immobility (low acceleration = not moving)
    # If impact magnitude is very low, consider it immobile
    df['immobility_duration'] = (df['impact_magnitude'] < 1.0).astype(int) * 3
    
    # Impact duration (estimate based on magnitude)
    df['impact_duration'] = np.where(
        df['impact_magnitude'] > 5.0,
        np.random.uniform(0.2, 0.8, len(df)),  # Real impacts last longer
        np.random.uniform(0.01, 0.15, len(df))  # Brief movements
    )
    
    # Secondary impacts (higher magnitude suggests multiple impacts)
    df['secondary_impacts'] = np.where(
        df['impact_magnitude'] > 10.0,
        np.random.randint(1, 4, len(df)),
        0
    )
    
    # Additional features
    df['altitude_change'] = np.random.uniform(0, 2, len(df))
    df['gps_accuracy'] = np.random.uniform(3, 15, len(df))
    
    # Convert timestamp to hour of day
    # Assuming timestamp is milliseconds since epoch
    df['time_of_day'] = ((df['timestamp'] // 3600000) % 24).astype(int)
    
    # Is moving (if speed > threshold)
    df['is_moving'] = (df['pre_speed'] > 5.0).astype(int)
    
    # Post-crash vibrations
    df['post_vibrations'] = df['rotation_magnitude'] * 0.5
    
    # Map Class to label
    # AGGRESSIVE = REAL accident
    # You can adjust this mapping based on your classes
    class_mapping = {
        'AGGRESSIVE': 'REAL',
        'NORMAL': 'FAKE',
        'SLOW': 'FAKE',
        # Add more mappings as needed
    }
    
    df['label'] = df['Class'].map(class_mapping)
    
    # If any unmapped classes exist, default to FAKE
    df['label'] = df['label'].fillna('FAKE')
    
    # Keep accident_type as original class
    df['accident_type'] = df['Class'].str.lower()
    
    # Convert timestamp to readable format
    df['timestamp'] = pd.to_datetime(df['timestamp'], unit='ms').dt.strftime('%Y-%m-%d %H:%M:%S')
    
    # Select and order final columns
    final_columns = [
        'timestamp',
        'impact_x', 'impact_y', 'impact_z', 'impact_magnitude',
        'pre_speed', 'post_speed', 'speed_change',
        'immobility_duration',
        'rotation_x', 'rotation_y', 'rotation_z', 'rotation_magnitude',
        'impact_duration', 'secondary_impacts',
        'altitude_change', 'gps_accuracy', 'time_of_day',
        'is_moving', 'post_vibrations',
        'accident_type', 'label'
    ]
    
    processed_df = df[final_columns].copy()
    
    print(f"   ✅ Created {len(final_columns)} features")
    print(f"   Label distribution:")
    print(processed_df['label'].value_counts())
    
    # Split into train/test/validation
    print(f"\n4️⃣  Splitting dataset...")
    
    # Shuffle data
    processed_df = processed_df.sample(frac=1, random_state=42).reset_index(drop=True)
    
    # Calculate split sizes
    total = len(processed_df)
    train_size = int(0.70 * total)
    test_size = int(0.15 * total)
    
    train_df = processed_df[:train_size]
    test_df = processed_df[train_size:train_size + test_size]
    val_df = processed_df[train_size + test_size:]
    
    print(f"   Training:   {len(train_df)} rows (70%)")
    print(f"   Testing:    {len(test_df)} rows (15%)")
    print(f"   Validation: {len(val_df)} rows (15%)")
    
    # Create processed directory if needed
    os.makedirs('processed', exist_ok=True)
    
    # Save processed datasets
    print(f"\n5️⃣  Saving processed data...")
    
    processed_df.to_csv('raw_data/combined_dataset_processed.csv', index=False)
    train_df.to_csv('processed/training_data.csv', index=False)
    test_df.to_csv('processed/test_data.csv', index=False)
    val_df.to_csv('processed/validation_data.csv', index=False)
    
    print(f"   ✅ raw_data/combined_dataset_processed.csv ({len(processed_df)} rows)")
    print(f"   ✅ processed/training_data.csv ({len(train_df)} rows)")
    print(f"   ✅ processed/test_data.csv ({len(test_df)} rows)")
    print(f"   ✅ processed/validation_data.csv ({len(val_df)} rows)")
    
    # Show sample data
    print(f"\n6️⃣  Sample processed data:")
    print(processed_df[['impact_magnitude', 'speed_change', 'rotation_magnitude', 
                        'immobility_duration', 'accident_type', 'label']].head(10))
    
    # Statistics
    print(f"\n7️⃣  Feature Statistics:")
    stats_features = ['impact_magnitude', 'speed_change', 'rotation_magnitude', 'immobility_duration']
    print(processed_df[stats_features].describe())
    
    print("\n" + "="*60)
    print("✅ PREPROCESSING COMPLETE!")
    print("="*60)
    print(f"\n📊 Summary:")
    print(f"   • Original records: {total}")
    print(f"   • Features created: {len(final_columns)}")
    print(f"   • REAL accidents: {(processed_df['label'] == 'REAL').sum()}")
    print(f"   • FAKE alerts: {(processed_df['label'] == 'FAKE').sum()}")
    print(f"\n💡 Next Steps:")
    print(f"   1. Review processed/training_data.csv")
    print(f"   2. Train Random Forest model")
    print(f"   3. Convert model to TFLite")
    print(f"   4. Deploy to Flutter app")
    print("="*60 + "\n")
    
    return processed_df

if __name__ == "__main__":
    preprocess_motion_data()
