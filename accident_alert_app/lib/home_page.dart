import 'dart:math';
import 'package:flutter/material.dart';
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
                      '🤚 Phone shake detected (${acceleration.toStringAsFixed(1)} m/s²) - Not a crash',
                    ),
                    backgroundColor: Colors.blue,
                    duration: const Duration(seconds: 2),
                  ),
                );
              }
              
              // Log as shake
              final log = '${_now()} - Shake detected (${acceleration.toStringAsFixed(2)} m/s²), not analyzed';
              await AccidentLogStore.add(log);
              return; // Skip Edge AI analysis
            }
            
            // Not a shake pattern - proceed with Edge AI
            await _checkAccidentWithEdgeAI(event, acceleration);
          } else {
            // Edge AI not ready - ignore impact completely
            print('⏳ Edge AI not initialized yet, ignoring impact: ${acceleration.toStringAsFixed(2)} m/s²');
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
      
      // Show success notification
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('🤖 Edge AI Ready - Smart accident detection enabled'),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 3),
          ),
        );
      }
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
            content: Text('❌ Edge AI Failed - Accident detection DISABLED until fixed'),
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
      final dotProduct = (prev.x * curr.x) + (prev.y * curr.y) + (prev.z * curr.z);
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
      print('🔍 Shake pattern detected: $directionChanges direction changes, avg ${avgMagnitude.toStringAsFixed(2)} m/s²');
      _recentImpacts.clear(); // Clear buffer after detecting shake
      return true;
    }
    
    // Additional check: Single very high magnitude (>70) without pattern = likely real crash
    if (acceleration > 70.0 && directionChanges < 2) {
      print('🔍 High single impact: ${acceleration.toStringAsFixed(2)} m/s², no shake pattern');
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
      final isHighConfidenceReal = result.isRealAccident && result.confidence > 0.75;

      // Only trigger alert if it's a REAL accident with high confidence
      if (isHighConfidenceReal) {
        print('✅ Real accident confirmed (confidence: ${(result.confidence * 100).toStringAsFixed(1)}%) - triggering alert');
        _triggerAccidentAlertWithAI(event, acceleration, result);
      } else if (result.isRealAccident && result.confidence <= 0.75) {
        // Low confidence REAL = treat as FALSE ALARM
        print('🚫 Low confidence detection (${(result.confidence * 100).toStringAsFixed(1)}%) - treating as false alarm');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                '⚠️ Impact detected but confidence too low (${(result.confidence * 100).toStringAsFixed(0)}%)\n${result.explanation}',
              ),
              backgroundColor: Colors.orange,
              duration: const Duration(seconds: 3),
            ),
          );
        }

        // Log as low confidence
        final log = '${_now()} - Low confidence (${(result.confidence * 100).toStringAsFixed(1)}%) - not sending alert';
        await AccidentLogStore.add(log);
      } else {
        print('🚫 False alarm detected - no alert sent');
        // Show notification that false alarm was detected
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                '🤖 Edge AI: False alarm detected\n${result.explanation}',
              ),
              backgroundColor: Colors.blue,
              duration: const Duration(seconds: 4),
            ),
          );
        }

        // Log as false alarm
        final log = '${_now()} - False alarm (Edge AI: ${(result.confidence * 100).toStringAsFixed(1)}% confidence)';
        await AccidentLogStore.add(log);
      }
    } catch (e) {
      print('❌ Edge AI prediction failed: $e');
      // NO FALLBACK - Just log the error and notify user
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('❌ Edge AI Error: $e\nImpact ignored for safety'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 4),
          ),
        );
      }
      
      // Log the error
      final log = '${_now()} - Edge AI error, impact ignored: ${acceleration.toStringAsFixed(2)} m/s²';
      await AccidentLogStore.add(log);
    }
  }

  Future<void> _trackSpeed() async {
    while (mounted) {
      try {
        final pos = await Geolocator.getCurrentPosition();
        _lastSpeed = pos.speed * 3.6; // Convert m/s to km/h
      } catch (e) {
        // Ignore errors
      }
      await Future.delayed(const Duration(seconds: 2));
    }
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

    String hospitalInfo = "No nearby hospital found.";
    if (hospitalName != null && hospitalDistance != null) {
      hospitalInfo = "$hospitalName\n📏 Distance: ${hospitalDistance.toStringAsFixed(2)} km";
      if (routeInfo != null) {
        hospitalInfo += "\n🚗 $routeInfo";
      }
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
      final pos = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
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
        );

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
            );
            
            if (route != null) {
              routeInfo = '${OSRMRoutingService.formatDistance(route['distance'])} • ETA ${OSRMRoutingService.formatDuration(route['duration'])}';
              
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
        hospitalName: hospitalName != "No nearby hospital found" ? hospitalName : null,
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
                    hospitalName: hospitalName != "No nearby hospital found" ? hospitalName : null,
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
      final pos = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
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
        );

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
            );
            
            if (route != null) {
              routeInfo = '${OSRMRoutingService.formatDistance(route['distance'])} • ETA ${OSRMRoutingService.formatDuration(route['duration'])}';
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
          hospitalName: hospitalName != "No nearby hospital found" ? hospitalName : null,
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
                    hospitalName: hospitalName != "No nearby hospital found" ? hospitalName : null,
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
    // Show Edge AI analysis
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            '🤖 Edge AI: Real Accident\nConfidence: ${(aiResult.confidence * 100).toStringAsFixed(1)}%',
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
                      color: widget.isDarkMode ? Colors.white70 : Colors.black87,
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
  void _startManualDialog(
    AccelerometerEvent event,
    double impactForce,
  ) async {
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Accident Alert App'),
        centerTitle: true,
        actions: [
          IconButton(
            icon: Icon(
              _useVoiceInteraction ? Icons.mic : Icons.mic_off,
              color: _useVoiceInteraction ? Colors.green : Colors.red,
            ),
            tooltip: _useVoiceInteraction
                ? "Voice AI: ON (tap to disable)"
                : "Voice AI: OFF (tap to enable)",
            onPressed: () {
              setState(() {
                _useVoiceInteraction = !_useVoiceInteraction;
              });
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(
                    _useVoiceInteraction
                        ? '🎤 Voice AI enabled'
                        : '🔇 Voice AI disabled',
                  ),
                  duration: const Duration(seconds: 1),
                ),
              );
            },
          ),
          IconButton(
            icon: Icon(widget.isDarkMode ? Icons.dark_mode : Icons.light_mode),
            tooltip: widget.isDarkMode
                ? "Switch to Light Mode"
                : "Switch to Dark Mode",
            onPressed: widget.onToggleTheme,
          ),
        ],
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.start,
            children: [
              Image.asset('assets/images/logo.png', height: 300, width: 300),
              const SizedBox(height: 10),

              ElevatedButton.icon(
                icon: const Icon(Icons.sensors),
                label: const Text('Start Detection'),
                style: ElevatedButton.styleFrom(
                  minimumSize: const Size.fromHeight(50),
                ),
                onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const AccidentDetector()),
                ),
              ),
              const SizedBox(height: 16),
              ElevatedButton.icon(
                icon: const Icon(Icons.warning),
                label: const Text('Send Alert'),
                style: ElevatedButton.styleFrom(
                  minimumSize: const Size.fromHeight(50),
                ),
                onPressed: () => _sendAlertWithLocation(context),
              ),
              const SizedBox(height: 16),
              ElevatedButton.icon(
                icon: const Icon(Icons.list),
                label: const Text('View Logs'),
                style: ElevatedButton.styleFrom(
                  minimumSize: const Size.fromHeight(50),
                ),
                onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => LogPage(
                      isDarkMode:
                          widget.isDarkMode, // Pass the dark mode to LogPage
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              ElevatedButton.icon(
                icon: const Icon(Icons.contacts),
                label: const Text('Emergency Contacts'),
                style: ElevatedButton.styleFrom(
                  minimumSize: const Size.fromHeight(50),
                ),
                onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => ManageContactsPage(
                      isDarkMode: widget.isDarkMode, // Pass dark mode here
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              ElevatedButton.icon(
                icon: const Icon(Icons.local_hospital),
                label: const Text('Nearby Hospitals'),
                style: ElevatedButton.styleFrom(
                  minimumSize: const Size.fromHeight(50),
                ),
                onPressed: _showNearbyHospitals,
              ),
              const SizedBox(height: 16),
              ElevatedButton.icon(
                icon: const Icon(Icons.description),
                label: const Text('📝 Crash Reports (AI)'),
                style: ElevatedButton.styleFrom(
                  minimumSize: const Size.fromHeight(50),
                  backgroundColor: widget.isDarkMode
                      ? const Color(0xFF2C5F2D)
                      : const Color(0xFF4CAF50),
                ),
                onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) =>
                        CrashReportsPage(isDarkMode: widget.isDarkMode),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
