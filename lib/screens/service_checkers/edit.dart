import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:flutter/services.dart';
import '../../services/service_check_service.dart';

class ServiceCheckerEditForm extends StatefulWidget {
  final String serviceCheckerId;

  const ServiceCheckerEditForm({Key? key, required this.serviceCheckerId}) : super(key: key);

  @override
  _ServiceCheckerEditFormState createState() => _ServiceCheckerEditFormState();
}

class _ServiceCheckerEditFormState extends State<ServiceCheckerEditForm> {
  final _formKey = GlobalKey<FormState>();
  final _scrollController = ScrollController();
  DateTime? _selectedDate;
  String? _selectedDriverId;
  List<dynamic> _drivers = [];
  Map<String, dynamic> _serviceChecker = {};
  Map<String, dynamic> _formData = {};
  bool _isLoading = true;
  bool _isSubmitting = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _loadServiceCheckerData();
    _loadDrivers();
  }


  Future<void> _loadDrivers() async {
    try {
      final data = await ServiceCheckService.getDrivers();
      if (mounted) {
        setState(() {
          _drivers = data;
        });
      }
    } catch (e) {
      debugPrint("Error loading drivers: $e");
      if (mounted) {
        setState(() {
          _errorMessage = "Failed to load drivers: $e";
        });
      }
    }
  }

  Future<void> _loadServiceCheckerData() async {
    try {
      final serviceChecker = await ServiceCheckService.getServiceChecker(widget.serviceCheckerId);
      if (mounted) {
        setState(() {
          _serviceChecker = serviceChecker;
          _selectedDate = DateTime.parse(serviceChecker['date']);
          _selectedDriverId = serviceChecker['driver']['id'].toString();
          _initializeFormData();
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

  void _initializeFormData() {
    // Initialize form data with existing values
    if (_serviceChecker['items'] != null) {
      for (var item in _serviceChecker['items']) {
        if (item['notes'] != null) {
          for (var note in item['notes']) {
            _formData['passed_${note['inspectionItem']['id']}'] = {'value': note['passed']};
            _formData['note_${note['inspectionItem']['id']}'] = {'value': note['note'] ?? ''};
          }
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: Text('Edit Service Check', style: TextStyle(color: Colors.white)),
        backgroundColor: Colors.blue[700],
        foregroundColor: Colors.white,
        elevation: 0,
        systemOverlayStyle: SystemUiOverlayStyle.light,
        iconTheme: IconThemeData(color: Colors.white),
        actions: [
          if (!_isLoading)
            IconButton(
              icon: Icon(Icons.refresh),
              onPressed: _loadServiceCheckerData,
              tooltip: 'Reload',
            ),
        ],
      ),
      body: _isLoading
          ? _buildLoadingState()
          : Stack(
                children: [
                  _buildFormContent(),
                  _buildFloatingActionButton(),
                ],
              ),
    );
  }

  Widget _buildLoadingState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CircularProgressIndicator(valueColor: AlwaysStoppedAnimation(Colors.blue[700]!)),
          SizedBox(height: 16),
          Text('Loading service check...', style: TextStyle(color: Colors.grey[600])),
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
            Icon(Icons.error_outline, size: 64, color: Colors.red),
            SizedBox(height: 16),
            Text(
              'Error Loading Data',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.red),
            ),
            SizedBox(height: 8),
            Text(
              _errorMessage!,
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey[600]),
            ),
            SizedBox(height: 20),
            ElevatedButton(
              onPressed: _loadServiceCheckerData,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blue[700],
                padding: EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              ),
              child: Text('Try Again', style: TextStyle(color: Colors.white)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFormContent() {
    return Form(
      key: _formKey,
      child: Column(
        children: [
          // Header with basic info
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
                Text(
                  'Service Check #${_serviceChecker['id']}',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.blue[700]),
                ),
                SizedBox(height: 12),
                Row(
                  children: [
                    Icon(Icons.calendar_today, size: 16, color: Colors.grey[600]),
                    SizedBox(width: 8),
                    Text(
                      _selectedDate != null 
                          ? DateFormat('MMM dd, yyyy').format(_selectedDate!)
                          : 'No date selected',
                      style: TextStyle(color: Colors.grey[600]),
                    ),
                    Expanded(child: _buildDriverDropdown()),
                  ],
                ),
              ],
            ),
          ),
          SizedBox(height: 1),
          // Inspection items list
          Expanded(
            child: ListView.builder(
              controller: _scrollController,
              padding: EdgeInsets.only(bottom: 80),
              itemCount: _serviceChecker['items']?.length ?? 0,
              itemBuilder: (context, index) {
                final category = _serviceChecker['items'][index];
                return _buildCategoryCard(category);
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDriverDropdown() {
    return DropdownButtonFormField<String>(
      isExpanded: true, // ✅ makes sure it uses full width safely
      decoration: InputDecoration(
        border: OutlineInputBorder(),
        contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 16),
      ),
      value: _selectedDriverId,
      hint: Text('Select a driver'),
      onChanged: (String? newValue) {
        setState(() {
          _selectedDriverId = newValue;
        });
      },
      items: _drivers.map<DropdownMenuItem<String>>((driver) {
        return DropdownMenuItem<String>(
          value: driver['id'].toString(),
          child: Text('${driver['firstName']} ${driver['lastName']}'),
        );
      }).toList(),
      validator: (value) {
        if (value == null || value.isEmpty) {
          return 'Please select a driver';
        }
        return null;
      },
    );
  }



  Widget _buildCategoryCard(Map<String, dynamic> category) {
    return Card(
      margin: EdgeInsets.all(12),
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Category header
            Row(
              children: [
                Icon(Icons.checklist, color: Colors.blue[700]),
                SizedBox(width: 12),
                Expanded(
                  child: Text(
                    category['category']['khmerName'] ?? 'Unknown Category',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
            SizedBox(height: 16),
            Divider(height: 1),
            SizedBox(height: 16),
            // Inspection items
            ..._buildInspectionItems(category),
          ],
        ),
      ),
    );
  }

  List<Widget> _buildInspectionItems(Map<String, dynamic> category) {
    List<Widget> items = [];
    
    if (category['notes'] != null) {
      for (var note in category['notes']) {
        final inspectionItem = note['inspectionItem'];
        items.add(_buildInspectionItemRow(inspectionItem, note));
        items.add(SizedBox(height: 16));
      }
    }
    
    // Remove the last SizedBox
    if (items.isNotEmpty) items.removeLast();
    
    return items;
  }

  Widget _buildInspectionItemRow(Map<String, dynamic> inspectionItem, Map<String, dynamic> note) {
    bool isPassed = _formData['passed_${inspectionItem['id']}']?['value'] ?? true;
    String noteText = _formData['note_${inspectionItem['id']}']?['value'] ?? '';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Item title and radio buttons
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Text(
                inspectionItem['khmerName'] ?? 'Unknown Item',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
              ),
            ),
            SizedBox(width: 12),
            // Pass/Fail radio buttons
            Container(
              decoration: BoxDecoration(
                color: Colors.grey[100],
                borderRadius: BorderRadius.circular(20),
              ),
              padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              child: Row(
                children: [
                  // Pass button
                  InkWell(
                    onTap: () {
                      setState(() {
                        _formData['passed_${inspectionItem['id']}'] = {'value': true};
                      });
                    },
                    child: Container(
                      padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: isPassed ? Colors.green[100] : Colors.transparent,
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            Icons.check_circle,
                            size: 16,
                            color: isPassed ? Colors.green : Colors.grey,
                          ),
                          SizedBox(width: 4),
                          Text(
                            'មាន',
                            style: TextStyle(
                              color: isPassed ? Colors.green[800] : Colors.grey[600],
                              fontWeight: isPassed ? FontWeight.bold : FontWeight.normal,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  // Fail button
                  InkWell(
                    onTap: () {
                      setState(() {
                        _formData['passed_${inspectionItem['id']}'] = {'value': false};
                      });
                    },
                    child: Container(
                      padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: !isPassed ? Colors.red[100] : Colors.transparent,
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            Icons.cancel,
                            size: 16,
                            color: !isPassed ? Colors.red : Colors.grey,
                          ),
                          SizedBox(width: 4),
                          Text(
                            'មិនមាន',
                            style: TextStyle(
                              color: !isPassed ? Colors.red[800] : Colors.grey[600],
                              fontWeight: !isPassed ? FontWeight.bold : FontWeight.normal,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        // Notes field (shown when item fails)
        if (!isPassed) ...[
          SizedBox(height: 8),
          TextFormField(
            initialValue: noteText,
            onChanged: (value) {
              _formData['note_${inspectionItem['id']}'] = {'value': value};
            },
            decoration: InputDecoration(
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: BorderSide(color: Colors.grey[300]!),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: BorderSide(color: Colors.grey[300]!),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: BorderSide(color: Colors.blue[700]!),
              ),
              hintText: 'មូលហេតុ...',
              contentPadding: EdgeInsets.all(12),
              prefixIcon: Icon(Icons.note, size: 20, color: Colors.grey[500]),
            ),
            maxLines: 2,
          ),
        ],
      ],
    );
  }

  // Floating action button for submission
  Widget _buildFloatingActionButton() {
    return Positioned(
      bottom: 16,
      right: 16,
      child: FloatingActionButton.extended(
        onPressed: _isSubmitting ? null : _submitForm,
        backgroundColor: Colors.blue[700],
        foregroundColor: Colors.white,
        elevation: 4,
        label: _isSubmitting
            ? SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation(Colors.white),
                ),
              )
            : Text('Update Check'),
        icon: _isSubmitting ? SizedBox() : Icon(Icons.save),
      ),
    );
  }


  void _submitForm() async {
    if (_formKey.currentState!.validate()) {
      setState(() {
        _isSubmitting = true;
      });

      try {
        // Prepare data for submission
        Map<String, dynamic> formData = {
          'date': DateFormat('yyyy-MM-dd').format(_selectedDate!),
          'driverId': int.parse(_selectedDriverId!),
          'categories': _serviceChecker['items'].map((category) {
            return {
              'categoryId': category['category']['id'],
              'items': category['notes'].map<Map<String, dynamic>>((note) {
                final inspectionItem = note['inspectionItem'];
                return {
                  'itemId': inspectionItem['id'],
                  'passed': _formData['passed_${inspectionItem['id']}']?['value'] ?? true,
                  'note': _formData['note_${inspectionItem['id']}']?['value'] ?? '',
                };
              }).toList(),
            };
          }).toList(),
        };

        // Submit to backend
        await ServiceCheckService.updateServiceChecker(widget.serviceCheckerId, formData);
        
        // Show success message
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Service check updated successfully!'),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 2),
          ),
        );
        
        // Navigate back after a short delay
        await Future.delayed(Duration(milliseconds: 1500));
        Navigator.pop(context);
        
      } catch (e) {
        setState(() {
          _isSubmitting = false;
        });
        
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
            backgroundColor: Colors.red,
            duration: Duration(seconds: 3),
          ),
        );
      }
    }
  }
}