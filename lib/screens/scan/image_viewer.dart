import 'package:flutter/material.dart';
// import 'package:gallery_saver/gallery_saver.dart';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';

class FullScreenImageViewer extends StatefulWidget {
  final String imageUrl;
  final String? heroTag; // For Hero animation

  const FullScreenImageViewer({
    super.key,
    required this.imageUrl,
    this.heroTag,
  });

  @override
  State<FullScreenImageViewer> createState() => _FullScreenImageViewerState();
}

class _FullScreenImageViewerState extends State<FullScreenImageViewer> {
  @override
  void initState() {
    super.initState();
    _requestPermissions();
  }

  Future<void> _requestPermissions() async {
    if (Theme.of(context).platform == TargetPlatform.android) {
      final status = await Permission.storage.request();
      if (!status.isGranted) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Storage permission is required to save images.')),
          );
        }
      }
    }
  }

  Future<void> _saveImage() async {
    File? tempFile; // Track the temp file for cleanup

    try {
      // 1. Handle permissions (Android only)
      if (Theme.of(context).platform == TargetPlatform.android) {
        // For Android 13+ we need to request specific media permissions
        if (await Permission.mediaLibrary.isRestricted) {
          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Please enable media permissions in settings')),
          );
          return;
        }

        final status = await Permission.mediaLibrary.status;
        if (!status.isGranted) {
          final result = await Permission.mediaLibrary.request();
          if (!result.isGranted) {
            if (!mounted) return;
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Media permission required to save images')),
            );
            return;
          }
        }
      }

      // 2. Show downloading indicator
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Downloading image...', 
              style: TextStyle(color: Theme.of(context).colorScheme.onPrimary),
            ),
            backgroundColor: Theme.of(context).colorScheme.primary,
            behavior: SnackBarBehavior.floating,
            duration: const Duration(seconds: 2),
          ),
        );
      }

      // 3. Download the image
      final response = await http.get(Uri.parse(widget.imageUrl));
      if (response.statusCode != 200) {
        throw Exception('Failed to download image (HTTP ${response.statusCode})');
      }

      // 4. Save to temporary file
      final directory = await getTemporaryDirectory();
      final filePath = '${directory.path}/${DateTime.now().millisecondsSinceEpoch}.jpg';
      tempFile = File(filePath);
      await tempFile.writeAsBytes(response.bodyBytes);

      // 5. Save to gallery using gallery_saver
      final bool? success = null; //await GallerySaver.saveImage(tempFile.path);

      // 6. Show result to user
      if (mounted) {
        if (success == true) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Image saved to gallery!',
                style: TextStyle(color: Theme.of(context).colorScheme.onSecondary),
              ),
              backgroundColor: Theme.of(context).colorScheme.secondary,
              behavior: SnackBarBehavior.floating,
            ),
          );
        } else {
          throw Exception('Failed to save image to gallery');
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Error: ${e.toString().replaceAll('Exception: ', '')}',
              style: TextStyle(color: Theme.of(context).colorScheme.onError),
            ),
            backgroundColor: Theme.of(context).colorScheme.error,
            behavior: SnackBarBehavior.floating,
            duration: const Duration(seconds: 3),
          ),
        );
      }
    } finally {
      // 7. Clean up temporary file if it exists
      if (tempFile != null && await tempFile.exists()) {
        await tempFile.delete();
      }
    }
  }
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black, // Dark background for image viewing
      appBar: AppBar(
        backgroundColor: Colors.black, // Transparent or dark app bar
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.download),
            onPressed: _saveImage,
            tooltip: 'Download Image',
          ),
        ],
      ),
      body: Center(
        child: Hero(
          tag: widget.heroTag ?? 'full_image_hero', // Use provided tag or default
          child: InteractiveViewer(
            boundaryMargin: const EdgeInsets.all(20.0),
            minScale: 0.1,
            maxScale: 4.0,
            child: Image.network(
              widget.imageUrl,
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
                color: Colors.grey[900],
                child: Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.broken_image, size: 60, color: Colors.grey[600]),
                      const SizedBox(height: 12),
                      Text(
                        'Failed to load image',
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(color: Colors.grey[600]),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
