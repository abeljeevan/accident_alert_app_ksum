import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:latlong2/latlong.dart';

/// OSRM (Open Source Routing Machine) service for route calculation
class OSRMRoutingService {
  /// Calculate route between two points using OSRM
  static Future<Map<String, dynamic>?> calculateRoute({
    required double startLat,
    required double startLon,
    required double endLat,
    required double endLon,
  }) async {
    try {
      // OSRM demo server - free but rate-limited
      // For production, consider hosting your own OSRM instance
      final url = 'https://router.project-osrm.org/route/v1/driving/'
          '$startLon,$startLat;$endLon,$endLat'
          '?overview=full&geometries=geojson';

      final response = await http.get(
        Uri.parse(url),
        headers: {'User-Agent': 'accident_alert_app/1.0'},
      ).timeout(
        const Duration(seconds: 10),
        onTimeout: () {
          throw Exception('OSRM routing request timed out');
        },
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        
        if (data['code'] == 'Ok' && data['routes'] != null && data['routes'].isNotEmpty) {
          final route = data['routes'][0];
          final geometry = route['geometry']['coordinates'] as List;
          
          // Convert coordinates to LatLng format
          final routePoints = geometry.map<LatLng>((coord) {
            return LatLng(coord[1].toDouble(), coord[0].toDouble());
          }).toList();

          return {
            'distance': route['distance'] / 1000, // Convert to km
            'duration': route['duration'] / 60, // Convert to minutes
            'routePoints': routePoints,
            'geometry': geometry,
          };
        } else {
          throw Exception('No route found');
        }
      } else {
        throw Exception('OSRM server error: HTTP ${response.statusCode}');
      }
    } catch (e) {
      print('⚠️ OSRM routing failed: $e');
      return null;
    }
  }

  /// Generate OpenStreetMap routing link
  static String generateOSMRouteLink({
    required double startLat,
    required double startLon,
    required double endLat,
    required double endLon,
  }) {
    // OpenStreetMap routing link
    return 'https://www.openstreetmap.org/directions?'
        'engine=fossgis_osrm_car&'
        'route=$startLat%2C$startLon%3B$endLat%2C$endLon';
  }

  /// Format duration for display
  static String formatDuration(double minutes) {
    if (minutes < 1) {
      return '< 1 min';
    } else if (minutes < 60) {
      return '${minutes.round()} min';
    } else {
      final hours = minutes ~/ 60;
      final mins = (minutes % 60).round();
      return '$hours hr ${mins} min';
    }
  }

  /// Format distance for display
  static String formatDistance(double km) {
    if (km < 1) {
      return '${(km * 1000).round()} m';
    } else {
      return '${km.toStringAsFixed(1)} km';
    }
  }
}
