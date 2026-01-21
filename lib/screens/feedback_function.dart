import 'package:flutter_tts/flutter_tts.dart'; //tts plugin
import 'package:vibration/vibration.dart'; // phone vibration plugin
import 'dart:async';

class FeedbackFunction {
  // To make sure that only one feedback function across the app
  static final FeedbackFunction _instance = FeedbackFunction._internal();
  factory FeedbackFunction() => _instance;
  FeedbackFunction._internal() {
    // Register completion handler
    _flutterTts.setCompletionHandler(() {
      _currentCompleter?.complete();
      _currentCompleter = null;
    });
  }

  // TTS
  final FlutterTts _flutterTts = FlutterTts();
  bool voiceEnabled = true;
  double voiceVolume = 1.0;

  Completer<void>? _currentCompleter;

  /// TTS Speak
  Future<void> speak(String text) async {
  if (!voiceEnabled) return;

  await _flutterTts.setVolume(voiceVolume); // volume
  await _flutterTts.setPitch(1.0); // pitch 
  await _flutterTts.setSpeechRate(0.5); // rate 

  final completer = Completer<void>();

  _flutterTts.setCompletionHandler(() {
    if (!completer.isCompleted) {
      completer.complete();
    }
  });

  await _flutterTts.speak(text); // Call speak once
  return completer.future; // Wait until speech finishes
}

  Future<void> stopSpeak() async => await _flutterTts.stop();

  /// Toggle TTS
  void toggleVoice(bool value) {
    voiceEnabled = value;
    if (!voiceEnabled) stopSpeak();
  }

  void setVoiceVolume(double value) => voiceVolume = value;

  /// Haptic vibration
  bool hapticEnabled = true;
  double hapticStrength = 1.0;

  Future<void> vibrate(int baseDuration) async {
    if (!hapticEnabled) return; // to check if haptic function is enable
    if (await Vibration.hasVibrator() ?? false) {
      // calculates the vibration duration
      int duration = (baseDuration * hapticStrength).toInt();
      if (duration > 0)  {
        await Vibration.vibrate(duration: duration);
      }
    }
  }

  void toggleHaptic(bool value) => hapticEnabled = value; // enables/disables haptic feedback
  void setHapticStrength(double value) => hapticStrength = value; // adjust vibration strength
}
