import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:sv_service_checker/screens/service_checkers/edit-form.dart';
import '../../services/service_check_service.dart';

class ServiceCheckerDetailScreen extends StatefulWidget {
  final String serviceCheckerId;
  final bool isViewOnly;

  const ServiceCheckerDetailScreen({
    Key? key,
    required this.serviceCheckerId,
    this.isViewOnly = false,
  }) : super(key: key);

  @override
  _ServiceCheckerDetailScreenState createState() => _ServiceCheckerDetailScreenState();
}

class _ServiceCheckerDetailScreenState extends State<ServiceCheckerDetailScreen> {
  Map<String, dynamic> _serviceChecker = {};
  bool _isLoading = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _loadServiceCheckerData();
  }

  Future<void> _loadServiceCheckerData() async {
    try {
      final serviceChecker = await ServiceCheckService.getServiceChecker(widget.serviceCheckerId);
      if (mounted) {
        setState(() {
          _serviceChecker = serviceChecker;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = "Failed to load service checker: $e";
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: Text(
          'Service Check Details',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
        ),
        backgroundColor: Colors.blue[700],
        foregroundColor: Colors.white,
        elevation: 0,
        systemOverlayStyle: SystemUiOverlayStyle.light,
        iconTheme: IconThemeData(color: Colors.white),
        actions: [
          if (!widget.isViewOnly && !_isLoading)
            IconButton(
              icon: Icon(Icons.edit, size: 22),
              onPressed: () {
                Navigator.pushReplacement(
                  context,
                  MaterialPageRoute(
                    builder: (context) => ServiceCheckerEditForm(
                      serviceCheckerId: widget.serviceCheckerId,
                    ),
                  ),
                );
              },
              tooltip: 'Edit Service Check',
            ),
          if (!_isLoading)
            IconButton(
              icon: Icon(Icons.refresh, size: 22),
              onPressed: _loadServiceCheckerData,
              tooltip: 'Refresh',
            ),
        ],
      ),
      body: _isLoading
          ? _buildLoadingState()
          : _errorMessage != null
            ? _buildErrorState()
            : _buildDetailContent(),
    );
  }

  Widget _buildLoadingState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CircularProgressIndicator(
            valueColor: AlwaysStoppedAnimation(Colors.blue[700]!),
            strokeWidth: 2,
          ),
          SizedBox(height: 16),
          Text(
            'Loading service check details...',
            style: TextStyle(color: Colors.grey[600], fontSize: 14),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorState() {
    return Center(
      child: Padding(
        padding: EdgeInsets.all(20),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.error_outline, size: 64, color: Colors.red[400]),
            SizedBox(height: 16),
            Text(
              'Unable to Load Details',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w600,
                color: Colors.grey[800],
              ),
            ),
            SizedBox(height: 12),
            Text(
              _errorMessage!,
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey[600], fontSize: 14),
            ),
            SizedBox(height: 24),
            ElevatedButton(
              onPressed: _loadServiceCheckerData,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blue[700],
                padding: EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              child: Text(
                'Try Again',
                style: TextStyle(color: Colors.white, fontWeight: FontWeight.w500),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDetailContent() {
    final date = _serviceChecker['date'] != null 
        ? DateFormat('MMMM dd, yyyy').format(DateTime.parse(_serviceChecker['date']))
        : 'Unknown date';
    
    final driver = _serviceChecker['driver'] != null
        ? '${_serviceChecker['driver']['firstName']} ${_serviceChecker['driver']['lastName']}'
        : 'Unknown driver';

    // Calculate stats
    int totalItems = 0;
    int passedItems = 0;
    int failedItems = 0;

    if (_serviceChecker['items'] != null) {
      for (var category in _serviceChecker['items']) {
        if (category['notes'] != null) {
          for (var note in category['notes']) {
            totalItems++;
            if (note['passed'] == true) {
              passedItems++;
            } else {
              failedItems++;
            }
          }
        }
      }
    }

    final passRate = totalItems > 0 ? (passedItems / totalItems * 100) : 0;
    final statusColor = _getStatusColor(passRate.toDouble());
    final statusText = _getStatusText(passRate.toDouble());

    return SingleChildScrollView(
      padding: EdgeInsets.only(bottom: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header Card
          Container(
            width: double.infinity,
            padding: EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.white,
              boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 4, offset: Offset(0, 2))],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: statusColor.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.circle,
                            size: 10,
                            color: statusColor,
                          ),
                          SizedBox(width: 6),
                          Text(
                            statusText,
                            style: TextStyle(
                              color: statusColor,
                              fontWeight: FontWeight.w600,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Spacer(),
                    Text(
                      '#${_serviceChecker['id']}',
                      style: TextStyle(
                        color: Colors.grey[500],
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
                SizedBox(height: 16),
                Text(
                  'Service Check Summary',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: Colors.grey[800],
                  ),
                ),
                SizedBox(height: 12),
                Row(
                  children: [
                    _buildInfoItem(
                      icon: Icons.person,
                      label: 'Driver',
                      value: driver,
                    ),
                    SizedBox(width: 20),
                    _buildInfoItem(
                      icon: Icons.calendar_today,
                      label: 'Date',
                      value: date,
                    ),
                  ],
                ),
                SizedBox(height: 16),
                // Stats Grid
                Row(
                  children: [
                    Expanded(
                      child: _buildStatCard(
                        value: totalItems.toString(),
                        label: 'Total Items',
                        color: Colors.blue,
                        icon: Icons.checklist,
                      ),
                    ),
                    SizedBox(width: 12),
                    Expanded(
                      child: _buildStatCard(
                        value: passedItems.toString(),
                        label: 'Passed',
                        color: Colors.green,
                        icon: Icons.check_circle,
                      ),
                    ),
                    SizedBox(width: 12),
                    Expanded(
                      child: _buildStatCard(
                        value: failedItems.toString(),
                        label: 'Failed',
                        color: Colors.red,
                        icon: Icons.cancel,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          SizedBox(height: 1),
          // Inspection Categories
          ..._buildCategorySections(),
        ],
      ),
    );
  }

  Widget _buildInfoItem({required IconData icon, required String label, required String value}) {
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 16, color: Colors.grey[600]),
              SizedBox(width: 6),
              Text(
                label,
                style: TextStyle(
                  color: Colors.grey[600],
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
          SizedBox(height: 4),
          Text(
            value,
            style: TextStyle(
              color: Colors.grey[800],
              fontSize: 14,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatCard({required String value, required String label, required Color color, required IconData icon}) {
    return Container(
      padding: EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 16, color: color),
              Spacer(),
              Text(
                value,
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: color,
                ),
              ),
            ],
          ),
          SizedBox(height: 4),
          Text(
            label,
            style: TextStyle(
              color: Colors.grey[600],
              fontSize: 12,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  List<Widget> _buildCategorySections() {
    if (_serviceChecker['items'] == null || _serviceChecker['items'].isEmpty) {
      return [
        Padding(
          padding: EdgeInsets.all(20),
          child: Center(
            child: Text(
              'No inspection items found',
              style: TextStyle(color: Colors.grey[500]),
            ),
          ),
        ),
      ];
    }

    return _serviceChecker['items'].map<Widget>((category) {
      return _buildCategoryCard(category);
    }).toList();
  }

  Widget _buildCategoryCard(Map<String, dynamic> category) {
    final categoryName = category['category']['khmerName'] ?? 'Unknown Category';
    final items = category['notes'] ?? [];

    int passedInCategory = items.where((item) => item['passed'] == true).length;
    int totalInCategory = items.length;
    double categoryPassRate = totalInCategory > 0 ? (passedInCategory / totalInCategory * 100) : 0;

    return Container(
      margin: EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black12,
            blurRadius: 6,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Category Header
          Container(
            width: double.infinity,
            padding: EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.blue[50],
              borderRadius: BorderRadius.only(
                topLeft: Radius.circular(12),
                topRight: Radius.circular(12),
              ),
            ),
            child: Row(
              children: [
                Icon(Icons.checklist, size: 20, color: Colors.blue[700]),
                SizedBox(width: 12),
                Expanded(
                  child: Text(
                    categoryName,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: Colors.blue[800],
                    ),
                  ),
                ),
                Container(
                  padding: EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.blue[100],
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    '$passedInCategory/$totalInCategory',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: Colors.blue[800],
                    ),
                  ),
                ),
              ],
            ),
          ),
          // Items List
          ..._buildInspectionItems(items),
        ],
      ),
    );
  }

  List<Widget> _buildInspectionItems(List<dynamic> items) {
    return items.map<Widget>((note) {
      final inspectionItem = note['inspectionItem'];
      final itemName = inspectionItem['khmerName'] ?? 'Unknown Item';
      final passed = note['passed'] ?? false;
      final noteText = note['note'] ?? '';

      return Container(
        padding: EdgeInsets.all(16),
        decoration: BoxDecoration(
          border: Border(bottom: BorderSide(color: Colors.grey[100]!)),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Status Icon
            Container(
              width: 24,
              height: 24,
              decoration: BoxDecoration(
                color: passed ? Colors.green[100] : Colors.red[100],
                shape: BoxShape.circle,
              ),
              child: Icon(
                passed ? Icons.check : Icons.close,
                size: 16,
                color: passed ? Colors.green[600] : Colors.red[600],
              ),
            ),
            SizedBox(width: 12),
            // Item Details
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    itemName,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      color: Colors.grey[800],
                    ),
                  ),
                  if (noteText.isNotEmpty) ...[
                    SizedBox(height: 4),
                    Text(
                      'Note: $noteText',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey[600],
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      );
    }).toList();
  }

  Color _getStatusColor(double passRate) {
    if (passRate >= 90) return Colors.green;
    if (passRate >= 70) return Colors.orange;
    return Colors.red;
  }

  String _getStatusText(double passRate) {
    if (passRate >= 90) return 'Excellent';
    if (passRate >= 70) return 'Good';
    if (passRate >= 50) return 'Fair';
    return 'Poor';
  }
}