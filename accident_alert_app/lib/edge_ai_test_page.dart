import 'package:flutter/material.dart';
import 'edge_ai_detector.dart';
import 'feature_extractor.dart';
import 'explainable_ai.dart';

/// Demo page to test Edge AI accident detection
class EdgeAITestPage extends StatefulWidget {
  const EdgeAITestPage({super.key});

  @override
  State<EdgeAITestPage> createState() => _EdgeAITestPageState();
}

class _EdgeAITestPageState extends State<EdgeAITestPage> {
  final EdgeAIDetector _edgeAI = EdgeAIDetector();
  bool _isInitialized = false;
  bool _isLoading = true;
  AccidentDetectionResult? _lastResult;

  @override
  void initState() {
    super.initState();
    _initializeEdgeAI();
  }

  Future<void> _initializeEdgeAI() async {
    try {
      await _edgeAI.initialize();
      setState(() {
        _isInitialized = true;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to initialize Edge AI: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _testRealAccident() async {
    setState(() => _isLoading = true);

    try {
      // Simulate high-impact accident
      final result = await _edgeAI.testPrediction(
        impactMagnitude: 45.0, // Very high impact
        rotationMagnitude: 12.0, // High rotation
      );

      setState(() {
        _lastResult = result;
        _isLoading = false;
      });

      _showResultDialog(result);
    } catch (e) {
      setState(() => _isLoading = false);
      _showError('Test failed: $e');
    }
  }

  Future<void> _testFakeAccident() async {
    setState(() => _isLoading = true);

    try {
      // Simulate low-impact false alarm
      final result = await _edgeAI.testPrediction(
        impactMagnitude: 8.0, // Low impact
        rotationMagnitude: 2.0, // Low rotation
      );

      setState(() {
        _lastResult = result;
        _isLoading = false;
      });

      _showResultDialog(result);
    } catch (e) {
      setState(() => _isLoading = false);
      _showError('Test failed: $e');
    }
  }

  Future<void> _testCustom(double impact, double rotation) async {
    setState(() => _isLoading = true);

    try {
      final result = await _edgeAI.testPrediction(
        impactMagnitude: impact,
        rotationMagnitude: rotation,
      );

      setState(() {
        _lastResult = result;
        _isLoading = false;
      });

      _showResultDialog(result);
    } catch (e) {
      setState(() => _isLoading = false);
      _showError('Test failed: $e');
    }
  }

  void _showResultDialog(AccidentDetectionResult result) {
    ExplainableAI.showExplanationDialog(context, result);
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('🤖 Edge AI Test'),
        backgroundColor: Colors.deepPurple,
      ),
      body: _isLoading
          ? const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(),
                  SizedBox(height: 16),
                  Text('Loading Edge AI...'),
                ],
              ),
            )
          : !_isInitialized
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.error, size: 64, color: Colors.red),
                      const SizedBox(height: 16),
                      const Text(
                        'Edge AI initialization failed',
                        style: TextStyle(fontSize: 18),
                      ),
                      const SizedBox(height: 24),
                      ElevatedButton(
                        onPressed: () {
                          setState(() => _isLoading = true);
                          _initializeEdgeAI();
                        },
                        child: const Text('Retry'),
                      ),
                    ],
                  ),
                )
              : SingleChildScrollView(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // Status Card
                      Card(
                        color: Colors.green[50],
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Row(
                            children: [
                              const Icon(Icons.check_circle,
                                  color: Colors.green, size: 32),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text(
                                      'Edge AI Ready',
                                      style: TextStyle(
                                        fontSize: 18,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      'Random Forest: ${_edgeAI.nEstimators} trees',
                                      style: TextStyle(
                                        color: Colors.grey[700],
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),

                      const SizedBox(height: 24),

                      // Test Buttons
                      const Text(
                        'Quick Tests',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 12),

                      ElevatedButton.icon(
                        onPressed: _testRealAccident,
                        icon: const Icon(Icons.warning),
                        label: const Text('Test Real Accident'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.red,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.all(16),
                        ),
                      ),

                      const SizedBox(height: 12),

                      ElevatedButton.icon(
                        onPressed: _testFakeAccident,
                        icon: const Icon(Icons.check_circle),
                        label: const Text('Test False Alarm'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.green,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.all(16),
                        ),
                      ),

                      const SizedBox(height: 24),

                      // Custom Test
                      const Text(
                        'Custom Test',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 12),

                      _CustomTestForm(
                        onTest: _testCustom,
                      ),

                      const SizedBox(height: 24),

                      // Last Result
                      if (_lastResult != null) ...[
                        const Text(
                          'Last Result',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 12),
                        ExplainableAI.buildExplanationCard(_lastResult!),
                      ],

                      const SizedBox(height: 24),

                      // Info Card
                      Card(
                        color: Colors.blue[50],
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  const Icon(Icons.info, color: Colors.blue),
                                  const SizedBox(width: 8),
                                  Text(
                                    'About This Test',
                                    style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.blue[900],
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 12),
                              Text(
                                '• Random Forest with 100 decision trees\n'
                                '• Trained on 3,084 accident samples\n'
                                '• 19 engineered features from sensors\n'
                                '• On-device processing (no internet)\n'
                                '• Explainable AI with confidence scores',
                                style: TextStyle(
                                  color: Colors.grey[800],
                                  height: 1.5,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
    );
  }
}

class _CustomTestForm extends StatefulWidget {
  final Function(double, double) onTest;

  const _CustomTestForm({required this.onTest});

  @override
  State<_CustomTestForm> createState() => _CustomTestFormState();
}

class _CustomTestFormState extends State<_CustomTestForm> {
  double _impactMagnitude = 25.0;
  double _rotationMagnitude = 5.0;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Impact Magnitude: ${_impactMagnitude.toStringAsFixed(1)} m/s²',
              style: const TextStyle(fontSize: 16),
            ),
            Slider(
              value: _impactMagnitude,
              min: 1.0,
              max: 60.0,
              divisions: 59,
              label: _impactMagnitude.toStringAsFixed(1),
              onChanged: (value) {
                setState(() => _impactMagnitude = value);
              },
            ),
            const SizedBox(height: 12),
            Text(
              'Rotation Magnitude: ${_rotationMagnitude.toStringAsFixed(1)} rad/s',
              style: const TextStyle(fontSize: 16),
            ),
            Slider(
              value: _rotationMagnitude,
              min: 0.0,
              max: 20.0,
              divisions: 40,
              label: _rotationMagnitude.toStringAsFixed(1),
              onChanged: (value) {
                setState(() => _rotationMagnitude = value);
              },
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () {
                  widget.onTest(_impactMagnitude, _rotationMagnitude);
                },
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.all(16),
                ),
                child: const Text('Run Custom Test'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
