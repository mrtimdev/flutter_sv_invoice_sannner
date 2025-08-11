import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:google_ml_kit/google_ml_kit.dart';

// Ensure you have added the camera and google_ml_kit dependencies to your pubspec.yaml:
// dependencies:
//   flutter:
//     sdk: flutter
//   camera: ^0.10.5+9
//   google_ml_kit: ^0.16.3

class ScanLineCameraScreen extends StatefulWidget {
  const ScanLineCameraScreen({super.key});

  @override
  State<ScanLineCameraScreen> createState() => _ScanLineCameraScreenState();
}

class _ScanLineCameraScreenState extends State<ScanLineCameraScreen> {
  // Camera and OCR variables
  late CameraController _controller;
  late Future<void> _initializeControllerFuture;
  final _textRecognizer = GoogleMlKit.vision.textRecognizer();
  bool _isDetecting = false;
  bool _isDisposed = false;
  String _detectedText = '';

  // Configuration constants for scan lines
  // These values might need adjustment based on your device and desired layout
  static const _numberOfLines = 8; // Number of horizontal scan lines
  static const _lineHeight = 40.0; // Vertical spacing between lines
  static const _startYOffset = 100.0; // Starting Y-offset from the top of the camera preview
  static const _lineColor = Colors.green; // Color of the scan lines
  static const _lineThickness = 2.0; // Thickness of the scan lines
  static const _lineOpacity = 0.7; // Opacity of the scan lines

  @override
  void initState() {
    super.initState();
    _initializeControllerFuture = _initCamera();
  }

  Future<void> _initCamera() async {
    try {
      final cameras = await availableCameras();
      if (cameras.isEmpty) {
        throw Exception('No cameras found');
      }

      // Prefer back camera, otherwise use the first available camera
      final backCamera = cameras.firstWhere(
        (c) => c.lensDirection == CameraLensDirection.back,
        orElse: () => cameras.first,
      );

      _controller = CameraController(
        backCamera,
        ResolutionPreset.medium, // Medium resolution is often a good balance for OCR
        enableAudio: false,
      );

      await _controller.initialize();

      if (!mounted) return;
      // Start streaming images for OCR processing only if the controller is initialized
      if (_controller.value.isInitialized) {
        _controller.startImageStream(_processCameraFrame);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Camera error: ${e.toString()}')),
        );
      }
      debugPrint('Camera initialization error: $e'); // Log the error for debugging
      rethrow; // Re-throw to propagate the error to the FutureBuilder
    }
  }

  Future<void> _processCameraFrame(CameraImage image) async {
    if (_isDetecting || _isDisposed) return; // Prevent multiple detections and process after dispose
    _isDetecting = true;

    try {
      final inputImage = _convertToInputImage(image);
      final recognizedText = await _textRecognizer.processImage(inputImage);

      if (!mounted || _isDisposed) return; // Check mount state again after async operation

      final matchedText = _extractTextFromLines(recognizedText);
      if (matchedText.isNotEmpty) {
        setState(() => _detectedText = matchedText.join('\n'));
      }
    } catch (e) {
      debugPrint("OCR Error: $e");
    } finally {
      if (!_isDisposed) _isDetecting = false; // Reset detection flag if not disposed
    }
  }

  InputImage _convertToInputImage(CameraImage image) {
    // Determine the rotation based on camera orientation.
    // This is a simplified approach; for a robust solution, you might
    // need to consider the device's current orientation as well.
    InputImageRotation rotation;
    switch (_controller.description.sensorOrientation) {
      case 90:
        rotation = InputImageRotation.rotation90deg;
        break;
      case 180:
        rotation = InputImageRotation.rotation180deg;
        break;
      case 270:
        rotation = InputImageRotation.rotation270deg;
        break;
      default:
        rotation = InputImageRotation.rotation0deg;
    }

    // Convert camera image format to InputImageFormat
    final InputImageFormat format =
        InputImageFormatValue.fromRawValue(image.format.raw) ?? InputImageFormat.nv21;

    final inputImageData = InputImageMetadata(
      size: Size(image.width.toDouble(), image.height.toDouble()),
      rotation: rotation,
      format: format,
      bytesPerRow: image.planes.first.bytesPerRow,
    );

    // Combine planes into a single Uint8List
    final bytes = image.planes.fold<Uint8List>(
      Uint8List(0),
      (Uint8List previous, Plane plane) => Uint8List.fromList(
        previous + plane.bytes,
      ),
    );

    return InputImage.fromBytes(bytes: bytes, metadata: inputImageData);
  }

  List<String> _extractTextFromLines(RecognizedText recognizedText) {
    final matchedText = <String>[];

    // Get the dimensions of the CameraPreview widget on the screen
    // This requires the context to be available and rendered
    final double screenWidth = MediaQuery.of(context).size.width;
    // Calculate the height of the camera preview based on its aspect ratio
    // Assuming the camera preview takes the full width and maintains its aspect ratio
    final double cameraPreviewAspectRatio = _controller.value.aspectRatio;
    final double cameraPreviewHeight = screenWidth / cameraPreviewAspectRatio;

    // Calculate scaling factors to convert ML Kit's raw image coordinates
    // to screen coordinates relative to the CameraPreview.
    // We need to ensure _controller.value.previewSize is not null.
    if (_controller.value.previewSize == null) {
      debugPrint("Camera preview size is null, cannot scale coordinates.");
      return matchedText;
    }

    final double widthScaleFactor = screenWidth / _controller.value.previewSize!.width;
    final double heightScaleFactor = cameraPreviewHeight / _controller.value.previewSize!.height;


    for (final textBlock in recognizedText.blocks) {
      // Scale the bounding box coordinates of the text block to screen coordinates
      final scaledBlockTop = textBlock.boundingBox.top * heightScaleFactor;
      final scaledBlockBottom = textBlock.boundingBox.bottom * heightScaleFactor;
      final scaledBlockLeft = textBlock.boundingBox.left * widthScaleFactor;
      final scaledBlockRight = textBlock.boundingBox.right * widthScaleFactor;

      for (int i = 0; i < _numberOfLines; i++) {
        final lineTop = _startYOffset + (i * _lineHeight);
        final lineBottom = lineTop + _lineHeight;

        // Check for overlap between the scaled text block and the current scan line
        // A text block is considered to be "on" a line if any part of it
        // falls within the vertical bounds of the line.
        if (
            // Text block starts above line, ends within or below line
            (scaledBlockTop <= lineBottom && scaledBlockBottom >= lineTop)
           ) {
          matchedText.add(textBlock.text);
          break; // Found a line match for this block, move to the next block
        }
      }
    }
    return matchedText;
  }

  // Widget to draw the horizontal scan lines
  Widget _buildLineOverlays() {
    return IgnorePointer(
      child: Stack( // Use Stack to position the lines precisely
        children: List.generate(_numberOfLines, (i) {
          final topPosition = _startYOffset + (i * _lineHeight);
          return Positioned(
            top: topPosition,
            left: 0,
            right: 0,
            child: Container(
              height: _lineThickness,
              color: _lineColor.withOpacity(_lineOpacity),
            ),
          );
        }),
      ),
    );
  }

  @override
  void dispose() {
    _isDisposed = true; // Set flag to prevent further processing
    _controller.dispose(); // Dispose camera controller
    _textRecognizer.close(); // Close ML Kit text recognizer
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Live Scan Line OCR")),
      body: FutureBuilder<void>(
        future: _initializeControllerFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.done) {
            // If the Future is complete, display the camera preview
            if (snapshot.hasError) {
              return Center(child: Text('Error: ${snapshot.error}'));
            }
            return _buildCameraPreview();
          } else {
            // Otherwise, display a loading indicator
            return const Center(child: CircularProgressIndicator());
          }
        },
      ),
    );
  }

  Widget _buildCameraPreview() {
    // Ensure the controller is initialized before attempting to use it
    if (!_controller.value.isInitialized) {
      return const Center(child: CircularProgressIndicator());
    }

    return Column(
      children: [
        Expanded(
          flex: 3, // Camera preview takes more space
          child: Stack(
            children: [
              // Use AspectRatio to maintain the camera's aspect ratio
              AspectRatio(
                aspectRatio: _controller.value.aspectRatio,
                child: CameraPreview(_controller),
              ),
              _buildLineOverlays(), // Overlay the scan lines
            ],
          ),
        ),
        const SizedBox(height: 10), // Spacing between camera and text
        const Text(
          "Detected Text:",
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
        ),
        Expanded(
          flex: 2, // Text display area
          child: Container(
            margin: const EdgeInsets.all(8),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              border: Border.all(color: Colors.grey.shade400, width: 1.5),
              borderRadius: BorderRadius.circular(10),
              color: Colors.grey.shade100,
              boxShadow: [
                BoxShadow(
                  color: Colors.grey.withOpacity(0.2),
                  spreadRadius: 1,
                  blurRadius: 3,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: SingleChildScrollView(
              child: Text(
                _detectedText.isNotEmpty ? _detectedText : 'Point camera at text to scan...',
                style: const TextStyle(fontSize: 16, color: Colors.black87),
                textAlign: TextAlign.center,
              ),
            ),
          ),
        ),
      ],
    );
  }
}