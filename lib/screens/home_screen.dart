import 'dart:convert';
import 'dart:io';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:flutter/cupertino.dart';
import 'package:http/http.dart' as http;
import 'selectdestination_screen.dart';
import 'settings_screen.dart';
import 'feeback_function.dart';
import '../main.dart';

class HomeScreen extends StatefulWidget {
  @override
  _HomeScreenState createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with RouteAware {
  CameraController? _controller;
  bool _isInitialized = false;

  bool loading = false;
  bool showBottomContent = false;

  // Bottom content text
  String bottomText1 = "Localization in Progress...";
  String bottomText2 =
      "Please hold your device still for a moment while we try to find your location";

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    routeObserver.subscribe(this, ModalRoute.of(context)!);
  }

  @override
  void initState() {
    super.initState();
    initializeCamera();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _speakInstructions();
    });
  }

  @override
  void didPopNext() {
    // Reset UI and speak instructions when coming back
    _speakInstructions();
    setState(() {
      loading = false;
      showBottomContent = false;
      bottomText1 = "Localization in Progress...";
      bottomText2 =
          "Please hold your device still for a moment while we try to find your location";
    });
  }

  void _speakInstructions() async {
    const instructionText =
        "Tap the shutter button below to start scanning your surroundings.";
    FeedbackFunction().speak(instructionText);
  }

  Future<void> initializeCamera() async {
    final status = await Permission.camera.request();
    if (status.isGranted && cameras.isNotEmpty) {
      _controller = CameraController(cameras[0], ResolutionPreset.medium);
      await _controller!.initialize();
      setState(() {
        _isInitialized = true;
      });
    } else {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text("Camera Permission Denied")));
    }
  }

  @override
  void dispose() {
    FeedbackFunction().stopSpeak();
    _controller?.dispose();
    routeObserver.unsubscribe(this);
    super.dispose();
  }

String currentLocation = 'Unknown';

  // ==============================
  // CAMERA BUTTON CLICKED
  // ==============================
  void _onCameraButtonClicked() async {
    FeedbackFunction().vibrate(300);
    if (_controller == null || !_controller!.value.isInitialized) return;

    setState(() {
      loading = true;
      showBottomContent = true;
      bottomText1 = "Localization in Progress...";
      bottomText2 =
        "Please hold your device still for a moment while we try to find your location";
    });

    // Speak first message
    await FeedbackFunction().speak(bottomText1 + " " + bottomText2);
    try {
      // Capture image
      final XFile image = await _controller!.takePicture();

      // API request
      final request = http.MultipartRequest(
        'POST',
        Uri.parse('http://192.168.1.11:5000/predict_location'),
      );
      request.files.add(await http.MultipartFile.fromPath('image', image.path));

      final response = await request.send();

      if (response.statusCode == 200) {
        final respStr = await response.stream.bytesToString();
        final data = json.decode(respStr);

        // Check if location is recognized
        if (data['predicted_location'] == null || (data['good_matches'] ?? 0) < 20) {
          setState(() {
            bottomText1 = "Location Not Recognized!";
            bottomText2 = "Please hold your device steady and scan again";
            FeedbackFunction().vibrate(100);
            loading = true;
            showBottomContent = true;
          });          
          await FeedbackFunction().speak(bottomText1 + " " + bottomText2);
          showBottomContent = false;
          // Do NOT navigate, user can try again
          return;
        }

        // Valid location → update bottom text and navigate
        setState(() {
          bottomText1 = "Location Detected!";
          bottomText2 = "You are at ${data['predicted_location']}";
          currentLocation = data['predicted_location'];
          FeedbackFunction().vibrate(600);
        });

        await FeedbackFunction().speak(bottomText1 + " " + bottomText2);

        // Optional small delay
        await Future.delayed(Duration(seconds: 1));

        // Navigate to SelectDestinationScreen
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => SelectDestinationScreen(
              cameraController: _controller!,
              currentLocation: currentLocation,
            ),
          ),
        );

      } else {
        setState(() {
          bottomText1 = "Error";
          bottomText2 = "Failed to get location from server";
        });
      }
    } catch (e) {
        setState(() {
          bottomText1 = "Error";
          bottomText2 = e.toString();
        });
      } finally {
          setState(() {
            loading = false;
          });
        }
  }


  @override
  Widget build(BuildContext context) {
    if (_controller == null || !_isInitialized) {
      return Scaffold(
        backgroundColor: CupertinoColors.black,
        body: Center(child: CircularProgressIndicator()),
      );
    }

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
              SizedBox(width: 60),
              IconButton(
                icon: Icon(
                  CupertinoIcons.line_horizontal_3,
                  color: CupertinoColors.white,
                  size: 70,
                ),
                onPressed: () {
                  FeedbackFunction().vibrate(300);
                  FeedbackFunction().stopSpeak();
                  if (_controller != null && _controller!.value.isInitialized) {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) =>
                            SettingsScreen(cameraController: _controller!),
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
          // Camera preview
          Positioned.fill(
            child: FittedBox(
              fit: BoxFit.cover,
              child: SizedBox(
                width: _controller!.value.previewSize!.height,
                height: _controller!.value.previewSize!.width,
                child: CameraPreview(_controller!),
              ),
            ),
          ),

          // Instruction box
          Center(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: Container(
                width: 250,
                height: 250,
                padding: EdgeInsets.all(16),
                color: CupertinoColors.white.withOpacity(0.4),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      CupertinoIcons.camera_viewfinder,
                      size: 64,
                      color: CupertinoColors.white,
                      shadows: [
                        Shadow(
                          color: CupertinoColors.black.withOpacity(0.5),
                          offset: Offset(2, 2),
                          blurRadius: 2,
                        ),
                      ],
                    ),
                    SizedBox(height: 12),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 32.0),
                      child: Text(
                        "Tap the shutter button below to start scanning your surroundings.",
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: CupertinoColors.white,
                          fontSize: 16,
                          shadows: [
                            Shadow(
                              color: CupertinoColors.black.withOpacity(0.5),
                              offset: Offset(2, 2),
                              blurRadius: 2,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),

          // Camera button
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: Container(
              height: 200,
              decoration: BoxDecoration(color: Color(0xFF000000)),
              child: Center(
                child: GestureDetector(
                  onTap: _onCameraButtonClicked,
                  child: Container(
                    width: 100,
                    height: 100,
                    decoration: BoxDecoration(
                      color: CupertinoColors.white,
                      shape: BoxShape.circle,
                    ),
                    child: Center(
                      child: Container(
                        width: 90,
                        height: 90,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border:
                              Border.all(color: CupertinoColors.black, width: 3),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),

          // Loading overlay
          if (loading)
            Positioned.fill(
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                child: Container(
                  color: CupertinoColors.black.withOpacity(0.1),
                ),
              ),
            ),

          if (loading)
            Center(
              child: CircularProgressIndicator(
                valueColor:
                    AlwaysStoppedAnimation<Color>(CupertinoColors.black),
              ),
            ),

          // Bottom content
          if (showBottomContent)
            Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              child: Container(
                height: 200,
                decoration: BoxDecoration(
                  color: CupertinoColors.white,
                ),
                child: BottomContent(
                  text1: bottomText1,
                  text2: bottomText2,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

// Bottom content widget
class BottomContent extends StatelessWidget {
  final String text1;
  final String text2;

  BottomContent({required this.text1, required this.text2});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.all(16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(height: 10),
          Text(
            text1,
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
          ),
          SizedBox(height: 30),
          Text(
            text2,
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 18),
          ),
          SizedBox(height: 10),
        ],
      ),
    );
  }
}