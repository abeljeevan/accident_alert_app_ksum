import 'dart:math';

/// AI-based severity analyzer using sensor data and impact metrics
class AISeverityAnalyzer {
  /// Analyze crash severity based on multiple factors
  static Map<String, dynamic> analyzeSeverity({
    required double impactForce,
    required double speedBeforeCrash,
    required double impactX,
    required double impactY,
    required double impactZ,
    required int immobilityDuration,
  }) {
    // Calculate various risk factors
    double forceScore = _calculateForceScore(impactForce);
    double speedScore = _calculateSpeedScore(speedBeforeCrash);
    double impactScore = _calculateImpactScore(impactX, impactY, impactZ);
    double immobilityScore = _calculateImmobilityScore(immobilityDuration);

    // Weighted average (AI simulation)
    double finalScore =
        (forceScore * 0.35 + // Impact force is most important
        speedScore * 0.25 + // Speed before crash
        impactScore * 0.20 + // Impact direction/intensity
        immobilityScore *
            0.20 // Post-crash immobility
            );

    // Determine severity level
    String severity;
    String reason;
    double confidence;

    if (finalScore >= 0.85) {
      severity = 'Critical';
      confidence = 0.90 + (finalScore - 0.85) * 0.10 / 0.15;
      reason =
          'Extremely high impact force detected. Multiple severe injury indicators. Immediate medical attention required.';
    } else if (finalScore >= 0.65) {
      severity = 'Severe';
      confidence = 0.85 + (finalScore - 0.65) * 0.05 / 0.20;
      reason =
          'High impact force with significant speed. Serious injuries likely. Emergency response needed.';
    } else if (finalScore >= 0.40) {
      severity = 'Moderate';
      confidence = 0.80 + (finalScore - 0.40) * 0.05 / 0.25;
      reason =
          'Moderate impact detected. Possible injuries. Medical evaluation recommended.';
    } else {
      severity = 'Minor';
      confidence = 0.75 + finalScore * 0.05 / 0.40;
      reason =
          'Low impact force. Minor collision detected. Check for any injuries.';
    }

    return {
      'severity': severity,
      'confidence': confidence.clamp(0.0, 1.0),
      'reason': reason,
      'scores': {
        'force': forceScore,
        'speed': speedScore,
        'impact': impactScore,
        'immobility': immobilityScore,
        'final': finalScore,
      },
    };
  }

  /// Calculate score based on impact force (0.0 to 1.0)
  static double _calculateForceScore(double force) {
    // Force threshold mapping:
    // < 40: Normal activity
    // 40-60: Minor impact
    // 60-100: Moderate impact
    // 100-150: Severe impact
    // > 150: Critical impact

    if (force < 40) return 0.0;
    if (force < 60) return 0.2 + (force - 40) / 20 * 0.2; // 0.2-0.4
    if (force < 100) return 0.4 + (force - 60) / 40 * 0.3; // 0.4-0.7
    if (force < 150) return 0.7 + (force - 100) / 50 * 0.2; // 0.7-0.9
    return min(1.0, 0.9 + (force - 150) / 100 * 0.1); // 0.9-1.0
  }

  /// Calculate score based on speed (0.0 to 1.0)
  static double _calculateSpeedScore(double speed) {
    // Speed threshold mapping (km/h):
    // < 20: Very low risk
    // 20-40: Low risk
    // 40-60: Moderate risk
    // 60-80: High risk
    // > 80: Critical risk

    if (speed < 20) return 0.1;
    if (speed < 40) return 0.3 + (speed - 20) / 20 * 0.2;
    if (speed < 60) return 0.5 + (speed - 40) / 20 * 0.2;
    if (speed < 80) return 0.7 + (speed - 60) / 20 * 0.2;
    return min(1.0, 0.9 + (speed - 80) / 40 * 0.1);
  }

  /// Calculate score based on 3D impact vector (0.0 to 1.0)
  static double _calculateImpactScore(double x, double y, double z) {
    // Calculate total impact magnitude
    double magnitude = sqrt(x * x + y * y + z * z);

    // Vertical impact (Z-axis) is more dangerous
    double verticalWeight = z.abs() / magnitude;
    double lateralWeight = (x.abs() + y.abs()) / magnitude;

    // Weighted impact score
    double baseScore = magnitude / 200; // Normalize to ~0-1
    double directionMultiplier =
        1.0 + (verticalWeight * 0.3); // Up to 30% increase for vertical

    return min(1.0, baseScore * directionMultiplier);
  }

  /// Calculate score based on immobility duration (0.0 to 1.0)
  static double _calculateImmobilityScore(int durationSeconds) {
    // Immobility indicates potential unconsciousness or severe injury
    // < 5s: Normal (may have moved away)
    // 5-15s: Concerning
    // 15-30s: Serious
    // > 30s: Critical

    if (durationSeconds < 5) return 0.1;
    if (durationSeconds < 15) return 0.3 + (durationSeconds - 5) / 10 * 0.3;
    if (durationSeconds < 30) return 0.6 + (durationSeconds - 15) / 15 * 0.3;
    return min(1.0, 0.9 + (durationSeconds - 30) / 30 * 0.1);
  }

  /// Get recommendations based on severity
  static List<String> getRecommendations(String severity) {
    switch (severity) {
      case 'Critical':
        return [
          '🚨 Call emergency services immediately (911/112)',
          '🏥 Request ambulance and paramedics',
          '⚠️ Do not move the victim unless necessary',
          '🩹 Check for breathing and pulse',
          '📞 Contact all emergency contacts',
          '📍 Share exact location with responders',
        ];
      case 'Severe':
        return [
          '📞 Call emergency services',
          '🏥 Go to nearest hospital immediately',
          '👨‍⚕️ Seek medical evaluation',
          '🩹 Check for visible injuries',
          '📸 Document injuries if possible',
          '📱 Contact emergency contacts',
        ];
      case 'Moderate':
        return [
          '🏥 Visit hospital or urgent care',
          '👨‍⚕️ Get medical evaluation',
          '📸 Document any injuries or damages',
          '📝 File police report if needed',
          '📞 Inform emergency contacts',
          '⚠️ Monitor for delayed symptoms',
        ];
      case 'Minor':
        return [
          '🏥 Consider medical check-up',
          '📸 Take photos of scene and damages',
          '📝 Document incident details',
          '👮 File report if other parties involved',
          '⚠️ Watch for symptoms in next 24-48 hours',
        ];
      default:
        return ['Seek appropriate medical attention'];
    }
  }
}
