import 'package:flutter/material.dart';
import 'package:sv_service_checker/enum/dateFilter.dart';
import '../services/service_check_service.dart';


String getDateFilterText(DateFilter filter) {
  switch (filter) {
    case DateFilter.all: return 'All Scans';
    case DateFilter.today: return 'Today';
    case DateFilter.yesterday: return 'Yesterday';
    case DateFilter.last7Days: return 'Last 7 Days';
    case DateFilter.last30Days: return 'Last 30 Days';
  }
}

class ServiceCheckerProvider with ChangeNotifier {
  List<dynamic> _serviceCheckers = [];
  bool _isLoading = false;
  bool _isLoadingMore = false;
  bool _hasMore = true;
  int _currentPage = 1;
  DateFilter _currentFilter = DateFilter.all;
  String? _selectedDriverId;
  String? _errorMessage;

  List<dynamic> get serviceCheckers => _serviceCheckers;
  bool get isLoading => _isLoading;
  bool get isLoadingMore => _isLoadingMore;
  bool get hasMore => _hasMore;
  DateFilter get currentFilter => _currentFilter;
  String? get selectedDriverId => _selectedDriverId;
  String? get errorMessage => _errorMessage;

  set currentFilter(DateFilter filter) {
    _currentFilter = filter;
    notifyListeners();
  }

  set selectedDriverId(String? driverId) {
    _selectedDriverId = driverId;
    notifyListeners();
  }


  Future<void> fetchServiceCheckers({bool refresh = false}) async {
    if (refresh) {
      _currentPage = 1;
      _hasMore = true;
      _serviceCheckers = [];
    }

    if (_isLoading || _isLoadingMore) return;

    if (_currentPage == 1) {
      _isLoading = true;
    } else {
      _isLoadingMore = true;
    }

    _errorMessage = null;
    notifyListeners();

    try {
      final response = await ServiceCheckService.getServiceCheckers(
        page: _currentPage,
        dateFilter: _currentFilter,
        driverId: _selectedDriverId,
      );

      if (refresh) {
        _serviceCheckers = response['data'] ?? [];
      } else {
        _serviceCheckers.addAll(response['data'] ?? []);
      }

      // Check if there's more data
      _hasMore = response['hasMore'] ?? false;
      if (_hasMore) {
        _currentPage++;
      }

      _errorMessage = null;
    } catch (e) {
      _errorMessage = e.toString();
      if (_currentPage == 1) {
        _serviceCheckers = [];
      }
    } finally {
      _isLoading = false;
      _isLoadingMore = false;
      notifyListeners();
    }
  }

  Future<void> refreshData() async {
    await fetchServiceCheckers(refresh: true);
  }

  void resetFilters() {
    _currentFilter = DateFilter.all;
    _selectedDriverId = null;
    notifyListeners();
  }

  Future<void> deleteChecker(String id) async {
    await ServiceCheckService.deleteServiceChecker(id);
    serviceCheckers.removeWhere((c) => c['id'] == id);
    notifyListeners();
  }
}
