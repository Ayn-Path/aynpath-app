import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:camera/camera.dart';
import 'feeback_function.dart';

class SettingsScreen extends StatefulWidget {
  final CameraController cameraController;
  SettingsScreen({required this.cameraController});

  @override
  _SettingsScreenState createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  bool isVoiceEnabled = FeedbackFunction().voiceEnabled;
  double voiceVolume = FeedbackFunction().voiceVolume;

  bool isHapticEnabled = FeedbackFunction().hapticEnabled;
  double hapticStrength = FeedbackFunction().hapticStrength;

  @override
  void initState() {
    super.initState();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _speakInstructions(); // Speak instructions
    });
  }

  @override
  void didPopNext() {
    _speakInstructions(); // repeat instructions
  }

  void _speakInstructions() async {
    const instructionText = "Settings";
    FeedbackFunction().speak(instructionText);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      backgroundColor: Colors.transparent,
      appBar: PreferredSize(
        preferredSize: Size.fromHeight(130),
        child: Container(
          padding: EdgeInsets.only(top: 40, left: 16, right: 16),
          height: 130,
          decoration: BoxDecoration(
            color: Color(0xFF000000),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Material(
                shape: CircleBorder(),
                color: CupertinoColors.white.withOpacity(0.8),
                elevation: 4,
                child: InkWell(
                  customBorder: CircleBorder(),
                  onTap: () {
                    FeedbackFunction().vibrate(300); // short vibration
                    Navigator.pop(context);
                  },
                  child: SizedBox(
                    width: 60,
                    height: 60,
                    child: Center(
                      child: Icon(
                          Icons.arrow_back_ios_new_rounded,
                          color: CupertinoColors.black, size: 45
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
      body: Stack(
        children: [
          Positioned.fill(
            child: CameraPreview(widget.cameraController),
          ),
          BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
            child: Container(color: CupertinoColors.black.withOpacity(0.1)),
          ),
          Center(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(20),
              child: Container(
                width: 300,
                height: 350,
                padding: EdgeInsets.all(16),
                color: CupertinoColors.white.withOpacity(0.8),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    SizedBox(height: 20),
                    _buildSettingRow(
                      title: 'Voice',
                      enabled: isVoiceEnabled,
                      sliderValue: voiceVolume,
                      onToggle: (value) {
                        setState(() {
                          isVoiceEnabled = value;
                          FeedbackFunction().toggleVoice(value);
                          FeedbackFunction().speak("Voice ${value ? 'On' : 'Off'}");
                        });
                      },
                      onSliderChanged: (value) {
                        setState(() {
                          voiceVolume = value;
                          FeedbackFunction().setVoiceVolume(value);
                        });
                      },
                    ),
                    SizedBox(height: 20),
                    Divider(),
                    SizedBox(height: 20),
                    _buildSettingRow(
                      title: 'Haptic',
                      enabled: isHapticEnabled,
                      sliderValue: hapticStrength,
                      onToggle: (value) {
                        setState(() {
                          isHapticEnabled = value;
                          FeedbackFunction().toggleHaptic(value);
                          FeedbackFunction().speak("Haptic ${value ? 'On' : 'Off'}");
                        });
                      },
                      onSliderChanged: (value) {
                        setState(() {
                          hapticStrength = value;
                          FeedbackFunction().setHapticStrength(value);
                        });
                      },
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSettingRow({
    required String title,
    required bool enabled,
    required double sliderValue,
    required Function(bool) onToggle,
    required Function(double) onSliderChanged,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(title, style: TextStyle(fontSize: 30, fontWeight: FontWeight.w400)),
            Switch(
              value: enabled,
              onChanged: onToggle,
              activeColor: Colors.white,
              activeTrackColor: Colors.green,
              inactiveThumbColor: Colors.grey,
              inactiveTrackColor: Colors.grey.shade300,
            ),
          ],
        ),
        SizedBox(height: 15),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Icon(Icons.volume_off_rounded, size: 40),
            Expanded(
              child: Slider(
                value: sliderValue,
                onChanged: enabled ? onSliderChanged : null,
                activeColor: CupertinoColors.activeBlue,
                inactiveColor: Colors.grey.shade300,
              ),
            ),
            Icon(Icons.volume_up_rounded, size: 40),
          ],
        ),
      ],
    );
  }
}