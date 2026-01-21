import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:tflite_flutter/tflite_flutter.dart';
import 'package:image/image.dart' as img;
import 'package:tflite_flutter_helper/tflite_flutter_helper.dart';

import '../main.dart';
import 'navigation_screen.dart';
import 'feeback_function.dart';

class ObjectDetectionScreen extends StatefulWidget {
  final String destination;
  final String currentLocation;
  final String startNodeId;
  final String destNodeId;

  const ObjectDetectionScreen({
    Key? key,
    required this.destination,
    required this.currentLocation,
    required this.startNodeId,
    required this.destNodeId,
  }) : super(key: key);

  @override
  State<ObjectDetectionScreen> createState() => _ObjectDetectionScreenState();
}

class _ObjectDetectionScreenState extends State<ObjectDetectionScreen> {
  // ================= CAMERA =================
  late CameraController _cameraController;
  bool _isCameraInitialized = false;

  // ================= ML =================
  Interpreter? _interpreter;
  List<String> _labels = [];
  bool _isDetecting = false;
  List<Map<String, dynamic>> _results = [];

  DateTime _lastFeedbackTime = DateTime.now();

  Size get _previewSize {
    final s = _cameraController.value.previewSize!;
    return Size(s.height, s.width); // portrait swap
  }

  @override
  void initState() {
    super.initState();
    _initializeCamera();
    _initializeModel();
  }

  // ================= INIT =================
  Future<void> _initializeCamera() async {
    final rearCamera =
        cameras.firstWhere((c) => c.lensDirection == CameraLensDirection.back);

    _cameraController = CameraController(
      rearCamera,
      ResolutionPreset.medium,
      enableAudio: false,
      imageFormatGroup: ImageFormatGroup.yuv420,
    );

    await _cameraController.initialize();
    if (!mounted) return;

    setState(() => _isCameraInitialized = true);
    _startImageStream();
  }

  Future<void> _initializeModel() async {
    _interpreter = await Interpreter.fromAsset('detect.tflite');
    final labelsData =
        await DefaultAssetBundle.of(context).loadString('assets/labelmap.txt');
    _labels = labelsData.split('\n');
  }

  // ================= IMAGE STREAM (FROM YOUR WORKING CODE) =================
  Future<void> _startImageStream() async {
    if (_cameraController.value.isStreamingImages) {
      await _cameraController.stopImageStream();
    }

    _cameraController.startImageStream((CameraImage image) async {
      if (_isDetecting || _interpreter == null || _labels.isEmpty || !mounted) {
        return;
      }

      _isDetecting = true;

      try {
        final rgb = _convertCameraImageToRGB(image);
        final tensorImage = _preprocessImageWithHelper(rgb);

        var boxes =
            List.generate(1, (_) => List.generate(10, (_) => List.filled(4, 0.0)));
        var classes = List.generate(1, (_) => List.filled(10, 0.0));
        var scores = List.generate(1, (_) => List.filled(10, 0.0));
        var count = List.filled(1, 0.0);

        _interpreter!.runForMultipleInputs([tensorImage.buffer], {
          0: boxes,
          1: classes,
          2: scores,
          3: count,
        });

        final List<Map<String, dynamic>> detections = [];
        final int num = count[0].toInt();

        for (int i = 0; i < num; i++) {
          final score = scores[0][i];
          if (score < 0.6) continue;

          final label = _labels[classes[0][i].toInt()];
          final box = boxes[0][i];

          // EXACT SAME RECT LOGIC AS REFERENCE CODE
          final rect = Rect.fromLTWH(
            box[1] * 300,
            box[0] * 300,
            (box[3] - box[1]) * 300,
            (box[2] - box[0]) * 300,
          );

          detections.add({
            'rect': rect,
            'label': label,
            'confidence': score,
          });

          _provideFeedback(label, rect, score);
        }

        if (mounted) setState(() => _results = detections);
      } catch (e) {
        debugPrint('❌ Detection error: $e');
      }

      await Future.delayed(const Duration(milliseconds: 300));
      _isDetecting = false;
    });
  }

  // ================= FEEDBACK =================
  Future<void> _provideFeedback(String label, Rect rect, double confidence) async {
    final now = DateTime.now();
    if (now.difference(_lastFeedbackTime).inSeconds < 3) return;

    final normalizedHeight = rect.height / 300;
    String distanceText;
    int vibrationDuration;

    if (normalizedHeight > 0.6) {
      distanceText = "very near";
      vibrationDuration = 600;
    } else if (normalizedHeight > 0.3) {
      distanceText = "near";
      vibrationDuration = 300;
    } else {
      distanceText = "ahead";
      vibrationDuration = 100;
    }

    if (confidence > 0.7) {
      await FeedbackFunction().speak("$label $distanceText");
      await FeedbackFunction().vibrate(vibrationDuration);
      _lastFeedbackTime = now;
    }
  }

  // ================= IMAGE UTILS (UNCHANGED FROM REF CODE) =================
  img.Image _convertCameraImageToRGB(CameraImage image) {
    final rgbImage = img.Image(image.width, image.height);
    final y = image.planes[0];
    final u = image.planes[1];
    final v = image.planes[2];

    for (int row = 0; row < image.height; row++) {
      for (int col = 0; col < image.width; col++) {
        final uvIndex = (row ~/ 2) * u.bytesPerRow + (col ~/ 2);
        final yIndex = row * y.bytesPerRow + col;

        final yVal = y.bytes[yIndex];
        final uVal = u.bytes[uvIndex];
        final vVal = v.bytes[uvIndex];

        final r = (yVal + 1.370705 * (vVal - 128)).clamp(0, 255).toInt();
        final g =
            (yVal - 0.337633 * (uVal - 128) - 0.698001 * (vVal - 128))
                .clamp(0, 255)
                .toInt();
        final b =
            (yVal + 1.732446 * (uVal - 128)).clamp(0, 255).toInt();

        rgbImage.setPixel(col, row, img.getColor(r, g, b));
      }
    }

    final resized = img.copyResize(rgbImage, width: 300, height: 300);
    return MediaQuery.of(context).orientation == Orientation.portrait
        ? img.copyRotate(resized, 90)
        : resized;
  }

  TensorImage _preprocessImageWithHelper(img.Image image) {
    final tensorImage = TensorImage(TfLiteType.uint8);
    tensorImage.loadImage(image);

    return ImageProcessorBuilder()
        .add(ResizeOp(300, 300, ResizeMethod.BILINEAR))
        .build()
        .process(tensorImage);
  }

  // ================= OVERLAY (SAME MAPPING AS REF CODE) =================
  Widget _buildDetectionsOverlay() {
  return LayoutBuilder(builder: (context, constraints) {
    final previewW = constraints.maxWidth;
    final previewH = constraints.maxHeight;

    return Stack(
      children: _results.map((obj) {
        final Rect rect = obj['rect'];
        final String label = obj['label'];
        final double confidence = obj['confidence'];

        final left = rect.left / 300 * previewW;
        final top = rect.top / 300 * previewH;
        final width = rect.width / 300 * previewW;
        final height = rect.height / 300 * previewH;

        return Positioned(
          left: left,
          top: top,
          width: width,
          height: height,
          child: Container(
            decoration: BoxDecoration(
              border: Border.all(color: Colors.black, width: 2),
              borderRadius: BorderRadius.circular(4),
            ),
            child: Align(
              alignment: Alignment.topLeft,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                color: Colors.black,
                child: Text(
                  "$label ${(confidence * 100).toStringAsFixed(0)}%",
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ),
          ),
        );
      }).toList(),
    );
  });
}

  // ================= UI (UNCHANGED) =================
  void _backToNavigation() {
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (_) => NavigationScreen(
          destination: widget.destination,
          currentLocation: widget.currentLocation,
          startNodeId: widget.startNodeId,
          destNodeId: widget.destNodeId,
        ),
      ),
    );
  }

  @override
  void dispose() {
    _cameraController.dispose();
    _interpreter?.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      backgroundColor: Colors.transparent,
      body: Stack(
        children: [
          Positioned.fill(
            child: _isCameraInitialized
                ? OverflowBox(
                    alignment: Alignment.center,
                    child: FittedBox(
                      fit: BoxFit.cover,
                      child: SizedBox(
                        width: _previewSize.width,
                        height: _previewSize.height,
                        child: CameraPreview(_cameraController),
                      ),
                    ),
                  )
                : const SizedBox(),
          ),
          _buildDetectionsOverlay(),
          Positioned(
            bottom: 40,
            left: 20,
            right: 20,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.black,
                padding: const EdgeInsets.symmetric(vertical: 16),
              ),
              onPressed: _backToNavigation,
              child: const Text(
                "Back to AR Navigation",
                style: TextStyle(color: Colors.white, fontSize: 18),
              ),
            ),
          ),
        ],
      ),
    );
  }
}