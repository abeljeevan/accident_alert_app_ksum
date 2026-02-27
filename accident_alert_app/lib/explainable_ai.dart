import 'package:flutter/material.dart';
import 'edge_ai_detector.dart';

/// Explainable AI handler for visualizing and explaining predictions
class ExplainableAI {
  /// Generate explanation widget for accident detection result
  static Widget buildExplanationCard(AccidentDetectionResult result) {
    return Card(
      elevation: 4,
      margin: const EdgeInsets.all(16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildHeader(result),
            const SizedBox(height: 16),
            _buildProbabilityBar(result),
            const SizedBox(height: 16),
            _buildExplanationText(result),
            const SizedBox(height: 16),
            _buildTopFeatures(result),
          ],
        ),
      ),
    );
  }

  /// Build header with prediction and confidence
  static Widget _buildHeader(AccidentDetectionResult result) {
    final isReal = result.isRealAccident;
    final color = isReal ? Colors.red : Colors.green;
    final icon = isReal ? Icons.warning : Icons.check_circle;

    return Row(
      children: [
        Icon(icon, color: color, size: 32),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                isReal ? '🚨 Real Accident Detected' : '✅ False Alarm',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: color,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Confidence: ${(result.confidence * 100).toStringAsFixed(1)}%',
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.grey[600],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  /// Build probability visualization bar
  static Widget _buildProbabilityBar(AccidentDetectionResult result) {
    final realProb = result.probabilities['REAL'] ?? 0.0;
    final fakeProb = result.probabilities['FAKE'] ?? 0.0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Prediction Probability',
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: Colors.grey[700],
          ),
        ),
        const SizedBox(height: 8),
        ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: Stack(
            children: [
              Container(
                height: 40,
                decoration: BoxDecoration(
                  color: Colors.grey[200],
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              Row(
                children: [
                  Expanded(
                    flex: (fakeProb * 100).round(),
                    child: Container(
                      height: 40,
                      color: Colors.green.withOpacity(0.7),
                      alignment: Alignment.center,
                      child: fakeProb > 0.15
                          ? Text(
                              'FAKE ${(fakeProb * 100).toStringAsFixed(0)}%',
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                              ),
                            )
                          : null,
                    ),
                  ),
                  Expanded(
                    flex: (realProb * 100).round(),
                    child: Container(
                      height: 40,
                      color: Colors.red.withOpacity(0.7),
                      alignment: Alignment.center,
                      child: realProb > 0.15
                          ? Text(
                              'REAL ${(realProb * 100).toStringAsFixed(0)}%',
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                              ),
                            )
                          : null,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  /// Build explanation text
  static Widget _buildExplanationText(AccidentDetectionResult result) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.blue.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.blue.withOpacity(0.3)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.lightbulb, color: Colors.blue, size: 20),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              result.explanation,
              style: const TextStyle(fontSize: 14),
            ),
          ),
        ],
      ),
    );
  }

  /// Build top contributing features
  static Widget _buildTopFeatures(AccidentDetectionResult result) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Key Contributing Factors',
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: Colors.grey[700],
          ),
        ),
        const SizedBox(height: 8),
        ...result.topFeatures.map((feature) => Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Row(
                children: [
                  Container(
                    width: 6,
                    height: 6,
                    decoration: BoxDecoration(
                      color: Colors.blue,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      feature,
                      style: const TextStyle(fontSize: 13),
                    ),
                  ),
                ],
              ),
            )),
      ],
    );
  }

  /// Generate detailed report text
  static String generateDetailedReport(AccidentDetectionResult result) {
    final buffer = StringBuffer();
    
    buffer.writeln('═══════════════════════════════════════');
    buffer.writeln('  ACCIDENT DETECTION REPORT');
    buffer.writeln('═══════════════════════════════════════');
    buffer.writeln();
    buffer.writeln('Timestamp: ${result.timestamp}');
    buffer.writeln('Prediction: ${result.prediction}');
    buffer.writeln('Confidence: ${(result.confidence * 100).toStringAsFixed(2)}%');
    buffer.writeln();
    buffer.writeln('Probabilities:');
    buffer.writeln('  FAKE: ${(result.probabilities["FAKE"]! * 100).toStringAsFixed(2)}%');
    buffer.writeln('  REAL: ${(result.probabilities["REAL"]! * 100).toStringAsFixed(2)}%');
    buffer.writeln();
    buffer.writeln('Explanation:');
    buffer.writeln('  ${result.explanation}');
    buffer.writeln();
    buffer.writeln('Top Contributing Features:');
    for (final feature in result.topFeatures) {
      buffer.writeln('  • $feature');
    }
    buffer.writeln();
    buffer.writeln('All Features:');
    result.features.forEach((key, value) {
      buffer.writeln('  ${key.padRight(25)}: ${value.toStringAsFixed(4)}');
    });
    buffer.writeln('═══════════════════════════════════════');
    
    return buffer.toString();
  }

  /// Show explanation dialog
  static Future<void> showExplanationDialog(
    BuildContext context,
    AccidentDetectionResult result,
  ) {
    return showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(
          result.isRealAccident ? 'Real Accident Detected' : 'False Alarm',
          style: TextStyle(
            color: result.isRealAccident ? Colors.red : Colors.green,
          ),
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              buildExplanationCard(result),
              const SizedBox(height: 16),
              const Text(
                'This analysis is provided by a Random Forest machine learning model trained on real accident data.',
                style: TextStyle(
                  fontSize: 12,
                  fontStyle: FontStyle.italic,
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Close'),
          ),
          TextButton(
            onPressed: () {
              final report = generateDetailedReport(result);
              print(report);
              Navigator.of(context).pop();
            },
            child: const Text('View Full Report'),
          ),
        ],
      ),
    );
  }

  /// Get color for confidence level
  static Color getConfidenceColor(double confidence) {
    if (confidence >= 0.9) return Colors.green;
    if (confidence >= 0.7) return Colors.orange;
    return Colors.red;
  }

  /// Get icon for prediction type
  static IconData getPredictionIcon(bool isRealAccident) {
    return isRealAccident ? Icons.warning_amber : Icons.check_circle;
  }
}
