import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:sv_service_checker/enum/dateFilter.dart';
import 'package:sv_service_checker/providers/service_checker_provider.dart';
import 'package:sv_service_checker/screens/service_checkers/detail.dart';
import 'package:sv_service_checker/screens/service_checkers/edit-form.dart';
import 'package:sv_service_checker/screens/service_checkers/form.dart';
import 'package:sv_service_checker/widgets/service_checker_item.dart';
import '../../services/service_check_service.dart';
import '../../widgets/date_filter_bar.dart';

class ServiceCheckersIndex extends StatefulWidget {
  const ServiceCheckersIndex({Key? key}) : super(key: key);

  @override
  _ServiceCheckersIndexState createState() => _ServiceCheckersIndexState();
}

class _ServiceCheckersIndexState extends State<ServiceCheckersIndex> {
  final ScrollController _scrollController = ScrollController();
  List<dynamic> _drivers = [];

  @override
  void initState() {
    super.initState();
    _loadDrivers();
    _scrollController.addListener(_scrollListener);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<ServiceCheckerProvider>().fetchServiceCheckers();
    });
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _loadDrivers() async {
    try {
      final drivers = await ServiceCheckService.getDrivers();
      setState(() {
        _drivers = drivers;
      });
    } catch (e) {
      print("Error loading drivers: $e");
    }
  }

  void _scrollListener() {
    if (_scrollController.position.pixels ==
        _scrollController.position.maxScrollExtent) {
      final provider = context.read<ServiceCheckerProvider>();
      if (!provider.isLoadingMore && provider.hasMore) {
        provider.fetchServiceCheckers();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Service Checkers'),
        backgroundColor: Colors.blue[700],
        foregroundColor: Colors.white,
        elevation: 4,
        actions: [
          IconButton(
            icon: Icon(Icons.refresh),
            onPressed: () {
              context.read<ServiceCheckerProvider>().refreshData();
            },
          ),
        ],
      ),
      body: Consumer<ServiceCheckerProvider>(
        builder: (context, provider, child) {
          return Column(
            children: [
              // Filter bar
              Padding(
                padding: EdgeInsets.all(12),
                child: DateFilterBar(
                  currentFilter: provider.currentFilter,
                  onFilterChange: (filter) {
                    provider.currentFilter = filter;
                    provider.fetchServiceCheckers(refresh: true);
                  },
                  selectedDriverId: provider.selectedDriverId,
                  drivers: _drivers,
                  onDriverChange: (driverId) {
                    provider.selectedDriverId = driverId;
                    provider.fetchServiceCheckers(refresh: true);
                  },
                ),
              ),
              
              // Results count
              Padding(
                padding: EdgeInsets.symmetric(horizontal: 16),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      '${provider.serviceCheckers.length} results',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Colors.grey[600],
                      ),
                    ),
                    if (provider.currentFilter != DateFilter.all || provider.selectedDriverId != null)
                      TextButton(
                        onPressed: () {
                          provider.resetFilters();
                          provider.fetchServiceCheckers(refresh: true);
                        },
                        child: Text('Clear Filters'),
                      ),
                  ],
                ),
              ),
              
              // Loading indicator or error message
              if (provider.isLoading && provider.serviceCheckers.isEmpty)
                Expanded(
                  child: Center(child: CircularProgressIndicator()),
                )
              else if (provider.errorMessage != null && provider.serviceCheckers.isEmpty)
                Expanded(
                  child: Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.error_outline, size: 48, color: Colors.red),
                        SizedBox(height: 16),
                        Text(
                          'Error loading data',
                          style: TextStyle(fontSize: 18, color: Colors.red),
                        ),
                        SizedBox(height: 8),
                        Text(
                          provider.errorMessage!,
                          textAlign: TextAlign.center,
                        ),
                        SizedBox(height: 16),
                        ElevatedButton(
                          onPressed: () {
                            provider.fetchServiceCheckers(refresh: true);
                          },
                          child: Text('Retry'),
                        ),
                      ],
                    ),
                  ),
                )
              else if (provider.serviceCheckers.isEmpty)
                Expanded(
                  child: Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.assignment, size: 48, color: Colors.grey),
                        SizedBox(height: 16),
                        Text(
                          'No service checkers found',
                          style: TextStyle(fontSize: 18, color: Colors.grey),
                        ),
                        SizedBox(height: 8),
                        Text(
                          'Try adjusting your filters or create a new service checker',
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  ),
                )
              else
                // Service checkers list
                Expanded(
                  child: RefreshIndicator(
                    onRefresh: () async {
                      await provider.refreshData();
                    },
                    child: ListView.builder(
                      controller: _scrollController,
                      itemCount: provider.serviceCheckers.length + (provider.hasMore ? 1 : 0),
                      itemBuilder: (context, index) {
                        if (index == provider.serviceCheckers.length) {
                          return Padding(
                            padding: EdgeInsets.all(16),
                            child: Center(
                              child: provider.isLoadingMore
                                  ? CircularProgressIndicator()
                                  : Text('No more items to load'),
                            ),
                          );
                        }
                        
                        final serviceChecker = provider.serviceCheckers[index];
                        return ServiceCheckerItem(
                          serviceChecker: serviceChecker,
                          onTap: () {
                            // Navigate to detail screen
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => ServiceCheckerDetailScreen(
                                  serviceCheckerId: serviceChecker['id'].toString(),
                                ),
                              ),
                            );
                          },
                          onView: () {
                            // Navigate to view-only detail screen
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => ServiceCheckerDetailScreen(
                                  serviceCheckerId: serviceChecker['id'].toString(),
                                  isViewOnly: true,
                                ),
                              ),
                            );
                          },
                          onEdit: () {
                            // Navigate to edit screen
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => ServiceCheckerEditForm(
                                  serviceCheckerId: serviceChecker['id'].toString(),
                                ),
                              ),
                            );
                          },
                          onDelete: () {
                            // Show delete confirmation dialog
                            _showDeleteDialog(context, serviceChecker);
                          },
                        );

                      },
                    ),
                  ),
                ),
            ],
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          // Navigate to create form
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => ServiceCheckerForm(),
            ),
          );
        },
        backgroundColor: Colors.blue,
        child: Icon(Icons.add, color: Colors.white),
      ),
    );
  }
}


void _showDeleteDialog(BuildContext context, dynamic serviceChecker) {
  final driverName = serviceChecker['driver'] != null
      ? '${serviceChecker['driver']['firstName']} ${serviceChecker['driver']['lastName']}'
      : 'this service check';
  
  final date = serviceChecker['date'] != null 
      ? DateFormat('MMM dd, yyyy').format(DateTime.parse(serviceChecker['date']))
      : '';

  showDialog(
    context: context,
    builder: (BuildContext context) {
      return AlertDialog(
        title: Row(
          children: [
            Icon(Icons.delete, color: Colors.red),
            SizedBox(width: 8),
            Text('Confirm Delete'),
          ],
        ),
        content: Text(
          'Are you sure you want to delete the service check for $driverName on $date?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text('Cancel', style: TextStyle(color: Colors.grey[600])),
          ),
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
              _deleteServiceChecker(context, serviceChecker['id'].toString());
            },
            child: Text('Delete', style: TextStyle(color: Colors.red)),
          ),
        ],
      );
    },
  );
}

Future<void> _deleteServiceChecker(BuildContext context, String id) async {
  try {
    // Call your delete service method
    await ServiceCheckService.deleteServiceChecker(id);
    
    // Show success message
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Service check deleted successfully'),
        backgroundColor: Colors.green,
      ),
    );
    
    // Refresh the list
  } catch (e) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Failed to delete service check: $e'),
        backgroundColor: Colors.red,
      ),
    );
  }
}