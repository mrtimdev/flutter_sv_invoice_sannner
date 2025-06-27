import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:camera/camera.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:image_picker/image_picker.dart';
import 'package:http/http.dart' as http;
import 'package:lottie/lottie.dart'; 

import '../models/scan_item.dart';
import '../providers/scan_provider.dart'; 
import 'scan/list.dart';

class ScanScreen extends StatefulWidget {
  const ScanScreen({super.key});

  @override
  State<ScanScreen> createState() => _ScanScreenState();
}

class _ScanScreenState extends State<ScanScreen> with WidgetsBindingObserver, SingleTickerProviderStateMixin {
  CameraController? _controller; // Made nullable to explicitly handle uninitialized state
  bool _isControllerReady = false; // Flag to track if camera controller is initialized and ready
  bool _isScanning = false; // Flag for active scanning process
  List<CameraDescription>? _cameras; // List of available cameras
  final ImagePicker _picker = ImagePicker(); // Image picker instance
  int _selectedCameraIndex = 0; // Index of the currently selected camera (front/back)
  bool _isUploading = false;

  late AnimationController _animationController;
  late Animation<double> _scanAnimation;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _initializeCamera(); // Initialize camera on screen load

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
    // Safely dispose controller only if it exists and is initialized
    if (_controller != null && _controller!.value.isInitialized) {
      _controller!.dispose();
    }
    _animationController.dispose();
    super.dispose();
  }


  Future<ui.Image> _loadImageFromFile(String filePath) async {
    final Uint8List bytes = await File(filePath).readAsBytes();
    final ui.Codec codec = await ui.instantiateImageCodec(bytes);
    final ui.FrameInfo frameInfo = await codec.getNextFrame();
    return frameInfo.image;
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Crucial null check for _controller before attempting any operations
    if (_controller == null || !_controller!.value.isInitialized) {
      return;
    }

    if (state == AppLifecycleState.inactive) {
      // App is going to background, dispose camera to free up resources
      _controller!.dispose();
      setState(() {
        _isControllerReady = false;
      });
    } else if (state == AppLifecycleState.resumed) {
      // App is returning to foreground, reinitialize camera
      _initializeCamera();
    }
  }

  Future<void> _initializeCamera() async {
    // If the controller is already initialized and ready, do nothing.
    // This prevents redundant initializations and potential race conditions.
    if (_isControllerReady && _controller != null && _controller!.value.isInitialized) {
      return;
    }

    // Set _isControllerReady to false to show loading indicator during initialization
    // and to prevent operations on a half-ready controller.
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

      if (_selectedCameraIndex >= _cameras!.length) {
        _selectedCameraIndex = 0;
      }

      // Dispose of the existing controller before creating a new one.
      // This is crucial for a clean state, especially when reinitializing or switching cameras.
      if (_controller != null && _controller!.value.isInitialized) {
        await _controller!.dispose();
        _controller = null; // Set to null after disposing to ensure a clean slate
      }

      _controller = CameraController(
        _cameras![_selectedCameraIndex],
        ResolutionPreset.high,
        enableAudio: false,
        imageFormatGroup: ImageFormatGroup.jpeg,
      );

      await _controller!.initialize(); // Initialize the controller

      if (!mounted) return;
      setState(() {
        _isControllerReady = true; // Set to true only upon successful initialization
      });
    } on CameraException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to initialize camera: ${e.description}')),
        );
      }
      // Ensure _controller is null and _isControllerReady is false on error
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
      // Ensure _controller is null and _isControllerReady is false on error
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

      final textRecognizer = TextRecognizer();
      final RecognizedText recognizedText = await textRecognizer.processImage(inputImage);
      await textRecognizer.close();

      if (imageFile.path.isNotEmpty && recognizedText.text.isNotEmpty) {
        // Show preview dialog FIRST
        // await _showPreviewAndSaveDialog(imageFile, recognizedText);
        final Map<String, dynamic>? uploadedScanItem = await provider.saveScan(imageFile.path, recognizedText.text);
        if(uploadedScanItem != null) {
          debugPrint("uploadedScanItem: $uploadedScanItem");
          ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Great, your scan has been uploaded.'),
                backgroundColor: Colors.green, 
              ),
            );
          }
        
        // The dialog handles the actual upload and showing _showScanResult
        // The temporary file deletion will happen when _isScanning is set to false.
      } else if (imageFile.path.isNotEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No image path provided for preview.'), backgroundColor: Colors.red),
        );
      }

      else if (recognizedText.text.isEmpty && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No text recognized. Try a clearer image!'), backgroundColor: Colors.red),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Scan failed: ${e.toString()}')),
        );
      }
    } finally {
      if (imageFile.path.isNotEmpty && // Use imageFile.path here
          imageFile.path.startsWith('/data/user/0') && // Common temp path on Android
          await File(imageFile.path).exists()) { // Use imageFile.path here
        try {
          await File(imageFile.path).delete(); // Use imageFile.path here
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


  Future<void> _showPreviewAndSaveDialog(XFile imageFile, RecognizedText recognizedText) async {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return StatefulBuilder( // Use StatefulBuilder for local state management within modal
          builder: (BuildContext context, StateSetter modalSetState) {
            return Container(
              decoration: BoxDecoration(
                color: Theme.of(context).cardColor,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.1),
                    blurRadius: 10,
                    spreadRadius: 5,
                  ),
                ],
              ),
              padding: EdgeInsets.only(
                top: 24,
                left: 16,
                right: 16,
                bottom: MediaQuery.of(context).viewInsets.bottom + 16,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Align(
                    alignment: Alignment.center,
                    child: Container(
                      width: 40,
                      height: 5,
                      decoration: BoxDecoration(
                        color: Colors.grey[300],
                        borderRadius: BorderRadius.circular(2.5),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Preview Scan',
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: Theme.of(context).colorScheme.primary,
                        ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 16),
                  Flexible(
                    child: SingleChildScrollView(
                      child: Column(
                        children: [
                          Container(
                            constraints: BoxConstraints(
                              maxHeight: MediaQuery.of(context).size.height * 0.4,
                            ),
                            decoration: BoxDecoration(
                              border: Border.all(color: Colors.grey.shade300),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            clipBehavior: Clip.antiAlias,
                            child: FutureBuilder<ui.Image>(
                              future: _loadImageFromFile(imageFile.path),
                              builder: (context, snapshot) {
                                if (snapshot.connectionState == ConnectionState.done && snapshot.hasData) {
                                  return FittedBox(
                                    fit: BoxFit.contain,
                                    child: SizedBox(
                                      width: snapshot.data!.width.toDouble(),
                                      height: snapshot.data!.height.toDouble(),
                                      child: CustomPaint(
                                        painter: TextOverlayPainter(
                                          image: snapshot.data!,
                                          recognizedText: recognizedText,
                                        ),
                                      ),
                                    ),
                                  );
                                } else if (snapshot.hasError) {
                                  return Center(
                                    child: Padding(
                                      padding: const EdgeInsets.all(16.0),
                                      child: Text(
                                        'Error loading image: ${snapshot.error}',
                                        textAlign: TextAlign.center,
                                        style: TextStyle(color: Theme.of(context).colorScheme.error),
                                      ),
                                    ),
                                  );
                                }
                                return const Center(child: CircularProgressIndicator());
                              },
                            ),
                          ),
                          const SizedBox(height: 20),
                          Align(
                            alignment: Alignment.centerLeft,
                            child: Text(
                              'Recognized Text Preview:',
                              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                    fontWeight: FontWeight.bold,
                                  ),
                            ),
                          ),
                          const SizedBox(height: 8),
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: Theme.of(context).cardColor,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: Colors.grey.shade200),
                            ),
                            child: SelectableText(
                              recognizedText.text.trim().isEmpty ? 'No text recognized.' : recognizedText.text.trim(),
                              style: Theme.of(context).textTheme.bodyLarge,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: _isUploading
                              ? null
                              : () {
                                  Navigator.pop(context); // Dismiss preview modal
                                  // This effectively "retakes" by returning to the camera view
                                },
                          icon: const Icon(Icons.refresh),
                          label: const Text('Retake'),
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            foregroundColor: Theme.of(context).colorScheme.primary,
                            side: BorderSide(color: Theme.of(context).colorScheme.primary),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          ),
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: _isUploading
                              ? null
                              : () async {
                                  modalSetState(() {
                                    _isUploading = true; // Set local state for loading
                                  });
                                  final provider = Provider.of<ScanProvider>(context, listen: false);
                                  final Map<String, dynamic>? uploadedScanItem = await provider.saveScan(
                                    imageFile.path,
                                    recognizedText.text,
                                  );

                                  if (mounted) { // Check mounted status after async operation
                                    modalSetState(() {
                                      _isUploading = false;
                                    });
                                    if (uploadedScanItem != null) {
                                      Navigator.pop(context); // Dismiss preview modal
                                      // _showScanResult(uploadedScanItem); // Show final success result
                                    } else {
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        const SnackBar(content: Text('Failed to upload scan. Please try again.')),
                                      );
                                    }
                                  }
                                },
                          icon: _isUploading
                              ? SizedBox(
                                  width: 24,
                                  height: 24,
                                  child: CircularProgressIndicator(
                                    valueColor: AlwaysStoppedAnimation<Color>(Theme.of(context).colorScheme.onSecondary),
                                    strokeWidth: 3,
                                  ),
                                )
                              : const Icon(Icons.save),
                          label: Text(_isUploading ? 'Uploading...' : 'Save Scan'),
                          style: ElevatedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            backgroundColor: Theme.of(context).colorScheme.secondary,
                            foregroundColor: Theme.of(context).colorScheme.onSecondary,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Future<void> _captureAndScan() async {
    // Ensure controller is not null AND ready AND not already scanning
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

  // This method will show the final uploaded scan result (after it's saved to backend)
  void _showScanResult(ScanItem scanItem) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        decoration: BoxDecoration(
          color: Theme.of(context).cardColor,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.1),
              blurRadius: 10,
              spreadRadius: 5,
            ),
          ],
        ),
        padding: EdgeInsets.only(
          top: 24,
          left: 16,
          right: 16,
          bottom: MediaQuery.of(context).viewInsets.bottom + 16,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Align(
              alignment: Alignment.center,
              child: Container(
                width: 40,
                height: 5,
                decoration: BoxDecoration(
                  color: Colors.grey[300],
                  borderRadius: BorderRadius.circular(2.5),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'Scan Results Saved!', // Updated title for clarity
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: Theme.of(context).colorScheme.primary,
                  ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            Flexible(
              child: SingleChildScrollView(
                child: Column(
                  children: [
                    Container(
                      constraints: BoxConstraints(
                        maxHeight: MediaQuery.of(context).size.height * 0.4,
                      ),
                      decoration: BoxDecoration(
                        border: Border.all(color: Colors.grey.shade300),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      clipBehavior: Clip.antiAlias,
                      child: Image.network(
                        scanItem.imagePath, // Use network image for uploaded scan
                        fit: BoxFit.contain,
                        loadingBuilder: (context, child, loadingProgress) {
                          if (loadingProgress == null) return child;
                          return Center(
                            child: CircularProgressIndicator(
                              value: loadingProgress.expectedTotalBytes != null
                                  ? loadingProgress.cumulativeBytesLoaded / loadingProgress.expectedTotalBytes!
                                  : null,
                              color: Theme.of(context).colorScheme.secondary,
                            ),
                          );
                        },
                        errorBuilder: (context, error, stackTrace) => Container(
                          color: Theme.of(context).colorScheme.surfaceVariant,
                          child: Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.broken_image, size: 48, color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6)),
                                const SizedBox(height: 8),
                                Text(
                                  'Error loading image',
                                  textAlign: TextAlign.center,
                                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: Theme.of(context).colorScheme.error),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        'Saved Text:', // Updated label
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Theme.of(context).cardColor,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.grey.shade200),
                      ),
                      child: SelectableText(
                        scanItem.scannedText.trim().isEmpty ? 'No text recognized.' : scanItem.scannedText.trim(),
                        style: Theme.of(context).textTheme.bodyLarge,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () {
                      Navigator.pop(context); // Dismiss modal
                      // Stays on ScanScreen for new scan
                    },
                    icon: const Icon(Icons.refresh),
                    label: const Text('New Scan'),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      foregroundColor: Theme.of(context).colorScheme.primary,
                      side: BorderSide(color: Theme.of(context).colorScheme.primary),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () {
                      Navigator.pop(context); // Dismiss modal
                      Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const ScansListScreen()));
                    },
                    icon: const Icon(Icons.photo_library),
                    label: const Text('View All'),
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      backgroundColor: Theme.of(context).colorScheme.secondary,
                      foregroundColor: Theme.of(context).colorScheme.onSecondary,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Future<ui.Image> _loadImage(String imagePathOrUrl) async {
    try {
      if (imagePathOrUrl.startsWith('http://') || imagePathOrUrl.startsWith('https://')) {
        final response = await http.get(Uri.parse(imagePathOrUrl));
        if (response.statusCode == 200) {
          final data = response.bodyBytes;
          return decodeImageFromList(data);
        } else {
          throw Exception('Failed to load image from URL: HTTP ${response.statusCode}');
        }
      } else {
        final data = await File(imagePathOrUrl).readAsBytes();
        return decodeImageFromList(data);
      }
    } catch (e) {
      debugPrint('Error in _loadImage: $e');
      rethrow;
    }
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
        ],
      ),
      body: _buildCameraPreview(),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
      floatingActionButton: _buildScanFAB(context),
    );
  }

  Widget _buildCameraPreview() {
    // Only show CameraPreview if _controller is not null AND it's initialized and ready
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

  Future<void> _switchCamera() async {
    // Only switch if multiple cameras exist and not currently scanning
    if (_cameras == null || _cameras!.length < 2 || _isScanning) return;

    // Dispose current controller BEFORE updating selected index and re-initializing
    // This is important to free up camera resources immediately.
    if (_controller != null && _controller!.value.isInitialized) {
      await _controller!.dispose();
      _controller = null; // Set to null after disposing
    }

    // Update the selected camera index
    setState(() {
      _selectedCameraIndex = (_selectedCameraIndex + 1) % _cameras!.length;
      _isControllerReady = false; // Mark controller as not ready to show loading
    });

    // Reinitialize with the new camera
    await _initializeCamera();
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
    final paint = Paint()..filterQuality = FilterQuality.high; // Corrected line
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