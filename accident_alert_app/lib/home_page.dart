import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'app_ui_components.dart';
import 'package:geolocator/geolocator.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:sensors_plus/sensors_plus.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:geocoding/geocoding.dart';
import 'hospital_service.dart';

import 'accident_detector.dart';
import 'log_page.dart';
import 'contact_store.dart';
import 'log_store.dart';
import 'manage_contacts.dart';
import 'crash_report.dart';
import 'ai_severity_analyzer.dart';
import 'voice_ai_handler.dart';
import 'osrm_routing_service.dart';
import 'accident_map_page.dart';
// import 'pdf_report_generator.dart'; // Temporarily disabled
import 'crash_reports_page.dart';
import 'edge_ai_detector.dart';
import 'feature_extractor.dart';
import 'explainable_ai.dart';
import 'emergency_corridor_service.dart';
import 'emergency_corridor_page.dart';

class HomePage extends StatefulWidget {
  final bool isDarkMode;
  final VoidCallback onToggleTheme;

  const HomePage({
    super.key,
    required this.isDarkMode,
    required this.onToggleTheme,
  });

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  static const MethodChannel _smsChannel = MethodChannel('accident/sms');
  static const double shakeThreshold = 40.0;
  static const Color _red = Color(0xFFFF263F);
  static const Color _navy = Color(0xFF10194D);

  void _openScreen(Widget page) =>
      Navigator.push(context, MaterialPageRoute(builder: (_) => page));

  void _showScreen(String title, Widget child) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => Scaffold(
          appBar: AppBar(title: Text(title)),
          body: SafeArea(child: child),
        ),
      ),
    );
  }

  DateTime? lastShakeTime;

  // Sensor data tracking for crash report
  double _lastSpeed = 0.0;
  AccelerometerEvent? _impactEvent;

  final FlutterTts _tts = FlutterTts();
  final VoiceAIHandler _voiceAI = VoiceAIHandler();
  bool _useVoiceInteraction = true; // Voice AI enabled by default

  // Edge AI for Real vs Fake accident detection
  final EdgeAIDetector _edgeAI = EdgeAIDetector();
  bool _edgeAIEnabled = true;
  bool _edgeAIInitialized = false;
  // NO FALLBACK - Only Edge AI makes decisions

  // Shake pattern detection (filters obvious shakes before Edge AI)
  final List<AccelerometerEvent> _recentImpacts = [];
  static const int _shakeWindowSize = 10; // Last 10 impacts
  static const Duration _shakeWindowDuration = Duration(seconds: 2);

  Future<void> _speak(String text) async {
    await _tts.setLanguage('en-US');
    await _tts.setPitch(1.0);
    await _tts.speak(text);
  }

  @override
  void initState() {
    super.initState();

    EmergencyContactsStore.load().then((_) => setState(() {}));
    AccidentLogStore.load().then((_) => setState(() {}));
    CrashReportStore.load().then((_) => setState(() {}));

    // Initialize Edge AI detector
    _initializeEdgeAI();

    // 🔹 Shake detection with sensor tracking + Edge AI
    accelerometerEvents.listen((AccelerometerEvent event) async {
      double acceleration = sqrt(
        (event.x * event.x) + (event.y * event.y) + (event.z * event.z),
      );

      // Feed data to Edge AI continuously (if enabled and initialized)
      if (_edgeAIEnabled && _edgeAIInitialized) {
        try {
          final reading = SensorReading(
            accX: event.x,
            accY: event.y,
            accZ: event.z,
            gyroX: 0.0, // Gyroscope data would come from gyroscopeEvents
            gyroY: 0.0,
            gyroZ: 0.0,
            timestamp: DateTime.now(),
          );
          // Add reading to buffer (doesn't trigger detection yet)
          _edgeAI.clearBuffer(); // Clear first to avoid stale data
          for (int i = 0; i < 15; i++) {
            await _edgeAI.detectAccident(reading);
          }
        } catch (e) {
          print('⚠️ Edge AI error: $e');
        }
      }

      if (acceleration > shakeThreshold) {
        final now = DateTime.now();
        if (lastShakeTime == null ||
            now.difference(lastShakeTime!) > const Duration(seconds: 5)) {
          lastShakeTime = now;
          _impactEvent = event; // Store impact data

          // ✅ ONLY Edge AI makes decisions - no fallback
          if (_edgeAIEnabled && _edgeAIInitialized) {
            // First check if it's an obvious shake pattern
            if (_isShakePattern(event, acceleration)) {
              print('🚫 Shake pattern detected - ignoring without AI analysis');
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                      '🤚 Explainable AI: Phone shake detected (${acceleration.toStringAsFixed(1)} m/s²) - Not a crash',
                    ),
                    backgroundColor: Colors.blue,
                    duration: const Duration(seconds: 2),
                  ),
                );
              }

              // Log as shake
              final log =
                  '${_now()} - Shake detected (${acceleration.toStringAsFixed(2)} m/s²), not analyzed';
              await AccidentLogStore.add(log);
              return; // Skip Edge AI analysis
            }

            // Not a shake pattern - proceed with Edge AI
            await _checkAccidentWithEdgeAI(event, acceleration);
          } else {
            // Edge AI not ready - ignore impact completely
            print(
              '⏳ Edge AI not initialized yet, ignoring impact: ${acceleration.toStringAsFixed(2)} m/s²',
            );
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(
                    '⏳ AI Loading... Impact detected (${acceleration.toStringAsFixed(1)} m/s²) but waiting for Edge AI',
                  ),
                  backgroundColor: Colors.orange,
                  duration: const Duration(seconds: 2),
                ),
              );
            }
          }
        }
      }
    });

    // Track speed continuously
    _trackSpeed();
  }

  Future<void> _initializeEdgeAI() async {
    try {
      print('🚀 Initializing Edge AI...');
      await _edgeAI.initialize();
      setState(() {
        _edgeAIInitialized = true;
      });
      print('✅ Edge AI initialized successfully!');

    } catch (e) {
      print('❌ Edge AI initialization failed: $e');
      setState(() {
        _edgeAIInitialized = false;
        _edgeAIEnabled = false; // Disable if initialization fails
      });

      // Show error notification
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              '❌ Explainable AI Failed - Accident detection DISABLED until fixed',
            ),
            backgroundColor: Colors.red,
            duration: Duration(seconds: 5),
          ),
        );
      }
    }
  }

  /// Detect if this is a phone shake pattern (not a real accident)
  /// Returns true if it looks like intentional shaking
  bool _isShakePattern(AccelerometerEvent event, double acceleration) {
    final now = DateTime.now();

    // Clean old impacts outside the time window
    _recentImpacts.removeWhere((oldEvent) {
      // Store timestamp in the event somehow - using current approach
      return _recentImpacts.length > _shakeWindowSize;
    });

    // Add current impact
    _recentImpacts.add(event);

    // Need at least 3 impacts to detect a pattern
    if (_recentImpacts.length < 3) {
      return false;
    }

    // Shake detection: multiple impacts in rapid succession with direction changes
    int directionChanges = 0;
    double totalMagnitude = 0;

    for (int i = 1; i < _recentImpacts.length; i++) {
      final prev = _recentImpacts[i - 1];
      final curr = _recentImpacts[i];

      // Check if direction changed significantly
      final dotProduct =
          (prev.x * curr.x) + (prev.y * curr.y) + (prev.z * curr.z);
      final prevMag = sqrt(prev.x * prev.x + prev.y * prev.y + prev.z * prev.z);
      final currMag = sqrt(curr.x * curr.x + curr.y * curr.y + curr.z * curr.z);

      if (prevMag > 0 && currMag > 0) {
        final cosAngle = dotProduct / (prevMag * currMag);

        // Direction change (angle > 90 degrees = opposite directions)
        if (cosAngle < 0) {
          directionChanges++;
        }
      }

      totalMagnitude += currMag;
    }

    // Shake pattern: 2+ direction changes in recent impacts
    // AND moderate average magnitude (not extremely high like a real crash)
    final avgMagnitude = totalMagnitude / _recentImpacts.length;

    if (directionChanges >= 2 && avgMagnitude < 60.0) {
      print(
        '🔍 Shake pattern detected: $directionChanges direction changes, avg ${avgMagnitude.toStringAsFixed(2)} m/s²',
      );
      _recentImpacts.clear(); // Clear buffer after detecting shake
      return true;
    }

    // Additional check: Single very high magnitude (>70) without pattern = likely real crash
    if (acceleration > 70.0 && directionChanges < 2) {
      print(
        '🔍 High single impact: ${acceleration.toStringAsFixed(2)} m/s², no shake pattern',
      );
      return false; // Not a shake, likely real impact
    }

    return false;
  }

  Future<void> _checkAccidentWithEdgeAI(
    AccelerometerEvent event,
    double acceleration,
  ) async {
    try {
      // Create sensor reading
      final reading = SensorReading(
        accX: event.x,
        accY: event.y,
        accZ: event.z,
        gyroX: 0.0, // In production, get from gyroscopeEvents
        gyroY: 0.0,
        gyroZ: 0.0,
        timestamp: DateTime.now(),
      );

      // Get prediction from Edge AI
      final result = await _edgeAI.detectAccident(reading);

      print('🤖 Edge AI Prediction: ${result.prediction}');
      print('   Confidence: ${(result.confidence * 100).toStringAsFixed(1)}%');
      print('   Explanation: ${result.explanation}');

      // Confidence threshold: Only trigger if REAL with high confidence (>75%)
      final isHighConfidenceReal =
          result.isRealAccident && result.confidence > 0.75;

      // Only trigger alert if it's a REAL accident with high confidence
      if (isHighConfidenceReal) {
        print(
          '✅ Real accident confirmed (confidence: ${(result.confidence * 100).toStringAsFixed(1)}%) - triggering alert',
        );
        _triggerAccidentAlertWithAI(event, acceleration, result);
      } else if (result.isRealAccident && result.confidence <= 0.75) {
        // Low confidence REAL = treat as FALSE ALARM
        print(
          '🚫 Low confidence detection (${(result.confidence * 100).toStringAsFixed(1)}%) - treating as false alarm',
        );
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                '⚠️ Explainable AI: Impact detected but confidence too low (${(result.confidence * 100).toStringAsFixed(0)}%)\n${result.explanation}',
              ),
              backgroundColor: Colors.orange,
              duration: const Duration(seconds: 3),
            ),
          );
        }

        // Log as low confidence
        final log =
            '${_now()} - Low confidence (${(result.confidence * 100).toStringAsFixed(1)}%) - not sending alert';
        await AccidentLogStore.add(log);
      } else {
        print('🚫 False alarm detected - no alert sent');
        // Show notification that false alarm was detected
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                '🤖 Explainable AI: False alarm detected\n${result.explanation}',
              ),
              backgroundColor: Colors.blue,
              duration: const Duration(seconds: 4),
            ),
          );
        }

        // Log as false alarm
        final log =
            '${_now()} - False alarm (Edge AI: ${(result.confidence * 100).toStringAsFixed(1)}% confidence)';
        await AccidentLogStore.add(log);
      }
    } catch (e) {
      print('❌ Edge AI prediction failed: $e');
      // NO FALLBACK - Just log the error and notify user
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              '❌ Explainable AI Error: $e\nImpact ignored for safety',
            ),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 4),
          ),
        );
      }

      // Log the error
      final log =
          '${_now()} - Edge AI error, impact ignored: ${acceleration.toStringAsFixed(2)} m/s²';
      await AccidentLogStore.add(log);
    }
  }

  Future<void> _trackSpeed() async {
    try {
      await _getCurrentPosition();
    } catch (e) {
      debugPrint('Location is not ready yet: $e');
    }
    while (mounted) {
      try {
        final pos = await _getCurrentPosition();
        _lastSpeed = pos.speed * 3.6; // Convert m/s to km/h
      } catch (e) {
        debugPrint('Location update failed: $e');
      }
      await Future.delayed(const Duration(seconds: 2));
    }
  }

  Future<Position> _getCurrentPosition() async {
    if (!await Geolocator.isLocationServiceEnabled()) {
      throw Exception(
        'Location services are turned off. Enable GPS and retry.',
      );
    }
    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }
    if (permission == LocationPermission.denied ||
        permission == LocationPermission.deniedForever) {
      throw Exception(
        'Location permission is required to find nearby hospitals.',
      );
    }
    return Geolocator.getCurrentPosition(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.high,
        timeLimit: Duration(seconds: 20),
      ),
    );
  }

  String _now() {
    return DateFormat('dd MMM yyyy, hh:mm:ss a').format(DateTime.now());
  }

  Future<String> _buildSmsBody(
    Position pos, {
    String? hospitalName,
    double? hospitalDistance,
    String? routeInfo,
    String? osmRouteLink,
  }) async {
    final maps = 'https://maps.google.com/?q=${pos.latitude},${pos.longitude}';

    String hospitalInfo = "No nearby hospital name is available.";
    if (hospitalName != null && hospitalDistance != null) {
      hospitalInfo =
          "$hospitalName\n📏 Distance: ${hospitalDistance.toStringAsFixed(2)} km";
      if (routeInfo != null) {
        hospitalInfo += "\n🚗 $routeInfo";
      }
    }

    if (hospitalName == null || hospitalDistance == null) {
      final searchUrl = Uri.https('www.google.com', '/maps/search/', {
        'api': '1',
        'query': 'hospitals near ${pos.latitude},${pos.longitude}',
      });
      hospitalInfo += '\nFind nearby hospitals: $searchUrl';
    } else if (routeInfo == null) {
      final estimatedRoadKm = hospitalDistance * 1.4;
      final estimatedMinutes = ((estimatedRoadKm / 30) * 60).ceil();
      hospitalInfo +=
          '\n🚗 ~${estimatedRoadKm.toStringAsFixed(1)} km • ETA ~$estimatedMinutes min (estimate)';
    }

    String routingSection = '';
    if (osmRouteLink != null) {
      routingSection = '\n🗺️ Directions:\n$osmRouteLink\n';
    }

    return '''
⚠ SOS!
📅 ${_now()}
📍 Accident Location:
Lat: ${pos.latitude.toStringAsFixed(5)}, Lon: ${pos.longitude.toStringAsFixed(5)}
➡ $maps

🏥 Nearest Hospital:
$hospitalInfo$routingSection
''';
  }

  Future<bool> _ensureSmsPermission() async {
    var sms = await Permission.sms.status;
    var phone = await Permission.phone.status;
    if (sms.isGranted && phone.isGranted) return true;
    if (!sms.isGranted) sms = await Permission.sms.request();
    if (!phone.isGranted) phone = await Permission.phone.request();
    return sms.isGranted && phone.isGranted;
  }

  Future<void> _sendAlertWithLocation(BuildContext context) async {
    try {
      final pos = await _getCurrentPosition();
      unawaited(
        EmergencyCorridorService.createIncident(
          latitude: pos.latitude,
          longitude: pos.longitude,
          occurredAt: DateTime.now(),
        ),
      );

      if (!await _ensureSmsPermission()) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('❌ SMS permission denied')),
        );
        return;
      }

      final contacts = EmergencyContactsStore.contacts;
      if (contacts.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('⚠ No emergency contacts added')),
        );
        return;
      }

      // Get address from coordinates
      String address = 'Address unavailable';
      try {
        List<Placemark> placemarks = await placemarkFromCoordinates(
          pos.latitude,
          pos.longitude,
        );
        if (placemarks.isNotEmpty) {
          final place = placemarks.first;
          address =
              '${place.street}, ${place.locality}, ${place.administrativeArea}, ${place.postalCode}';
        }
      } catch (e) {
        print('Error getting address: $e');
      }

      // Get smart hospital selection
      String hospitalName = "No nearby hospital found";
      double hospitalDistance = 0.0;
      double? hospitalLat;
      double? hospitalLon;
      String? routeInfo;
      String? osmRouteLink;

      try {
        final hospital = await HospitalService.getSmartHospital(
          lat: pos.latitude,
          lng: pos.longitude,
          severity: 'Moderate', // Default severity for manual alerts
        ).timeout(const Duration(seconds: 10));

        if (hospital != null) {
          hospitalName = hospital['name'];
          hospitalLat = hospital['lat'];
          hospitalLon = hospital['lon'];
          osmRouteLink = OSRMRoutingService.generateOSMRouteLink(
            startLat: pos.latitude,
            startLon: pos.longitude,
            endLat: hospitalLat!,
            endLon: hospitalLon!,
          );

          final distanceMeters = Geolocator.distanceBetween(
            pos.latitude,
            pos.longitude,
            hospital["lat"],
            hospital["lon"],
          );
          hospitalDistance = distanceMeters / 1000;

          // Calculate route with OSRM
          try {
            final route = await OSRMRoutingService.calculateRoute(
              startLat: pos.latitude,
              startLon: pos.longitude,
              endLat: hospitalLat!,
              endLon: hospitalLon!,
              timeoutPerEndpoint: const Duration(seconds: 7),
            );

            if (route != null) {
              routeInfo =
                  '${OSRMRoutingService.formatDistance(route['distance'])} • ETA ${OSRMRoutingService.formatDuration(route['duration'])}';

              // Generate OSM route link
              osmRouteLink = OSRMRoutingService.generateOSMRouteLink(
                startLat: pos.latitude,
                startLon: pos.longitude,
                endLat: hospitalLat,
                endLon: hospitalLon,
              );
            }
          } catch (e) {
            print('⚠️ OSRM route calculation failed: $e');
          }
        }
      } catch (e) {
        print('⚠️ Failed to fetch hospital info: $e');
      }

      final message = await _buildSmsBody(
        pos,
        hospitalName: hospitalName != "No nearby hospital found"
            ? hospitalName
            : null,
        hospitalDistance: hospitalDistance > 0 ? hospitalDistance : null,
        routeInfo: routeInfo,
        osmRouteLink: osmRouteLink,
      );

      for (var number in contacts) {
        final res = await _smsChannel.invokeMethod<String>('sendSMS', {
          'number': number,
          'message': message,
        });

        if (res != 'SMS_SENT' && res != 'SMS_DISPATCHED') {
          throw Exception(res ?? 'UNKNOWN');
        }
      }

      final log =
          '''
✅ ALERT:
🕒 ${_now()}
📍 Lat: ${pos.latitude.toStringAsFixed(5)}, Lon: ${pos.longitude.toStringAsFixed(5)}
Sent to: ${contacts.join(', ')}
''';

      await AccidentLogStore.add(log);

      _speak('Alert SMS sent to all contacts');

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                '🚨 Alert SMS sent to all contacts',
                style: TextStyle(color: Colors.white),
              ),
              if (routeInfo != null)
                Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Text(
                    '🏥 $hospitalName\n🚗 $routeInfo',
                    style: const TextStyle(color: Colors.white70, fontSize: 12),
                  ),
                ),
            ],
          ),
          backgroundColor: widget.isDarkMode
              ? Colors.black
              : const Color(0xFFE63946),
          duration: const Duration(seconds: 5),
          action: SnackBarAction(
            label: 'View Map',
            textColor: Colors.white,
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => AccidentMapPage(
                    accidentLat: pos.latitude,
                    accidentLon: pos.longitude,
                    hospitalName: hospitalName != "No nearby hospital found"
                        ? hospitalName
                        : null,
                    hospitalLat: hospitalLat,
                    hospitalLon: hospitalLon,
                    address: address,
                    severity: 'Moderate',
                    isDarkMode: widget.isDarkMode,
                  ),
                ),
              );
            },
          ),
        ),
      );
      setState(() {});
      if (mounted)
        _openScreen(
          EmergencyCorridorPage(
            latitude: pos.latitude,
            longitude: pos.longitude,
            isDarkMode: widget.isDarkMode,
          ),
        );
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('❌ Alert failed: $e')));
    }
  }

  Future<void> _sendAlertWithLocationAndReport(
    BuildContext context,
    AccelerometerEvent event,
    double impactForce,
  ) async {
    try {
      final pos = await _getCurrentPosition();
      unawaited(
        EmergencyCorridorService.createIncident(
          latitude: pos.latitude,
          longitude: pos.longitude,
          occurredAt: DateTime.now(),
          severity: 'Accident',
        ),
      );

      // Get address from coordinates
      String address = 'Address unavailable';
      try {
        List<Placemark> placemarks = await placemarkFromCoordinates(
          pos.latitude,
          pos.longitude,
        );
        if (placemarks.isNotEmpty) {
          final place = placemarks.first;
          address =
              '${place.street}, ${place.locality}, ${place.administrativeArea}, ${place.postalCode}';
        }
      } catch (e) {
        print('Error getting address: $e');
      }

      // Run AI severity analysis FIRST (needed for smart hospital selection)
      final analysis = AISeverityAnalyzer.analyzeSeverity(
        impactForce: impactForce,
        speedBeforeCrash: _lastSpeed,
        impactX: event.x,
        impactY: event.y,
        impactZ: event.z,
        immobilityDuration: 10, // Based on alert countdown
      );

      // Get nearest hospital (don't let this block the emergency alert)
      String hospitalName = "No nearby hospital found";
      double hospitalDistance = 0.0;
      double? hospitalLat;
      double? hospitalLon;
      String? routeInfo;

      try {
        // Use smart hospital selection based on AI severity
        final severity = analysis['severity'] ?? 'Moderate';
        final hospital = await HospitalService.getSmartHospital(
          lat: pos.latitude,
          lng: pos.longitude,
          severity: severity,
        ).timeout(const Duration(seconds: 10));

        if (hospital != null) {
          hospitalName = hospital['name'];
          hospitalLat = hospital['lat'];
          hospitalLon = hospital['lon'];

          final distanceMeters = Geolocator.distanceBetween(
            pos.latitude,
            pos.longitude,
            hospital["lat"],
            hospital["lon"],
          );
          hospitalDistance = distanceMeters / 1000;

          // Calculate route with OSRM
          try {
            final route = await OSRMRoutingService.calculateRoute(
              startLat: pos.latitude,
              startLon: pos.longitude,
              endLat: hospitalLat!,
              endLon: hospitalLon!,
              timeoutPerEndpoint: const Duration(seconds: 7),
            );

            if (route != null) {
              routeInfo =
                  '${OSRMRoutingService.formatDistance(route['distance'])} • ETA ${OSRMRoutingService.formatDuration(route['duration'])}';
            }
          } catch (e) {
            print('⚠️ OSRM route calculation failed: $e');
          }
        }
      } catch (e) {
        print('⚠️ Failed to fetch hospital info: $e');
        // Continue with alert anyway - hospital info is not critical
      }

      // Create crash report
      final crashReport = CrashReport(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        dateTime: DateTime.now(),
        latitude: pos.latitude,
        longitude: pos.longitude,
        address: address,
        nearestHospital: hospitalName,
        hospitalDistance: hospitalDistance,
        speedBeforeCrash: _lastSpeed,
        impactForce: impactForce,
        impactX: event.x,
        impactY: event.y,
        impactZ: event.z,
        immobilityDuration: 10,
        severity: analysis['severity'],
        aiConfidence: analysis['confidence'],
        severityReason: analysis['reason'],
        emergencyContacts: EmergencyContactsStore.contacts,
        alertSent: false,
        reportGenerated: false,
      );

      // Save crash report
      await CrashReportStore.add(crashReport);

      // Send SMS alerts
      if (!await _ensureSmsPermission()) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('❌ SMS permission denied')),
        );
        return;
      }

      final contacts = EmergencyContactsStore.contacts;
      if (contacts.isNotEmpty) {
        // Generate OSM route link if hospital found
        String? osmRouteLink;
        if (hospitalLat != null && hospitalLon != null) {
          osmRouteLink = OSRMRoutingService.generateOSMRouteLink(
            startLat: pos.latitude,
            startLon: pos.longitude,
            endLat: hospitalLat,
            endLon: hospitalLon,
          );
        }

        final message = await _buildSmsBody(
          pos,
          hospitalName: hospitalName != "No nearby hospital found"
              ? hospitalName
              : null,
          hospitalDistance: hospitalDistance > 0 ? hospitalDistance : null,
          routeInfo: routeInfo,
          osmRouteLink: osmRouteLink,
        );

        for (var number in contacts) {
          final res = await _smsChannel.invokeMethod<String>('sendSMS', {
            'number': number,
            'message': message,
          });

          if (res != 'SMS_SENT' && res != 'SMS_DISPATCHED') {
            throw Exception(res ?? 'UNKNOWN');
          }
        }
      }

      // Update log
      final log =
          '''
✅ ALERT & CRASH REPORT:
🕒 ${_now()}
📍 Lat: ${pos.latitude.toStringAsFixed(5)}, Lon: ${pos.longitude.toStringAsFixed(5)}
${crashReport.getSeverityEmoji()} Severity: ${crashReport.severity}
Sent to: ${contacts.join(', ')}
''';

      await AccidentLogStore.add(log);

      _speak('Alert sent! Crash report generated.');

      // Show success with map and report options
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                '🚨 Alert sent! Crash report generated.',
                style: TextStyle(color: Colors.white),
              ),
              if (routeInfo != null)
                Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Text(
                    '🏥 $hospitalName\n🚗 $routeInfo',
                    style: const TextStyle(color: Colors.white70, fontSize: 12),
                  ),
                ),
            ],
          ),
          backgroundColor: widget.isDarkMode
              ? Colors.black
              : const Color(0xFFE63946),
          duration: const Duration(seconds: 5),
          action: SnackBarAction(
            label: 'View Map',
            textColor: Colors.white,
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => AccidentMapPage(
                    accidentLat: pos.latitude,
                    accidentLon: pos.longitude,
                    hospitalName: hospitalName != "No nearby hospital found"
                        ? hospitalName
                        : null,
                    hospitalLat: hospitalLat,
                    hospitalLon: hospitalLon,
                    address: address,
                    severity: crashReport.severity,
                    isDarkMode: widget.isDarkMode,
                  ),
                ),
              );
            },
          ),
        ),
      );

      setState(() {});
      if (mounted)
        _openScreen(
          EmergencyCorridorPage(
            latitude: pos.latitude,
            longitude: pos.longitude,
            isDarkMode: widget.isDarkMode,
          ),
        );
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('❌ Alert failed: $e')));
    }
  }

  /// Traditional accident alert (NO LONGER USED for automatic detection)
  /// Only called manually for testing or from manual trigger button
  /// Edge AI is the ONLY path for accelerometer-based detection
  void _triggerAccidentAlert(
    AccelerometerEvent event,
    double impactForce,
  ) async {
    if (_useVoiceInteraction) {
      _startVoiceInteraction(event, impactForce);
    } else {
      _startManualDialog(event, impactForce);
    }
  }

  // Trigger accident alert with Edge AI result
  void _triggerAccidentAlertWithAI(
    AccelerometerEvent event,
    double impactForce,
    AccidentDetectionResult aiResult,
  ) async {
    // Show Explainable AI analysis
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            '🤖 Explainable AI: Real Accident\nConfidence: ${(aiResult.confidence * 100).toStringAsFixed(1)}%',
          ),
          backgroundColor: Colors.deepOrange,
          duration: const Duration(seconds: 2),
        ),
      );
    }

    // Proceed with normal alert flow
    if (_useVoiceInteraction) {
      _startVoiceInteraction(event, impactForce);
    } else {
      _startManualDialog(event, impactForce);
    }
  }

  // Voice AI interaction
  void _startVoiceInteraction(
    AccelerometerEvent event,
    double impactForce,
  ) async {
    bool dialogDismissed = false;
    String recognizedText = '';

    // Create a variable to hold the setState function from StatefulBuilder
    void Function(void Function())? updateDialog;

    _voiceAI.startEmergencyInteraction(
      onOkay: () {
        if (!dialogDismissed && mounted) {
          dialogDismissed = true;
          Navigator.of(context).pop();
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('✅ Alert cancelled. Stay safe!'),
              backgroundColor: Colors.green,
            ),
          );
        }
      },
      onHelp: () async {
        if (!dialogDismissed && mounted) {
          dialogDismissed = true;
          Navigator.of(context).pop();
          await _sendAlertWithLocationAndReport(context, event, impactForce);
        }
      },
      onTimeout: () async {
        if (!dialogDismissed && mounted) {
          dialogDismissed = true;
          Navigator.of(context).pop();
          await _sendAlertWithLocationAndReport(context, event, impactForce);
        }
      },
      onSpeechUpdate: (text) {
        recognizedText = text;
        // Update the dialog UI when new text is recognized
        updateDialog?.call(() {});
      },
    );

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setState) {
            // Save setState so it can be called from the callback
            updateDialog = setState;

            return AlertDialog(
              backgroundColor: widget.isDarkMode
                  ? const Color(0xFF2C2C2C)
                  : Colors.white,
              title: Text(
                '🚨 Accident Detected',
                style: TextStyle(
                  color: widget.isDarkMode ? Colors.white : Colors.black,
                ),
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    '🎤 Listening... Say YES if okay, or HELP',
                    style: TextStyle(
                      color: widget.isDarkMode
                          ? Colors.white70
                          : Colors.black87,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: widget.isDarkMode
                          ? Colors.black26
                          : Colors.grey[200],
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      recognizedText.isEmpty
                          ? 'Waiting for speech...'
                          : recognizedText,
                      style: TextStyle(
                        fontSize: 16,
                        color: widget.isDarkMode ? Colors.white : Colors.black,
                      ),
                    ),
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () {
                    if (!dialogDismissed) {
                      dialogDismissed = true;
                      _voiceAI.dispose();
                      Navigator.of(ctx).pop();
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('✅ Alert cancelled.'),
                          backgroundColor: Colors.green,
                        ),
                      );
                    }
                  },
                  child: Text(
                    "I'm OK",
                    style: TextStyle(
                      color: widget.isDarkMode ? Colors.white : Colors.black,
                    ),
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }

  // Manual button interaction (fallback)
  void _startManualDialog(AccelerometerEvent event, double impactForce) async {
    bool alertCancelled = false;

    _speak('Are you okay? Sending alert in 10 seconds.');

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) {
        Future.delayed(const Duration(seconds: 10), () async {
          if (!alertCancelled && Navigator.of(ctx).canPop()) {
            Navigator.of(ctx).pop();
            await _sendAlertWithLocationAndReport(context, event, impactForce);
          }
        });

        return AlertDialog(
          backgroundColor: widget.isDarkMode
              ? const Color(0xFF2C2C2C)
              : Colors.white,
          title: Text(
            "🚨 Accident Detected",
            style: TextStyle(
              color: widget.isDarkMode ? Colors.white : Colors.black,
            ),
          ),
          content: Text(
            "Are you okay? Sending alert in 10 seconds…",
            style: TextStyle(
              color: widget.isDarkMode ? Colors.white : Colors.black,
            ),
          ),
          actions: [
            TextButton(
              child: Text(
                "I'm OK",
                style: TextStyle(
                  color: widget.isDarkMode ? Colors.white : Colors.black,
                ),
              ),
              onPressed: () {
                alertCancelled = true;
                Navigator.of(ctx).pop();
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                      '✅ Alert cancelled.',
                      style: TextStyle(color: Colors.white),
                    ),
                    backgroundColor: widget.isDarkMode
                        ? Colors.black
                        : const Color(0xFFE63946),
                  ),
                );
              },
            ),
          ],
        );
      },
    );
  }

  void _showNearbyHospitalsPage() {
    _showScreen('Nearby Hospitals', _buildNearbyHospitalsView());
  }

  Widget _buildNearbyHospitalsView() => NearbyHospitalsView(
    isDarkMode: widget.isDarkMode,
    onNavigate: (name, lat, lon) async {
      final pos = await _getCurrentPosition();
      final placemarks = await placemarkFromCoordinates(
        pos.latitude,
        pos.longitude,
      );
      final address = placemarks.isEmpty
          ? '${pos.latitude}, ${pos.longitude}'
          : '${placemarks.first.locality ?? ''}, ${placemarks.first.country ?? ''}';
      if (!mounted) return;
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => AccidentMapPage(
            accidentLat: pos.latitude,
            accidentLon: pos.longitude,
            hospitalName: name,
            hospitalLat: lat,
            hospitalLon: lon,
            address: address,
            severity: 'Minor',
            isDarkMode: widget.isDarkMode,
          ),
        ),
      );
    },
    onLoad: () async {
      final pos = await _getCurrentPosition();
      final hospitals = await HospitalService.fetchNearbyHospitals(
        pos.latitude,
        pos.longitude,
      );
      final nearby = hospitals.map((h) => Map<String, dynamic>.from(h)).toList()
        ..sort(
          (a, b) =>
              Geolocator.distanceBetween(
                pos.latitude,
                pos.longitude,
                a['lat'] as double,
                a['lon'] as double,
              ).compareTo(
                Geolocator.distanceBetween(
                  pos.latitude,
                  pos.longitude,
                  b['lat'] as double,
                  b['lon'] as double,
                ),
              ),
        );
      return nearby
          .map<(String, double, double, double)>(
            (h) => (
              h['name'] ?? 'Unknown',
              Geolocator.distanceBetween(
                    pos.latitude,
                    pos.longitude,
                    h['lat'] as double,
                    h['lon'] as double,
                  ) /
                  1000,
              h['lat'] as double,
              h['lon'] as double,
            ),
          )
          .toList();
    },
  );

  Future<void> _showNearbyHospitals() async {
    try {
      final pos = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );
      final hospitals = await HospitalService.fetchNearbyHospitals(
        pos.latitude,
        pos.longitude,
      );

      if (hospitals.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No hospitals found nearby.')),
        );
        return;
      }

      showDialog(
        context: context,
        builder: (_) => AlertDialog(
          backgroundColor: widget.isDarkMode
              ? const Color(0xFF2C2C2C)
              : Colors.white,
          title: Text(
            'Nearby Hospitals',
            style: TextStyle(
              color: widget.isDarkMode ? Colors.white : Colors.black,
            ),
          ),
          content: SizedBox(
            width: double.maxFinite,
            child: ListView.builder(
              shrinkWrap: true,
              itemCount: hospitals.length,
              itemBuilder: (context, index) {
                final hospital = hospitals[index];
                final distanceMeters = Geolocator.distanceBetween(
                  pos.latitude,
                  pos.longitude,
                  double.parse(hospital['lat'].toString()),
                  double.parse(hospital['lon'].toString()),
                );
                final distanceKm = (distanceMeters / 1000).toStringAsFixed(2);

                return ListTile(
                  title: Text(
                    hospital['name'] ?? 'Unknown',
                    style: TextStyle(
                      color: widget.isDarkMode ? Colors.white : Colors.black,
                    ),
                  ),
                  subtitle: Text(
                    "📏 $distanceKm km",
                    style: TextStyle(
                      color: widget.isDarkMode
                          ? Colors.white70
                          : Colors.grey[700],
                    ),
                  ),
                );
              },
            ),
          ),
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error: $e')));
    }
  }

  void _showDetector() {
    _openScreen(const AccidentDetector());
  }

  Future<void> _openEmergencyCorridor() async {
    try {
      final pos = await _getCurrentPosition();
      if (!mounted) return;
      _openScreen(
        EmergencyCorridorPage(
          latitude: pos.latitude,
          longitude: pos.longitude,
          isDarkMode: widget.isDarkMode,
        ),
      );
    } catch (error) {
      if (mounted)
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not get GPS location: $error')),
        );
    }
  }

  Widget _buildHomeTab() {
    final dark = widget.isDarkMode;
    final navy = dark ? Colors.white : _navy;
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(18, 4, 18, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.fromLTRB(2, 4, 0, 16),
            child: Row(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(18),
                  child: Image.asset(
                    'assets/images/logo.png',
                    width: 62,
                    height: 62,
                    fit: BoxFit.cover,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      RichText(
                        text: TextSpan(
                          style: TextStyle(
                            fontSize: 21,
                            fontWeight: FontWeight.w900,
                            color: navy,
                            letterSpacing: -.5,
                          ),
                          children: const [
                            TextSpan(text: 'Accident '),
                            TextSpan(
                              text: 'Alert',
                              style: TextStyle(
                                color: _red,
                                fontStyle: FontStyle.italic,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        'Stay Safe  •  Detect  •  Alert  •  Save Lives',
                        style: TextStyle(
                          fontSize: 10,
                          color: dark
                              ? Colors.white70
                              : const Color(0xFF52678C),
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
                _HeaderCircleButton(
                  icon: _useVoiceInteraction
                      ? Icons.mic_rounded
                      : Icons.mic_off_rounded,
                  color: _useVoiceInteraction ? const Color(0xFF19B67A) : _red,
                  tooltip: 'Voice assistant',
                  onTap: () {
                    setState(
                      () => _useVoiceInteraction = !_useVoiceInteraction,
                    );
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(
                          _useVoiceInteraction
                              ? 'Voice assistant enabled'
                              : 'Voice assistant disabled',
                        ),
                        duration: const Duration(seconds: 1),
                      ),
                    );
                  },
                ),
                const SizedBox(width: 6),
                _HeaderCircleButton(
                  icon: dark ? Icons.wb_sunny_rounded : Icons.dark_mode_rounded,
                  color: dark ? const Color(0xFFFFC857) : _navy,
                  tooltip: dark
                      ? 'Switch to light mode'
                      : 'Switch to dark mode',
                  onTap: widget.onToggleTheme,
                ),
              ],
            ),
          ),
          _SafetyHero(isDarkMode: dark),
          const SizedBox(height: 16),
          _DetectionAction(onTap: _showDetector),
          const SizedBox(height: 11),
          Builder(
            builder: (context) {
              final screenWidth = MediaQuery.sizeOf(context).width;
              final contentWidth = screenWidth > 720 ? 680.0 : screenWidth - 36;
              final width = ((contentWidth - 10) / 2).clamp(125.0, 335.0).toDouble();
              return Align(
                alignment: Alignment.centerLeft,
                child: Wrap(
                spacing: 10,
                runSpacing: 10,
                children: [
                  _GridFeatureCard(
                    width: width,
                    icon: Icons.warning_rounded,
                    title: 'Emergency Alert',
                    subtitle: 'Notify your contacts',
                    tint: _red,
                    background: const Color(0xFFFFEEF1),
                    onTap: () => _sendAlertWithLocation(context),
                  ),
                  _GridFeatureCard(
                    width: width,
                    icon: Icons.receipt_long_rounded,
                    title: 'Logs',
                    subtitle: 'Review alert activity',
                    tint: const Color(0xFF2456A6),
                    background: const Color(0xFFE8F3FF),
                    onTap: () =>
                        _showScreen('Accident Logs', LogPage(isDarkMode: dark)),
                  ),
                  _GridFeatureCard(
                    width: width,
                    icon: Icons.groups_rounded,
                    title: 'Emergency Contacts',
                    subtitle: 'Manage saved contacts',
                    tint: _homeGreen,
                    background: const Color(0xFFE2F8EF),
                    onTap: () => _showScreen(
                      'Emergency Contacts',
                      ManageContactsPage(isDarkMode: dark),
                    ),
                  ),
                  _GridFeatureCard(
                    width: width,
                    icon: Icons.local_hospital_rounded,
                    title: 'Nearby Hospitals',
                    subtitle: 'Find medical help',
                    tint: const Color(0xFFF07932),
                    background: const Color(0xFFFFF0E5),
                    onTap: _showNearbyHospitalsPage,
                  ),
                ],
                ),
              );
            },
          ),
          const SizedBox(height: 12),
          _CorridorFeatureCard(onTap: _openEmergencyCorridor),
          const SizedBox(height: 10),
          _ReferenceFeatureCard(
            icon: Icons.analytics_rounded,
            title: 'Crash Reports (AI)',
            subtitle: 'View AI-generated crash insights.',
            tint: _red,
            iconBackground: const Color(0xFFFFEEF1),
            artwork: Icons.bar_chart_rounded,
            onTap: () => _showScreen(
              'AI Crash Reports',
              CrashReportsPage(isDarkMode: dark),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) =>
      Scaffold(body: SafeArea(child: _buildHomeTab()));
}

const _homeRed = Color(0xFFFF263F);
const _homeNavy = Color(0xFF10194D);
const _homeGreen = Color(0xFF12A875);

class _HeaderCircleButton extends StatelessWidget {
  const _HeaderCircleButton({
    required this.icon,
    required this.color,
    required this.tooltip,
    required this.onTap,
  });
  final IconData icon;
  final Color color;
  final String tooltip;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) => Material(
    color: Theme.of(context).colorScheme.surface,
    shape: const CircleBorder(),
    elevation: 1,
    child: IconButton(
      onPressed: onTap,
      tooltip: tooltip,
      icon: Icon(icon, color: color, size: 22),
    ),
  );
}

class _SafetyHero extends StatelessWidget {
  const _SafetyHero({required this.isDarkMode});
  final bool isDarkMode;
  @override
  Widget build(BuildContext context) {
    final fg = isDarkMode ? Colors.white : _homeNavy;
    return Container(
      height: 255,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(27),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: isDarkMode
              ? const [Color(0xFF142E5C), Color(0xFF07162F)]
              : const [Color(0xFFDFF1FF), Color(0xFFF6FBFF)],
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF2456A6).withValues(alpha: .15),
            blurRadius: 18,
            offset: const Offset(0, 7),
          ),
        ],
      ),
      child: Stack(
        children: [
          Positioned.fill(
            child: CustomPaint(painter: _HomeCityPainter(dark: isDarkMode)),
          ),
          Positioned.fill(
            child: CustomPaint(painter: _HomeRoadPainter(dark: isDarkMode)),
          ),
          Positioned(
            right: 14,
            top: 44,
            child: Icon(
              Icons.location_on_rounded,
              color: _homeRed.withValues(alpha: .85),
              size: 32,
            ),
          ),
          Positioned(
            right: 4,
            bottom: 39,
            child: CustomPaint(
              size: const Size(165, 118),
              painter: _HomeAmbulancePainter(dark: isDarkMode),
            ),
          ),
          Positioned(
            left: 18,
            top: 22,
            width: 185,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text.rich(
                  TextSpan(
                    style: TextStyle(
                      color: fg,
                      fontSize: 25,
                      height: 1.02,
                      fontWeight: FontWeight.w900,
                    ),
                    children: const [
                      TextSpan(text: 'Your Safety\n'),
                      TextSpan(
                        text: 'Comes First',
                        style: TextStyle(color: _homeRed),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  'Detect accidents early.\nGet help instantly.\nSave lives together.',
                  style: TextStyle(
                    color: isDarkMode
                        ? Colors.white70
                        : const Color(0xFF35547E),
                    fontSize: 12,
                    height: 1.55,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
          Positioned(
            left: 10,
            right: 10,
            bottom: 10,
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 10),
              decoration: BoxDecoration(
                color: isDarkMode
                    ? const Color(0xFF0A1A38).withValues(alpha: .88)
                    : Colors.white.withValues(alpha: .88),
                borderRadius: BorderRadius.circular(17),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  const _HeroBenefit(
                    icon: Icons.verified_user_rounded,
                    label: 'Stay Safe',
                    color: Color(0xFF2456A6),
                  ),
                  const _HeroBenefit(
                    icon: Icons.monitor_heart_rounded,
                    label: 'Get Help',
                    color: _homeRed,
                  ),
                  const _HeroBenefit(
                    icon: Icons.groups_rounded,
                    label: 'Save Lives',
                    color: Color(0xFF2456A6),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _HeroBenefit extends StatelessWidget {
  const _HeroBenefit({
    required this.icon,
    required this.label,
    required this.color,
  });
  final IconData icon;
  final String label;
  final Color color;
  @override
  Widget build(BuildContext context) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      Icon(icon, size: 17, color: color),
      const SizedBox(width: 5),
      Text(
        label,
        style: TextStyle(
          color: Theme.of(context).colorScheme.onSurface,
          fontSize: 10,
          fontWeight: FontWeight.w700,
        ),
      ),
    ],
  );
}

class _HomeCityPainter extends CustomPainter {
  const _HomeCityPainter({required this.dark});
  final bool dark;

  @override
  void paint(Canvas canvas, Size size) {
    final base = dark ? const Color(0xFF3F75B7) : const Color(0xFF82B7E8);
    final buildings = <Rect>[
      Rect.fromLTWH(size.width * .60, size.height * .23, 29, size.height * .45),
      Rect.fromLTWH(size.width * .69, size.height * .10, 38, size.height * .60),
      Rect.fromLTWH(size.width * .81, size.height * .30, 28, size.height * .40),
      Rect.fromLTWH(size.width * .90, size.height * .17, 44, size.height * .56),
    ];
    final fill = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [base.withValues(alpha: .10), base.withValues(alpha: .20)],
      ).createShader(Offset.zero & size);
    for (var i = 0; i < buildings.length; i++) {
      final rect = buildings[i];
      canvas.drawRRect(
        RRect.fromRectAndRadius(rect, const Radius.circular(4)),
        fill,
      );
      final window = Paint()
        ..color = (dark ? const Color(0xFF87C8FF) : Colors.white)
            .withValues(alpha: dark ? .26 : .58);
      for (double x = rect.left + 6; x < rect.right - 4; x += 11) {
        for (double y = rect.top + 10; y < rect.bottom - 6; y += 15) {
          canvas.drawRRect(
            RRect.fromRectAndRadius(
              Rect.fromLTWH(x, y, 4, 6),
              const Radius.circular(1),
            ),
            window,
          );
        }
      }
    }
  }

  @override
  bool shouldRepaint(covariant _HomeCityPainter oldDelegate) =>
      dark != oldDelegate.dark;
}

class _HomeAmbulancePainter extends CustomPainter {
  const _HomeAmbulancePainter({required this.dark});
  final bool dark;

  @override
  void paint(Canvas canvas, Size size) {
    final scale = size.width / 165;
    canvas.save();
    canvas.scale(scale);
    final glow = Paint()
      ..color = _homeRed.withValues(alpha: dark ? .25 : .15)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 15);
    canvas.drawOval(const Rect.fromLTWH(13, 83, 139, 24), glow);

    final body = Path()
      ..moveTo(15, 51)
      ..quadraticBezierTo(15, 43, 23, 43)
      ..lineTo(94, 43)
      ..lineTo(116, 55)
      ..lineTo(143, 57)
      ..quadraticBezierTo(151, 58, 153, 68)
      ..lineTo(153, 85)
      ..lineTo(14, 85)
      ..close();
    final bodyPaint = Paint()
      ..shader = const LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [Colors.white, Color(0xFFE7F1FC), Color(0xFFC9D9EA)],
      ).createShader(const Rect.fromLTWH(14, 43, 140, 43));
    canvas.drawShadow(body, Colors.black.withValues(alpha: .22), 7, true);
    canvas.drawPath(body, bodyPaint);
    canvas.drawPath(
      body,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.2
        ..color = const Color(0xFF7891AD),
    );

    final glass = Paint()
      ..shader = const LinearGradient(
        colors: [Color(0xFF173C68), Color(0xFF4C8FC8)],
      ).createShader(const Rect.fromLTWH(99, 48, 43, 23));
    final window = Path()
      ..moveTo(101, 48)
      ..lineTo(115, 48)
      ..lineTo(127, 57)
      ..lineTo(138, 58)
      ..lineTo(140, 69)
      ..lineTo(101, 69)
      ..close();
    canvas.drawPath(window, glass);
    canvas.drawPath(
      window,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1
        ..color = Colors.white.withValues(alpha: .7),
    );

    canvas.drawRect(
      const Rect.fromLTWH(18, 72, 133, 7),
      Paint()..color = _homeRed,
    );
    canvas.drawRect(
      const Rect.fromLTWH(21, 73, 127, 1.5),
      Paint()..color = Colors.white.withValues(alpha: .75),
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        const Rect.fromLTWH(57, 49, 25, 20),
        const Radius.circular(3),
      ),
      Paint()..color = const Color(0xFFDCEBFA),
    );
    final cross = Paint()
      ..color = _homeRed
      ..strokeWidth = 5
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(const Offset(69, 53), const Offset(69, 65), cross);
    canvas.drawLine(const Offset(63, 59), const Offset(75, 59), cross);

    for (final x in [43.0, 124.0]) {
      canvas.drawCircle(Offset(x, 84), 12, Paint()..color = const Color(0xFF18243C));
      canvas.drawCircle(Offset(x, 84), 6, Paint()..color = const Color(0xFF9FB2C9));
      canvas.drawCircle(Offset(x - 2, 82), 2, Paint()..color = Colors.white70);
    }
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        const Rect.fromLTWH(126, 62, 12, 6),
        const Radius.circular(2),
      ),
      Paint()..color = const Color(0xFFFFD56B),
    );
    canvas.drawCircle(const Offset(80, 41), 5, Paint()..color = _homeRed);
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        const Rect.fromLTWH(69, 35, 22, 6),
        const Radius.circular(3),
      ),
      Paint()..color = const Color(0xFFFF6878),
    );
    canvas.drawCircle(const Offset(80, 38), 5, Paint()..color = Colors.white.withValues(alpha: .5));
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _HomeAmbulancePainter oldDelegate) =>
      dark != oldDelegate.dark;
}

class _HomeRoadPainter extends CustomPainter {
  _HomeRoadPainter({required this.dark});
  final bool dark;
  @override
  void paint(Canvas canvas, Size size) {
    final road = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 25
      ..strokeCap = StrokeCap.round
      ..color = (dark ? const Color(0xFF588FC7) : const Color(0xFF9BCBF4))
          .withValues(alpha: .35);
    final path = Path()
      ..moveTo(size.width + 10, size.height * .62)
      ..cubicTo(
        size.width * .55,
        size.height * .42,
        size.width * .8,
        size.height * .97,
        size.width * .18,
        size.height * .92,
      );
    canvas.drawPath(path, road);
    canvas.drawPath(
      path,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2
        ..color = Colors.white.withValues(alpha: .75),
    );
  }

  @override
  bool shouldRepaint(covariant _HomeRoadPainter oldDelegate) =>
      dark != oldDelegate.dark;
}

class _DetectionAction extends StatefulWidget {
  const _DetectionAction({required this.onTap});
  final VoidCallback onTap;
  @override
  State<_DetectionAction> createState() => _DetectionActionState();
}

class _DetectionActionState extends State<_DetectionAction>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1500),
  )..repeat(reverse: true);
  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Material(
    color: Colors.transparent,
    borderRadius: BorderRadius.circular(25),
    clipBehavior: Clip.antiAlias,
    child: InkWell(
      onTap: widget.onTap,
      borderRadius: BorderRadius.circular(25),
      child: Ink(
        height: 112,
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFFFF4056), Color(0xFFFF263F), Color(0xFFE91E3A)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(25),
          boxShadow: [
            BoxShadow(
              color: _homeRed.withValues(alpha: .25),
              blurRadius: 17,
              offset: const Offset(0, 7),
            ),
          ],
        ),
        child: Row(
          children: [
            const SizedBox(width: 14),
            AnimatedBuilder(
              animation: _controller,
              builder: (context, _) => Container(
                width: 70,
                height: 70,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: Colors.white.withValues(alpha: .3),
                    width: 3 + _controller.value * 5,
                  ),
                ),
                child: const Center(
                  child: CircleAvatar(
                    radius: 24,
                    backgroundColor: Color(0x44FFFFFF),
                    child: Icon(
                      Icons.play_arrow_rounded,
                      color: Colors.white,
                      size: 35,
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 14),
            const Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Start Detection',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w900,
                      fontSize: 18,
                    ),
                  ),
                  SizedBox(height: 5),
                  Text(
                    'Monitor sensors for an accident',
                    style: TextStyle(color: Colors.white, fontSize: 11),
                  ),
                ],
              ),
            ),
            const Icon(
              Icons.monitor_heart_rounded,
              color: Color(0xBBFFFFFF),
              size: 30,
            ),
            const SizedBox(width: 5),
            const Icon(
              Icons.chevron_right_rounded,
              color: Colors.white,
              size: 30,
            ),
            const SizedBox(width: 8),
          ],
        ),
      ),
    ),
  );
}

class _GridFeatureCard extends StatelessWidget {
  const _GridFeatureCard({
    required this.width,
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.tint,
    required this.background,
    required this.onTap,
  });
  final double width;
  final IconData icon;
  final String title, subtitle;
  final Color tint, background;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) => Material(
    color: Theme.of(context).cardColor,
    borderRadius: BorderRadius.circular(22),
    elevation: 1.5,
    shadowColor: const Color(0xFF24466E).withValues(alpha: .1),
    child: InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(22),
      child: SizedBox(
        width: width,
        height: 132,
        child: Stack(
          children: [
            Positioned(
              right: 5,
              bottom: 2,
              child: Icon(icon, size: 58, color: tint.withValues(alpha: .055)),
            ),
            Padding(
              padding: const EdgeInsets.all(13),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 43,
                        height: 43,
                        decoration: BoxDecoration(
                          color: background,
                          borderRadius: BorderRadius.circular(15),
                        ),
                        child: Icon(icon, color: tint, size: 24),
                      ),
                      const Spacer(),
                      Icon(Icons.arrow_forward_rounded, color: tint, size: 18),
                    ],
                  ),
                  const Spacer(),
                  Text(
                    title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.onSurface,
                      fontWeight: FontWeight.w900,
                      fontSize: 12,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    subtitle,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                      fontSize: 10,
                      height: 1.25,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

class _ReferenceFeatureCard extends StatelessWidget {
  const _ReferenceFeatureCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.tint,
    required this.iconBackground,
    required this.artwork,
    required this.onTap,
  });
  final IconData icon, artwork;
  final String title, subtitle;
  final Color tint, iconBackground;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) => Material(
    color: Theme.of(context).cardColor,
    borderRadius: BorderRadius.circular(23),
    elevation: 1,
    child: InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(23),
      child: SizedBox(
        height: 82,
        child: Stack(
          children: [
            Positioned(
              right: 40,
              bottom: -18,
              child: Icon(
                artwork,
                size: 80,
                color: const Color(0xFF8CBFEF).withValues(alpha: .08),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 13),
              child: Row(
                children: [
                  Container(
                    width: 55,
                    height: 55,
                    decoration: BoxDecoration(
                      color: iconBackground,
                      borderRadius: BorderRadius.circular(18),
                    ),
                    child: Icon(icon, color: tint, size: 28),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          title,
                          style: TextStyle(
                            color: Theme.of(context).colorScheme.onSurface,
                            fontWeight: FontWeight.w900,
                            fontSize: 14,
                          ),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          subtitle,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: Theme.of(
                              context,
                            ).colorScheme.onSurfaceVariant,
                            fontSize: 10,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Icon(Icons.chevron_right_rounded, color: tint, size: 27),
                ],
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

class _CorridorFeatureCard extends StatelessWidget {
  const _CorridorFeatureCard({required this.onTap});
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) => Material(
    color: Colors.transparent,
    borderRadius: BorderRadius.circular(25),
    clipBehavior: Clip.antiAlias,
    child: InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(25),
      child: Ink(
        height: 172,
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFFDDF0FF), Color(0xFFB5D9FB), Color(0xFFEAF6FF)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(25),
          border: Border.all(color: Colors.white, width: 1.5),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF2456A6).withValues(alpha: .12),
              blurRadius: 15,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Stack(
          children: [
            Positioned.fill(child: CustomPaint(painter: _CorridorArtPainter())),
            Positioned(
              left: 14,
              top: 16,
              width: 220,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Smart Emergency Corridor',
                    style: TextStyle(
                      color: _homeNavy,
                      fontSize: 15,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 6),
                  const Text(
                    'Coordinate ambulance routes\nand traffic priority',
                    style: TextStyle(
                      color: Color(0xFF315C91),
                      fontSize: 11,
                      height: 1.35,
                    ),
                  ),
                  const SizedBox(height: 12),
                  FilledButton.icon(
                    onPressed: onTap,
                    icon: const Icon(Icons.alt_route_rounded, size: 16),
                    label: const Text(
                      'View Corridor',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    style: FilledButton.styleFrom(
                      backgroundColor: _homeRed,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 10,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(15),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Positioned(
              right: 4,
              bottom: 5,
              child: CustomPaint(
                size: const Size(155, 112),
                painter: const _HomeAmbulancePainter(dark: false),
              ),
            ),
            Positioned(
              right: 99,
              top: 17,
              child: Icon(
                Icons.location_on_rounded,
                color: _homeRed.withValues(alpha: .85),
                size: 27,
              ),
            ),
            Positioned(
              right: 13,
              top: 42,
              child: const Icon(
                Icons.traffic_rounded,
                color: Color(0xFF168A67),
                size: 24,
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

class _CorridorArtPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final skylineColor = const Color(0xFF5893CE).withValues(alpha: .16);
    final skyline = <Rect>[
      Rect.fromLTWH(size.width * .58, size.height * .38, 20, size.height * .32),
      Rect.fromLTWH(size.width * .66, size.height * .23, 28, size.height * .47),
      Rect.fromLTWH(size.width * .77, size.height * .31, 21, size.height * .39),
      Rect.fromLTWH(size.width * .86, size.height * .14, 34, size.height * .56),
      Rect.fromLTWH(size.width * .96, size.height * .29, 29, size.height * .41),
    ];
    final buildingPaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          const Color(0xFF9CCDF4).withValues(alpha: .12),
          skylineColor,
        ],
      ).createShader(Offset.zero & size);
    for (final building in skyline) {
      canvas.drawRRect(
        RRect.fromRectAndRadius(building, const Radius.circular(3)),
        buildingPaint,
      );
      for (double y = building.top + 8; y < building.bottom - 5; y += 13) {
        canvas.drawRect(
          Rect.fromLTWH(building.left + 5, y, 3, 5),
          Paint()..color = Colors.white.withValues(alpha: .48),
        );
        canvas.drawRect(
          Rect.fromLTWH(building.left + 12, y, 3, 5),
          Paint()..color = Colors.white.withValues(alpha: .38),
        );
      }
    }

    final road = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 22
      ..strokeCap = StrokeCap.round
      ..color = const Color(0xFF537FAF).withValues(alpha: .5);
    final path = Path()
      ..moveTo(size.width + 10, size.height + 15)
      ..cubicTo(
        size.width * .74,
        size.height * .57,
        size.width * .48,
        size.height * .95,
        size.width * .36,
        size.height * .56,
      )
      ..cubicTo(
        size.width * .28,
        size.height * .3,
        size.width * .58,
        size.height * .35,
        size.width * .53,
        size.height + 10,
      );
    canvas.drawPath(path, road);
    canvas.drawPath(
      path,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2
        ..color = Colors.white,
    );
    final route = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3
      ..strokeCap = StrokeCap.round
      ..color = _homeRed;
    canvas.drawPath(path, route);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

