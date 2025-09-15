import 'package:flutter_tts/flutter_tts.dart';
import 'package:vibration/vibration.dart';
import 'dart:async';

class FeedbackFunction {
  // Singleton pattern
  static final FeedbackFunction _instance = FeedbackFunction._internal();
  factory FeedbackFunction() => _instance;
  FeedbackFunction._internal() {
    // Register completion handler once
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

  await _flutterTts.setVolume(voiceVolume);
  await _flutterTts.setPitch(1.0);
  await _flutterTts.setSpeechRate(0.5);

  final completer = Completer<void>();

  _flutterTts.setCompletionHandler(() {
    if (!completer.isCompleted) completer.complete();
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
    if (!hapticEnabled) return;
    if (await Vibration.hasVibrator() ?? false) {
      int duration = (baseDuration * hapticStrength).toInt();
      if (duration > 0) await Vibration.vibrate(duration: duration);
    }
  }

  void toggleHaptic(bool value) => hapticEnabled = value;
  void setHapticStrength(double value) => hapticStrength = value;
}
