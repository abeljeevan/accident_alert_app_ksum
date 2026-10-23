# Front End and Back End Implementation

## FRONT END (Flutter/Dart)

### 1. Main Application Entry Point (`main.dart`)

```dart
import 'package:flutter/material.dart';
import 'home_page.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  bool _isDarkMode = false;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Accident Alert App',
      debugShowCheckedModeBanner: false,
      theme: _isDarkMode
          ? ThemeData.dark().copyWith(
              primaryColor: const Color(0xFFE63946),
              scaffoldBackgroundColor: const Color.fromARGB(255, 18, 18, 18),
              appBarTheme: const AppBarTheme(
                backgroundColor: Color.fromARGB(255, 30, 30, 30),
                titleTextStyle: TextStyle(
                  color: Colors.white,
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
                iconTheme: IconThemeData(color: Colors.white),
              ),
              cardTheme: const CardThemeData(
                color: Color.fromARGB(255, 30, 30, 30),
                margin: EdgeInsets.symmetric(vertical: 8, horizontal: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.all(Radius.circular(12)),
                ),
              ),
              elevatedButtonTheme: ElevatedButtonThemeData(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFE63946),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 24),
                ),
              ),
              floatingActionButtonTheme: const FloatingActionButtonThemeData(
                backgroundColor: Color(0xFFE63946),
                foregroundColor: Colors.white,
              ),
            )
          : ThemeData(
              scaffoldBackgroundColor: const Color.fromARGB(255, 249, 249, 249),
              primaryColor: const Color(0xFFE63946),
              appBarTheme: const AppBarTheme(
                backgroundColor: Color.fromARGB(255, 228, 231, 235),
                titleTextStyle: TextStyle(
                  color: Color(0xFFE63946),
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
              elevatedButtonTheme: ElevatedButtonThemeData(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFE63946),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 24),
                ),
              ),
            ),
      home: HomePage(
        isDarkMode: _isDarkMode,
        onToggleTheme: () {
          setState(() {
            _isDarkMode = !_isDarkMode;
          });
        },
      ),
    );
  }
}
```

### 2. Accident Detection Logic (`accident_detector.dart`)

```dart
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:flutter/services.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:intl/intl.dart';

import 'log_store.dart';
import 'contact_store.dart';
import 'voice_ai_handler.dart';

const bool kSmsEnabled = true;

class AccidentDetector extends StatefulWidget {
  const AccidentDetector({super.key});

  @override
  State<AccidentDetector> createState() => _AccidentDetectorState();
}

class _AccidentDetectorState extends State<AccidentDetector> {
  static const MethodChannel _smsChannel = MethodChannel('accident/sms');
  final FlutterTts _tts = FlutterTts();
  final VoiceAIHandler _voiceAI = VoiceAIHandler();

  String _locationMessage = 'Fetching location…';
  bool _isLoading = false;
  bool _useVoiceInteraction = true;

  String _now() => DateFormat('yyyy-MM-dd HH:mm:ss').format(DateTime.now());

  /// Text-to-speech for voice alerts
  Future<void> _speak(String text) async {
    await _tts.setLanguage('en-US');
    await _tts.setPitch(1.0);
    await _tts.speak(text);
  }

  /// Build SMS alert body with location
  String _buildSmsBody(Position pos) {
    final maps = 'https://maps.google.com/?q=${pos.latitude},${pos.longitude}';
    return '''
⚠️ Accident detected!
📅 ${_now()}
📍 Lat: ${pos.latitude.toStringAsFixed(5)}, Lon: ${pos.longitude.toStringAsFixed(5)}
➡️ $maps
Please send immediate assistance.
''';
  }

  /// Get device GPS location
  Future<Position?> _getLocation() async {
    try {
      if (!await Geolocator.isLocationServiceEnabled()) {
        setState(() => _locationMessage = '❌ Location services are disabled.');
        return null;
      }

      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          setState(() => _locationMessage = '❌ Location permission denied.');
          return null;
        }
      }
      if (permission == LocationPermission.deniedForever) {
        setState(() => _locationMessage = '❌ Location permanently denied.');
        return null;
      }

      final pos = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );
      setState(() {
        _locationMessage =
            'Lat: ${pos.latitude.toStringAsFixed(5)}, '
            'Lon: ${pos.longitude.toStringAsFixed(5)}, '
            'Speed: ${(pos.speed * 3.6).toStringAsFixed(1)} km/h';
      });
      return pos;
    } catch (e) {
      setState(() => _locationMessage = '⚠️ Error getting location: $e');
      return null;
    }
  }

  /// Ensure SMS permissions are granted
  Future<bool> _ensureSmsPermission() async {
    var sms = await Permission.sms.status;
    var phone = await Permission.phone.status;
    if (sms.isGranted && phone.isGranted) return true;
    if (!sms.isGranted) sms = await Permission.sms.request();
    if (!phone.isGranted) phone = await Permission.phone.request();
    return sms.isGranted && phone.isGranted;
  }

  /// Simulate accident detection and send alerts
  void _simulateAccident() async {
    setState(() => _isLoading = true);
    final pos = await _getLocation();
    setState(() => _isLoading = false);
    if (!mounted || pos == null) return;

    final logEntry = '🕒 ${_now()}\n📍 $_locationMessage';
    await AccidentLogStore.add(logEntry);
  }
}
```

### 3. Random Forest Model Integration (`random_forest_predictor.dart`)

```dart
import 'dart:convert';
import 'package:flutter/services.dart';

/// Node in a decision tree
class TreeNode {
  final int feature; // -1 for leaf nodes
  final double threshold;
  final int leftChild;
  final int rightChild;
  final List<double>? value; // Class probabilities for leaf nodes
  final int? predictedClass;

  TreeNode({
    required this.feature,
    required this.threshold,
    required this.leftChild,
    required this.rightChild,
    this.value,
    this.predictedClass,
  });

  factory TreeNode.fromJson(Map<String, dynamic> json) {
    return TreeNode(
      feature: json['feature'] as int,
      threshold: (json['threshold'] as num).toDouble(),
      leftChild: json['left_child'] as int,
      rightChild: json['right_child'] as int,
      value: json['value'] != null
          ? (json['value'] as List).map((v) => (v as num).toDouble()).toList()
          : null,
      predictedClass: json['predicted_class'] as int?,
    );
  }

  bool get isLeaf => leftChild == -1;
}

/// Single decision tree
class DecisionTree {
  final List<TreeNode> nodes;

  DecisionTree({required this.nodes});

  factory DecisionTree.fromJson(Map<String, dynamic> json) {
    final nodesList = json['nodes'] as List;
    final nodes = nodesList.map((n) => TreeNode.fromJson(n)).toList();
    return DecisionTree(nodes: nodes);
  }

  /// Predict class probabilities for a single sample
  List<double> predictProba(List<double> features) {
    int nodeIndex = 0; // Start at root

    while (!nodes[nodeIndex].isLeaf) {
      final node = nodes[nodeIndex];
      final featureValue = features[node.feature];

      // Navigate tree: left if feature <= threshold, right otherwise
      if (featureValue <= node.threshold) {
        nodeIndex = node.leftChild;
      } else {
        nodeIndex = node.rightChild;
      }
    }

    // Return class probabilities from leaf node
    final leafNode = nodes[nodeIndex];
    final value = leafNode.value!;
    final total = value.reduce((a, b) => a + b);

    // Normalize to probabilities
    return value.map((v) => v / total).toList();
  }

  /// Predict class for a single sample
  int predict(List<double> features) {
    int nodeIndex = 0;

    while (!nodes[nodeIndex].isLeaf) {
      final node = nodes[nodeIndex];
      final featureValue = features[node.feature];

      if (featureValue <= node.threshold) {
        nodeIndex = node.leftChild;
      } else {
        nodeIndex = node.rightChild;
      }
    }

    return nodes[nodeIndex].predictedClass!;
  }
}

/// Random Forest Classifier for accident detection
class RandomForestPredictor {
  List<DecisionTree>? _trees;
  List<String>? _featureNames;
  List<String>? _classNames;
  int? _nEstimators;
  int? _nFeatures;

  /// Load model from JSON asset
  Future<void> loadModel(String assetPath) async {
    try {
      final jsonString = await rootBundle.loadString(assetPath);
      final modelData = jsonDecode(jsonString);

      _nEstimators = modelData['n_estimators'];
      _nFeatures = modelData['n_features'];
      _classNames = List<String>.from(modelData['class_names']);
      _featureNames = List<String>.from(modelData['feature_names']);

      final treesList = modelData['trees'] as List;
      _trees = treesList.map((t) => DecisionTree.fromJson(t)).toList();

      print('✅ Model loaded: $_nEstimators trees, $_nFeatures features');
    } catch (e) {
      print('❌ Error loading model: $e');
      rethrow;
    }
  }

  /// Predict accident probability
  Map<String, dynamic> predict(List<double> features) {
    if (_trees == null || _classNames == null) {
      throw Exception('Model not loaded');
    }

    // Get predictions from all trees
    final probabilities = List<List<double>>.generate(
      _trees!.length,
      (i) => _trees![i].predictProba(features),
    );

    // Average probabilities across all trees
    final avgProba = List<double>.generate(
      probabilities[0].length,
      (i) => probabilities.map((p) => p[i]).reduce((a, b) => a + b) / _trees!.length,
    );

    final predictedClass = avgProba.indexOf(avgProba.reduce((a, b) => a > b ? a : b));

    return {
      'prediction': _classNames![predictedClass],
      'confidence': avgProba[predictedClass],
      'probabilities': {
        for (int i = 0; i < _classNames!.length; i++)
          _classNames![i]: avgProba[i],
      },
    };
  }
}
```

---

## BACK END (Python Machine Learning)

### 1. Data Preprocessing (`preprocess_data.py`)

```python
"""
Data Preprocessing Script
Converts motion sensor data to accident detection training format
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
    
    # Simulate pre/post speeds
    df['pre_speed'] = df['impact_magnitude'] * 2.5  # Rough estimate
    df['post_speed'] = df['pre_speed'] - df['speed_change']
    df['post_speed'] = df['post_speed'].clip(lower=0)  # Can't be negative
    
    # Calculate immobility (low acceleration = not moving)
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
    df['time_of_day'] = ((df['timestamp'] // 3600000) % 24).astype(int)
    
    # Is moving (if speed > threshold)
    df['is_moving'] = (df['pre_speed'] > 5.0).astype(int)
    
    # Post-crash vibrations
    df['post_vibrations'] = np.where(
        df['rotation_magnitude'] > 3.0,
        np.random.uniform(0.5, 2.0, len(df)),
        np.random.uniform(0, 0.3, len(df))
    )
    
    print(f"   ✅ Generated {len(df.columns)} features")
    print(f"   Features: {list(df.columns)}")
    
    # Save processed data
    print(f"\n4️⃣  Saving processed data...")
    os.makedirs('processed', exist_ok=True)
    
    df.to_csv('processed/full_dataset.csv', index=False)
    print(f"   ✅ Saved to processed/full_dataset.csv")
    
    return df
```

### 2. Model Training (`train_model.py`)

```python
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
    print(f"   {feature_columns}")
    
    # Prepare training data
    X_train = train_df[feature_columns]
    y_train = train_df['label']
    
    X_test = test_df[feature_columns]
    y_test = test_df['label']
    
    X_val = val_df[feature_columns]
    y_val = val_df['label']
    
    print(f"   Training samples   - REAL: {(y_train == 'REAL').sum():,}, FAKE: {(y_train == 'FAKE').sum():,}")
    print(f"   Testing samples    - REAL: {(y_test == 'REAL').sum():,}, FAKE: {(y_test == 'FAKE').sum():,}")
    print(f"   Validation samples - REAL: {(y_val == 'REAL').sum():,}, FAKE: {(y_val == 'FAKE').sum():,}")
    
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
    
    # Evaluate on all sets
    print(f"\n4️⃣  Evaluating model...")
    
    y_train_pred = model.predict(X_train)
    y_test_pred = model.predict(X_test)
    y_val_pred = model.predict(X_val)
    
    # Calculate metrics
    train_accuracy = accuracy_score(y_train, y_train_pred)
    test_accuracy = accuracy_score(y_test, y_test_pred)
    val_accuracy = accuracy_score(y_val, y_val_pred)
    
    test_precision = precision_score(y_test, y_test_pred, pos_label='REAL')
    test_recall = recall_score(y_test, y_test_pred, pos_label='REAL')
    test_f1 = f1_score(y_test, y_test_pred, pos_label='REAL')
    
    print(f"\n   📊 Accuracy:")
    print(f"      • Training:   {train_accuracy:.4f}")
    print(f"      • Testing:    {test_accuracy:.4f}")
    print(f"      • Validation: {val_accuracy:.4f}")
    
    print(f"\n   📊 Test Set Metrics (REAL detection):")
    print(f"      • Precision: {test_precision:.4f}")
    print(f"      • Recall:    {test_recall:.4f}")
    print(f"      • F1-Score:  {test_f1:.4f}")
    
    print(f"\n   Confusion Matrix (Test Set):")
    cm = confusion_matrix(y_test, y_test_pred)
    print(f"      True Negatives:  {cm[0, 0]}")
    print(f"      False Positives: {cm[0, 1]}")
    print(f"      False Negatives: {cm[1, 0]}")
    print(f"      True Positives:  {cm[1, 1]}")
    
    # Feature importance
    print(f"\n5️⃣  Feature Importance Analysis...")
    feature_importance = pd.DataFrame({
        'feature': feature_columns,
        'importance': model.feature_importances_
    }).sort_values('importance', ascending=False)
    
    print(f"\n   Top 10 Most Important Features:")
    for idx, row in feature_importance.head(10).iterrows():
        print(f"      {row['feature']:<25} {row['importance']:.4f}")
    
    # Save model
    print(f"\n6️⃣  Saving model...")
    os.makedirs('models', exist_ok=True)
    
    model_path = 'models/accident_detector_rf.pkl'
    joblib.dump(model, model_path)
    print(f"   ✅ Model saved to {model_path}")
    
    # Save metadata
    metadata = {
        'model_type': 'RandomForestClassifier',
        'n_estimators': 100,
        'max_depth': 15,
        'features': feature_columns,
        'classes': ['FAKE', 'REAL'],
        'training_date': datetime.now().isoformat(),
        'metrics': {
            'train_accuracy': float(train_accuracy),
            'test_accuracy': float(test_accuracy),
            'val_accuracy': float(val_accuracy),
            'test_precision': float(test_precision),
            'test_recall': float(test_recall),
            'test_f1': float(test_f1)
        }
    }
    
    metadata_path = 'models/model_metadata.json'
    with open(metadata_path, 'w') as f:
        json.dump(metadata, f, indent=2)
    print(f"   ✅ Metadata saved to {metadata_path}")
    
    print(f"\n{'='*70}")
    print(f"✅ MODEL TRAINING COMPLETE")
    print(f"{'='*70}\n")
    
    return model

if __name__ == '__main__':
    train_random_forest()
```

### 3. Model Export to JSON (`export_model_to_json.py`)

```python
"""
Export Random Forest model to JSON format for Flutter/Dart integration
This exports the complete tree structure for native Dart implementation
"""

import joblib
import json
import numpy as np
from pathlib import Path
from sklearn.ensemble import RandomForestClassifier
import sys

def export_tree_structure(tree, feature_names):
    """Extract tree structure from sklearn tree"""
    tree_data = {
        'n_nodes': int(tree.node_count),
        'nodes': [],
        'values': []
    }
    
    # Extract node information
    for i in range(tree.node_count):
        node_info = {
            'feature': int(tree.feature[i]) if tree.feature[i] != -2 else -1,
            'threshold': float(tree.threshold[i]) if tree.threshold[i] != -2 else 0.0,
            'left_child': int(tree.children_left[i]),
            'right_child': int(tree.children_right[i]),
            'impurity': float(tree.impurity[i]),
            'n_samples': int(tree.n_node_samples[i]),
            'weighted_n_samples': float(tree.weighted_n_node_samples[i]),
        }
        
        # Leaf node values (class probabilities)
        if tree.children_left[i] == -1:  # Leaf node
            value = tree.value[i][0]
            node_info['value'] = [float(v) for v in value]
            # Predicted class (0: FAKE, 1: REAL)
            node_info['predicted_class'] = int(np.argmax(value))
        
        tree_data['nodes'].append(node_info)
    
    return tree_data

def main():
    print("="*70)
    print("📦 EXPORTING RANDOM FOREST MODEL TO JSON")
    print("="*70)
    
    print("\n1️⃣  Loading trained Random Forest model...")
    
    # Load the trained model
    model_path = Path(__file__).parent / 'models' / 'accident_detector_rf.pkl'
    rf_model = joblib.load(model_path)
    
    # Load metadata to get feature names
    metadata_path = Path(__file__).parent / 'models' / 'model_metadata.json'
    with open(metadata_path, 'r') as f:
        metadata = json.load(f)
    
    feature_names = metadata['features']
    class_names = ['FAKE', 'REAL']  # Binary classification
    
    print(f"   ✅ Model loaded")
    print(f"   Trees: {len(rf_model.estimators_)}")
    print(f"   Features: {len(feature_names)}")
    print(f"   Classes: {class_names}")
    
    # Export model structure
    print(f"\n2️⃣  Exporting model structure...")
    export_data = {
        'model_type': 'RandomForestClassifier',
        'n_estimators': len(rf_model.estimators_),
        'n_features': len(feature_names),
        'n_classes': len(class_names),
        'feature_names': feature_names,
        'class_names': class_names,
        'max_depth': int(rf_model.max_depth) if rf_model.max_depth else None,
        'min_samples_split': int(rf_model.min_samples_split),
        'min_samples_leaf': int(rf_model.min_samples_leaf),
        'trees': []
    }
    
    # Export each tree structure
    print(f"\n3️⃣  Exporting tree structures...")
    for idx, estimator in enumerate(rf_model.estimators_):
        if idx % 20 == 0:
            print(f"   Processing tree {idx + 1}/{len(rf_model.estimators_)}...")
        
        tree_structure = export_tree_structure(estimator.tree_, feature_names)
        export_data['trees'].append(tree_structure)
    
    # Save to JSON
    print(f"\n4️⃣  Saving to JSON...")
    output_path = Path(__file__).parent / 'models' / 'accident_detector_rf.json'
    
    with open(output_path, 'w') as f:
        json.dump(export_data, f, indent=2)
    
    file_size_mb = output_path.stat().st_size / (1024 * 1024)
    print(f"   ✅ Saved to {output_path}")
    print(f"   File size: {file_size_mb:.2f} MB")
    
    print(f"\n{'='*70}")
    print(f"✅ MODEL EXPORT COMPLETE")
    print(f"{'='*70}\n")

if __name__ == '__main__':
    main()
```

---

## Dependencies

### Frontend (Flutter pubspec.yaml)
```yaml
dependencies:
  flutter:
    sdk: flutter
  http: ^1.2.1
  geolocator: ^14.0.1             # GPS/location
  sensors_plus: ^6.1.1            # accelerometer, gyroscope
  permission_handler: ^12.0.0+1   # runtime permissions
  shared_preferences: ^2.5.3      # persistent logs
  flutter_tts: ^4.0.2             # text-to-speech
  speech_to_text: ^7.0.0          # speech-to-text
  intl: ^0.20.2                   # date-time formatting
  pdf: ^3.11.1                    # PDF generation
  printing: ^5.14.0               # PDF support
  path_provider: ^2.1.5           # file system paths
  share_plus: ^10.1.3             # share reports
  flutter_map: ^7.0.2             # OSM maps
  latlong2: ^0.9.1                # geo calculations
```

### Backend (Python requirements.txt)
```
pandas>=2.0.0
numpy>=1.24.0
scikit-learn>=1.3.0
joblib>=1.3.0
```

---

## Key Implementation Details

### Frontend Architecture
- **Main App**: Material Design with dark/light theme support
- **Accident Detection**: Real-time GPS and sensor monitoring
- **ML Integration**: On-device Random Forest predictions from JSON model
- **Communication**: SMS alerts with location sharing
- **Voice AI**: Text-to-speech and speech-to-text capabilities

### Backend Architecture
- **Data Pipeline**: Preprocessing of sensor data with feature engineering
- **ML Model**: Random Forest with 100 trees, 19 input features
- **Model Export**: JSON serialization for cross-platform deployment
- **Metrics**: Accuracy, Precision, Recall, F1-Score evaluation
- **Reproducibility**: Fixed random seeds and detailed logging

### Feature Set
- **Accelerometer**: impact_x, impact_y, impact_z, impact_magnitude
- **Gyroscope**: rotation_x, rotation_y, rotation_z, rotation_magnitude
- **Derived**: speed_change, pre_speed, post_speed, impact_duration
- **Context**: time_of_day, is_moving, immobility_duration, altitude_change
- **Quality**: gps_accuracy, post_vibrations, secondary_impacts
