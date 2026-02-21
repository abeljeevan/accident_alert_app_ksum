import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:geolocator/geolocator.dart';

class HospitalService {
  /// Hospital type priorities (higher = better for severe accidents)
  static const Map<String, int> hospitalTypePriority = {
    'hospital': 100,
    'trauma_center': 150,
    'emergency_department': 120,
    'clinic': 50,
    'doctors': 30,
  };

  /// Fetch nearby hospitals within 5km using Overpass API
  static Future<List<Map<String, dynamic>>> fetchNearbyHospitals(
      double lat, double lng,
      {int radius = 5000}) async {
    try {
      final url =
          'https://overpass-api.de/api/interpreter?data=[out:json];'
          '(node["amenity"="hospital"](around:$radius,$lat,$lng);'
          'way["amenity"="hospital"](around:$radius,$lat,$lng);'
          'relation["amenity"="hospital"](around:$radius,$lat,$lng););'
          'out center;';

      final response = await http.get(
        Uri.parse(url),
        headers: {'User-Agent': 'accident_alert_app/1.0'},
      ).timeout(
        const Duration(seconds: 5), // Add timeout to prevent hanging
        onTimeout: () {
          throw Exception('Hospital API request timed out');
        },
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final elements = data['elements'] as List;

        return elements.map<Map<String, dynamic>>((h) {
          final double hospitalLat =
              h['lat'] ?? h['center']?['lat']?.toDouble() ?? 0.0;
          final double hospitalLon =
              h['lon'] ?? h['center']?['lon']?.toDouble() ?? 0.0;
          
          // Extract hospital type/category
          final tags = h['tags'] ?? {};
          final type = tags['healthcare'] ?? tags['emergency'] ?? 'hospital';
          final hasEmergency = tags['emergency'] == 'yes';

          return {
            "name": tags["name"] ?? "Unnamed Hospital",
            "lat": hospitalLat,
            "lon": hospitalLon,
            "type": type,
            "hasEmergency": hasEmergency,
            "tags": tags,
          };
        }).toList();
      } else {
        throw Exception('Failed to fetch hospitals: HTTP ${response.statusCode}');
      }
    } catch (e) {
      // Re-throw with more context
      throw Exception('Failed to fetch hospitals: $e');
    }
  }

  /// Get nearest hospital (simple distance-based)
  static Future<Map<String, dynamic>?> getNearestHospital(
      double lat, double lng) async {
    final hospitals = await fetchNearbyHospitals(lat, lng);

    if (hospitals.isEmpty) return null;

    hospitals.sort((a, b) {
      final distA = Geolocator.distanceBetween(lat, lng, a["lat"], a["lon"]);
      final distB = Geolocator.distanceBetween(lat, lng, b["lat"], b["lon"]);
      return distA.compareTo(distB);
    });

    return hospitals.first;
  }

  /// Smart hospital selection based on severity and distance
  static Future<Map<String, dynamic>?> getSmartHospital({
    required double lat,
    required double lng,
    required String severity, // 'Minor', 'Moderate', 'Severe', 'Critical'
  }) async {
    final hospitals = await fetchNearbyHospitals(lat, lng);

    if (hospitals.isEmpty) return null;

    // Calculate scores for each hospital
    final hospitalsWithScores = hospitals.map((hospital) {
      final distance = Geolocator.distanceBetween(
        lat,
        lng,
        hospital["lat"],
        hospital["lon"],
      ) / 1000; // Convert to km

      // Distance score (closer is better, max 100 points)
      double distanceScore = 100 - (distance * 10);
      if (distanceScore < 0) distanceScore = 0;

      // Type score based on hospital category
      final type = hospital['type'] ?? 'hospital';
      double typeScore = hospitalTypePriority[type]?.toDouble() ?? 100;

      // Emergency department bonus
      if (hospital['hasEmergency'] == true) {
        typeScore += 30;
      }

      // Severity multiplier
      double severityMultiplier = 1.0;
      if (severity == 'Critical' || severity == 'Severe') {
        // For severe cases, prioritize hospital quality over distance
        severityMultiplier = 1.5;
        typeScore *= 1.5;
      }

      // Final score
      final totalScore = (distanceScore + typeScore) * severityMultiplier;

      return {
        ...hospital,
        'distance': distance,
        'score': totalScore,
        'distanceScore': distanceScore,
        'typeScore': typeScore,
      };
    }).toList();

    // Sort by score (highest first)
    hospitalsWithScores.sort((a, b) => b['score'].compareTo(a['score']));

    return hospitalsWithScores.first;
  }
}
