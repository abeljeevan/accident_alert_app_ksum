"""
Random Forest Model Training Script
Trains accident detection model on preprocessed data
"""

import pandas as pd
import numpy as np
from sklearn.ensemble import RandomForestClassifier
from sklearn.metrics import (
    accuracy_score, precision_score, recall_score, f1_score,
    confusion_matrix, classification_report
)
import joblib
import json
import os
from datetime import datetime

def train_random_forest():
    """
    Train Random Forest classifier for accident detection
    """
    
    print("="*70)
    print("🤖 RANDOM FOREST MODEL TRAINING")
    print("="*70)
    
    # Load training data
    print("\n1️⃣  Loading training data...")
    try:
        train_df = pd.read_csv('processed/training_data.csv')
        test_df = pd.read_csv('processed/test_data.csv')
        val_df = pd.read_csv('processed/validation_data.csv')
        
        print(f"   ✅ Training:   {len(train_df)} samples")
        print(f"   ✅ Testing:    {len(test_df)} samples")
        print(f"   ✅ Validation: {len(val_df)} samples")
    except Exception as e:
        print(f"   ❌ Error loading data: {e}")
        return
    
    # Select features (exclude timestamp, accident_type, label)
    feature_columns = [
        'impact_x', 'impact_y', 'impact_z', 'impact_magnitude',
        'pre_speed', 'post_speed', 'speed_change',
        'immobility_duration',
        'rotation_x', 'rotation_y', 'rotation_z', 'rotation_magnitude',
        'impact_duration', 'secondary_impacts',
        'altitude_change', 'gps_accuracy', 'time_of_day',
        'is_moving', 'post_vibrations'
    ]
    
    print(f"\n2️⃣  Preparing features...")
    print(f"   Features selected: {len(feature_columns)}")
    
    # Prepare training data
    X_train = train_df[feature_columns]
    y_train = train_df['label']
    
    X_test = test_df[feature_columns]
    y_test = test_df['label']
    
    X_val = val_df[feature_columns]
    y_val = val_df['label']
    
    print(f"   Training samples - REAL: {(y_train == 'REAL').sum()}, FAKE: {(y_train == 'FAKE').sum()}")
    print(f"   Testing samples  - REAL: {(y_test == 'REAL').sum()}, FAKE: {(y_test == 'FAKE').sum()}")
    
    # Train Random Forest
    print(f"\n3️⃣  Training Random Forest classifier...")
    print(f"   Model parameters:")
    print(f"      • n_estimators: 100 (number of trees)")
    print(f"      • max_depth: 15 (prevent overfitting)")
    print(f"      • min_samples_split: 5")
    print(f"      • min_samples_leaf: 2")
    print(f"      • class_weight: balanced (handle imbalance)")
    
    model = RandomForestClassifier(
        n_estimators=100,        # 100 decision trees
        max_depth=15,            # Maximum depth of trees
        min_samples_split=5,     # Minimum samples to split a node
        min_samples_leaf=2,      # Minimum samples in leaf node
        class_weight='balanced', # Handle class imbalance
        random_state=42,         # Reproducibility
        n_jobs=-1,               # Use all CPU cores
        verbose=1                # Show progress
    )
    
    print(f"\n   Training in progress...")
    model.fit(X_train, y_train)
    print(f"   ✅ Training complete!")
    
    # Evaluate on training set
    print(f"\n4️⃣  Evaluating model...")
    
    y_train_pred = model.predict(X_train)
    y_test_pred = model.predict(X_test)
    y_val_pred = model.predict(X_val)
    
    # Calculate metrics
    train_accuracy = accuracy_score(y_train, y_train_pred)
    test_accuracy = accuracy_score(y_test, y_test_pred)
    val_accuracy = accuracy_score(y_val, y_val_pred)
    
    print(f"\n   📊 Accuracy Scores:")
    print(f"      Training:   {train_accuracy*100:.2f}%")
    print(f"      Testing:    {test_accuracy*100:.2f}%")
    print(f"      Validation: {val_accuracy*100:.2f}%")
    
    # Detailed metrics on test set
    print(f"\n   📋 Detailed Test Set Metrics:")
    precision = precision_score(y_test, y_test_pred, pos_label='REAL')
    recall = recall_score(y_test, y_test_pred, pos_label='REAL')
    f1 = f1_score(y_test, y_test_pred, pos_label='REAL')
    
    print(f"      Precision: {precision*100:.2f}% (of predicted REAL, how many were actually REAL)")
    print(f"      Recall:    {recall*100:.2f}% (of actual REAL, how many were detected)")
    print(f"      F1-Score:  {f1*100:.2f}% (harmonic mean of precision and recall)")
    
    # Confusion Matrix
    print(f"\n   🔢 Confusion Matrix (Test Set):")
    cm = confusion_matrix(y_test, y_test_pred, labels=['FAKE', 'REAL'])
    print(f"\n                  Predicted")
    print(f"                FAKE    REAL")
    print(f"      Actual")
    print(f"      FAKE      {cm[0][0]:4d}    {cm[0][1]:4d}    (False Positives: {cm[0][1]})")
    print(f"      REAL      {cm[1][0]:4d}    {cm[1][1]:4d}    (False Negatives: {cm[1][0]})")
    
    # Classification Report
    print(f"\n   📝 Full Classification Report:")
    print(classification_report(y_test, y_test_pred))
    
    # Feature Importance (for Explainable AI)
    print(f"\n5️⃣  Feature Importance (for Explainable AI)...")
    
    feature_importance = pd.DataFrame({
        'feature': feature_columns,
        'importance': model.feature_importances_
    }).sort_values('importance', ascending=False)
    
    print(f"\n   🎯 Top 10 Most Important Features:")
    for idx, row in feature_importance.head(10).iterrows():
        bar_length = int(row['importance'] * 50)
        bar = '█' * bar_length
        print(f"      {row['feature']:20s} {bar} {row['importance']:.4f}")
    
    # Save model
    print(f"\n6️⃣  Saving model...")
    os.makedirs('models', exist_ok=True)
    
    # Save Random Forest model
    model_path = 'models/accident_detector_rf.pkl'
    joblib.dump(model, model_path)
    print(f"   ✅ Model saved: {model_path}")
    
    # Save feature importance
    feature_importance.to_csv('models/feature_importance.csv', index=False)
    print(f"   ✅ Feature importance saved: models/feature_importance.csv")
    
    # Save metadata
    metadata = {
        'model_type': 'RandomForestClassifier',
        'training_date': datetime.now().strftime('%Y-%m-%d %H:%M:%S'),
        'n_estimators': 100,
        'max_depth': 15,
        'features': feature_columns,
        'training_samples': len(train_df),
        'test_samples': len(test_df),
        'metrics': {
            'train_accuracy': float(train_accuracy),
            'test_accuracy': float(test_accuracy),
            'val_accuracy': float(val_accuracy),
            'precision': float(precision),
            'recall': float(recall),
            'f1_score': float(f1),
            'confusion_matrix': cm.tolist()
        },
        'feature_importance': {
            row['feature']: float(row['importance']) 
            for _, row in feature_importance.iterrows()
        }
    }
    
    with open('models/model_metadata.json', 'w') as f:
        json.dump(metadata, f, indent=2)
    print(f"   ✅ Metadata saved: models/model_metadata.json")
    
    # Test prediction on sample data
    print(f"\n7️⃣  Testing prediction on sample data...")
    
    sample = X_test.iloc[0:1]
    sample_label = y_test.iloc[0]
    
    prediction = model.predict(sample)[0]
    probabilities = model.predict_proba(sample)[0]
    
    print(f"\n   Sample features:")
    for col in feature_columns[:5]:  # Show first 5 features
        print(f"      {col}: {sample[col].values[0]:.2f}")
    
    print(f"\n   Prediction: {prediction}")
    print(f"   Actual:     {sample_label}")
    print(f"   Confidence: FAKE={probabilities[0]*100:.1f}%, REAL={probabilities[1]*100:.1f}%")
    print(f"   Result:     {'✅ CORRECT' if prediction == sample_label else '❌ WRONG'}")
    
    # Summary
    print("\n" + "="*70)
    print("✅ MODEL TRAINING COMPLETE!")
    print("="*70)
    print(f"\n📊 Final Summary:")
    print(f"   • Model Type:        Random Forest (100 trees)")
    print(f"   • Training Accuracy: {train_accuracy*100:.2f}%")
    print(f"   • Test Accuracy:     {test_accuracy*100:.2f}%")
    print(f"   • Precision:         {precision*100:.2f}%")
    print(f"   • Recall:            {recall*100:.2f}%")
    print(f"   • F1-Score:          {f1*100:.2f}%")
    print(f"\n📁 Files Created:")
    print(f"   • models/accident_detector_rf.pkl       - Trained model")
    print(f"   • models/feature_importance.csv         - Feature rankings")
    print(f"   • models/model_metadata.json            - Model details")
    print(f"\n💡 Next Steps:")
    print(f"   1. Convert model to TensorFlow Lite format")
    print(f"   2. Deploy .tflite model to Flutter app")
    print(f"   3. Implement Edge AI detector in Dart")
    print(f"   4. Add Explainable AI features")
    print("="*70 + "\n")
    
    return model, metadata

if __name__ == "__main__":
    train_random_forest()
