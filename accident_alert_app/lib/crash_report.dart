import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

/// Comprehensive crash report data model
class CrashReport {
  final String id;
  final DateTime dateTime;

  // Location Data
  final double latitude;
  final double longitude;
  final String address;
  final String nearestHospital;
  final double hospitalDistance; // in km

  // Sensor Data
  final double speedBeforeCrash; // km/h
  final double impactForce; // acceleration magnitude
  final double impactX;
  final double impactY;
  final double impactZ;
  final int immobilityDuration; // seconds

  // AI Analysis
  final String severity; // Minor, Moderate, Severe, Critical
  final double aiConfidence; // 0.0 to 1.0
  final String severityReason;

  // User Data
  final String userName;
  final String vehicleType;
  final List<String> emergencyContacts;

  // Status
  final bool alertSent;
  final bool reportGenerated;

  CrashReport({
    required this.id,
    required this.dateTime,
    required this.latitude,
    required this.longitude,
    required this.address,
    required this.nearestHospital,
    required this.hospitalDistance,
    required this.speedBeforeCrash,
    required this.impactForce,
    required this.impactX,
    required this.impactY,
    required this.impactZ,
    required this.immobilityDuration,
    required this.severity,
    required this.aiConfidence,
    required this.severityReason,
    this.userName = 'User',
    this.vehicleType = 'Unknown',
    required this.emergencyContacts,
    this.alertSent = false,
    this.reportGenerated = false,
  });

  /// Convert to JSON
  Map<String, dynamic> toJson() => {
    'id': id,
    'dateTime': dateTime.toIso8601String(),
    'latitude': latitude,
    'longitude': longitude,
    'address': address,
    'nearestHospital': nearestHospital,
    'hospitalDistance': hospitalDistance,
    'speedBeforeCrash': speedBeforeCrash,
    'impactForce': impactForce,
    'impactX': impactX,
    'impactY': impactY,
    'impactZ': impactZ,
    'immobilityDuration': immobilityDuration,
    'severity': severity,
    'aiConfidence': aiConfidence,
    'severityReason': severityReason,
    'userName': userName,
    'vehicleType': vehicleType,
    'emergencyContacts': emergencyContacts,
    'alertSent': alertSent,
    'reportGenerated': reportGenerated,
  };

  /// Create from JSON
  factory CrashReport.fromJson(Map<String, dynamic> json) => CrashReport(
    id: json['id'],
    dateTime: DateTime.parse(json['dateTime']),
    latitude: json['latitude'],
    longitude: json['longitude'],
    address: json['address'],
    nearestHospital: json['nearestHospital'],
    hospitalDistance: json['hospitalDistance'],
    speedBeforeCrash: json['speedBeforeCrash'],
    impactForce: json['impactForce'],
    impactX: json['impactX'],
    impactY: json['impactY'],
    impactZ: json['impactZ'],
    immobilityDuration: json['immobilityDuration'],
    severity: json['severity'],
    aiConfidence: json['aiConfidence'],
    severityReason: json['severityReason'],
    userName: json['userName'] ?? 'User',
    vehicleType: json['vehicleType'] ?? 'Unknown',
    emergencyContacts: List<String>.from(json['emergencyContacts']),
    alertSent: json['alertSent'] ?? false,
    reportGenerated: json['reportGenerated'] ?? false,
  );

  /// Get severity color for UI
  String getSeverityEmoji() {
    switch (severity) {
      case 'Minor':
        return '🟡';
      case 'Moderate':
        return '🟠';
      case 'Severe':
        return '🔴';
      case 'Critical':
        return '🚨';
      default:
        return '⚪';
    }
  }
}

/// Store and retrieve crash reports
class CrashReportStore {
  static const String _key = 'crash_reports';
  static List<CrashReport> _reports = [];

  static List<CrashReport> get reports => _reports;

  /// Load all reports from storage
  static Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    final data = prefs.getStringList(_key) ?? [];
    _reports = data.map((str) {
      final json = jsonDecode(str);
      return CrashReport.fromJson(json);
    }).toList();
  }

  /// Save a new report
  static Future<void> add(CrashReport report) async {
    _reports.insert(0, report); // newest first
    await _save();
  }

  /// Save all reports to storage
  static Future<void> _save() async {
    final prefs = await SharedPreferences.getInstance();
    final data = _reports.map((r) => jsonEncode(r.toJson())).toList();
    await prefs.setStringList(_key, data);
  }

  /// Clear all reports
  static Future<void> clear() async {
    _reports.clear();
    await _save();
  }

  /// Get report by ID
  static CrashReport? getById(String id) {
    try {
      return _reports.firstWhere((r) => r.id == id);
    } catch (e) {
      return null;
    }
  }
}
