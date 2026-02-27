import 'dart:async';
import 'package:flutter/services.dart';
import 'random_forest_predictor.dart';
import 'feature_extractor.dart';

/// Real vs Fake accident detection result
class AccidentDetectionResult {
  final bool isRealAccident;
  final String prediction; // 'REAL' or 'FAKE'
  final double confidence;
  final Map<String, double> probabilities;
  final Map<String, double> features;
  final List<String> topFeatures;
  final String explanation;
  final DateTime timestamp;

  AccidentDetectionResult({
    required this.isRealAccident,
    required this.prediction,
    required this.confidence,
    required this.probabilities,
    required this.features,
    required this.topFeatures,
    required this.explanation,
    required this.timestamp,
  });

  /// Convert to JSON for logging/saving
  Map<String, dynamic> toJson() {
    return {
      'is_real_accident': isRealAccident,
      'prediction': prediction,
      'confidence': confidence,
      'probabilities': probabilities,
      'features': features,
      'top_features': topFeatures,
      'explanation': explanation,
      'timestamp': timestamp.toIso8601String(),
    };
  }
}

/// Edge AI Accident Detector
/// Combines Random Forest ML model with feature extraction and explainable AI
class EdgeAIDetector {
  final RandomForestPredictor _predictor = RandomForestPredictor();
  final FeatureExtractor _featureExtractor = FeatureExtractor();
  
  bool _isInitialized = false;
  Map<String, double>? _featureImportance;

  bool get isInitialized => _isInitialized;

  /// Initialize the Edge AI detector
  /// Loads the Random Forest model and feature importance
  Future<void> initialize() async {
    print('🚀 Initializing Edge AI Detector...');

    try {
      // Load Random Forest model
      await _predictor.loadModel();

      // Load feature importance for explainable AI
      await _loadFeatureImportance();

      _isInitialized = true;
      print('✅ Edge AI Detector initialized successfully!');
    } catch (e) {
      print('❌ Failed to initialize Edge AI Detector: $e');
      rethrow;
    }
  }

  /// Load feature importance from CSV for explainable AI
  Future<void> _loadFeatureImportance() async {
    try {
      final csvString = await rootBundle
          .loadString('assets/models/feature_importance.csv');
      
      // Parse CSV (skip header)
      final lines = csvString.split('\n').skip(1);
      _featureImportance = {};

      for (final line in lines) {
        if (line.trim().isEmpty) continue;
        
        final parts = line.split(',');
        if (parts.length >= 2) {
          final feature = parts[0].trim();
          final importance = double.tryParse(parts[1].trim());
          if (importance != null) {
            _featureImportance![feature] = importance;
          }
        }
      }

      print('   ✅ Loaded feature importance: ${_featureImportance!.length} features');
    } catch (e) {
      print('   ⚠️  Feature importance not available: $e');
      _featureImportance = {};
    }
  }

  /// Process sensor reading and detect if it's a real accident
  Future<AccidentDetectionResult> detectAccident(SensorReading reading) async {
    if (!_isInitialized) {
      throw StateError('Detector not initialized. Call initialize() first.');
    }

    // Add reading to feature extractor buffer
    _featureExtractor.addReading(reading);

    // Check if we have enough data
    if (!_featureExtractor.hasEnoughData) {
      // Return FAKE with low confidence if not enough data
      return AccidentDetectionResult(
        isRealAccident: false,
        prediction: 'FAKE',
        confidence: 0.5,
        probabilities: {'FAKE': 0.5, 'REAL': 0.5},
        features: {},
        topFeatures: [],
        explanation: 'Insufficient sensor data for reliable prediction',
        timestamp: DateTime.now(),
      );
    }

    // Extract features
    final features = _featureExtractor.extractFeatures();
    final featuresMap = _featureExtractor.extractFeaturesMap();

    // Make prediction
    final predictionResult = _predictor.predictDetailed(features);

    // Generate explanation
    final explanation = _generateExplanation(
      prediction: predictionResult['prediction'] as String,
      confidence: predictionResult['confidence'] as double,
      probabilities: predictionResult['probabilities'] as Map<String, double>,
      features: featuresMap,
    );

    // Get top contributing features
    final topFeatures = _getTopFeatures(featuresMap, limit: 5);

    return AccidentDetectionResult(
      isRealAccident: predictionResult['is_real_accident'] as bool,
      prediction: predictionResult['prediction'] as String,
      confidence: predictionResult['confidence'] as double,
      probabilities: predictionResult['probabilities'] as Map<String, double>,
      features: featuresMap,
      topFeatures: topFeatures,
      explanation: explanation,
      timestamp: DateTime.now(),
    );
  }

  /// Generate human-readable explanation for the prediction
  String _generateExplanation({
    required String prediction,
    required double confidence,
    required Map<String, double> probabilities,
    required Map<String, double> features,
  }) {
    final topFeatures = _getTopFeatures(features, limit: 3);
    
    if (prediction == 'REAL') {
      return 'Real accident detected with ${(confidence * 100).toStringAsFixed(1)}% confidence. '
          'Key indicators: ${topFeatures.join(", ")}. '
          'Impact magnitude: ${features["impact_magnitude"]?.toStringAsFixed(2)} m/s². '
          'Emergency response recommended.';
    } else {
      return 'Classified as false alarm with ${(confidence * 100).toStringAsFixed(1)}% confidence. '
          'Analysis shows: ${topFeatures.join(", ")}. '
          'Impact magnitude: ${features["impact_magnitude"]?.toStringAsFixed(2)} m/s². '
          'No emergency action required.';
    }
  }

  /// Get top N features that contributed most to this prediction
  List<String> _getTopFeatures(Map<String, double> features, {int limit = 5}) {
    if (_featureImportance == null || _featureImportance!.isEmpty) {
      // Fallback: use feature magnitudes
      final sorted = features.entries.toList()
        ..sort((a, b) => b.value.abs().compareTo(a.value.abs()));
      
      return sorted
          .take(limit)
          .map((e) => '${_formatFeatureName(e.key)}: ${e.value.toStringAsFixed(2)}')
          .toList();
    }

    // Use feature importance with current values
    final featureScores = <MapEntry<String, double>>[];
    
    for (final entry in features.entries) {
      final importance = _featureImportance![entry.key] ?? 0.0;
      // Score = importance × normalized feature value
      final score = importance * (entry.value.abs() / 100.0);
      featureScores.add(MapEntry(entry.key, score));
    }

    // Sort by score and take top N
    featureScores.sort((a, b) => b.value.compareTo(a.value));
    
    return featureScores
        .take(limit)
        .map((e) => '${_formatFeatureName(e.key)}: ${features[e.key]!.toStringAsFixed(2)}')
        .toList();
  }

  /// Format feature name for display
  String _formatFeatureName(String featureName) {
    return featureName
        .replaceAll('_', ' ')
        .split(' ')
        .map((word) => word.isEmpty ? '' : word[0].toUpperCase() + word.substring(1))
        .join(' ');
  }

  /// Get feature importance rankings
  Map<String, double> getFeatureImportance() {
    return Map.from(_featureImportance ?? {});
  }

  /// Get current sensor buffer statistics
  Map<String, double> getBufferStatistics() {
    return _featureExtractor.getBufferStatistics();
  }

  /// Clear the feature extraction buffer
  void clearBuffer() {
    _featureExtractor.clearBuffer();
  }

  /// Check if buffer has enough data for prediction
  bool get hasEnoughData => _featureExtractor.hasEnoughData;

  /// Get current buffer size
  int get bufferSize => _featureExtractor.bufferSize;

  /// Perform a quick test prediction (for debugging)
  Future<AccidentDetectionResult> testPrediction({
    double impactMagnitude = 15.0,
    double rotationMagnitude = 5.0,
  }) async {
    if (!_isInitialized) {
      throw StateError('Detector not initialized. Call initialize() first.');
    }

    // Create synthetic sensor reading
    final reading = SensorReading(
      accX: impactMagnitude * 0.6,
      accY: impactMagnitude * 0.3,
      accZ: impactMagnitude * 0.5,
      gyroX: rotationMagnitude * 0.7,
      gyroY: rotationMagnitude * 0.4,
      gyroZ: rotationMagnitude * 0.3,
      timestamp: DateTime.now(),
    );

    // Add multiple readings to build up buffer
    for (int i = 0; i < 15; i++) {
      _featureExtractor.addReading(reading);
      await Future.delayed(const Duration(milliseconds: 10));
    }

    return await detectAccident(reading);
  }
}
