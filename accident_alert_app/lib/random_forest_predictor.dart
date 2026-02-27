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
  int? _nClasses;

  bool get isLoaded =>
      _trees != null &&
      _featureNames != null &&
      _classNames != null;

  List<String> get featureNames => _featureNames ?? [];
  List<String> get classNames => _classNames ?? [];
  int get nEstimators => _nEstimators ?? 0;
  int get nFeatures => _nFeatures ?? 0;

  /// Load Random Forest model from JSON asset
  Future<void> loadModel({String assetPath = 'assets/models/accident_detector_rf.json'}) async {
    print('🌲 Loading Random Forest model from $assetPath...');

    try {
      // Load JSON from assets
      final jsonString = await rootBundle.loadString(assetPath);
      final jsonData = json.decode(jsonString) as Map<String, dynamic>;

      // Parse model metadata
      _nEstimators = jsonData['n_estimators'] as int;
      _nFeatures = jsonData['n_features'] as int;
      _nClasses = jsonData['n_classes'] as int;
      _featureNames = (jsonData['feature_names'] as List).cast<String>();
      _classNames = (jsonData['class_names'] as List).cast<String>();

      print('   Model type: ${jsonData['model_type']}');
      print('   Trees: $_nEstimators');
      print('   Features: $_nFeatures');
      print('   Classes: $_classNames');

      // Load all trees
      final treesList = jsonData['trees'] as List;
      _trees = treesList.map((t) => DecisionTree.fromJson(t)).toList();

      print('✅ Random Forest model loaded successfully!');
      print('   Total nodes: ${_trees!.fold(0, (sum, tree) => sum + tree.nodes.length)}');
    } catch (e) {
      print('❌ Error loading Random Forest model: $e');
      rethrow;
    }
  }

  /// Predict class probabilities for a single sample
  /// Returns: [probability_FAKE, probability_REAL]
  Map<String, dynamic> predictProba(List<double> features) {
    if (!isLoaded) {
      throw StateError('Model not loaded. Call loadModel() first.');
    }

    if (features.length != _nFeatures) {
      throw ArgumentError(
          'Expected ${_nFeatures} features, got ${features.length}');
    }

    // Collect predictions from all trees
    final allProba = <List<double>>[];

    for (final tree in _trees!) {
      final proba = tree.predictProba(features);
      allProba.add(proba);
    }

    // Average probabilities across all trees
    final avgProba = List<double>.filled(_nClasses!, 0.0);

    for (final proba in allProba) {
      for (int i = 0; i < _nClasses!; i++) {
        avgProba[i] += proba[i];
      }
    }

    for (int i = 0; i < _nClasses!; i++) {
      avgProba[i] /= _nEstimators!;
    }

    return {
      'probabilities': avgProba,
      'class_names': _classNames,
      'FAKE': avgProba[0],
      'REAL': avgProba[1],
    };
  }

  /// Predict class for a single sample
  /// Returns: 'FAKE' or 'REAL'
  String predict(List<double> features) {
    if (!isLoaded) {
      throw StateError('Model not loaded. Call loadModel() first.');
    }

    if (features.length != _nFeatures) {
      throw ArgumentError(
          'Expected ${_nFeatures} features, got ${features.length}');
    }

    // Collect predictions from all trees
    final votes = List<int>.filled(_nClasses!, 0);

    for (final tree in _trees!) {
      final prediction = tree.predict(features);
      votes[prediction]++;
    }

    // Return class with most votes
    int maxVotes = 0;
    int predictedClass = 0;

    for (int i = 0; i < _nClasses!; i++) {
      if (votes[i] > maxVotes) {
        maxVotes = votes[i];
        predictedClass = i;
      }
    }

    return _classNames![predictedClass];
  }

  /// Get feature importance (number of times each feature was used for splitting)
  Map<String, int> getFeatureUsage() {
    if (!isLoaded) {
      throw StateError('Model not loaded. Call loadModel() first.');
    }

    final usage = Map<String, int>.fromIterable(
      _featureNames!,
      key: (f) => f as String,
      value: (_) => 0,
    );

    for (final tree in _trees!) {
      for (final node in tree.nodes) {
        if (!node.isLeaf) {
          final featureName = _featureNames![node.feature];
          usage[featureName] = (usage[featureName] ?? 0) + 1;
        }
      }
    }

    return usage;
  }

  /// Predict with detailed results including probabilities and confidence
  Map<String, dynamic> predictDetailed(List<double> features) {
    final probaResult = predictProba(features);
    final prediction = predict(features);

    final probabilities = probaResult['probabilities'] as List<double>;
    final confidence = probabilities.reduce((a, b) => a > b ? a : b);

    return {
      'prediction': prediction,
      'confidence': confidence,
      'probabilities': {
        'FAKE': probabilities[0],
        'REAL': probabilities[1],
      },
      'is_real_accident': prediction == 'REAL',
      'votes': {
        'FAKE': (probabilities[0] * _nEstimators!).round(),
        'REAL': (probabilities[1] * _nEstimators!).round(),
      },
    };
  }
}
