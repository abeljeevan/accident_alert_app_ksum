import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:flutter/services.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:intl/intl.dart';

import 'log_store.dart';
import 'contact_store.dart';
import 'voice_ai_handler.dart';

const bool kSmsEnabled = true;

class AccidentDetector extends StatefulWidget {
  const AccidentDetector({super.key});

  @override
  State<AccidentDetector> createState() => _AccidentDetectorState();
}

class _AccidentDetectorState extends State<AccidentDetector> {
  static const MethodChannel _smsChannel = MethodChannel('accident/sms');
  final FlutterTts _tts = FlutterTts();
  final VoiceAIHandler _voiceAI = VoiceAIHandler();

  String _locationMessage = 'Fetching location…';
  bool _isLoading = false;
  bool _useVoiceInteraction = true; // Voice AI enabled for hands-free response

  String _now() => DateFormat('yyyy-MM-dd HH:mm:ss').format(DateTime.now());

  Future<void> _speak(String text) async {
    await _tts.setLanguage('en-US');
    await _tts.setPitch(1.0);
    await _tts.speak(text);
  }

  String _buildSmsBody(Position pos) {
    final maps = 'https://maps.google.com/?q=${pos.latitude},${pos.longitude}';
    return '''
⚠️ Accident detected!
📅 ${_now()}
📍 Lat: ${pos.latitude.toStringAsFixed(5)}, Lon: ${pos.longitude.toStringAsFixed(5)}
➡️ $maps
Please send immediate assistance.
''';
  }

  Future<Position?> _getLocation() async {
    try {
      if (!await Geolocator.isLocationServiceEnabled()) {
        setState(() => _locationMessage = '❌ Location services are disabled.');
        return null;
      }

      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          setState(() => _locationMessage = '❌ Location permission denied.');
          return null;
        }
      }
      if (permission == LocationPermission.deniedForever) {
        setState(() => _locationMessage = '❌ Location permanently denied.');
        return null;
      }

      final pos = await Geolocator.getCurrentPosition(desiredAccuracy: LocationAccuracy.high);
      setState(() {
        _locationMessage =
            'Lat: ${pos.latitude.toStringAsFixed(5)}, '
            'Lon: ${pos.longitude.toStringAsFixed(5)}, '
            'Speed: ${(pos.speed * 3.6).toStringAsFixed(1)} km/h';
      });
      return pos;
    } catch (e) {
      setState(() => _locationMessage = '⚠️ Error getting location: $e');
      return null;
    }
  }

  Future<bool> _ensureSmsPermission() async {
    var sms = await Permission.sms.status;
    var phone = await Permission.phone.status;
    if (sms.isGranted && phone.isGranted) return true;
    if (!sms.isGranted) sms = await Permission.sms.request();
    if (!phone.isGranted) phone = await Permission.phone.request();
    return sms.isGranted && phone.isGranted;
  }

  void _simulateAccident() async {
    setState(() => _isLoading = true);
    final pos = await _getLocation();
    setState(() => _isLoading = false);
    if (!mounted || pos == null) return;

    final logEntry = '🕒 ${_now()}\n📍 $_locationMessage';
    await AccidentLogStore.add(logEntry);

    // Check microphone permission for voice interaction
    if (_useVoiceInteraction) {
      final micStatus = await Permission.microphone.request();
      debugPrint('🎙️ Microphone permission status: $micStatus');
      if (micStatus.isGranted) {
        debugPrint('✅ Starting voice interaction...');
        await _startVoiceInteraction(logEntry, pos);
        return;
      }
      // If microphone permission denied, fall back to manual dialog
      debugPrint('⚠️ Microphone permission denied, using manual dialog');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('⚠️ Microphone permission denied. Using manual mode.'),
            backgroundColor: Colors.orange,
          ),
        );
      }
    }

    // Fallback to manual dialog
    _startManualDialog(logEntry, pos);
  }

  /// Voice-based interaction (hands-free)
  Future<void> _startVoiceInteraction(String logEntry, Position pos) async {
    bool alertCancelled = false;
    String lastRecognized = '';

    // Show a dialog showing voice is active
    final dialog = showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: const Row(
                children: [
                  Text('🚨 Accident Detected'),
                  SizedBox(width: 10),
                  Icon(Icons.mic, color: Colors.red, size: 30),
                ],
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const CircularProgressIndicator(color: Colors.red),
                  const SizedBox(height: 20),
                  const Text(
                    '🎙️ Voice AI is listening...\n\nSay "YES" if you\'re okay\nSay "HELP" if you need assistance\n\n⏰ Auto-alert in 15 seconds',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.black, fontSize: 16),
                  ),
                  if (lastRecognized.isNotEmpty) ...[
                    const SizedBox(height: 15),
                    const Divider(),
                    const SizedBox(height: 10),
                    Text(
                      'Heard: "$lastRecognized"',
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: Colors.blue,
                        fontWeight: FontWeight.bold,
                        fontSize: 18,
                      ),
                    ),
                  ],
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () {
                    alertCancelled = true;
                    _voiceAI.cancel();
                    Navigator.of(ctx).pop();
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('✅ Alert cancelled manually.'),
                        backgroundColor: Colors.green,
                      ),
                    );
                  },
                  child: const Text("Cancel Manually"),
                ),
              ],
            );
          },
        );
      },
    );

    // Start voice AI interaction
    await _voiceAI.startEmergencyInteraction(
      onOkay: () {
        if (!alertCancelled && mounted) {
          alertCancelled = true;
          Navigator.of(context).pop();
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('✅ Alert cancelled - User confirmed okay via voice.'),
              backgroundColor: Colors.green,
            ),
          );
        }
      },
      onHelp: () {
        if (!alertCancelled && mounted) {
          alertCancelled = true;
          Navigator.of(context).pop();
          _handleAlertSend(logEntry, pos);
        }
      },
      onSpeechUpdate: (text) {
        // Update the dialog with what was recognized
        if (mounted) {
          setState(() {
            lastRecognized = text;
          });
        }
      },
      timeoutSeconds: 15,
    );
  }

  /// Manual dialog interaction (traditional)
  void _startManualDialog(String logEntry, Position pos) {
    bool alertCancelled = false;
    _speak('Accident detected. Are you okay? Sending alert in 10 seconds.');

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) {
        Future.delayed(const Duration(seconds: 10), () {
          if (!alertCancelled && Navigator.of(ctx).canPop()) {
            Navigator.of(ctx).pop();
            _handleAlertSend(logEntry, pos);
          }
        });

        return AlertDialog(
          title: const Text('🚨 Accident Detected'),
          content: const Text(
            'Are you okay? Sending alert in 10 seconds…',
            style: TextStyle(color: Colors.black), // <-- Set to black
          ),
          actions: [
            TextButton(
              onPressed: () {
                alertCancelled = true;
                Navigator.of(ctx).pop();
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text(
                      '✅ Alert cancelled.',
                      style: TextStyle(color: Colors.black), // <-- Set to black
                    ),
                    backgroundColor: Colors.white, // <-- White background for contrast
                  ),
                );
                _speak('Alert cancelled. Glad you\'re okay.');
              },
              child: const Text("I'm OK"),
            ),
          ],
        );
      },
    );
  }

  Future<void> _handleAlertSend(String logEntry, Position pos) async {
    if (!kSmsEnabled) {
      await AccidentLogStore.add('❌ SMS NOT IMPLEMENTED:\n$logEntry');
      if (!mounted) return;
      _speak('SMS feature not yet implemented.');
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('❌ SMS feature not yet implemented.')),
      );
      return;
    }

    await _sendEmergencyAlert(logEntry, pos);
  }

  Future<void> _sendEmergencyAlert(String logEntry, Position pos) async {
    if (!await _ensureSmsPermission()) return;

    final contacts = EmergencyContactsStore.contacts;
    final message = _buildSmsBody(pos);

    try {
      for (var number in contacts) {
        final res = await _smsChannel.invokeMethod<String>('sendSMS', {
          'number': number,
          'message': message,
        });

        if (res != 'SMS_SENT' && res != 'SMS_DISPATCHED') {
          throw PlatformException(code: 'FAILED', message: res);
        }
      }

      await AccidentLogStore.add('✅ ALERT SENT:\n$logEntry\nSent to: ${contacts.join(', ')}');
      if (!mounted) return;
      _speak('Emergency alert sent to all contacts.');
      showDialog(
        context: context,
        builder: (_) => AlertDialog(
          title: const Text('✅ Alert Sent'),
          content: Text(
            'SMS successfully sent to: ${contacts.join(', ')}',
            style: const TextStyle(color: Colors.black), // <-- Set to black
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('OK'),
            ),
          ],
        ),
      );
    } catch (e) {
      await AccidentLogStore.add('❌ ALERT FAILED:\n$logEntry\nError: $e');
      if (!mounted) return;
      _speak('Failed to send emergency alert.');
      showDialog(
        context: context,
        builder: (_) => AlertDialog(
          title: const Text('❌ Alert Failed'),
          content: Text('Could not send SMS.\nReason: $e'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('OK'),
            ),
          ],
        ),
      );
    }
  }

  @override
  void dispose() {
    _voiceAI.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Accident Detector'),
        actions: [
          // Toggle for voice interaction
          IconButton(
            icon: Icon(_useVoiceInteraction ? Icons.mic : Icons.mic_off),
            tooltip: _useVoiceInteraction ? 'Voice AI: ON' : 'Voice AI: OFF',
            onPressed: () {
              setState(() {
                _useVoiceInteraction = !_useVoiceInteraction;
              });
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(
                    _useVoiceInteraction
                        ? '🎙️ Voice AI Enabled'
                        : '🔇 Voice AI Disabled',
                  ),
                  duration: const Duration(seconds: 2),
                ),
              );
            },
          ),
        ],
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (_isLoading) const CircularProgressIndicator(),
              ElevatedButton(
                onPressed: _simulateAccident,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red,
                  foregroundColor: const Color.fromARGB(255, 220, 220, 228),
                  padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 16),
                ),
                child: const Text(
                  'Simulate Accident',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
              ),
              const SizedBox(height: 20),
              Text(
                _locationMessage,
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 16),
              ),
              const SizedBox(height: 20),
              // Voice AI Status
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: _useVoiceInteraction ? Colors.green.shade50 : Colors.grey.shade200,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: _useVoiceInteraction ? Colors.green : Colors.grey,
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      _useVoiceInteraction ? Icons.mic : Icons.mic_off,
                      color: _useVoiceInteraction ? Colors.green : Colors.grey,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      _useVoiceInteraction ? 'Voice AI: Active' : 'Voice AI: Disabled',
                      style: TextStyle(
                        color: _useVoiceInteraction ? Colors.green.shade900 : Colors.grey.shade700,
                        fontWeight: FontWeight.bold,
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
}
