import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sv_invoice_scanner/models/user.model.dart';
import 'package:sv_invoice_scanner/providers/auth_provider.dart';
import 'package:sv_invoice_scanner/screens/scan/detail.dart';
import 'package:timeago/timeago.dart' as timeago;

import '../../enum/dateFilter.dart';
import '../../models/scan_item.dart';
import '../../providers/scan_provider.dart';
import '../in_app_scanner.dart';

class ScansListScreen extends StatefulWidget {
  const ScansListScreen({super.key});

  @override
  State<ScansListScreen> createState() => _ScansListScreenState();
}

class _ScansListScreenState extends State<ScansListScreen> {
  final ScrollController _scrollController = ScrollController();
  final TextEditingController _searchController = TextEditingController();

  DateFilter _selectedFilter = DateFilter.all;
  String _searchTerm = "";
  bool _isLoadingMore = false;
  String? _baseUrl = ""; 
  String? _rootUrl = "";

  bool _showCropped = false;


  @override
  void initState() {
    super.initState();
    _loadBaseUrl();
    final provider = Provider.of<ScanProvider>(context, listen: false);
    provider.resetPagination();

    _fetchInitialData();

    _requestPermissions();

    _scrollController.addListener(_onScroll);
  }


  Future<void> _requestPermissions() async {
    if (Theme.of(context).platform == TargetPlatform.android) {
      await Permission.storage.request();
      await Permission.mediaLibrary.request();
    }
  }


  Future<void> _fetchInitialData() async {
    await Provider.of<ScanProvider>(context, listen: false)
          .fetchMoreScans(filter: _selectedFilter, search: _searchTerm, loadMore: false);
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

  void _onScroll() {
    final maxScroll = _scrollController.position.maxScrollExtent;
    final currentScroll = _scrollController.position.pixels;
    
    // Load more when we're within 200 pixels of the start (which is the top in reverse mode)
    if (maxScroll - currentScroll <= 200 && 
        !_isLoadingMore &&
        Provider.of<ScanProvider>(context, listen: false).hasMore) {
      _loadMoreData();
    }
  }

  Future<void> _loadMoreData() async {
    if (_isLoadingMore) return;
    
    setState(() => _isLoadingMore = true);
    try {
      final provider = Provider.of<ScanProvider>(context, listen: false);
      await provider.fetchMoreScans(
        filter: _selectedFilter,
        search: _searchTerm,
        loadMore: true,
      );
    } finally {
      if (mounted) {
        setState(() => _isLoadingMore = false);
      }
    }
  }

  void _onSearchChanged(String value) async {
    _searchTerm = value.trim();
    await Provider.of<ScanProvider>(context, listen: false)
          .resetAndFetch(_selectedFilter, _searchTerm);
  }

  void _onFilterChanged(DateFilter newFilter) async {
    setState(() {
      _selectedFilter = newFilter;
    });
    await Provider.of<ScanProvider>(context, listen: false)
          .resetAndFetch(_selectedFilter, _searchTerm);
  }

  void _toggleImageView(BuildContext context) {
    final provider = Provider.of<ScanProvider>(context, listen: false);
    provider.toggleShowCropped();

    final isCropped = provider.showCropped;

    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(isCropped ? 'Showing Cropped Images' : 'Showing Original Images'),
      duration: const Duration(seconds: 1),
    ));
  }



  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<ScanProvider>(context);
    final authProvider = Provider.of<AuthProvider>(context);
    final scans = provider.scans;
    final isLoading = provider.isLoading;
    final colorScheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final userMap = authProvider.user;
    final user = User.fromJson(userMap!);
    print("authProvider: $user");

    final isCropped = provider.showCropped;

    return Scaffold(
      appBar: AppBar(
        backgroundColor: isDark ? colorScheme.surfaceVariant : colorScheme.primary,
        elevation: 4,
        centerTitle: true,
        title: const Text(
          "Your Scans",
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 20,
          ),
        ),
        actions: [
          IconButton(
            tooltip: isCropped ? 'Show Original' : 'Show Cropped',
            icon: Icon(isCropped ? Icons.crop : Icons.crop_original),
            onPressed: () => _toggleImageView(context),
          ),
        ],
      ),
      body: Column(
        children: [
          _buildSearchAndFilter(colorScheme, provider),
          Expanded(
            child: Stack(
              children: [
                NotificationListener<ScrollNotification>(
                  onNotification: (scrollNotification) {
                    if (scrollNotification is ScrollEndNotification &&
                        _scrollController.position.pixels ==
                            _scrollController.position.minScrollExtent &&
                        !_isLoadingMore) {
                      provider.resetAndFetch(_selectedFilter, _searchTerm);
                      return true;
                    }
                    return false;
                  },
                  child: RefreshIndicator(
                    onRefresh: () async {
                      await provider.resetAndFetch(_selectedFilter, _searchTerm);
                      if (_scrollController.hasClients) {
                        _scrollController.animateTo(
                          0,
                          duration: const Duration(milliseconds: 300),
                          curve: Curves.easeOut,
                        );
                      }
                    },
                    displacement: 40,
                    child: ListView.builder(
                      controller: _scrollController,
                      reverse: false,
                      physics: const AlwaysScrollableScrollPhysics(),
                      itemCount: scans.length + (_isLoadingMore ? 1 : 0),
                      itemBuilder: (context, index) {
                        if (index >= scans.length) {
                          return _buildLoadMoreIndicator();
                        }
                        return _buildScanCard(context, scans[index], _rootUrl!, user);
                      },
                    ),
                  ),
                ),

                // Loading indicator for search
                if (isLoading && !_isLoadingMore)
                  const Center(
                    child: CircularProgressIndicator(),
                  ),

                // Empty state
                if (!isLoading && !_isLoadingMore && scans.isEmpty)
                  SingleChildScrollView(
                    child: Container(
                      constraints: BoxConstraints(
                        minHeight: MediaQuery.of(context).size.height - 100,
                      ),
                      padding: const EdgeInsets.all(20),
                      child: Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            // Image illustration
                            Image.asset(
                              'assets/images/not_found.png',
                              width: 200,
                              height: 200,
                              fit: BoxFit.contain,
                              color: Theme.of(context).colorScheme.primary.withOpacity(0.7),
                              colorBlendMode: BlendMode.modulate,
                            ),
                            const SizedBox(height: 16),
                            // Title with cool text style
                            Text(
                              'No Scans Found',
                              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                                    fontWeight: FontWeight.bold,
                                    color: Theme.of(context).colorScheme.onSurface.withOpacity(0.8),
                                  ),
                            ),
                            const SizedBox(height: 8),
                            // Description with dynamic text
                            Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 48),
                              child: Text(
                                _searchTerm.isEmpty
                                    ? 'Your scan history is empty'
                                    : 'No matches for "$_searchTerm"',
                                textAlign: TextAlign.center,
                                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                      color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
                                    ),
                              ),
                            ),
                            const SizedBox(height: 16),
                            // Action button with nice elevation
                            if (_searchTerm.isNotEmpty)
                              ElevatedButton(
                                onPressed: () {
                                  _searchController.clear();
                                  _onSearchChanged('');
                                },
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Theme.of(context).colorScheme.primaryContainer,
                                  foregroundColor: Theme.of(context).colorScheme.onPrimaryContainer,
                                  elevation: 1,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                                ),
                                child: const Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(Icons.clear_rounded, size: 20),
                                    SizedBox(width: 5),
                                    Text('Clear Search'),
                                  ],
                                ),
                              )
                            else
                              FilledButton(
                                onPressed: () {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(builder: (_) => const ScanScreen()),
                                  );
                                },
                                style: FilledButton.styleFrom(
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                                ),
                                child: const Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(Icons.document_scanner_rounded, size: 20),
                                    SizedBox(width: 8),
                                    Text('Scan Document'),
                                  ],
                                ),
                              ),
                          ],
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLoadMoreIndicator() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 16.0),
      child: Center(
        child: SizedBox(
          width: 24,
          height: 24,
          child: CircularProgressIndicator(
            strokeWidth: 2,
            valueColor: AlwaysStoppedAnimation<Color>(
              Theme.of(context).colorScheme.primary,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSearchAndFilter(ColorScheme colorScheme, ScanProvider provider) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Column(
        children: [
          TextField(
            controller: _searchController,
            onChanged: _onSearchChanged,
            decoration: InputDecoration(
              hintText: "Search scans...",
              prefixIcon: const Icon(Icons.search),
              suffixIcon: _searchController.text.isNotEmpty
                  ? IconButton(
                      icon: const Icon(Icons.clear),
                      onPressed: () {
                        _searchController.clear();
                        _onSearchChanged('');
                      },
                    )
                  : null,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
              ),
            ),
          ),
          const SizedBox(height: 12),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: DateFilter.values.map((filter) {
                final bool isSelected = _selectedFilter == filter;
                return Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: ChoiceChip(
                    label: Text(provider.getDateFilterText(filter)),
                    selected: isSelected,
                    onSelected: (_) => _onFilterChanged(filter),
                    selectedColor: colorScheme.primaryContainer,
                    labelStyle: TextStyle(
                      color: isSelected
                          ? colorScheme.onPrimaryContainer
                          : colorScheme.onSurface,
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildScanCard(BuildContext context, ScanItem scan, String _rootUrl, User user) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme colorScheme = theme.colorScheme;
    final bool isDark = theme.brightness == Brightness.dark;
    final String timeAgoString = timeago.format(scan.date);

    final provider = Provider.of<ScanProvider>(context);
    final isCropped = provider.showCropped;

    String imagePath_ = isCropped && scan.croppedPath != null
      ? scan.croppedPath!
      : scan.imagePath;
    final imagePath = '$_rootUrl${imagePath_}';
    
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      elevation: 4,
      color: isDark ? colorScheme.surface : Colors.white,
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
                  imagePath,
                  width: 80,
                  height: 80,
                  fit: BoxFit.cover,
                  errorBuilder: (context, error, stackTrace) => Container(
                    width: 80,
                    height: 80,
                    color: colorScheme.surfaceVariant,
                    child: Icon(
                      Icons.broken_image, 
                      color: colorScheme.onSurface.withOpacity(0.6),
                    ),
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
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                        color: colorScheme.onSurface,
                        fontFamily: 'NotoSansKhmer'
                      ),
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Scanned by ${scan.user.username ?? scan.user.email ?? 'Unknown User'}',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: colorScheme.onSurface.withOpacity(0.7),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      timeAgoString,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: colorScheme.onSurface.withOpacity(0.5),
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                  ],
                ),
              ),
              if(user.isAdmin)
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

  @override
  void dispose() {
    _scrollController.dispose();
    _searchController.dispose();
    super.dispose();
  }
}
