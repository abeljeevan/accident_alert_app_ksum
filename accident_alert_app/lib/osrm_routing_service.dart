import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';

/// OSRM routing with a fallback provider for availability issues.
class OSRMRoutingService {
  static const _routeEndpoints = [
    'https://router.project-osrm.org',
    'https://routing.openstreetmap.de/routed-car',
  ];

  static Future<Map<String, dynamic>?> calculateRoute({
    required double startLat,
    required double startLon,
    required double endLat,
    required double endLon,
    Duration timeoutPerEndpoint = const Duration(seconds: 18),
  }) async {
    if (![startLat, startLon, endLat, endLon].every((v) => v.isFinite) ||
        startLat.abs() > 90 ||
        endLat.abs() > 90 ||
        startLon.abs() > 180 ||
        endLon.abs() > 180) {
      return null;
    }

    for (final endpoint in _routeEndpoints) {
      try {
        final uri =
            Uri.parse(
              '$endpoint/route/v1/driving/$startLon,$startLat;$endLon,$endLat',
            ).replace(
              queryParameters: const {
                'overview': 'full',
                'geometries': 'geojson',
                'steps': 'false',
              },
            );
        final response = await http
            .get(
              uri,
              headers: const {
                'User-Agent': 'accident_alert_app/1.0',
                'Accept': 'application/json',
              },
            )
            .timeout(timeoutPerEndpoint);
        if (response.statusCode != 200) continue;

        final data = jsonDecode(response.body);
        if (data is! Map ||
            data['code'] != 'Ok' ||
            data['routes'] is! List ||
            (data['routes'] as List).isEmpty)
          continue;
        final route = (data['routes'] as List).first;
        final coordinates = route['geometry']?['coordinates'];
        if (coordinates is! List || coordinates.isEmpty) continue;
        final routePoints = coordinates
            .map<LatLng>(
              (coordinate) => LatLng(
                (coordinate[1] as num).toDouble(),
                (coordinate[0] as num).toDouble(),
              ),
            )
            .toList();
        return {
          'distance': (route['distance'] as num).toDouble() / 1000,
          'duration': (route['duration'] as num).toDouble() / 60,
          'routePoints': routePoints,
          'geometry': coordinates,
        };
      } catch (error) {
        print('OSRM endpoint failed ($endpoint): $error');
      }
    }
    return null;
  }

  static String generateOSMRouteLink({
    required double startLat,
    required double startLon,
    required double endLat,
    required double endLon,
  }) {
    final uri = Uri.https('www.openstreetmap.org', '/directions', {
      'engine': 'fossgis_osrm_car',
      'route': '$startLat,$startLon;$endLat,$endLon',
    });
    return uri.toString();
  }

  static String formatDuration(double minutes) {
    if (minutes < 1) return '< 1 min';
    if (minutes < 60) return '${minutes.round()} min';
    final hours = minutes ~/ 60;
    final mins = (minutes % 60).round();
    return '$hours hr $mins min';
  }

  static String formatDistance(double km) =>
      km < 1 ? '${(km * 1000).round()} m' : '${km.toStringAsFixed(1)} km';
}
