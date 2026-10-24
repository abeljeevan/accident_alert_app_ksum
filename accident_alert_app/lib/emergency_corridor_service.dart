import 'dart:convert';

import 'package:http/http.dart' as http;

/// FastAPI contract: POST {baseUrl}/api/emergency-corridors with incident GPS.
/// Set CORRIDOR_API_BASE_URL with --dart-define to enable live dispatch.
/// Without a configured server, results are explicitly marked simulated.
class EmergencyCorridorService {
  static const _baseUrl = String.fromEnvironment('CORRIDOR_API_BASE_URL');
  static String? _lastIncidentKey;
  static Future<Map<String, dynamic>>? _lastIncidentRequest;
  static DateTime? _lastIncidentAt;

  static Future<Map<String, dynamic>> createIncident({
    required double latitude,
    required double longitude,
    required DateTime occurredAt,
    String severity = 'Emergency',
  }) {
    final key = '${latitude.toStringAsFixed(5)},${longitude.toStringAsFixed(5)}';
    if (_lastIncidentKey == key && _lastIncidentRequest != null && _lastIncidentAt != null && DateTime.now().difference(_lastIncidentAt!) < const Duration(minutes: 3)) return _lastIncidentRequest!;
    _lastIncidentKey = key;
    _lastIncidentAt = DateTime.now();
    return _lastIncidentRequest = _createIncident(
      latitude: latitude,
      longitude: longitude,
      occurredAt: occurredAt,
      severity: severity,
    );
  }

  static Future<Map<String, dynamic>> _createIncident({
    required double latitude,
    required double longitude,
    required DateTime occurredAt,
    required String severity,
  }) async {
    if (_baseUrl.isNotEmpty) {
      try {
        final response = await http
            .post(
              Uri.parse('$_baseUrl/api/emergency-corridors'),
              headers: const {'Content-Type': 'application/json'},
              body: jsonEncode({
                'latitude': latitude,
                'longitude': longitude,
                'occurred_at': occurredAt.toUtc().toIso8601String(),
                'severity': severity,
              }),
            )
            .timeout(const Duration(seconds: 8));
        if (response.statusCode >= 200 && response.statusCode < 300) {
          final body = jsonDecode(response.body);
          if (body is Map<String, dynamic>) {
            return {...body, 'simulated': body['simulated'] == true, 'backendUnavailable': false};
          }
        }
      } catch (_) {
        // Keep emergency UI usable if the optional dispatch service is offline.
      }
      return {
        'simulated': true,
        'backendUnavailable': true,
        'message': 'Backend unavailable; showing a local simulation.',
      };
    }
    return {
      'simulated': true,
      'backendUnavailable': false,
      'message': 'Demo mode: no FastAPI endpoint is configured.',
    };
  }
}
