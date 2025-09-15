import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:camera/camera.dart';
import 'settings_screen.dart';
import 'navigation_screen.dart';
import 'feeback_function.dart';
import '../main.dart';

class SelectDestinationScreen extends StatefulWidget {
  final CameraController cameraController;
  final String currentLocation;

  SelectDestinationScreen({
    required this.cameraController,
    required this.currentLocation,
  });

  @override
  _SelectDestinationScreenState createState() => _SelectDestinationScreenState();
}

class _SelectDestinationScreenState extends State<SelectDestinationScreen> with RouteAware {
  String? selectedItem; // The currently selected item
  bool waitingForConfirmation = false; // To track if we’re waiting for user to confirm

  final items = [
    'VIP Porch',
    'Cafeteria',
    'Toilet Cafe',
    'Toilet Add Musolla',
    'Musolla',
    'Cita Lab',
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
  void didPopNext() {
    // Called when returning from another screen
    _speakInstructions();
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _speakInstructions();
    });
  }

  void _speakInstructions() {
    FeedbackFunction().speak("Please select your destination.");
  }

  void _onItemFocus(String item) {
    // TTS announcement + gentle vibration when item gets focus
    FeedbackFunction().speak(item);
    FeedbackFunction().vibrate(50); // gentle vibration
  }

  void _onItemTap(String item) async {
    if (waitingForConfirmation && selectedItem == item) {

      if (widget.currentLocation == selectedItem){
        FeedbackFunction().speak("You are already at $item. Please select another location");
        FeedbackFunction().vibrate(600);

        setState(() {
          waitingForConfirmation = false;
          selectedItem = null;
        });

      } else{
        // User confirmed selection
        FeedbackFunction().speak("Confirmed. Navigating to $item");
        FeedbackFunction().vibrate(200); // stronger vibration
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => NavigationScreen(
              cameraController: widget.cameraController,
              destination: item,
              currentLocation: widget.currentLocation,
            ),
          ),
        );
        setState(() {
          waitingForConfirmation = false;
          selectedItem = null;
        });
      }    
    } else {
      // First tap: prompt for confirmation
      setState(() {
        selectedItem = item;
        waitingForConfirmation = true;
      });
      FeedbackFunction().speak("You selected $item. Tap again to confirm.");
      FeedbackFunction().vibrate(100); // medium vibration
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: PreferredSize(
        preferredSize: Size.fromHeight(130),
        child: Container(
          padding: const EdgeInsets.only(top: 40, left: 16, right: 16),
          height: 130,
          decoration: BoxDecoration(color: Color(0xFF000000)),
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
                        color: CupertinoColors.black,
                        size: 45,
                      ),
                    ),
                  ),
                ),
              ),
              IconButton(
                icon: Icon(CupertinoIcons.line_horizontal_3,
                    color: CupertinoColors.white, size: 70),
                onPressed: () {
                  if (widget.cameraController.value.isInitialized) {
                    FeedbackFunction().vibrate(600);
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => SettingsScreen(
                          cameraController: widget.cameraController,
                        ),
                      ),
                    );
                  }
                },
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
            child: Container(
              width: 350,
              padding: EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: CupertinoColors.white.withOpacity(0.7),
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black12,
                    blurRadius: 10,
                    offset: Offset(0, 4),
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: items.map((item) {
                  final isSelected = selectedItem == item;
                  return Container(
                    margin: EdgeInsets.symmetric(vertical: 6),
                    decoration: BoxDecoration(
                      color: isSelected
                          ? CupertinoColors.black
                          : CupertinoColors.systemGrey6,
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Focus(
                      onFocusChange: (hasFocus) {
                        if (hasFocus) _onItemFocus(item);
                      },
                      child: CupertinoButton(
                        padding:
                            EdgeInsets.symmetric(vertical: 16, horizontal: 12),
                        borderRadius: BorderRadius.circular(14),
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
                              fontWeight: FontWeight.w500,
                            ),
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