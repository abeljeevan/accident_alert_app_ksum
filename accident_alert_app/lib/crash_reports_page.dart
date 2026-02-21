import 'dart:io';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:share_plus/share_plus.dart';
import 'crash_report.dart';
// import 'pdf_report_generator.dart'; // Temporarily disabled
import 'ai_severity_analyzer.dart';

class CrashReportsPage extends StatefulWidget {
  final bool isDarkMode;

  const CrashReportsPage({super.key, required this.isDarkMode});

  @override
  State<CrashReportsPage> createState() => _CrashReportsPageState();
}

class _CrashReportsPageState extends State<CrashReportsPage> {
  bool _isGenerating = false;

  Future<void> _generateAndViewPDF(CrashReport report) async {
    // PDF generation temporarily disabled - coming soon!
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text(
          '📄 PDF feature coming soon! All data is saved and viewable here.',
        ),
        duration: Duration(seconds: 3),
      ),
    );
    return;
  }

  Future<void> _sharePDF(File pdfFile) async {
    try {
      await Share.shareXFiles(
        [XFile(pdfFile.path)],
        text: 'Accident Crash Report - AI Generated',
        subject: 'Crash Report PDF',
      );
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('❌ Error sharing: $e')));
    }
  }

  void _viewReportDetails(CrashReport report) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => CrashReportDetailPage(
          report: report,
          isDarkMode: widget.isDarkMode,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final reports = CrashReportStore.reports;

    return Scaffold(
      appBar: AppBar(
        title: const Text('📝 AI Crash Reports'),
        actions: [
          if (reports.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.delete_sweep),
              tooltip: 'Clear all reports',
              onPressed: () {
                showDialog(
                  context: context,
                  builder: (_) => AlertDialog(
                    title: const Text('Clear All Reports?'),
                    content: const Text(
                      'This will permanently delete all crash reports.',
                    ),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(context),
                        child: const Text('Cancel'),
                      ),
                      TextButton(
                        onPressed: () async {
                          await CrashReportStore.clear();
                          Navigator.pop(context);
                          setState(() {});
                        },
                        child: const Text(
                          'Delete All',
                          style: TextStyle(color: Colors.red),
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
        ],
      ),
      body: _isGenerating
          ? const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(),
                  SizedBox(height: 20),
                  Text('Generating PDF Report...'),
                ],
              ),
            )
          : reports.isEmpty
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.description_outlined,
                    size: 80,
                    color: widget.isDarkMode ? Colors.white38 : Colors.grey,
                  ),
                  const SizedBox(height: 20),
                  Text(
                    'No crash reports yet',
                    style: TextStyle(
                      fontSize: 18,
                      color: widget.isDarkMode
                          ? Colors.white70
                          : Colors.grey[700],
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    'Reports will be automatically generated\nwhen accidents are detected',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 14,
                      color: widget.isDarkMode
                          ? Colors.white54
                          : Colors.grey[600],
                    ),
                  ),
                ],
              ),
            )
          : ListView.builder(
              padding: const EdgeInsets.all(12),
              itemCount: reports.length,
              itemBuilder: (context, index) {
                final report = reports[index];
                return _buildReportCard(report);
              },
            ),
    );
  }

  Widget _buildReportCard(CrashReport report) {
    final severityColor = _getSeverityColor(report.severity);

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      color: widget.isDarkMode
          ? const Color(0xFF2C2C2C)
          : const Color(0xFF194276),
      child: InkWell(
        onTap: () => _viewReportDetails(report),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header row
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(
                      '${report.getSeverityEmoji()} ${report.severity} Accident',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: severityColor,
                      ),
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: severityColor.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: severityColor),
                    ),
                    child: Text(
                      '${(report.aiConfidence * 100).toStringAsFixed(0)}% AI',
                      style: TextStyle(
                        color: severityColor,
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),

              // Date and time
              Row(
                children: [
                  const Icon(
                    Icons.access_time,
                    size: 16,
                    color: Colors.white70,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    DateFormat('dd MMM yyyy, hh:mm a').format(report.dateTime),
                    style: const TextStyle(color: Colors.white70, fontSize: 13),
                  ),
                ],
              ),
              const SizedBox(height: 8),

              // Location
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(
                    Icons.location_on,
                    size: 16,
                    color: Colors.white70,
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      report.address.length > 60
                          ? '${report.address.substring(0, 60)}...'
                          : report.address,
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 13,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),

              // Impact metrics
              Row(
                children: [
                  _buildMetric(
                    '⚡',
                    '${report.impactForce.toStringAsFixed(1)} m/s²',
                  ),
                  const SizedBox(width: 16),
                  _buildMetric(
                    '🚗',
                    '${report.speedBeforeCrash.toStringAsFixed(0)} km/h',
                  ),
                  const SizedBox(width: 16),
                  _buildMetric(
                    '🏥',
                    '${report.hospitalDistance.toStringAsFixed(1)} km',
                  ),
                ],
              ),
              const SizedBox(height: 12),

              const Divider(color: Colors.white24, height: 1),
              const SizedBox(height: 12),

              // Action buttons
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton.icon(
                      icon: const Icon(Icons.picture_as_pdf, size: 18),
                      label: const Text('Generate PDF'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFE63946),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 8),
                      ),
                      onPressed: () => _generateAndViewPDF(report),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: OutlinedButton.icon(
                      icon: const Icon(Icons.info_outline, size: 18),
                      label: const Text('Details'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.white,
                        side: const BorderSide(color: Colors.white70),
                        padding: const EdgeInsets.symmetric(vertical: 8),
                      ),
                      onPressed: () => _viewReportDetails(report),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMetric(String icon, String value) {
    return Row(
      children: [
        Text(icon, style: const TextStyle(fontSize: 14)),
        const SizedBox(width: 4),
        Text(
          value,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 13,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }

  Color _getSeverityColor(String severity) {
    switch (severity) {
      case 'Critical':
        return Colors.red[900]!;
      case 'Severe':
        return Colors.red;
      case 'Moderate':
        return Colors.orange;
      case 'Minor':
        return Colors.yellow[700]!;
      default:
        return Colors.grey;
    }
  }
}

// Detail page for individual crash report
class CrashReportDetailPage extends StatelessWidget {
  final CrashReport report;
  final bool isDarkMode;

  const CrashReportDetailPage({
    super.key,
    required this.report,
    required this.isDarkMode,
  });

  @override
  Widget build(BuildContext context) {
    final recommendations = AISeverityAnalyzer.getRecommendations(
      report.severity,
    );

    return Scaffold(
      appBar: AppBar(title: const Text('Crash Report Details')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Severity card
          Card(
            color: _getSeverityColor(report.severity).withOpacity(0.2),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  Text(
                    '${report.getSeverityEmoji()} ${report.severity.toUpperCase()}',
                    style: TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                      color: _getSeverityColor(report.severity),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'AI Confidence: ${(report.aiConfidence * 100).toStringAsFixed(1)}%',
                    style: TextStyle(
                      fontSize: 16,
                      color: isDarkMode ? Colors.white : Colors.black,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Time and location
          _buildSection('Incident Information', [
            _buildInfoRow(
              'Date & Time',
              DateFormat('dd MMM yyyy, hh:mm:ss a').format(report.dateTime),
            ),
            _buildInfoRow('Address', report.address),
            _buildInfoRow(
              'Coordinates',
              '${report.latitude.toStringAsFixed(6)}, ${report.longitude.toStringAsFixed(6)}',
            ),
          ]),

          // Sensor data
          _buildSection('Sensor Data', [
            _buildInfoRow(
              'Impact Force',
              '${report.impactForce.toStringAsFixed(2)} m/s²',
            ),
            _buildInfoRow(
              'Speed Before Crash',
              '${report.speedBeforeCrash.toStringAsFixed(1)} km/h',
            ),
            _buildInfoRow(
              'Impact X-axis',
              '${report.impactX.toStringAsFixed(2)} m/s²',
            ),
            _buildInfoRow(
              'Impact Y-axis',
              '${report.impactY.toStringAsFixed(2)} m/s²',
            ),
            _buildInfoRow(
              'Impact Z-axis',
              '${report.impactZ.toStringAsFixed(2)} m/s²',
            ),
            _buildInfoRow(
              'Immobility Duration',
              '${report.immobilityDuration} seconds',
            ),
          ]),

          // Hospital info
          _buildSection('Nearest Hospital', [
            _buildInfoRow('Hospital', report.nearestHospital),
            _buildInfoRow(
              'Distance',
              '${report.hospitalDistance.toStringAsFixed(2)} km',
            ),
          ]),

          // AI Analysis
          _buildSection('AI Analysis', [
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Text(
                report.severityReason,
                style: TextStyle(
                  fontSize: 14,
                  color: isDarkMode ? Colors.white : Colors.black,
                  height: 1.5,
                ),
              ),
            ),
          ]),

          // Recommendations
          _buildSection(
            '⚠️ Recommendations',
            recommendations
                .map(
                  (rec) => Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('• ', style: TextStyle(fontSize: 16)),
                        Expanded(
                          child: Text(
                            rec,
                            style: TextStyle(
                              fontSize: 14,
                              color: isDarkMode ? Colors.white : Colors.black,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                )
                .toList(),
          ),

          // Emergency contacts
          if (report.emergencyContacts.isNotEmpty)
            _buildSection(
              'Emergency Contacts Notified',
              report.emergencyContacts
                  .map(
                    (contact) => Padding(
                      padding: const EdgeInsets.only(bottom: 4),
                      child: Text(
                        '📞 $contact',
                        style: TextStyle(
                          fontSize: 14,
                          color: isDarkMode ? Colors.white : Colors.black,
                        ),
                      ),
                    ),
                  )
                  .toList(),
            ),
        ],
      ),
    );
  }

  Widget _buildSection(String title, List<Widget> children) {
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      color: isDarkMode ? const Color(0xFF2C2C2C) : const Color(0xFF194276),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
            const Divider(color: Colors.white38),
            ...children,
          ],
        ),
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 140,
            child: Text(
              '$label:',
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                color: Colors.white70,
                fontSize: 14,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(color: Colors.white, fontSize: 14),
            ),
          ),
        ],
      ),
    );
  }

  Color _getSeverityColor(String severity) {
    switch (severity) {
      case 'Critical':
        return Colors.red[900]!;
      case 'Severe':
        return Colors.red;
      case 'Moderate':
        return Colors.orange;
      case 'Minor':
        return Colors.yellow[700]!;
      default:
        return Colors.grey;
    }
  }
}
