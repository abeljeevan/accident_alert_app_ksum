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

  static const _overpassEndpoints = [
    'https://overpass-api.de/api/interpreter',
    'https://overpass.kumi.systems/api/interpreter',
    'https://overpass.private.coffee/api/interpreter',
  ];

  /// Use the fast, location-biased Photon search first, then Overpass mirrors.
  static Future<List<Map<String, dynamic>>> fetchNearbyHospitals(
    double lat,
    double lng, {
    int radius = 10000,
  }) async {
    if (!lat.isFinite || !lng.isFinite || lat.abs() > 90 || lng.abs() > 180) {
      throw ArgumentError('The current location is not valid.');
    }

    Object? lastError;
    try {
      final hospitals = await _fetchFromPhoton(lat, lng, radius)
          .timeout(const Duration(seconds: 8));
      if (hospitals.isNotEmpty) return hospitals;
    } catch (error) {
      lastError = error;
    }

    final query = '[out:json][timeout:8];'
        '(nwr["amenity"="hospital"](around:$radius,$lat,$lng);'
        'nwr["healthcare"="hospital"](around:$radius,$lat,$lng););'
        'out center tags;';
    for (final endpoint in _overpassEndpoints) {
      try {
        final response = await http.post(
          Uri.parse(endpoint),
          headers: const {
            'User-Agent': 'accident_alert_app/1.0',
            'Accept': 'application/json',
          },
          body: {'data': query},
        ).timeout(const Duration(seconds: 10));
        if (response.statusCode != 200) {
          throw Exception('Hospital service returned HTTP ${response.statusCode}.');
        }
        final decoded = jsonDecode(response.body);
        if (decoded is! Map || decoded['elements'] is! List) {
          throw const FormatException('Hospital service returned invalid data.');
        }
        final hospitals = <Map<String, dynamic>>[];
        final seen = <String>{};
        for (final item in decoded['elements'] as List) {
          if (item is! Map) continue;
          final tags = item['tags'] is Map ? item['tags'] as Map : const {};
          final coordinates = item['center'] is Map ? item['center'] as Map : item;
          final hospitalLat = _number(coordinates['lat']);
          final hospitalLon = _number(coordinates['lon']);
          if (hospitalLat == null || hospitalLon == null) continue;
          final name = (tags['name'] ?? tags['name:en'] ?? tags['official_name'])
              ?.toString().trim();
          final hospitalName = name == null || name.isEmpty ? 'Unnamed Hospital' : name;
          final key = '${hospitalName.toLowerCase()}|${hospitalLat.toStringAsFixed(5)}|${hospitalLon.toStringAsFixed(5)}';
          if (!seen.add(key)) continue;
          final type = (tags['healthcare'] ?? tags['emergency'] ?? 'hospital').toString();
          hospitals.add({
            'name': hospitalName,
            'lat': hospitalLat,
            'lon': hospitalLon,
            'type': type,
            'hasEmergency': tags['emergency'] == 'yes' || tags['emergency'] == 'emergency_ward',
            'tags': tags,
          });
        }
        return hospitals;
      } catch (error) {
        lastError = error;
      }
    }
    throw Exception('Nearby hospital information is temporarily unavailable. Check your internet connection and try again. ($lastError)');
  }

  static Future<List<Map<String, dynamic>>> _fetchFromPhoton(
    double lat,
    double lng,
    int radius,
  ) async {
    final uri = Uri.https('photon.komoot.io', '/api/', {
      'q': 'hospital',
      'lat': '$lat',
      'lon': '$lng',
      'limit': '30',
      'location_bias_scale': '0.2',
      'osm_tag': ['amenity:hospital', 'healthcare:hospital'],
    });
    final response = await http.get(uri, headers: const {
      'User-Agent': 'accident_alert_app/1.0',
      'Accept': 'application/json',
    }).timeout(const Duration(seconds: 8));
    if (response.statusCode != 200) {
      throw Exception('Hospital search returned HTTP ${response.statusCode}.');
    }
    final decoded = jsonDecode(response.body);
    if (decoded is! Map || decoded['features'] is! List) {
      throw const FormatException('Hospital search returned invalid data.');
    }
    final hospitals = <Map<String, dynamic>>[];
    final seen = <String>{};
    for (final feature in decoded['features'] as List) {
      if (feature is! Map) continue;
      final properties = feature['properties'] is Map ? feature['properties'] as Map : const {};
      final geometry = feature['geometry'] is Map ? feature['geometry'] as Map : const {};
      final coordinates = geometry['coordinates'];
      if (coordinates is! List || coordinates.length < 2) continue;
      final hospitalLon = _number(coordinates[0]);
      final hospitalLat = _number(coordinates[1]);
      if (hospitalLat == null || hospitalLon == null ||
          Geolocator.distanceBetween(lat, lng, hospitalLat, hospitalLon) > radius) continue;
      final name = (properties['name'] ?? properties['name:en'])?.toString().trim();
      final hospitalName = name == null || name.isEmpty ? 'Unnamed Hospital' : name;
      final key = '${hospitalName.toLowerCase()}|${hospitalLat.toStringAsFixed(5)}|${hospitalLon.toStringAsFixed(5)}';
      if (!seen.add(key)) continue;
      hospitals.add({
        'name': hospitalName,
        'lat': hospitalLat,
        'lon': hospitalLon,
        'type': (properties['osm_value'] ?? 'hospital').toString(),
        'hasEmergency': false,
        'tags': properties,
      });
    }
    hospitals.sort((a, b) => Geolocator.distanceBetween(
      lat, lng, a['lat'] as double, a['lon'] as double,
    ).compareTo(Geolocator.distanceBetween(
      lat, lng, b['lat'] as double, b['lon'] as double,
    )));
    return hospitals;
  }

  static double? _number(dynamic value) {
    if (value is num) return value.toDouble();
    return double.tryParse(value?.toString() ?? '');
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
