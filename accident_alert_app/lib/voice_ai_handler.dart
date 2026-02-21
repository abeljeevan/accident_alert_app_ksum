import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:speech_to_text/speech_to_text.dart';
import 'package:speech_to_text/speech_recognition_result.dart';

/// Voice-based AI interaction handler for hands-free emergency response
class VoiceAIHandler {
  final FlutterTts _tts = FlutterTts();
  final SpeechToText _speech = SpeechToText();
  
  bool _isInitialized = false;
  bool _isListening = false;
  Timer? _timeoutTimer;
  String? _availableLocale; // Store detected locale
  
  // Callback when user says they're okay
  Function()? onUserOkay;
  
  // Callback when user needs help or doesn't respond
  Function()? onUserNeedsHelp;
  
  // Callback for real-time speech updates
  Function(String)? onSpeechUpdate;

  /// Initialize TTS and Speech Recognition
  Future<bool> initialize() async {
    if (_isInitialized) return true;

    try {
      // Initialize Text-to-Speech
      await _tts.setLanguage("en-US");
      await _tts.setSpeechRate(0.5); // Slower for emergency situations
      await _tts.setVolume(1.0);
      await _tts.setPitch(1.0);

      // Initialize Speech-to-Text (supports offline on Android)
      _isInitialized = await _speech.initialize(
        onError: (error) {
          debugPrint('🎙️ Speech recognition error: ${error.errorMsg} (${error.permanent})');
        },
        onStatus: (status) {
          debugPrint('🎙️ Speech recognition status: $status');
          if (status == 'notListening') {
            _isListening = false;
          } else if (status == 'listening') {
            debugPrint('✅ Microphone is active and listening');
          }
        },
      );

      if (_isInitialized) {
        debugPrint('✅ Voice AI Handler initialized successfully');
        // Check if offline recognition is available and detect locale
        final locales = await _speech.locales();
        debugPrint('📋 Available locales: ${locales.length}');
        
        if (locales.isEmpty) {
          debugPrint('⚠️ WARNING: No speech recognition languages installed on device!');
          debugPrint('⚠️ Please install a language pack in Settings → Languages → Speech Recognition');
        }
        
        // Find English locale or use first available
        if (locales.isNotEmpty) {
          // Try to find English locale first
          for (var locale in locales) {
            debugPrint('   - ${locale.localeId}: ${locale.name}');
            if (locale.localeId.startsWith('en')) {
              _availableLocale = locale.localeId;
              break;
            }
          }
          
          // If no English locale, use the first available
          if (_availableLocale == null) {
            _availableLocale = locales.first.localeId;
          }
        }
        debugPrint('✅ Using locale: $_availableLocale');
      } else {
        debugPrint('❌ Failed to initialize speech recognition');
      }

      return _isInitialized;
    } catch (e) {
      debugPrint('❌ Error initializing Voice AI: $e');
      return false;
    }
  }

  /// Start the emergency voice interaction sequence
  Future<void> startEmergencyInteraction({
    required Function() onOkay,
    required Function() onHelp,
    Function(String)? onSpeechUpdate,
    Function()? onTimeout, // Optional callback for timeout (test mode)
    int timeoutSeconds = 15,
  }) async {
    if (!_isInitialized) {
      final initialized = await initialize();
      if (!initialized) {
        debugPrint('❌ Cannot start voice interaction: Not initialized');
        // If voice fails, default to emergency
        onHelp();
        return;
      }
    }

    // Check if we have a valid locale
    if (_availableLocale == null) {
      debugPrint('❌ No language available for speech recognition');
      _speak("Speech recognition not available. Please respond manually.");
      if (onTimeout != null) {
        onTimeout();
      } else {
        onHelp();
      }
      return;
    }

    onUserOkay = onOkay;
    onUserNeedsHelp = onHelp;
    this.onSpeechUpdate = onSpeechUpdate;

    // Speak the prompt - clearer and simpler
    await _speak(
      "Accident detected! Say YES if you are okay. Say HELP if you need assistance. I'm listening now.",
    );

    // Wait longer for TTS to complete before starting to listen
    await Future.delayed(const Duration(milliseconds: 1500));
    
    debugPrint('🎙️ ⚠️ START SPEAKING NOW!');

    // Start listening for response
    await _startListening(
      timeoutSeconds: timeoutSeconds,
      onTimeout: onTimeout,
    );
  }

  /// Speak text using TTS
  Future<void> _speak(String text) async {
    try {
      debugPrint('🗣️ Speaking: $text');
      await _tts.speak(text);
    } catch (e) {
      debugPrint('❌ TTS error: $e');
    }
  }

  /// Start listening for user response
  Future<void> _startListening({
    int timeoutSeconds = 15,
    Function()? onTimeout,
  }) async {
    if (_isListening) {
      debugPrint('⚠️ Already listening');
      return;
    }

    try {
      _isListening = true;
      
      // Set timeout - if no response, trigger emergency
      _timeoutTimer = Timer(Duration(seconds: timeoutSeconds), () {
        debugPrint('⏰ Voice response timeout');
        _stopListening();
        
        // Use custom timeout handler if provided (for testing), otherwise trigger help
        if (onTimeout != null) {
          onTimeout();
        } else {
          _speak("No response detected. Triggering emergency alert.");
          onUserNeedsHelp?.call();
        }
      });

      // Start listening - try online mode first (more compatible)
      debugPrint('🎙️ Starting speech recognition with locale: $_availableLocale');
      debugPrint('🎙️ Attempting online speech recognition...');
      debugPrint('🎙️ ⚠️⚠️⚠️ SAY "YES" OR "HELP" NOW! ⚠️⚠️⚠️');
      await _speech.listen(
        onResult: _onSpeechResult,
        listenFor: Duration(seconds: timeoutSeconds),
        pauseFor: const Duration(seconds: 5), // Longer pause before stopping
        partialResults: true,
        // Don't specify locale - let system choose automatically
        // Use cloud-based recognition for better compatibility
        onDevice: false,
        listenMode: ListenMode.confirmation,
      );

      debugPrint('🎙️ Listening for user response...');
    } catch (e) {
      debugPrint('❌ Error starting speech recognition: $e');
      _isListening = false;
      // Default to emergency if listening fails
      onUserNeedsHelp?.call();
    }
  }

  /// Process speech recognition results
  void _onSpeechResult(SpeechRecognitionResult result) {
    final recognizedWords = result.recognizedWords.toLowerCase().trim();
    debugPrint('🎙️ ===== SPEECH RECOGNITION RESULT =====');
    debugPrint('🎙️ Raw text: "$recognizedWords"');
    debugPrint('🎙️ Is final: ${result.finalResult}');
    debugPrint('🎙️ Confidence: ${result.confidence ?? "N/A"}');

    // Update UI with what was heard
    if (recognizedWords.isNotEmpty) {
      onSpeechUpdate?.call(recognizedWords);
    }

    // Process partial results for clear keywords to be more responsive
    if (recognizedWords.isEmpty) {
      debugPrint('🎙️ Empty recognition, skipping...');
      return;
    }

    // Check for positive responses (user is okay) - process immediately even if partial
    final isAffirmative = _containsAffirmative(recognizedWords);
    final isHelp = _containsHelp(recognizedWords);
    
    debugPrint('🎙️ Affirmative match: $isAffirmative');
    debugPrint('🎙️ Help match: $isHelp');
    debugPrint('🎙️ =====================================');
    
    if (isAffirmative) {
      debugPrint('✅ User confirmed they are okay');
      _timeoutTimer?.cancel();
      _stopListening();
      _speak("Okay, canceling emergency alert. Stay safe!");
      onUserOkay?.call();
      return;
    }

    // Check for help/emergency responses - process immediately
    if (isHelp) {
      debugPrint('🚨 User requested help');
      _timeoutTimer?.cancel();
      _stopListening();
      _speak("Understood. Triggering emergency alert now.");
      onUserNeedsHelp?.call();
      return;
    }

    // If final result but no clear answer, log it
    if (result.finalResult && recognizedWords.isNotEmpty) {
      debugPrint('❓ Unclear response: "$recognizedWords" - waiting for timeout');
    }
  }

  /// Check if text contains affirmative responses
  bool _containsAffirmative(String text) {
    // More aggressive matching - check individual words too
    final words = text.split(' ');
    
    const affirmatives = [
      'yes',
      'yeah',
      'yep',
      'yup',
      'ya',
      'okay',
      'ok',
      'fine',
      'good',
      'alright',
      'i\'m okay',
      'im okay',
      'i am okay',
      'i\'m fine',
      'im fine',
      'i am fine',
      'no help',
      'don\'t need',
      'dont need',
      'cancel',
    ];

    // Check if any word matches
    for (var word in words) {
      word = word.toLowerCase().trim();
      if (affirmatives.contains(word)) {
        debugPrint('✅ Matched affirmative word: "$word"');
        return true;
      }
    }
    
    // Also check full text
    if (affirmatives.any((word) => text.contains(word))) {
      debugPrint('✅ Matched affirmative in text: "$text"');
      return true;
    }
    
    return false;
  }

  /// Check if text contains help/emergency keywords
  bool _containsHelp(String text) {
    // Split into words for more precise matching
    final words = text.split(' ').map((w) => w.toLowerCase().trim()).toList();
    
    const helpKeywords = [
      'help',
      'emergency',
      'hurt',
      'injured',
      'pain',
      'ambulance',
      'hospital',
      'need help',
      'not okay',
    ];

    // Check exact word matches for single words
    for (var word in words) {
      if (helpKeywords.contains(word)) {
        debugPrint('🚨 Matched help keyword: "$word"');
        return true;
      }
    }
    
    // Check for multi-word phrases
    for (var phrase in helpKeywords) {
      if (text.contains(phrase)) {
        debugPrint('🚨 Matched help phrase: "$phrase"');
        return true;
      }
    }
    
    return false;
  }

  /// Stop listening
  void _stopListening() {
    if (_isListening) {
      _speech.stop();
      _isListening = false;
      _timeoutTimer?.cancel();
      debugPrint('🛑 Stopped listening');
    }
  }

  /// Cancel any ongoing voice interaction
  void cancel() {
    _stopListening();
    _timeoutTimer?.cancel();
    _tts.stop();
    onUserOkay = null;
    onUserNeedsHelp = null;
  }

  /// Check if speech recognition is available
  Future<bool> isSpeechAvailable() async {
    if (!_isInitialized) {
      await initialize();
    }
    return _speech.isAvailable;
  }

  /// Get available languages for speech recognition
  Future<List<LocaleName>> getAvailableLanguages() async {
    if (!_isInitialized) {
      await initialize();
    }
    return await _speech.locales();
  }

  /// Dispose resources
  void dispose() {
    cancel();
    _speech.cancel();
  }
}
