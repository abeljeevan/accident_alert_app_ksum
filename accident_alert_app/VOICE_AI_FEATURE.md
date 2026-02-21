# 🎙️ Voice-Based AI Interaction (Hands-Free)

## Overview
The app now includes **offline-capable voice AI** that allows hands-free emergency response after accident detection.

## How It Works

### 1. Accident Detection
When an accident is detected, the app:
- 🗣️ Speaks: *"Accident detected! Are you okay? Say YES if you're fine, or say HELP if you need assistance."*
- 🎙️ Starts listening for your voice response
- ⏰ Auto-triggers emergency alert after 15 seconds if no clear response

### 2. Voice Commands

#### ✅ To Cancel Alert (You're Okay):
Say any of these:
- "YES"
- "I'm okay"
- "I'm fine"
- "Fine"
- "Okay"
- "No help"
- "Don't need help"
- "Cancel"

**Result:** Alert is cancelled, app says *"Okay, canceling emergency alert. Stay safe!"*

#### 🚨 To Trigger Emergency:
Say any of these:
- "HELP"
- "Emergency"
- "Hurt"
- "Injured"
- "Pain"
- "Not okay"
- "Ambulance"
- "Hospital"

**Result:** Emergency alert is sent immediately

#### ⏰ No Response:
If you don't respond within 15 seconds:
- Automatic emergency alert is triggered
- Assumes you may be unconscious or unable to respond

## Features

### ✨ Key Benefits
- 🤲 **Hands-Free**: No need to touch your phone
- 📴 **Offline Capable**: Works without internet (on Android)
- 🧠 **Smart Recognition**: Understands multiple ways to say yes/no
- ⚡ **Fast Response**: Processes speech in real-time
- 🔄 **Fallback**: If voice fails, shows traditional dialog

### 🎯 Toggle Voice AI
- Tap the microphone icon in the top-right corner
- 🎤 Green = Voice AI Enabled
- 🔇 Gray = Voice AI Disabled (uses manual dialog)

## Technical Implementation

### Dependencies
```yaml
speech_to_text: ^7.0.0  # Offline speech recognition
flutter_tts: ^4.0.2      # Text-to-speech
```

### Android Permissions Required
```xml
<uses-permission android:name="android.permission.RECORD_AUDIO" />
<uses-permission android:name="android.permission.BLUETOOTH" />
<uses-permission android:name="android.permission.INTERNET" />
```

### Offline Support
- **Android**: Uses on-device Google Speech Recognition
  - Set `onDevice: true` in speech recognition config
  - Works even without internet connection
  - Supports multiple languages

- **iOS**: Requires internet for first-time setup, then works offline

## Code Architecture

### Files Added/Modified

1. **voice_ai_handler.dart** (NEW)
   - Manages TTS and STT
   - Handles voice interaction logic
   - Keyword detection and decision making

2. **accident_detector.dart** (UPDATED)
   - Integrated voice AI handler
   - Added microphone permission handling
   - Voice interaction toggle

3. **AndroidManifest.xml** (UPDATED)
   - Added microphone permissions
   - Added speech recognition service queries

## Usage Example

```dart
final voiceAI = VoiceAIHandler();

// Initialize
await voiceAI.initialize();

// Start emergency interaction
await voiceAI.startEmergencyInteraction(
  onOkay: () {
    // User confirmed they're okay
    print('Alert cancelled');
  },
  onHelp: () {
    // User needs help or no response
    print('Sending emergency alert');
  },
  timeoutSeconds: 15,
);
```

## Testing

### To Test Voice AI:
1. Run the app on a physical device (emulators may have limited voice support)
2. Tap "Simulate Accident"
3. Listen for the voice prompt
4. Speak clearly: "YES" or "HELP"
5. Check if alert is cancelled or triggered correctly

### Troubleshooting:
- **Not listening**: Check microphone permission
- **Not recognizing**: Speak clearly and louder
- **Always timing out**: Check Android speech recognition is enabled in device settings
- **Still not working**: Toggle voice AI off to use manual dialog

## Future Enhancements

Possible improvements:
- Support for more languages
- Customizable timeout duration
- Voice authentication
- Background listening mode
- Integration with car Bluetooth systems

## Privacy & Security

- ⚠️ Voice data is processed **on-device only** (when offline)
- No voice recordings are stored
- No data sent to servers (when using offline mode)
- Microphone is only active during emergency interaction (15s max)

---

**Status**: ✅ Fully Implemented & Tested
**Platform Support**: Android (offline), iOS (online/offline hybrid)
