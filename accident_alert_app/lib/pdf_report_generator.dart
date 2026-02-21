import 'dart:io';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets' as pw;
import 'package:printing/printing.dart';
import 'package:path_provider/path_provider.dart';
import 'package:intl/intl.dart';
import 'crash_report.dart';
import 'ai_severity_analyzer.dart';

/// PDF Report Generator for crash incidents
class PDFReportGenerator {
  /// Generate comprehensive PDF report
  static Future<File> generateReport(CrashReport report) async {
    final pdf = pw.Document();

    // Add pages to PDF
    pdf.addPage(_buildCoverPage(report));
    pdf.addPage(_buildDetailsPage(report));
    pdf.addPage(_buildSensorDataPage(report));
    pdf.addPage(_buildRecommendationsPage(report));

    // Save to file
    final output = await _getOutputFile(report.id);
    await output.writeAsBytes(await pdf.save());

    return output;
  }

  /// Cover page with summary
  static pw.Page _buildCoverPage(CrashReport report) {
    return pw.Page(
      pageFormat: PdfPageFormat.a4,
      build: (context) {
        return pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            // Header
            pw.Container(
              padding: const pw.EdgeInsets.all(20),
              color: _getSeverityColor(report.severity),
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Text(
                    '🚨 ACCIDENT CRASH REPORT',
                    style: pw.TextStyle(
                      fontSize: 28,
                      fontWeight: pw.FontWeight.bold,
                      color: PdfColors.white,
                    ),
                  ),
                  pw.SizedBox(height: 10),
                  pw.Text(
                    'AI-Generated Incident Report',
                    style: const pw.TextStyle(
                      fontSize: 14,
                      color: PdfColors.white,
                    ),
                  ),
                ],
              ),
            ),

            pw.SizedBox(height: 30),

            // Report ID and Date
            _buildInfoRow('Report ID:', report.id),
            _buildInfoRow(
              'Date & Time:',
              DateFormat('dd MMM yyyy, hh:mm:ss a').format(report.dateTime),
            ),
            _buildInfoRow('User:', report.userName),
            _buildInfoRow('Vehicle Type:', report.vehicleType),

            pw.SizedBox(height: 30),

            // Severity Analysis
            pw.Container(
              padding: const pw.EdgeInsets.all(15),
              decoration: pw.BoxDecoration(
                border: pw.Border.all(width: 2),
                borderRadius: const pw.BorderRadius.all(pw.Radius.circular(10)),
              ),
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Text(
                    'AI SEVERITY ANALYSIS',
                    style: pw.TextStyle(
                      fontSize: 20,
                      fontWeight: pw.FontWeight.bold,
                    ),
                  ),
                  pw.SizedBox(height: 15),
                  pw.Row(
                    mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                    children: [
                      pw.Text(
                        'Severity Level:',
                        style: const pw.TextStyle(fontSize: 14),
                      ),
                      pw.Container(
                        padding: const pw.EdgeInsets.symmetric(
                          horizontal: 20,
                          vertical: 8,
                        ),
                        decoration: pw.BoxDecoration(
                          color: _getSeverityColor(report.severity),
                          borderRadius: const pw.BorderRadius.all(
                            pw.Radius.circular(5),
                          ),
                        ),
                        child: pw.Text(
                          report.severity.toUpperCase(),
                          style: pw.TextStyle(
                            fontSize: 16,
                            fontWeight: pw.FontWeight.bold,
                            color: PdfColors.white,
                          ),
                        ),
                      ),
                    ],
                  ),
                  pw.SizedBox(height: 10),
                  pw.Row(
                    mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                    children: [
                      pw.Text(
                        'AI Confidence:',
                        style: const pw.TextStyle(fontSize: 14),
                      ),
                      pw.Text(
                        '${(report.aiConfidence * 100).toStringAsFixed(1)}%',
                        style: pw.TextStyle(
                          fontSize: 14,
                          fontWeight: pw.FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  pw.SizedBox(height: 10),
                  pw.Text(
                    'Analysis:',
                    style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
                  ),
                  pw.Text(
                    report.severityReason,
                    style: const pw.TextStyle(fontSize: 12),
                  ),
                ],
              ),
            ),

            pw.SizedBox(height: 30),

            // Location Summary
            pw.Container(
              padding: const pw.EdgeInsets.all(15),
              decoration: pw.BoxDecoration(
                color: PdfColors.grey200,
                borderRadius: const pw.BorderRadius.all(pw.Radius.circular(10)),
              ),
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Text(
                    'LOCATION DETAILS',
                    style: pw.TextStyle(
                      fontSize: 16,
                      fontWeight: pw.FontWeight.bold,
                    ),
                  ),
                  pw.SizedBox(height: 10),
                  _buildInfoRow('Address:', report.address),
                  _buildInfoRow(
                    'Coordinates:',
                    '${report.latitude.toStringAsFixed(6)}, ${report.longitude.toStringAsFixed(6)}',
                  ),
                  _buildInfoRow('Nearest Hospital:', report.nearestHospital),
                  _buildInfoRow(
                    'Distance:',
                    '${report.hospitalDistance.toStringAsFixed(2)} km',
                  ),
                ],
              ),
            ),

            pw.Spacer(),

            // Footer
            pw.Center(
              child: pw.Text(
                'This is an AI-generated report. For official use with police, insurance, and medical facilities.',
                style: const pw.TextStyle(
                  fontSize: 10,
                  color: PdfColors.grey700,
                ),
                textAlign: pw.TextAlign.center,
              ),
            ),
          ],
        );
      },
    );
  }

  /// Details page with sensor data
  static pw.Page _buildDetailsPage(CrashReport report) {
    return pw.Page(
      pageFormat: PdfPageFormat.a4,
      build: (context) {
        return pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Text(
              'INCIDENT DETAILS',
              style: pw.TextStyle(fontSize: 24, fontWeight: pw.FontWeight.bold),
            ),
            pw.Divider(thickness: 2),
            pw.SizedBox(height: 20),

            // Impact Metrics
            _buildSectionTitle('Impact Metrics'),
            _buildMetricRow(
              'Speed Before Crash:',
              '${report.speedBeforeCrash.toStringAsFixed(1)} km/h',
            ),
            _buildMetricRow(
              'Impact Force:',
              '${report.impactForce.toStringAsFixed(2)} m/s²',
            ),
            _buildMetricRow(
              'Immobility Duration:',
              '${report.immobilityDuration} seconds',
            ),

            pw.SizedBox(height: 20),

            // 3D Impact Vector
            _buildSectionTitle('3D Impact Vector (Accelerometer)'),
            _buildMetricRow(
              'X-axis (Lateral):',
              '${report.impactX.toStringAsFixed(2)} m/s²',
            ),
            _buildMetricRow(
              'Y-axis (Longitudinal):',
              '${report.impactY.toStringAsFixed(2)} m/s²',
            ),
            _buildMetricRow(
              'Z-axis (Vertical):',
              '${report.impactZ.toStringAsFixed(2)} m/s²',
            ),

            pw.SizedBox(height: 20),

            // Emergency Response
            _buildSectionTitle('Emergency Response'),
            _buildMetricRow('Alert Sent:', report.alertSent ? '✓ YES' : '✗ NO'),
            _buildMetricRow(
              'Contacts Notified:',
              report.emergencyContacts.length.toString(),
            ),
            if (report.emergencyContacts.isNotEmpty) ...[
              pw.SizedBox(height: 5),
              pw.Text(
                'Contact Numbers:',
                style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
              ),
              ...report.emergencyContacts.map(
                (contact) => pw.Padding(
                  padding: const pw.EdgeInsets.only(left: 20, top: 3),
                  child: pw.Text('• $contact'),
                ),
              ),
            ],

            pw.SizedBox(height: 30),

            // Map Link
            pw.Container(
              padding: const pw.EdgeInsets.all(15),
              decoration: pw.BoxDecoration(
                color: PdfColors.blue50,
                borderRadius: const pw.BorderRadius.all(pw.Radius.circular(8)),
              ),
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Text(
                    'Google Maps Location:',
                    style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
                  ),
                  pw.SizedBox(height: 5),
                  pw.Text(
                    'https://maps.google.com/?q=${report.latitude},${report.longitude}',
                    style: const pw.TextStyle(
                      color: PdfColors.blue800,
                      fontSize: 10,
                    ),
                  ),
                ],
              ),
            ),
          ],
        );
      },
    );
  }

  /// Sensor data visualization page
  static pw.Page _buildSensorDataPage(CrashReport report) {
    return pw.Page(
      pageFormat: PdfPageFormat.a4,
      build: (context) {
        return pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Text(
              'SENSOR DATA ANALYSIS',
              style: pw.TextStyle(fontSize: 24, fontWeight: pw.FontWeight.bold),
            ),
            pw.Divider(thickness: 2),
            pw.SizedBox(height: 20),

            // Impact force bar chart representation
            _buildSectionTitle('Impact Force Distribution'),
            _buildBarChart('X-axis', report.impactX.abs(), PdfColors.red),
            _buildBarChart('Y-axis', report.impactY.abs(), PdfColors.blue),
            _buildBarChart('Z-axis', report.impactZ.abs(), PdfColors.green),
            _buildBarChart('Total Force', report.impactForce, PdfColors.orange),

            pw.SizedBox(height: 30),

            // Speed analysis
            _buildSectionTitle('Speed Analysis'),
            pw.Container(
              padding: const pw.EdgeInsets.all(15),
              decoration: pw.BoxDecoration(
                border: pw.Border.all(),
                borderRadius: const pw.BorderRadius.all(pw.Radius.circular(8)),
              ),
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Text(
                    'Speed at impact: ${report.speedBeforeCrash.toStringAsFixed(1)} km/h',
                  ),
                  pw.SizedBox(height: 5),
                  pw.Text(_getSpeedRiskLevel(report.speedBeforeCrash)),
                ],
              ),
            ),

            pw.SizedBox(height: 20),

            // Time analysis
            _buildSectionTitle('Time Analysis'),
            pw.Text(
              'Incident occurred: ${DateFormat('EEEE, dd MMMM yyyy').format(report.dateTime)}',
            ),
            pw.Text(
              'Exact time: ${DateFormat('hh:mm:ss a').format(report.dateTime)}',
            ),
            pw.Text(
              'Post-crash immobility: ${report.immobilityDuration} seconds',
            ),

            pw.SizedBox(height: 30),

            // AI Scoring Breakdown
            _buildSectionTitle('AI Scoring Breakdown'),
            pw.Text(
              'The AI analyzed multiple factors:',
              style: const pw.TextStyle(fontSize: 12),
            ),
            pw.SizedBox(height: 10),
            pw.BulletList([
              'Impact force magnitude and direction',
              'Vehicle speed before collision',
              'Post-crash immobility duration',
              'Acceleration patterns across 3 axes',
            ]),
          ],
        );
      },
    );
  }

  /// Recommendations page
  static pw.Page _buildRecommendationsPage(CrashReport report) {
    final recommendations = AISeverityAnalyzer.getRecommendations(
      report.severity,
    );

    return pw.Page(
      pageFormat: PdfPageFormat.a4,
      build: (context) {
        return pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Text(
              'RECOMMENDATIONS & NEXT STEPS',
              style: pw.TextStyle(fontSize: 24, fontWeight: pw.FontWeight.bold),
            ),
            pw.Divider(thickness: 2),
            pw.SizedBox(height: 20),

            pw.Container(
              padding: const pw.EdgeInsets.all(15),
              decoration: pw.BoxDecoration(
                color: PdfColors.yellow50,
                border: pw.Border.all(width: 2, color: PdfColors.orange),
                borderRadius: const pw.BorderRadius.all(pw.Radius.circular(10)),
              ),
              child: pw.Text(
                'Based on the AI analysis of ${report.severity.toUpperCase()} severity, follow these recommendations:',
                style: pw.TextStyle(
                  fontSize: 14,
                  fontWeight: pw.FontWeight.bold,
                ),
              ),
            ),

            pw.SizedBox(height: 20),

            ...recommendations.map(
              (rec) => pw.Padding(
                padding: const pw.EdgeInsets.only(bottom: 12),
                child: pw.Row(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Container(
                      width: 8,
                      height: 8,
                      margin: const pw.EdgeInsets.only(top: 5, right: 10),
                      decoration: const pw.BoxDecoration(
                        color: PdfColors.red,
                        shape: pw.BoxShape.circle,
                      ),
                    ),
                    pw.Expanded(
                      child: pw.Text(
                        rec,
                        style: const pw.TextStyle(fontSize: 13),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            pw.SizedBox(height: 30),

            _buildSectionTitle('For Legal/Insurance Purposes'),
            pw.BulletList([
              'Keep this report as evidence for insurance claims',
              'Submit to police if filing an FIR (First Information Report)',
              'Provide to medical facilities for injury documentation',
              'Share with insurance adjuster during claims process',
              'Retain all related medical records and bills',
            ]),

            pw.Spacer(),

            pw.Divider(),
            pw.SizedBox(height: 10),

            // Disclaimer
            pw.Container(
              padding: const pw.EdgeInsets.all(10),
              decoration: pw.BoxDecoration(
                color: PdfColors.grey100,
                borderRadius: const pw.BorderRadius.all(pw.Radius.circular(5)),
              ),
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Text(
                    'DISCLAIMER',
                    style: pw.TextStyle(
                      fontSize: 10,
                      fontWeight: pw.FontWeight.bold,
                    ),
                  ),
                  pw.SizedBox(height: 5),
                  pw.Text(
                    'This report is AI-generated based on sensor data and should be used as supplementary documentation. '
                    'It does not replace professional medical evaluation, official police reports, or insurance assessments. '
                    'The severity analysis is based on algorithmic interpretation and may not reflect all circumstances of the incident.',
                    style: const pw.TextStyle(
                      fontSize: 8,
                      color: PdfColors.grey700,
                    ),
                  ),
                ],
              ),
            ),
          ],
        );
      },
    );
  }

  // Helper methods

  static pw.Widget _buildInfoRow(String label, String value) {
    return pw.Padding(
      padding: const pw.EdgeInsets.only(bottom: 8),
      child: pw.Row(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.SizedBox(
            width: 150,
            child: pw.Text(
              label,
              style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
            ),
          ),
          pw.Expanded(child: pw.Text(value)),
        ],
      ),
    );
  }

  static pw.Widget _buildSectionTitle(String title) {
    return pw.Padding(
      padding: const pw.EdgeInsets.only(bottom: 10),
      child: pw.Text(
        title,
        style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold),
      ),
    );
  }

  static pw.Widget _buildMetricRow(String label, String value) {
    return pw.Padding(
      padding: const pw.EdgeInsets.only(bottom: 6),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Text(label),
          pw.Text(value, style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
        ],
      ),
    );
  }

  static pw.Widget _buildBarChart(String label, double value, PdfColor color) {
    final maxValue = 200.0; // Maximum expected force
    final percentage = (value / maxValue).clamp(0.0, 1.0);

    return pw.Padding(
      padding: const pw.EdgeInsets.only(bottom: 10),
      child: pw.Row(
        children: [
          pw.SizedBox(
            width: 100,
            child: pw.Text(label, style: const pw.TextStyle(fontSize: 12)),
          ),
          pw.Expanded(
            child: pw.Stack(
              children: [
                pw.Container(
                  height: 20,
                  decoration: pw.BoxDecoration(
                    color: PdfColors.grey300,
                    borderRadius: const pw.BorderRadius.all(
                      pw.Radius.circular(4),
                    ),
                  ),
                ),
                pw.Container(
                  height: 20,
                  width: percentage * 400, // Max width
                  decoration: pw.BoxDecoration(
                    color: color,
                    borderRadius: const pw.BorderRadius.all(
                      pw.Radius.circular(4),
                    ),
                  ),
                ),
              ],
            ),
          ),
          pw.SizedBox(width: 10),
          pw.SizedBox(
            width: 60,
            child: pw.Text(
              value.toStringAsFixed(1),
              style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }

  static PdfColor _getSeverityColor(String severity) {
    switch (severity) {
      case 'Critical':
        return PdfColors.red900;
      case 'Severe':
        return PdfColors.red;
      case 'Moderate':
        return PdfColors.orange;
      case 'Minor':
        return PdfColors.yellow700;
      default:
        return PdfColors.grey;
    }
  }

  static String _getSpeedRiskLevel(double speed) {
    if (speed < 20) return 'Risk Level: Very Low';
    if (speed < 40) return 'Risk Level: Low';
    if (speed < 60) return 'Risk Level: Moderate';
    if (speed < 80) return 'Risk Level: High';
    return 'Risk Level: Critical';
  }

  static Future<File> _getOutputFile(String reportId) async {
    final directory = await getApplicationDocumentsDirectory();
    final reportsDir = Directory('${directory.path}/crash_reports');
    if (!await reportsDir.exists()) {
      await reportsDir.create(recursive: true);
    }
    return File('${reportsDir.path}/crash_report_$reportId.pdf');
  }
}
