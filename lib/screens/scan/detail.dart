import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:timeago/timeago.dart' as timeago;
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
// import 'package:image_gallery_saver/image_gallery_saver.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../models/scan_item.dart';
import 'image_viewer.dart';

class ScanDetailScreen extends StatefulWidget {
  final ScanItem item;

  const ScanDetailScreen({super.key, required this.item});

  @override
  State<ScanDetailScreen> createState() => _ScanDetailScreenState();
}

class _ScanDetailScreenState extends State<ScanDetailScreen> {
  static const Color primaryBlue = Color(0xFF1976D2);
  static const Color secondaryRed = Color(0xFFD32F2F);
  static const Color accentBlue = Color(0xFF2196F3);
  static const Color accentRed = Color(0xFFEF5350);

  String? _baseUrl = ""; 
  String? _rootUrl = "";

  @override
  void initState() {
    super.initState();
    _requestPermissions();

    _loadBaseUrl();
  }

  Future<void> _loadBaseUrl() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    String? baseUrl = prefs.getString('baseUrl');
    String? rootUrl = prefs.getString('rootUrl');
    if (baseUrl != null) {
      setState(() {
        _baseUrl = baseUrl;
      });
    }
    if (rootUrl != null) {
      setState(() {
        _rootUrl = rootUrl;
      });
    }
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

  Future<void> _saveImage(String imageUrl) async {
    try {
      if (Theme.of(context).platform == TargetPlatform.android) {
        final status = await Permission.storage.status;
        if (!status.isGranted) {
          final result = await Permission.storage.request();
          if (!result.isGranted) {
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Permission denied: Cannot save image.')),
              );
            }
            return;
          }
        }
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Downloading image...', style: TextStyle(color: Theme.of(context).colorScheme.onPrimary)),
            backgroundColor: Theme.of(context).colorScheme.primary,
            duration: const Duration(seconds: 2),
          ),
        );
      }

      final response = await http.get(Uri.parse(imageUrl));
      final directory = await getTemporaryDirectory();
      final filePath = '${directory.path}/${DateTime.now().millisecondsSinceEpoch}.png';
      final file = File(filePath);
      await file.writeAsBytes(response.bodyBytes);

      final result = null;//await ImageGallerySaver.saveFile(file.path, isReturnPathOfIOS: true);

      if (mounted) {
        if (result != null && result['isSuccess']) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Image saved to gallery!', style: TextStyle(color: Theme.of(context).colorScheme.onSecondary)), backgroundColor: Theme.of(context).colorScheme.secondary),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Failed to save image: ${result?['errorMessage'] ?? 'Unknown error'}', style: TextStyle(color: Theme.of(context).colorScheme.onError)), backgroundColor: Theme.of(context).colorScheme.error),
          );
        }
      }
      await file.delete();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error saving image: $e', style: TextStyle(color: Theme.of(context).colorScheme.onError)), backgroundColor: Theme.of(context).colorScheme.error),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final ColorScheme colorScheme = Theme.of(context).colorScheme.copyWith(
      primary: primaryBlue,
      onPrimary: Colors.white,
      secondary: secondaryRed,
      onSecondary: Colors.white,
      error: accentRed,
      onError: Colors.white,
      surface: Colors.white,
      onSurface: Colors.grey[900],
      background: Colors.grey[50],
      onBackground: Colors.grey[900],
    );
    final TextTheme textTheme = Theme.of(context).textTheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Scan Details'),
        backgroundColor: colorScheme.primary,
        foregroundColor: colorScheme.onPrimary,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.save_alt),
            onPressed: () => _saveImage("${_rootUrl}${widget.item.imagePath}"),
            tooltip: 'Save Image to Gallery',
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                constraints: BoxConstraints(
                  maxHeight: MediaQuery.of(context).size.height * 0.6,
                  maxWidth: MediaQuery.of(context).size.width * 0.9,
                ),
                decoration: BoxDecoration(
                  color: colorScheme.surface,
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: colorScheme.shadow.withOpacity(0.2),
                      blurRadius: 15,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(20),
                  child: InkWell(
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => FullScreenImageViewer(
                            imageUrl: "${_rootUrl}${widget.item.imagePath}",
                            heroTag: 'scan_image_${widget.item.id}',
                          ),
                        ),
                      );
                    },
                    child: Hero(
                      tag: 'scan_image_${widget.item.id}',
                      child: InteractiveViewer(
                        boundaryMargin: const EdgeInsets.all(20.0),
                        minScale: 0.1,
                        maxScale: 4.0,
                        child: AspectRatio(
                          aspectRatio: 210 / 297,
                          child: Image.network(
                            "${_rootUrl}${widget.item.imagePath}",
                            fit: BoxFit.contain,
                            loadingBuilder: (context, child, loadingProgress) {
                              if (loadingProgress == null) return child;
                              return Center(
                                child: CircularProgressIndicator(
                                  value: loadingProgress.expectedTotalBytes != null
                                      ? loadingProgress.cumulativeBytesLoaded / loadingProgress.expectedTotalBytes!
                                      : null,
                                  color: colorScheme.secondary,
                                ),
                              );
                            },
                            errorBuilder: (context, error, stackTrace) => Container(
                              color: colorScheme.surfaceVariant,
                              child: Center(
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(Icons.broken_image, size: 60, color: colorScheme.onSurface.withOpacity(0.5)),
                                    const SizedBox(height: 12),
                                    Text(
                                      'Image failed to load',
                                      style: textTheme.titleMedium?.copyWith(color: colorScheme.onSurface.withOpacity(0.7)),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 32),

            Text(
              'Scanned Text',
              style: textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.bold,
                color: colorScheme.primary,
              ),
            ),
            const SizedBox(height: 12),
            Container(
              height: 200,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: colorScheme.surface,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: colorScheme.outline.withOpacity(0.2)),
                boxShadow: [
                  BoxShadow(
                    color: colorScheme.shadow.withOpacity(0.1),
                    blurRadius: 8,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: SingleChildScrollView(
                child: SelectableText(
                  widget.item.scannedText,
                  style: textTheme.bodyLarge?.copyWith(
                    color: colorScheme.onSurface,
                    height: 1.5,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 24),

            Text(
              'Scan Information',
              style: textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.bold,
                color: colorScheme.primary,
              ),
            ),
            const SizedBox(height: 12),
            _buildInfoRow(
              context,
              icon: Icons.calendar_today,
              label: 'Date',
              value: DateFormat('MMM d, y').format(widget.item.date),
              iconColor: colorScheme.secondary,
            ),
            _buildInfoRow(
              context,
              icon: Icons.access_time,
              label: 'Time',
              value: DateFormat('h:mm:ss a').format(widget.item.date),
              iconColor: colorScheme.secondary,
            ),
            _buildInfoRow(
              context,
              icon: Icons.history,
              label: 'Age',
              value: timeago.format(widget.item.date),
              iconColor: colorScheme.secondary,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoRow(BuildContext context, {
    required IconData icon,
    required String label,
    required String value,
    required Color iconColor,
  }) {
    final TextTheme textTheme = Theme.of(context).textTheme;
    final ColorScheme colorScheme = Theme.of(context).colorScheme;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: iconColor, size: 24),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: textTheme.bodySmall?.copyWith(
                    color: colorScheme.onSurface.withOpacity(0.6),
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  value,
                  style: textTheme.bodyLarge?.copyWith(
                    color: colorScheme.onSurface,
                    fontWeight: FontWeight.normal,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}