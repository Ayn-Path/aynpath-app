import 'dart:convert'; // to conver to json
import 'dart:io';
import 'dart:ui'; // image filters (blur effect)
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
  bool _isInitialized = false; // to indicate when the cam preview is ready

  bool loading = false;
  bool showBottomContent = false;

  List<XFile> capturedImages = []; // To save all the capture images in array
  int photoCount = 0;
  final int totalPhotos = 3;

  // The instruction text for the home screen
  String instructionText = "Tap the shutter button below to start scanning your surroundings.";
  bool isProcessing = false;
  
  // Bottom content text
  String bottomText1 = "Localization in Progress...";
  String bottomText2 = "Please hold your device still for a moment while we try to find your location";

  // It connects with the routeObserver from main
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

  // Reset UI and speak instructions when coming back
  @override
  void didPopNext() {
    _speakInstructions();
    setState(() {
      loading = false;
      showBottomContent = false;
      bottomText1 = "Localization in Progress...";
      bottomText2 = "Please hold your device still for a moment while we try to find your location";
    });
  }

  // For tts to read the instruction
  void _speakInstructions() async {
    const instructionText = "Tap the shutter button below to start scanning your surroundings.";
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

  String currentLocation = 'Unknown'; //Initialize the user's current location

  void _onCameraButtonClicked() async {
    if (_controller == null || !_controller!.value.isInitialized || isProcessing) return;
    
    FeedbackFunction().vibrate(200); // add vibration when taking photos
    
    try {
      final XFile image = await _controller!.takePicture();
      capturedImages.add(image);
      photoCount++;

      // Update instruction text depends on the photo taken
      if (photoCount == 1) {
        instructionText = "Nice! Now tap the shutter button again to take your second photo.";
        FeedbackFunction().speak(instructionText);
      } else if (photoCount == 2) {
        instructionText = "Almost done! Tap the shutter button one last time to capture your final photo.";
        FeedbackFunction().speak(instructionText);
      } else if (photoCount == totalPhotos) {
        isProcessing = true;
        setState(() {});
        await _uploadImages(); // upload all 3
        return;
      }
      
      setState(() {});
      FeedbackFunction().speak(instructionText); // to read all the instructions based on the photoCount

    } catch (e) {
      print("Error taking photo: $e");
    }
  }

  Future<void> _uploadImages() async {
  setState(() {
    loading = true;
    showBottomContent = true;
    bottomText1 = "Localization in Progress...";
    bottomText2 = "Please hold your device still for a moment while we try to find your location";
  });

  await FeedbackFunction().speak(bottomText1 + " " + bottomText2);

  try {
    // To show what files are being uploaded
    print("Preparing to upload ${capturedImages.length} images...");
    for (var img in capturedImages) {
      print("Image path: ${img.path}");
      if (!await File(img.path).exists()) {
        print("File does not exist: ${img.path}");
      }
    }

    // To send all the photos to the server
    var request = http.MultipartRequest(
      'POST',
      Uri.parse('http://172.20.10.3:5000/predict_location'),
    )
      ..headers.addAll({
        "Accept": "application/json",
        "Content-Type": "multipart/form-data",
        "Connection": "keep-alive",
      });

    // Add headers (important for Render/Flask CORS)
    request.headers.addAll({
      "Accept": "application/json",
    });

    // Attach images
    for (int i = 0; i < capturedImages.length; i++) {
      final file = File(capturedImages[i].path);
      request.files.add(await http.MultipartFile.fromPath(
        'image$i', // this matches server key naming since this apps take 3 photos and needs to upload it into the server
        file.path,
      ));
    }

    // Debug message for server status
    print("Sending request to server...");
    
    var response = await request.send();
    print("Response status: ${response.statusCode}");
    print("Response reason: ${response.reasonPhrase}");

    final respStr = await response.stream.bytesToString();
    print("Response body: $respStr");

    if (response.statusCode == 200) {
      final data = json.decode(respStr);
      String? location = data['predicted_location'];
      int matches = data['good_matches'] ?? 0;

      // To check if the photo is null or the matches low then 20, it will shows error message
      if (location == null || matches < 20) {
        setState(() {
          bottomText1 = "Location Not Recognized!";
          bottomText2 = "Please hold your device steady and scan again";
          loading = false;
          showBottomContent = true;
        });
        FeedbackFunction().vibrate(100);
        await FeedbackFunction().speak(bottomText1 + " " + bottomText2);
        return;
      }

      setState(() {
        bottomText1 = "Location Detected!";
        bottomText2 = "You are at $location";
        currentLocation = location;
        loading = false;
      });

      FeedbackFunction().vibrate(600);
      await FeedbackFunction().speak(bottomText1 + " " + bottomText2);
      await Future.delayed(const Duration(seconds: 1));

      // It will go to the next page if the location is detected
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
      // If there is a connection problem with the server
      setState(() {
        bottomText1 = "Server Error";
        bottomText2 = "Failed to get response from server";
        loading = false;
      });
      await FeedbackFunction().speak(bottomText1 + " " + bottomText2);
    }
  } catch (e) {
    setState(() {
      bottomText1 = "Error";
      bottomText2 = e.toString();
      loading = false;
    });
    await FeedbackFunction().speak("An error occurred. " + bottomText2);
    print("Upload error: $e");
  } finally {
    capturedImages.clear();
    photoCount = 0;
    isProcessing = false;
    setState(() {
      instructionText = "Tap the shutter button below to start scanning your surroundings.";
      loading = false;
      showBottomContent = false;
    });
  }
}

// UI
  @override
  Widget build(BuildContext context) {
    if (_controller == null || !_isInitialized) {
      return Scaffold(
        backgroundColor: CupertinoColors.black,
        body: Center(child: CircularProgressIndicator()),
      );
    }
    // Appbar
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
                  FeedbackFunction().stopSpeak(); // to make sure the tts stop after go to next page
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
      // Body
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
                        instructionText,
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