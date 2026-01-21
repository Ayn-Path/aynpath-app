import 'dart:async';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter_unity_widget/flutter_unity_widget.dart';

import '../utils/unity_bridge.dart';
import '../screens/feeback_function.dart';
import 'home_screen.dart';
import 'objectDetection_screen.dart';

class NavigationScreen extends StatefulWidget {
  final String destination;
  final String currentLocation;
  final String startNodeId;
  final String destNodeId;

  const NavigationScreen({
    super.key,
    required this.destination,
    required this.currentLocation,
    required this.startNodeId,
    required this.destNodeId,
  });

  @override
  State<NavigationScreen> createState() => _NavigationScreenState();
}

class _NavigationScreenState extends State<NavigationScreen> {
  final UnityBridge _bridge = UnityBridge();
  Timer? _pollTimer;

  bool _unityStarted = false;

  String _instructionText = 'Starting navigation…';
  String _distanceText = '-- m';
  String? _lastSpokenInstruction;

  bool _showArrivedDialog = false;
  bool _confirmAgain = false; // 🔴 DOUBLE CONFIRM STATE

  @override
  void initState() {
    super.initState();

    _bridge.onNavigationUpdate =
        (instruction, distance, arrived) {
      if (!mounted) return;

      setState(() {
        if (instruction.isNotEmpty) {
          _instructionText = instruction;
        }
        if (distance >= 0) {
          _distanceText = '${distance.toStringAsFixed(1)} m';
        }
        if (arrived) {
          _showArrivedDialog = true;
          _pollTimer?.cancel();
        }
      });

      if (instruction.isNotEmpty &&
          instruction != _lastSpokenInstruction) {
        FeedbackFunction().speak(instruction);
        _lastSpokenInstruction = instruction;
      }
    };
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    FeedbackFunction().stopSpeak();
    super.dispose();
  }

  Future<void> _onUnityCreated(UnityWidgetController controller) async {
    _bridge.onUnityCreated(controller);

    await Future.delayed(const Duration(milliseconds: 500));
    if (!mounted || _unityStarted) return;

    _unityStarted = true;

    _bridge.calibrate(widget.startNodeId);
    _bridge.startNavigation(
      widget.startNodeId,
      widget.destNodeId,
    );

    _pollTimer = Timer.periodic(
      const Duration(milliseconds: 700),
      (_) => _bridge.requestNavigationState(),
    );
  }

  // =============================
  // ACTIONS
  // =============================

  void _goToObjectDetection() {
    _pollTimer?.cancel();
    FeedbackFunction().stopSpeak();

    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (_) => ObjectDetectionScreen(
          destination: widget.destination,
          currentLocation: widget.currentLocation,
          startNodeId: widget.startNodeId,
          destNodeId: widget.destNodeId,
        ),
      ),
    );
  }

  void _confirmArrived() {
    if (!_confirmAgain) {
      setState(() {
        _confirmAgain = true;
      });
      FeedbackFunction().speak("Press confirm again to finish navigation.");
      return;
    }

    _goHome();
  }

  void _goHome() {
    _pollTimer?.cancel();
    FeedbackFunction().stopSpeak();

    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (_) => HomeScreen()),
      (_) => false,
    );
  }

  // =============================
  // UI
  // =============================
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          // =============================
          // UNITY VIEW
          // =============================
          UnityWidget(
            useAndroidViewSurface: true,
            onUnityCreated: _onUnityCreated,
            onUnityMessage: _bridge.onUnityMessage,
          ),

          // =============================
          // BOTTOM INFO PANEL
          // =============================
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: Container(
              height: 250,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.9),
                borderRadius:
                    const BorderRadius.vertical(top: Radius.circular(25)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      width: 40,
                      height: 5,
                      margin: const EdgeInsets.only(bottom: 16),
                      decoration: BoxDecoration(
                        color: Colors.grey[400],
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                  ),
                  Row(
                    children: [
                      const Icon(
                        CupertinoIcons.location_circle_fill,
                        size: 70,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Destination to',
                              style: TextStyle(fontSize: 18),
                            ),
                            const SizedBox(height: 7),
                            Row(
                              children: [
                                Text(
                                  widget.destination,
                                  style: const TextStyle(
                                    fontSize: 20,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                const Spacer(),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 10, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: Colors.black,
                                    borderRadius: BorderRadius.circular(20),
                                  ),
                                  child: Text(
                                    _distanceText,
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 20,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 20),
                            Text(
                              _instructionText,
                              style: const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.black,
                        padding:
                            const EdgeInsets.symmetric(vertical: 14),
                      ),
                      onPressed: _goToObjectDetection,
                      child: const Text(
                        'Switch to Object Detection',
                        style: TextStyle(color: Colors.white),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),

          // =============================
          // ARRIVED DIALOG + BLUR
          // =============================
          if (_showArrivedDialog)
            Positioned.fill(
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
                child: Container(
                  color: Colors.black54,
                  child: Center(
                    child: Container(
                      padding: const EdgeInsets.all(20),
                      width: MediaQuery.of(context).size.width * 0.85,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: const [
                              Icon(
                                CupertinoIcons.location_solid,
                                size: 36,
                              ),
                              SizedBox(width: 12),
                              Text(
                                'You have arrived',
                                style: TextStyle(
                                  fontSize: 22,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),

                          const SizedBox(height: 12),

                          Text(
                            _confirmAgain
                                ? 'Press confirm again to finish'
                                : 'Please confirm your arrival',
                            style: const TextStyle(fontSize: 16),
                          ),

                          const SizedBox(height: 24),

                          SizedBox(
                            width: double.infinity,
                            child: ElevatedButton(
                              onPressed: _confirmArrived,
                              child: Text(
                                _confirmAgain ? 'Confirm Again' : 'Confirm',
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}