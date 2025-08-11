// lib/providers/scan_provider.dart

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:gallery_saver_plus/gallery_saver.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import '../enum/dateFilter.dart';
import '../services/scan_service.dart'; 
import '../models/scan_item.dart';

import 'package:http/http.dart' as http;



class ScanProvider with ChangeNotifier {
  final ScanService _scanService; // Add ScanService dependency
  List<ScanItem> _scans = [];
  ScanItem? _scan;
  bool _isLoading = false;
  bool _isFetchingScans = false;
  String? _errorMessage;

  bool _isFetchingMore = false;
  bool _hasMore = true;
  String? _lastDateCursor;

  bool _isSavingImage = false;

  bool get isSavingImage => _isSavingImage;

  bool _showCropped = false;

  bool get showCropped => _showCropped;

  


  ScanProvider(this._scanService); // Constructor now takes ScanService

  // State getters
  bool get isLoading => _isLoading;
  bool get isFetchingScans => _isFetchingScans;
  String? get errorMessage => _errorMessage;
  ScanItem? get scan => _scan;
  bool get hasMore => _hasMore;


  void toggleShowCropped() {
    _showCropped = !_showCropped;
    notifyListeners();
  }

  void setShowCropped(bool value) {
    _showCropped = value;
    notifyListeners();
  }

  
  // Clear error message
  void _clearError() {
    if (_errorMessage != null) {
      _errorMessage = null;
      notifyListeners();
    }
  }

  List<ScanItem> get scans => [..._scans]; // Return a copy



  void resetPagination() {
    _scans = [];
    _lastDateCursor = null;
    _hasMore = true;
    _isFetchingMore = false;
    notifyListeners();
  }

  Future<void> resetAndFetch(DateFilter filter, String search) async {
    resetPagination();
    fetchMoreScans(filter: filter, search: search, loadMore: false);
  }

  Future<void> fetchMoreScans({
    required DateFilter filter,
    required String search,
    bool loadMore = false,
    int limit = 20,
  }) async {
    if (_isFetchingMore || !_hasMore) return;
    _isLoading = true;
    _isFetchingMore = true;
    notifyListeners();

    try {
      final newScans = await _scanService.fetchScans(
        filter: filter,
        search: search,
        before: _lastDateCursor,
        limit: limit
      );

      if (newScans.isNotEmpty) {
        _scans.addAll(newScans);
        _lastDateCursor = newScans.last.date.toIso8601String();
      } else {
        _hasMore = false;
      }
    } catch (e) {
      print('Error fetching scans: $e');
    } finally {
      _isLoading = false;
      _isFetchingMore = false;
      notifyListeners();
    }
  }

  Future<Map<String, dynamic>?> saveScan(String imagePath, String recognizedText, String scanType) async {
    // Instead of local storage, use the ScanService to upload
    final responseData = await _scanService.uploadScan(imagePath, recognizedText, scanType);

    if (responseData != null) {
      debugPrint("responseData: $responseData");
      // _scan = ScanItem.fromJson(responseData);
      notifyListeners();
      return responseData;
    }
    return null;
  }

  // Delete a scan with optimistic UI update
  Future<bool> deleteScan(int scanId) async {
    final index = _scans.indexWhere((scan) => scan.id == scanId);
    if (index == -1) return false;

    // Optimistically remove the scan
    final removedScan = _scans.removeAt(index);
    notifyListeners();

    try {
      final bool? success = await _scanService.deleteScanById(scanId);
      if (success != true) {
        // Revert if deletion failed
        _scans.insert(index, removedScan);
        _errorMessage = "Failed to delete scan";
        notifyListeners();
        return false;
      }
      return true;
    } catch (e) {
      // Revert on error
      _scans.insert(index, removedScan);
      _errorMessage = "Error deleting scan: ${e.toString()}";
      notifyListeners();
      return false;
    }
  }

  // Delete scans by user ID
  Future<int?> deleteUserScans() async {
    _isLoading = true;
    notifyListeners();
    _clearError();

    try {
      final count = await _scanService.deleteScansByUserId();
      
      if (count == null) {
        _errorMessage = 'Failed to delete user scans';
      } else if (count == 0) {
        _errorMessage = 'No scans found to delete';
      }
      
      return count;
    } catch (e) {
      _errorMessage = 'Error deleting user scans: ${e.toString()}';
      return null;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }


  String getDateFilterText(DateFilter filter) {
    switch (filter) {
      case DateFilter.all: return 'All Scans';
      case DateFilter.today: return 'Today';
      case DateFilter.yesterday: return 'Yesterday';
      case DateFilter.last7Days: return 'Last 7 Days';
      case DateFilter.last30Days: return 'Last 30 Days';
    }
  }

  // Delete multiple scans
  Future<int?> deleteMultipleScans(List<int> ids) async {
    if (ids.isEmpty) return 0;
    
    _isLoading = true;
    notifyListeners();
    _clearError();

    try {
      final count = await _scanService.deleteScansByIds(ids);
      
      if (count == null) {
        _errorMessage = 'Failed to delete selected scans';
      } else if (count == 0) {
        _errorMessage = 'No scans were deleted';
      }
      
      return count;
    } catch (e) {
      _errorMessage = 'Error deleting scans: ${e.toString()}';
      return null;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // Delete all scans (admin only)
  Future<int?> deleteAllScans() async {
    _isLoading = true;
    notifyListeners();
    _clearError();

    try {
      final count = await _scanService.deleteAllScans();
      
      if (count == null) {
        _errorMessage = 'Failed to delete all scans';
      }
      
      return count;
    } catch (e) {
      _errorMessage = 'Error deleting all scans: ${e.toString()}';
      return null;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }
  Future<ScanItem?> getScanById(String scanId) async {
    _isLoading = true;
    _isFetchingScans = true;
    notifyListeners();
    _clearError();

    try {

      // If not in cache, fetch from API
      final scan = await _scanService.getScanById(scanId);
      
      if (scan == null) {
        _errorMessage = 'Scan not found';
      }
      
      return scan;
    } catch (e) {
      _errorMessage = 'Error loading scan: ${e.toString()}';
      return null;
    } finally {
      _isLoading = false;
      _isFetchingScans = false;
      notifyListeners();
    }
  }


  Future<void> saveImageToGallery(
    String imageUrl, {
    BuildContext? context,
  }) async {
    if (_isSavingImage) return;
    _isSavingImage = true;
    notifyListeners();

    try {
      // Show downloading indicator if context is provided
      if (context != null && mounted(context)) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Downloading image...'),
            backgroundColor: Colors.blue[800],
            behavior: SnackBarBehavior.floating,
          ),
        );
      }

      // Check and request permissions
      await _requestPermissions();

      // Download the image
      final response = await http.get(Uri.parse(imageUrl));
      if (response.statusCode != 200) {
        throw Exception('Failed to download image');
      }

      // Save to temporary file
      final directory = await getTemporaryDirectory();
      final filePath = '${directory.path}/${DateTime.now().millisecondsSinceEpoch}.jpg';
      final tempFile = File(filePath);
      await tempFile.writeAsBytes(response.bodyBytes);

      // Save to gallery
      final success = await GallerySaver.saveImage(tempFile.path);
      if (success != true) {
        throw Exception('Failed to save image to gallery');
      }

      // Show success message if context is provided
      if (context != null && mounted(context)) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Image saved to gallery!'),
            backgroundColor: Colors.blue[600],
            behavior: SnackBarBehavior.floating,
            duration: const Duration(seconds: 2),
          ),
        );
      }
      await tempFile.delete();
    } catch (e) {
      // Show error message if context is provided
      if (context != null && mounted(context)) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: ${e.toString().replaceAll('Exception: ', '')}'),
            backgroundColor: Colors.blue[800],
            behavior: SnackBarBehavior.floating,
            duration: const Duration(seconds: 3),
          ),
        );
      }
      rethrow; // Re-throw the error if you want to handle it elsewhere
    } finally {
      _isSavingImage = false;
      notifyListeners();
    }
  }

  Future<void> _requestPermissions() async {
    if (Platform.isAndroid) {
      await Permission.storage.request();
      await Permission.mediaLibrary.request();
    }
  }

  // Helper method to check if widget is still mounted
  static bool mounted(BuildContext context) {
    return Navigator.of(context, rootNavigator: true).mounted;
  }
}