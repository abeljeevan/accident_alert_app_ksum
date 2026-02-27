import 'dart:math';
import 'dart:collection';

/// Raw sensor data point
class SensorReading {
  final double accX;
  final double accY;
  final double accZ;
  final double gyroX;
  final double gyroY;
  final double gyroZ;
  final DateTime timestamp;

  SensorReading({
    required this.accX,
    required this.accY,
    required this.accZ,
    required this.gyroX,
    required this.gyroY,
    required this.gyroZ,
    required this.timestamp,
  });

  /// Calculate impact magnitude from accelerometer
  double get impactMagnitude => sqrt(accX * accX + accY * accY + accZ * accZ);

  /// Calculate rotation magnitude from gyroscope
  double get rotationMagnitude =>
      sqrt(gyroX * gyroX + gyroY * gyroY + gyroZ * gyroZ);
}

/// Feature extraction engine for accident detection ML model
/// Converts raw sensor data into 19 features required by Random Forest
class FeatureExtractor {
  // Buffer of recent sensor readings (for temporal features)
  final _sensorBuffer = Queue<SensorReading>();
  static const int _bufferSize = 50; // Keep last 50 readings (~1 second at 50Hz)

  // Previous state for calculating changes
  double? _previousImpactMagnitude;
  DateTime? _lastLowActivityTime;
  int _currentImmobilityDuration = 0;

  /// Add a sensor reading to the buffer
  void addReading(SensorReading reading) {
    _sensorBuffer.add(reading);

    // Maintain buffer size
    while (_sensorBuffer.length > _bufferSize) {
      _sensorBuffer.removeFirst();
    }

    // Update immobility tracking
    if (reading.impactMagnitude < 1.0) {
      _lastLowActivityTime ??= reading.timestamp;
      _currentImmobilityDuration =
          reading.timestamp.difference(_lastLowActivityTime!).inSeconds;
    } else {
      _lastLowActivityTime = null;
      _currentImmobilityDuration = 0;
    }
  }

  /// Extract all 19 features from current sensor buffer
  /// Returns feature vector in the order expected by the model
  List<double> extractFeatures() {
    if (_sensorBuffer.isEmpty) {
      throw StateError('No sensor readings available. Call addReading() first.');
    }

    final latest = _sensorBuffer.last;
    
    // Calculate basic features
    final impactX = latest.accX;
    final impactY = latest.accY;
    final impactZ = latest.accZ;
    final impactMagnitude = latest.impactMagnitude;
    
    final rotationX = latest.gyroX;
    final rotationY = latest.gyroY;
    final rotationZ = latest.gyroZ;
    final rotationMagnitude = latest.rotationMagnitude;

    // Calculate speed change (acceleration change rate)
    double speedChange = 0.0;
    if (_previousImpactMagnitude != null) {
      speedChange = (impactMagnitude - _previousImpactMagnitude!).abs();
    }
    _previousImpactMagnitude = impactMagnitude;

    // Estimate pre-crash and post-crash speed (based on impact magnitude)
    final preSpeed = impactMagnitude * 2.5; // Rough estimate
    final postSpeed = max(0.0, preSpeed - speedChange);

    // Estimate impact duration (higher magnitude = longer duration)
    final impactDuration = impactMagnitude > 5.0
        ? 0.5 // Real impacts last longer (0.2-0.8s)
        : 0.08; // Brief movements (0.01-0.15s)

    // Estimate secondary impacts (higher magnitude suggests multiple impacts)
    final secondaryImpacts = impactMagnitude > 10.0 ? 2.0 : 0.0;

    // Altitude change (would come from GPS in production, simulated here)
    final altitudeChange = 1.0;

    // GPS accuracy (would come from GPS in production, simulated here)
    final gpsAccuracy = 8.0;

    // Time of day (0-23)
    final timeOfDay = latest.timestamp.hour.toDouble();

    // Is moving (based on speed)
    final isMoving = preSpeed > 5.0 ? 1.0 : 0.0;

    // Post-crash vibrations (from gyroscope)
    final postVibrations = rotationMagnitude * 0.5;

    // Immobility duration (seconds of low activity)
    final immobilityDuration = _currentImmobilityDuration.toDouble();

    // Return features in the exact order expected by the model
    return [
      impactX, // 0
      impactY, // 1
      impactZ, // 2
      impactMagnitude, // 3
      preSpeed, // 4
      postSpeed, // 5
      speedChange, // 6
      immobilityDuration, // 7
      rotationX, // 8
      rotationY, // 9
      rotationZ, // 10
      rotationMagnitude, // 11
      impactDuration, // 12
      secondaryImpacts, // 13
      altitudeChange, // 14
      gpsAccuracy, // 15
      timeOfDay, // 16
      isMoving, // 17
      postVibrations, // 18
    ];
  }

  /// Extract features with named keys (for debugging/logging)
  Map<String, double> extractFeaturesMap() {
    final features = extractFeatures();

    return {
      'impact_x': features[0],
      'impact_y': features[1],
      'impact_z': features[2],
      'impact_magnitude': features[3],
      'pre_speed': features[4],
      'post_speed': features[5],
      'speed_change': features[6],
      'immobility_duration': features[7],
      'rotation_x': features[8],
      'rotation_y': features[9],
      'rotation_z': features[10],
      'rotation_magnitude': features[11],
      'impact_duration': features[12],
      'secondary_impacts': features[13],
      'altitude_change': features[14],
      'gps_accuracy': features[15],
      'time_of_day': features[16],
      'is_moving': features[17],
      'post_vibrations': features[18],
    };
  }

  /// Get statistics from buffered sensor data
  Map<String, double> getBufferStatistics() {
    if (_sensorBuffer.isEmpty) {
      return {};
    }

    final impacts = _sensorBuffer.map((r) => r.impactMagnitude).toList();
    final rotations = _sensorBuffer.map((r) => r.rotationMagnitude).toList();

    return {
      'buffer_size': _sensorBuffer.length.toDouble(),
      'avg_impact': impacts.reduce((a, b) => a + b) / impacts.length,
      'max_impact': impacts.reduce(max),
      'min_impact': impacts.reduce(min),
      'avg_rotation': rotations.reduce((a, b) => a + b) / rotations.length,
      'max_rotation': rotations.reduce(max),
    };
  }

  /// Clear the sensor buffer (e.g., after processing an event)
  void clearBuffer() {
    _sensorBuffer.clear();
    _previousImpactMagnitude = null;
    _lastLowActivityTime = null;
    _currentImmobilityDuration = 0;
  }

  /// Check if there's enough data for reliable feature extraction
  bool get hasEnoughData => _sensorBuffer.length >= 10; // At least 10 readings

  /// Get current buffer size
  int get bufferSize => _sensorBuffer.length;
}
