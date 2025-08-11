import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:timeago/timeago.dart' as timeago;
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../models/scan_item.dart';
import '../../providers/scan_provider.dart';
import 'image_viewer.dart';

class ScanDetailScreen extends StatefulWidget {
  final ScanItem item;

  const ScanDetailScreen({super.key, required this.item});

  @override
  State<ScanDetailScreen> createState() => _ScanDetailScreenState();
}

class _ScanDetailScreenState extends State<ScanDetailScreen> {
  String? _baseUrl = ""; 
  String? _rootUrl = "";
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _loadBaseUrl();
  }

  Future<void> _loadBaseUrl() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    setState(() {
      _baseUrl = prefs.getString('baseUrl') ?? "";
      _rootUrl = prefs.getString('rootUrl') ?? "";
    });


    
  }

  Future<void> _saveImage(BuildContext context) async {
    if (_isSaving) return;
    final provider = Provider.of<ScanProvider>(context, listen: false);
    setState(() => _isSaving = true);
    
    try {
      final isCropped = provider.showCropped;
      String imagePath_ = isCropped && widget.item.croppedPath != null
      ? widget.item.croppedPath!
      : widget.item.imagePath;
    final imageUrl = '$_rootUrl${imagePath_}';
      if (!Uri.parse(imageUrl).isAbsolute) {
        throw Exception('Invalid image URL: $imageUrl');
      }

      await context.read<ScanProvider>().saveImageToGallery(
        imageUrl,
        context: context,
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: ${e.toString()}'),
            backgroundColor: Theme.of(context).colorScheme.error,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme colors = theme.colorScheme;


    final provider = Provider.of<ScanProvider>(context, listen: false);
    final isCropped = provider.showCropped;

    String imagePath_ = isCropped && widget.item.croppedPath != null
      ? widget.item.croppedPath!
      : widget.item.imagePath;
    final imageUrl = '$_rootUrl${imagePath_}';

    final isValidUrl = Uri.tryParse(imageUrl)?.isAbsolute ?? false;



    return Scaffold(
      appBar: AppBar(
        title: const Text('Scan Details'),
        elevation: 0,
        actions: [
          IconButton(
            icon: _isSaving
                ? CircularProgressIndicator(
                    color: colors.onPrimary,
                    strokeWidth: 2)
                : const Icon(Icons.save_alt),
            onPressed: () => _saveImage(context),
            tooltip: 'Save Image',
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Image Card
            Card(
              elevation: 4,
              color: Theme.of(context).brightness == Brightness.dark 
                ? null 
                : Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              clipBehavior: Clip.antiAlias,
              child: InkWell(
                onTap: isValidUrl ? () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => FullScreenImageViewer(
                        imageUrl: imageUrl,
                        heroTag: 'scan_image_${widget.item.id}',
                      ),
                    ),
                  );
                } : null,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    Hero(
                      tag: 'scan_image_${widget.item.id}',
                      child: isValidUrl
                          ? Image.network(
                              imageUrl,
                              fit: BoxFit.contain,
                              loadingBuilder: (context, child, progress) {
                                if (progress == null) return child;
                                return Center(
                                  child: CircularProgressIndicator(
                                    value: progress.expectedTotalBytes != null
                                        ? progress.cumulativeBytesLoaded / progress.expectedTotalBytes!
                                        : null,
                                    color: colors.primary,
                                  ),
                                );
                              },
                              errorBuilder: (context, error, stackTrace) => _buildErrorPlaceholder(),
                            )
                          : _buildErrorPlaceholder(),
                    ),
                    if (!isValidUrl)
                      Positioned(
                        bottom: 16,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(
                            color: colors.surfaceVariant,
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            'Invalid URL',
                            style: TextStyle(color: colors.onSurfaceVariant),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),

            // Scanned Text Section
            _buildSectionHeader('Scanned Text'),
            const SizedBox(height: 12),
            Card(
              elevation: 2,
              color: Theme.of(context).brightness == Brightness.dark 
                ? null 
                : Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Content',
                          style: theme.textTheme.titleMedium?.copyWith(
                                color: colors.primary,
                                fontWeight: FontWeight.bold,
                              ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.copy, size: 20),
                          color: colors.primary,
                          onPressed: () {
                            Clipboard.setData(ClipboardData(text: widget.item.scannedText));
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: const Text('Text copied to clipboard'),
                                backgroundColor: colors.primary,
                              ),
                            );
                          },
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    SizedBox(
                      height: 150, 
                      child: SingleChildScrollView(
                        child: SelectableText(
                          widget.item.scannedText,
                          style: theme.textTheme.bodyLarge?.copyWith(
                            color: colors.onSurface,
                            height: 1.5,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),

            // Scan Information Section - Compact Single Line Layout
            _buildSectionHeader('Scan Information'),
            const SizedBox(height: 12),
            Card(
              elevation: 2,
              color: Theme.of(context).brightness == Brightness.dark 
                ? null 
                : Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 12),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    _buildCompactInfoChip(
                      icon: Icons.calendar_today,
                      label: DateFormat('MMM d, y h:mm a').format(widget.item.date),
                    ),
                    _buildCompactInfoChip(
                      icon: Icons.history,
                      label: timeago.format(widget.item.date),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Text(
      title,
      style: Theme.of(context).textTheme.titleLarge?.copyWith(
            color: Theme.of(context).colorScheme.primary,
            fontWeight: FontWeight.bold,
          ),
    );
  }

  Widget _buildErrorPlaceholder() {
    final colors = Theme.of(context).colorScheme;
    return Container(
      color: colors.surfaceVariant,
      height: 300,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.broken_image, size: 60, color: colors.onSurfaceVariant),
          const SizedBox(height: 12),
          Text(
            'Image not available',
            style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                  color: colors.onSurfaceVariant,
                ),
          ),
        ],
      ),
    );
  }

  Widget _buildCompactInfoChip({
    required IconData icon,
    required String label,
  }) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceVariant.withOpacity(0.5),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: theme.colorScheme.primary),
          const SizedBox(width: 6),
          Text(
            label,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}