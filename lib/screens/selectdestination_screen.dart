import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:camera/camera.dart';

import 'settings_screen.dart';
import 'navigation_screen.dart';
import 'feeback_function.dart';
import '../main.dart';
import '../utils/node_map.dart';
import '../screens/navigation_loading_screen.dart';

class SelectDestinationScreen extends StatefulWidget {
  final CameraController cameraController;
  final String currentLocation;

  const SelectDestinationScreen({
    super.key,
    required this.cameraController,
    required this.currentLocation,
  });

  @override
  State<SelectDestinationScreen> createState() =>
      _SelectDestinationScreenState();
}

class _SelectDestinationScreenState extends State<SelectDestinationScreen>
    with RouteAware {
  String? selectedItem;
  bool waitingForConfirmation = false;
  bool _navigating = false;

  final items = [
    'Cafeteria',
    'Toilet Cafe',
    'VIP Porch',
    'Musolla',
    'Lobby',
    'Main Entrance',
  ];

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    routeObserver.subscribe(this, ModalRoute.of(context)!);
  }

  @override
  void dispose() {
    routeObserver.unsubscribe(this);
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      FeedbackFunction().speak("Please select your destination.");
    });
  }

  String toNodeId(String readable) {
    if (readable.startsWith('N_')) return readable;
    return placeToNodeId[readable] ?? '';
  }

  Future<void> _onItemTap(String item) async {
    if (_navigating) return;

    if (waitingForConfirmation && selectedItem == item) {
      if (widget.currentLocation == item) {
        FeedbackFunction().speak(
            "You are already at $item. Please select another location");
        FeedbackFunction().vibrate(600);
        setState(() {
          waitingForConfirmation = false;
          selectedItem = null;
        });
        return;
      }

      _navigating = true;

      final startNodeId = toNodeId(widget.currentLocation);
      final destNodeId = toNodeId(item);

      if (startNodeId.isEmpty || destNodeId.isEmpty) {
        FeedbackFunction().speak("Navigation failed. Node mapping missing.");
        _navigating = false;
        return;
      }

      FeedbackFunction().speak("Navigating to $item");
      FeedbackFunction().vibrate(200);

      // ==============================
      // 🔴 SAFE CAMERA HANDOVER
      // ==============================
      try {
        if (widget.cameraController.value.isStreamingImages) {
          await widget.cameraController.stopImageStream();
        }
        if (widget.cameraController.value.isInitialized) {
          await widget.cameraController.dispose();
        }
      } catch (_) {}

      // 🚨 GIVE ANDROID TIME TO RELEASE CAMERA
      await Future.delayed(const Duration(milliseconds: 500));
      if (!mounted) return;

      // ==============================
      // 🔴 STEP 1: PUSH LOADING SCREEN
      // ==============================
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => const NavigationLoadingScreen(),
        ),
      );

      // 🚨 LET LOADING SCREEN RENDER
      await WidgetsBinding.instance.endOfFrame;
      await Future.delayed(const Duration(milliseconds: 300));

      if (!mounted) return;

      // ==============================
      // 🔴 STEP 2: REPLACE WITH UNITY PAGE
      // ==============================
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (_) => NavigationScreen(
            destination: item,
            currentLocation: widget.currentLocation,
            startNodeId: startNodeId,
            destNodeId: destNodeId,
          ),
        ),
      );

      _navigating = false;
    } else {
      setState(() {
        selectedItem = item;
        waitingForConfirmation = true;
      });
      FeedbackFunction().speak("You selected $item. Tap again to confirm.");
      FeedbackFunction().vibrate(100);
    }
  }

  // ==============================
  // UI (UNCHANGED)
  // ==============================
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(130),
        child: Container(
          padding: const EdgeInsets.only(top: 40, left: 16, right: 16),
          height: 130,
          decoration: const BoxDecoration(color: Color(0xFF000000)),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Material(
                shape: const CircleBorder(),
                color: CupertinoColors.white,
                elevation: 4,
                child: InkWell(
                  customBorder: const CircleBorder(),
                  onTap: () => Navigator.pop(context),
                  child: const SizedBox(
                    width: 60,
                    height: 60,
                    child: Icon(Icons.arrow_back_ios_new_rounded, size: 45),
                  ),
                ),
              ),
              IconButton(
                icon: const Icon(CupertinoIcons.line_horizontal_3,
                    color: CupertinoColors.white, size: 70),
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => SettingsScreen(
                        cameraController: widget.cameraController,
                      ),
                    ),
                  );
                },
              ),
            ],
          ),
        ),
      ),
      body: Stack(
        children: [
          Positioned.fill(child: CameraPreview(widget.cameraController)),
          BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
            child: Container(color: CupertinoColors.black.withOpacity(0.1)),
          ),
          Center(
            child: Container(
              width: 350,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: CupertinoColors.white.withOpacity(0.7),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: items.map((item) {
                  final isSelected = selectedItem == item;
                  return Container(
                    margin: const EdgeInsets.symmetric(vertical: 6),
                    decoration: BoxDecoration(
                      color: isSelected
                          ? CupertinoColors.black
                          : CupertinoColors.systemGrey6,
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: CupertinoButton(
                      padding: const EdgeInsets.symmetric(
                          vertical: 16, horizontal: 12),
                      onPressed: () => _onItemTap(item),
                      child: Align(
                        alignment: Alignment.centerLeft,
                        child: Text(
                          item,
                          style: TextStyle(
                            color: isSelected
                                ? CupertinoColors.white
                                : CupertinoColors.black,
                            fontSize: 18,
                          ),
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
