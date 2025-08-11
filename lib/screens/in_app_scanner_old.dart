import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:camera/camera.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:image_picker/image_picker.dart';
import 'package:lottie/lottie.dart';
import 'package:sv_invoice_scanner/screens/scan/list.dart';

import '../providers/scan_provider.dart';

class ScanScreen extends StatefulWidget {
  const ScanScreen({super.key});

  @override
  State<ScanScreen> createState() => _ScanScreenState();
}

class _ScanScreenState extends State<ScanScreen> with WidgetsBindingObserver, SingleTickerProviderStateMixin {
  CameraController? _controller;
  bool _isControllerReady = false;
  bool _isScanning = false;
  List<CameraDescription>? _cameras;
  final ImagePicker _picker = ImagePicker();
  int _selectedCameraIndex = 0;
  late AnimationController _animationController;
  late Animation<double> _scanAnimation;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _initializeCamera();

    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);

    _scanAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _controller?.dispose();
    _animationController.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (_controller == null || !_controller!.value.isInitialized) {
      return;
    }

    if (state == AppLifecycleState.inactive) {
      _controller!.dispose();
      setState(() {
        _isControllerReady = false;
      });
    } else if (state == AppLifecycleState.resumed) {
      _initializeCamera();
    }
  }

  Future<void> _initializeCamera() async {
    if (_isControllerReady && _controller != null && _controller!.value.isInitialized) {
      return;
    }

    setState(() {
      _isControllerReady = false;
    });

    try {
      _cameras ??= await availableCameras();
      if (_cameras!.isEmpty) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('No cameras available')),
          );
        }
        return;
      }

      _selectedCameraIndex = _selectedCameraIndex.clamp(0, _cameras!.length - 1);

      await _controller?.dispose(); // Dispose previous controller if it exists
      _controller = null; // Ensure it's null after disposing

      _controller = CameraController(
        _cameras![_selectedCameraIndex],
        ResolutionPreset.high,
        enableAudio: false,
        imageFormatGroup: ImageFormatGroup.jpeg,
      );

      await _controller!.initialize();

      if (!mounted) return;
      setState(() {
        _isControllerReady = true;
      });
    } on CameraException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to initialize camera: ${e.description}')),
        );
      }
      _controller = null;
      setState(() {
        _isControllerReady = false;
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Unknown camera initialization error: ${e.toString()}')),
        );
      }
      _controller = null;
      setState(() {
        _isControllerReady = false;
      });
    }
  }

  Future<void> _processImage(XFile imageFile) async {
    if (_isScanning) return;
    setState(() => _isScanning = true);

    final provider = Provider.of<ScanProvider>(context, listen: false);

    try {
      final InputImage inputImage = InputImage.fromFilePath(imageFile.path);

      final textRecognizer = TextRecognizer(script: TextRecognitionScript.latin);
      final RecognizedText recognizedText = await textRecognizer.processImage(inputImage);
      await textRecognizer.close();

      if (!mounted) return; // Check mounted before showing SnackBar

      // --- START OF MODIFICATION FOR REGION-SPECIFIC SCANNING ---
      // Define the target region (top right of the image based on visual inspection)
      // These values need to be adjusted based on the actual image resolution
      // and the exact coordinates of your green box.
      // For best performance, the ML Kit processes the whole image, then we filter.
      final image = await decodeImageFromList(File(imageFile.path).readAsBytesSync());
      final double imageWidth = image.width.toDouble();
      final double imageHeight = image.height.toDouble();

      // Approximate coordinates for the top-right green box based on the provided image
      // Adjust these values as needed for your specific use case.
      // final Rect targetRegion = Rect.fromLTWH(
      //   imageWidth * 0.50, // Start from 50% of the width
      //   0.0, // Start from the top
      //   imageWidth * 1.0, // Width: 50% of the image
      //   imageHeight * 0.30, // Height: 30% of the image
      // );
      final Rect targetRegion = Rect.fromLTWH(
        0.0,          // Start from the left
        0.0,          // Start from the top
        imageWidth,   // Full width of the image
        imageHeight,  // Full height of the image
      );


      StringBuffer filteredTextBuffer = StringBuffer();

      for (TextBlock block in recognizedText.blocks) {
        // Check if the block's bounding box intersects with the target region
        if (targetRegion.overlaps(block.boundingBox)) {
          for (TextLine line in block.lines) {
            // Further filter by line to ensure it's truly within the region
            if (targetRegion.overlaps(line.boundingBox)) {
              filteredTextBuffer.writeln(line.text);
            }
          }
        }
      }

      final String scannedTextInRegion = filteredTextBuffer.toString().trim();
      debugPrint("Scanned text in region: \n$scannedTextInRegion");

      if (scannedTextInRegion.isNotEmpty) {
        // Use the filtered text for saving
        final Map<String, dynamic>? uploadedScanItem = await provider.saveScan(imageFile.path, scannedTextInRegion, "KHB");
        if (uploadedScanItem != null) {
          debugPrint("uploadedScanItem: $uploadedScanItem");
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Great, your scan has been uploaded.'),
              backgroundColor: Colors.green,
            ),
          );
        }
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text('No text recognized in the specified top-right region. Try a clearer image.'),
              backgroundColor: Colors.red),
        );
      }
      // --- END OF MODIFICATION FOR REGION-SPECIFIC SCANNING ---
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Scan failed: ${e.toString()}')),
        );
      }
    } finally {
      // Attempt to delete temporary file if it's from the camera
      if (imageFile.path.startsWith('/data/user/0') && await File(imageFile.path).exists()) {
        try {
          await File(imageFile.path).delete();
          debugPrint('Successfully deleted temporary camera file: ${imageFile.path}');
        } catch (e) {
          debugPrint('Error deleting temporary camera file: $e');
        }
      }
      if (mounted) {
        setState(() => _isScanning = false);
      }
    }
  }

  Future<void> _captureAndScan() async {
    if (_controller == null || !_isControllerReady || _isScanning) {
      return;
    }

    try {
      final XFile image = await _controller!.takePicture();
      await _processImage(image);
    } on CameraException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Camera capture failed: ${e.description}')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Unknown camera capture error: ${e.toString()}')),
        );
      }
    }
  }

  Future<void> _pickImageAndScan() async {
    if (_isScanning) return;

    try {
      final XFile? image = await _picker.pickImage(source: ImageSource.gallery);
      if (image != null) {
        await _processImage(image);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Image picking failed: ${e.toString()}')),
        );
      }
    }
  }

  Future<void> _switchCamera() async {
    if (_cameras == null || _cameras!.length < 2 || _isScanning) return;

    // Dispose current controller before updating selected index and re-initializing
    await _controller?.dispose();
    _controller = null; // Set to null after disposing

    setState(() {
      _selectedCameraIndex = (_selectedCameraIndex + 1) % _cameras!.length;
      _isControllerReady = false; // Mark controller as not ready to show loading
    });

    await _initializeCamera();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          if (_cameras != null && _cameras!.length > 1)
            IconButton(
              icon: const Icon(Icons.flip_camera_ios_rounded, color: Colors.white),
              onPressed: _switchCamera,
            ),
          IconButton(
            icon: const Icon(Icons.photo_library_outlined, color: Colors.white),
            onPressed: _pickImageAndScan,
          ),
          IconButton(
            icon: const Icon(Icons.adf_scanner_outlined, color: Colors.white),
            onPressed: () => {
              Navigator.push(context, MaterialPageRoute(builder: (_) => const ScansListScreen()))
            },
          ),
        ],
      ),
      body: _buildCameraPreview(),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
      floatingActionButton: _buildScanFAB(context),
    );
  }

  Widget _buildCameraPreview() {
    if (_controller == null || !_isControllerReady || !_controller!.value.isInitialized) {
      return const Center(child: CircularProgressIndicator());
    }

    return Stack(
      fit: StackFit.expand,
      children: [
        Center(
          child: CameraPreview(_controller!),
        ),
        Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                Colors.black.withOpacity(0.2),
                Colors.transparent,
                Colors.transparent,
                Colors.black.withOpacity(0.2),
              ],
              stops: const [0.0, 0.2, 0.8, 1.0],
            ),
          ),
        ),
        _buildScanAreaOverlay(context),
        Positioned(
          bottom: 120,
          left: 0,
          right: 0,
          child: Column(
            children: [
              if (_isScanning)
                Lottie.asset(
                  'assets/animations/scanner_animation.json',
                  width: 100,
                  height: 100,
                  repeat: true,
                )
              else
                Icon(Icons.crop_free, size: 60, color: Colors.white.withOpacity(0.7)),
              const SizedBox(height: 10),
              Text(
                _isScanning ? 'Processing image...' : 'Position text within the frame',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      shadows: [
                        Shadow(
                          blurRadius: 4,
                          color: Colors.black.withOpacity(0.5),
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildScanAreaOverlay(BuildContext context) {
    final double scanWidth = MediaQuery.of(context).size.width * 0.8;
    final double scanHeight = MediaQuery.of(context).size.height * 0.3;

    return ColorFiltered(
      colorFilter: ColorFilter.mode(
        Colors.black.withOpacity(0.6),
        BlendMode.srcOut,
      ),
      child: Stack(
        fit: StackFit.expand,
        children: [
          Container(
            color: Colors.black,
          ),
          Center(
            child: Container(
              width: scanWidth,
              height: scanHeight,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
              ),
            ),
          ),
          Center(
            child: Container(
              width: scanWidth,
              height: scanHeight,
              decoration: BoxDecoration(
                border: Border.all(
                  color: _isScanning
                      ? Theme.of(context).colorScheme.secondary
                      : Colors.white.withOpacity(0.8),
                  width: 3,
                ),
                borderRadius: BorderRadius.circular(16),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: AnimatedBuilder(
                  animation: _scanAnimation,
                  builder: (context, child) {
                    return Align(
                      alignment: Alignment(_scanAnimation.value * 2 - 1, 0),
                      child: _isScanning
                          ? Container(
                              width: scanWidth * 0.1,
                              height: scanHeight,
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  begin: Alignment.topCenter,
                                  end: Alignment.bottomCenter,
                                  colors: [
                                    Theme.of(context).colorScheme.secondary.withOpacity(0.0),
                                    Theme.of(context).colorScheme.secondary.withOpacity(0.8),
                                    Theme.of(context).colorScheme.secondary.withOpacity(0.0),
                                  ],
                                ),
                              ),
                            )
                          : const SizedBox.shrink(),
                    );
                  },
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildScanFAB(BuildContext context) {
    return _isScanning
        ? FloatingActionButton(
            onPressed: null,
            backgroundColor: Theme.of(context).colorScheme.secondary.withOpacity(0.5),
            child: const CircularProgressIndicator(valueColor: AlwaysStoppedAnimation(Colors.white)),
          )
        : FloatingActionButton.extended(
            onPressed: _captureAndScan,
            icon: const Icon(Icons.camera_alt_rounded, size: 28),
            label: const Text(
              'Capture & Scan',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            backgroundColor: Theme.of(context).colorScheme.primary,
            foregroundColor: Theme.of(context).colorScheme.onPrimary,
            elevation: 10,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(30),
            ),
          );
  }
}

// CustomPainter to draw bounding boxes of recognized text on the image
class TextOverlayPainter extends CustomPainter {
  final ui.Image image;
  final RecognizedText recognizedText;

  TextOverlayPainter({required this.image, required this.recognizedText});

  @override
  void paint(Canvas canvas, Size size) {
    // Draw the original image, scaled to fit the canvas
    final paint = Paint()..filterQuality = FilterQuality.high;
    final srcRect = Rect.fromLTWH(0, 0, image.width.toDouble(), image.height.toDouble());
    final dstRect = Rect.fromLTWH(0, 0, size.width, size.height);
    canvas.drawImageRect(image, srcRect, dstRect, paint);

    // Calculate scaling factors to match the image display size
    final double scaleX = size.width / image.width;
    final double scaleY = size.height / image.height;

    // Paint for the bounding box borders
    final borderPaint = Paint()
      ..color = Colors.red.withOpacity(0.7) // Semi-transparent red for highlight
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0;

    // Iterate through all recognized text blocks, lines, and elements
    for (TextBlock block in recognizedText.blocks) {
      for (TextLine line in block.lines) {
        for (TextElement element in line.elements) {
          // Scale the bounding box coordinates of each text element
          final scaledRect = Rect.fromLTRB(
            element.boundingBox.left * scaleX,
            element.boundingBox.top * scaleY,
            element.boundingBox.right * scaleX,
            element.boundingBox.bottom * scaleY,
          );
          canvas.drawRect(scaledRect, borderPaint); // Draw the scaled rectangle
        }
      }
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) {
    // Repaint only if the image or the recognized text has changed
    if (oldDelegate is TextOverlayPainter) {
      return oldDelegate.image != image || oldDelegate.recognizedText != recognizedText;
    }
    return true; // If it's a different type of delegate, always repaint
  }
}