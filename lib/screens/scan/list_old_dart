import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:timeago/timeago.dart' as timeago;
import 'package:intl/intl.dart';

import '../../providers/scan_provider.dart';
import '../../models/scan_item.dart';
import 'detail.dart'; // Ensure correct import for ScanDetailScreen

// Enum for date filter options
enum DateFilter {
  all,
  today,
  yesterday,
  last7Days,
  last30Days,
}

class ScansListScreen extends StatefulWidget {
  const ScansListScreen({super.key});

  @override
  State<ScansListScreen> createState() => _ScansListScreenState();
}

class _ScansListScreenState extends State<ScansListScreen> {
  // We no longer manage _isLoading directly here; ScanProvider handles it.
  Map<DateTime, List<ScanItem>> _groupedAndFilteredScans = {};
  TextEditingController _searchController = TextEditingController();
  DateFilter _selectedDateFilter = DateFilter.all;
  bool _isSearching = false; 
  String? _baseUrl = ""; 
  String? _rootUrl = "";

  @override
  void initState() {
    super.initState();
    // Schedule the initial load after the first frame is built
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadScans();
      _loadBaseUrl();
    });

    _searchController.addListener(_onSearchChanged);
  }

  @override
  void dispose() {
    _searchController.removeListener(_onSearchChanged);
    _searchController.dispose();
    super.dispose();
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

  // Called when the search text changes
  void _onSearchChanged() {
    // Debounce the search to prevent excessive rebuilds
    // A simple debounce: apply filters after a short delay
    if (_searchController.text.isEmpty && _groupedAndFilteredScans.isEmpty) {
        // Optimization: if search is cleared and list is already empty, no need to re-filter
        return;
    }
    _applyFiltersAndGroupScans(Provider.of<ScanProvider>(context, listen: false).scans);
  }

  // Toggles the visibility of the search bar
  void _toggleSearch() {
    setState(() {
      _isSearching = !_isSearching;
      if (!_isSearching) {
        _searchController.clear(); // Clear search when hiding
        _applyFiltersAndGroupScans(Provider.of<ScanProvider>(context, listen: false).scans); // Re-apply filters
      }
    });
  }

  // Helper to remove time part from DateTime for grouping and comparisons
  DateTime _stripTime(DateTime dateTime) {
    return DateTime(dateTime.year, dateTime.month, dateTime.day);
  }

  // Primary method to load scans from the provider and then apply filters and group
  Future<void> _loadScans() async {
    try {
      final scanProvider = Provider.of<ScanProvider>(context, listen: false);
      await scanProvider.fetchScans(); // This fetches and updates provider's _scans list
      _applyFiltersAndGroupScans(scanProvider.scans); // Apply filters and group
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to load scans: ${e.toString()}')),
        );
      }
    }
  }

  // Applies current filters (text and date) and then groups the scans
  void _applyFiltersAndGroupScans(List<ScanItem> allScans) {
    List<ScanItem> filteredScans = allScans;

    // 1. Apply Text Filter
    if (_searchController.text.isNotEmpty) {
      final searchText = _searchController.text.toLowerCase();
      filteredScans = filteredScans.where((scan) {
        return scan.scannedText.toLowerCase().contains(searchText);
      }).toList();
    }

    // 2. Apply Date Filter
    final now = _stripTime(DateTime.now());
    filteredScans = filteredScans.where((scan) {
      final scanDateOnly = _stripTime(scan.date);
      switch (_selectedDateFilter) {
        case DateFilter.all:
          return true; // No date filter
        case DateFilter.today:
          return scanDateOnly == now;
        case DateFilter.yesterday:
          return scanDateOnly == now.subtract(const Duration(days: 1));
        case DateFilter.last7Days:
          return scanDateOnly.isAfter(now.subtract(const Duration(days: 7)));
        case DateFilter.last30Days:
          return scanDateOnly.isAfter(now.subtract(const Duration(days: 30)));
      }
    }).toList();

    // 3. Group the filtered scans
    final Map<DateTime, List<ScanItem>> tempGrouped = {};
    for (var scan in filteredScans) {
      final dateOnly = _stripTime(scan.date);
      if (!tempGrouped.containsKey(dateOnly)) {
        tempGrouped[dateOnly] = [];
      }
      tempGrouped[dateOnly]!.add(scan);
    }

    // Sort each group's scans by time descending
    tempGrouped.forEach((key, value) {
      value.sort((a, b) => b.date.compareTo(a.date));
    });

    // Sort the date keys (groups) themselves in descending order
    final sortedKeys = tempGrouped.keys.toList()..sort((a, b) => b.compareTo(a));

    final Map<DateTime, List<ScanItem>> finalGroupedScans = {};
    for (var key in sortedKeys) {
      finalGroupedScans[key] = tempGrouped[key]!;
    }

    setState(() {
      _groupedAndFilteredScans = finalGroupedScans;
    });
  }

  Future<void> _confirmDeleteScan(int scanId) async {
    final bool confirm = await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Confirm Deletion'),
        content: const Text('Are you sure you want to delete this scan? This action cannot be undone.'),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Theme.of(ctx).colorScheme.error,
            ),
            child: const Text('Delete'),
          ),
        ],
      ),
    ) ?? false;

    if (confirm) {
      final scanProvider = Provider.of<ScanProvider>(context, listen: false);
      final bool? success = await scanProvider.deleteScan(scanId);
      debugPrint("success: $success");
      if (mounted) {
        if (success == true) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Scan deleted successfully!')),
          );
          _applyFiltersAndGroupScans(scanProvider.scans); // Re-apply filters to updated list
        } else if (success == false) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Failed to delete scan. Scan not found or other issue.')),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('An error occurred during deletion.')),
          );
        }
      }
    }
  }

  // Formats date for group headers (e.g., "Today", "Yesterday", "June 16, 2025")
  String _formatDateForHeader(DateTime date) {
    final now = _stripTime(DateTime.now());
    final yesterday = _stripTime(now.subtract(const Duration(days: 1))); // Corrected for accurate yesterday

    if (date == now) {
      return 'Today';
    } else if (date == yesterday) {
      return 'Yesterday';
    } else {
      return DateFormat('MMMM d, y').format(date);
    }
  }

  // Helper to get text for date filter chips
  String _getDateFilterText(DateFilter filter) {
    switch (filter) {
      case DateFilter.all: return 'All Scans';
      case DateFilter.today: return 'Today';
      case DateFilter.yesterday: return 'Yesterday';
      case DateFilter.last7Days: return 'Last 7 Days';
      case DateFilter.last30Days: return 'Last 30 Days';
    }
  }

  @override
  Widget build(BuildContext context) {
    final ColorScheme colorScheme = Theme.of(context).colorScheme;

    return Consumer<ScanProvider>(
      builder: (context, scanProvider, child) {
        // Re-apply filters and grouping whenever the provider's scan list changes
        // This ensures filters are maintained even after new scans or deletions.
        if (!scanProvider.isFetchingScans && scanProvider.scans.isNotEmpty && _groupedAndFilteredScans.isEmpty ||
            (!scanProvider.isFetchingScans && _searchController.text.isEmpty && _selectedDateFilter == DateFilter.all && _groupedAndFilteredScans.length != scanProvider.scans.length))
        {
          // This ensures initial grouping or re-grouping if filter changes
          // It's a bit of a heuristic. A more robust way might be to debounce
          // this, or have a direct 'applyFilters' method in provider.
          // For now, this handles initial load and filter changes.
          WidgetsBinding.instance.addPostFrameCallback((_) {
            _applyFiltersAndGroupScans(scanProvider.scans);
          });
        }


        return Scaffold(
          appBar: AppBar(
            title: _isSearching
                ? TextField(
                    controller: _searchController,
                    decoration: InputDecoration(
                      hintText: 'Search scans...',
                      hintStyle: TextStyle(color: colorScheme.onPrimary.withOpacity(0.7)),
                      border: InputBorder.none,
                      suffixIcon: IconButton(
                        icon: Icon(Icons.clear, color: colorScheme.onPrimary),
                        onPressed: () {
                          _searchController.clear();
                          _applyFiltersAndGroupScans(scanProvider.scans);
                        },
                      ),
                    ),
                    style: TextStyle(color: colorScheme.onPrimary, fontSize: 18),
                    cursorColor: colorScheme.onPrimary,
                  )
                : const Text('My Scans'),
            backgroundColor: colorScheme.primary,
            foregroundColor: colorScheme.onPrimary,
            elevation: 0,
            actions: [
              IconButton(
                icon: Icon(_isSearching ? Icons.close : Icons.search),
                onPressed: _toggleSearch,
              ),
              PopupMenuButton<DateFilter>(
                icon: Icon(Icons.filter_list, color: colorScheme.onPrimary),
                onSelected: (DateFilter filter) {
                  setState(() {
                    _selectedDateFilter = filter;
                    _applyFiltersAndGroupScans(scanProvider.scans); // Re-apply filters
                  });
                },
                itemBuilder: (BuildContext context) {
                  return DateFilter.values.map((DateFilter filter) {
                    return PopupMenuItem<DateFilter>(
                      value: filter,
                      child: Text(_getDateFilterText(filter)),
                    );
                  }).toList();
                },
              ),
            ],
          ),
          body: Column(
            children: [
              // Date Filter Chips (below AppBar)
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                child: Row(
                  children: DateFilter.values.map((filter) {
                    return Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 4.0),
                      child: ChoiceChip(
                        label: Text(_getDateFilterText(filter)),
                        selected: _selectedDateFilter == filter,
                        onSelected: (selected) {
                          if (selected) {
                            setState(() {
                              _selectedDateFilter = filter;
                              _applyFiltersAndGroupScans(scanProvider.scans);
                            });
                          }
                        },
                        selectedColor: colorScheme.secondary.withOpacity(0.8),
                        labelStyle: TextStyle(
                          color: _selectedDateFilter == filter ? colorScheme.onSecondary : colorScheme.onSurface,
                          fontWeight: _selectedDateFilter == filter ? FontWeight.bold : FontWeight.normal,
                        ),
                        backgroundColor: colorScheme.surfaceVariant.withOpacity(0.3),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(20),
                          side: BorderSide(
                            color: _selectedDateFilter == filter ? colorScheme.secondary : colorScheme.outline.withOpacity(0.5),
                            width: 1,
                          ),
                        ),
                        elevation: _selectedDateFilter == filter ? 4 : 1,
                      ),
                    );
                  }).toList(),
                ),
              ),
              Expanded(
                child: scanProvider.isFetchingScans // Use provider's loading state
                    ? Center(
                        child: CircularProgressIndicator(color: colorScheme.primary),
                      )
                    : RefreshIndicator(
                        onRefresh: _loadScans,
                        color: colorScheme.primary,
                        child: _groupedAndFilteredScans.isEmpty
                            ? Center(
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(Icons.image_not_supported_outlined, size: 80, color: colorScheme.onBackground.withOpacity(0.4)),
                                    const SizedBox(height: 16),
                                    Text(
                                      _searchController.text.isNotEmpty || _selectedDateFilter != DateFilter.all
                                          ? 'No matching scans found.'
                                          : 'No scans yet!',
                                      style: Theme.of(context).textTheme.headlineSmall?.copyWith(color: colorScheme.onBackground.withOpacity(0.7)),
                                    ),
                                    const SizedBox(height: 8),
                                    Text(
                                      _searchController.text.isNotEmpty || _selectedDateFilter != DateFilter.all
                                          ? 'Try adjusting your filters or search terms.'
                                          : 'Start scanning to see your documents here.',
                                      textAlign: TextAlign.center,
                                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: colorScheme.onBackground.withOpacity(0.6)),
                                    ),
                                    const SizedBox(height: 24),
                                    ElevatedButton.icon(
                                      onPressed: () {
                                        Navigator.pop(context);
                                      },
                                      icon: const Icon(Icons.document_scanner),
                                      label: const Text('Scan New Document'),
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: colorScheme.secondary,
                                        foregroundColor: colorScheme.onSecondary,
                                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                                        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                                      ),
                                    )
                                  ],
                                ),
                              )
                            : ListView.builder(
                                padding: const EdgeInsets.all(16.0),
                                itemCount: _groupedAndFilteredScans.keys.length,
                                itemBuilder: (context, groupIndex) {
                                  final date = _groupedAndFilteredScans.keys.elementAt(groupIndex);
                                  final scansForDate = _groupedAndFilteredScans[date]!;

                                  return Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Padding(
                                        padding: const EdgeInsets.symmetric(vertical: 12.0),
                                        child: Text(
                                          _formatDateForHeader(date),
                                          style: Theme.of(context).textTheme.titleLarge?.copyWith(
                                                fontWeight: FontWeight.bold,
                                                color: colorScheme.primary,
                                              ),
                                        ),
                                      ),
                                      ListView.builder(
                                        shrinkWrap: true,
                                        physics: const NeverScrollableScrollPhysics(),
                                        itemCount: scansForDate.length,
                                        itemBuilder: (context, scanIndex) {
                                          final scan = scansForDate[scanIndex];
                                          return _buildScanCard(context, scan, _rootUrl!);
                                        },
                                      ),
                                      if (groupIndex < _groupedAndFilteredScans.keys.length - 1)
                                        const Divider(height: 40, thickness: 0.5),
                                    ],
                                  );
                                },
                              ),
                      ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildScanCard(BuildContext context, ScanItem scan, String _rootUrl) {
    final ColorScheme colorScheme = Theme.of(context).colorScheme;
    final String timeAgoString = timeago.format(scan.date);

    

    return Card(
      margin: const EdgeInsets.symmetric(vertical: 8.0),
      elevation: 4,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => ScanDetailScreen(item: scan)),
          );
        },
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: Image.network(
                  "${_rootUrl}${scan.imagePath}",
                  width: 80,
                  height: 80,
                  fit: BoxFit.cover,
                  errorBuilder: (context, error, stackTrace) => Container(
                    width: 80,
                    height: 80,
                    color: colorScheme.surfaceVariant,
                    child: Icon(Icons.broken_image, color: colorScheme.onSurface.withOpacity(0.6)),
                  ),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      scan.scannedText.length > 100
                          ? '${scan.scannedText.substring(0, 100)}...'
                          : scan.scannedText,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w600,
                            color: colorScheme.onSurface,
                          ),
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Scanned by ${scan.user.username ?? scan.user.email ?? 'Unknown User'}',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: colorScheme.onSurface.withOpacity(0.7),
                          ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      timeAgoString,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: colorScheme.onSurface.withOpacity(0.5),
                            fontStyle: FontStyle.italic,
                          ),
                    ),
                  ],
                ),
              ),
              IconButton(
                icon: Icon(Icons.delete_outline, color: colorScheme.error),
                onPressed: () => _confirmDeleteScan(scan.id),
                tooltip: 'Delete Scan',
              ),
            ],
          ),
        ),
      ),
    );
  }
}
