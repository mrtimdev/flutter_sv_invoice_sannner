// lib/providers/scan_provider.dart

import 'package:flutter/material.dart';
import '../enum/dateFilter.dart';
import '../services/scan_service.dart'; 
import '../models/scan_item.dart';



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

  


  ScanProvider(this._scanService); // Constructor now takes ScanService

  // State getters
  bool get isLoading => _isLoading;
  bool get isFetchingScans => _isFetchingScans;
  String? get errorMessage => _errorMessage;
  ScanItem? get scan => _scan;
  bool get hasMore => _hasMore;



  
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

  Future<Map<String, dynamic>?> saveScan(String imagePath, String recognizedText) async {
    // Instead of local storage, use the ScanService to upload
    final responseData = await _scanService.uploadScan(imagePath, recognizedText);

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

  // Future<void> fetchScans_old() async {
  //   _isLoading = true;
  //   _isFetchingScans = true;
  //   notifyListeners();
  //   _clearError();

  //   try {
  //     final response = await _scanService.fetchScans();
      
  //     if (response == null) {
  //       _errorMessage = 'Failed to load scans';
  //     } else {
  //       _scans = response;
  //     }
  //   } catch (e) {
  //     _errorMessage = 'Error loading scans: ${e.toString()}';
  //     _scans = []; // Clear scans on error
  //   } finally {
  //     _isLoading = false;
  //     _isFetchingScans = false;
  //     notifyListeners();
  //   }
  // }
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
}