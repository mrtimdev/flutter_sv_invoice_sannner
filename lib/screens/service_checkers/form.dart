import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:sv_service_checker/services/service_check_service.dart';


class ServiceCheckerForm extends StatefulWidget {
  @override
  _ServiceCheckerFormState createState() => _ServiceCheckerFormState();
}

class _ServiceCheckerFormState extends State<ServiceCheckerForm> {
  final _formKey = GlobalKey<FormState>();
  DateTime? _selectedDate;
  String? _selectedDriverId;
  List<dynamic> _drivers = [];
  List<dynamic> _categories = [];
  Map<String, Map<String, dynamic>> _formData = {};

  @override
  void initState() {
    super.initState();
    _selectedDate = DateTime.now();
    _loadDrivers();
    _loadCategories();
  }

  Future<void> _loadDrivers() async {
    try {
      final data = await ServiceCheckService.getDrivers();
      setState(() {
        _drivers = data;
      });
    } catch (e) {
      debugPrint("Error loading drivers: $e");
    }
  }

  Future<void> _loadCategories() async {
    try {
      final categories = await ServiceCheckService.getCategories();
      setState(() {
        _categories = categories;
        
        // Initialize form data structure
        for (var category in categories) {
          for (var item in category['items']) {
            _formData['passed_${item['id']}'] = {'value': true};
            _formData['note_${item['id']}'] = {'value': ''};
          }
        }
      });
    } catch (e) {
      print("Error loading categories: $e");
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Create Service Checker'),
        backgroundColor: Colors.blue[700],
        foregroundColor: Colors.white,
        elevation: 4,
      ),
      body: _categories.isEmpty
          ? Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: EdgeInsets.all(16),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Date Field
                    _buildDateField(),
                    SizedBox(height: 20),
                    
                    // Driver Dropdown
                    _buildDriverDropdown(),
                    SizedBox(height: 20),
                    
                    // Inspection Categories
                    ..._buildCategorySections(),
                    
                    SizedBox(height: 30),
                    
                    // Submit Button
                    _buildSubmitButton(),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _buildDateField() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Date',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
        ),
        SizedBox(height: 8),
        InkWell(
          onTap: () => _selectDate(context),
          child: Container(
            padding: EdgeInsets.symmetric(horizontal: 12, vertical: 16),
            decoration: BoxDecoration(
              border: Border.all(color: Colors.grey),
              borderRadius: BorderRadius.circular(4),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  _selectedDate != null
                      ? DateFormat('yyyy-MM-dd').format(_selectedDate!)
                      : 'Select a date',
                  style: TextStyle(fontSize: 16),
                ),
                Icon(Icons.calendar_today, size: 20),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildDriverDropdown() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Driver',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
        ),
        SizedBox(height: 8),
        DropdownButtonFormField<String>(
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
        ),
      ],
    );
  }

  List<Widget> _buildCategorySections() {
    return _categories.map<Widget>((category) {
      return Card(
        elevation: 2,
        margin: EdgeInsets.only(bottom: 16),
        child: Padding(
          padding: EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                category['khmerName'],
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              SizedBox(height: 16),
              ...category['items'].map<Widget>((item) => _buildItemRow(item)),
            ],
          ),
        ),
      );
    }).toList();
  }

  Widget _buildItemRow(Map<String, dynamic> item) {
    bool isPassed = _formData['passed_${item['id']}']?['value'] ?? true;
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(
              child: Text(
                item['khmerName'],
                style: TextStyle(fontSize: 16),
              ),
            ),
            SizedBox(width: 16),
            // Pass/Fail Radio buttons
            Row(
              children: [
                Row(
                  children: [
                    Radio<bool>(
                      value: true,
                      groupValue: isPassed,
                      onChanged: (bool? value) {
                        setState(() {
                          _formData['passed_${item['id']}'] = {'value': value};
                        });
                      },
                      activeColor: Colors.blue,
                    ),
                    Text('មាន'),
                  ],
                ),
                SizedBox(width: 16),
                Row(
                  children: [
                    Radio<bool>(
                      value: false,
                      groupValue: isPassed,
                      onChanged: (bool? value) {
                        setState(() {
                          _formData['passed_${item['id']}'] = {'value': value};
                        });
                      },
                      activeColor: Colors.red,
                    ),
                    Text('មិនមាន'),
                  ],
                ),
              ],
            ),
          ],
        ),
        // Notes field (shown when 'No' is selected)
        if (!isPassed) ...[
          SizedBox(height: 8),
          TextFormField(
            initialValue: _formData['note_${item['id']}']?['value'],
            onChanged: (value) {
              _formData['note_${item['id']}'] = {'value': value};
            },
            decoration: InputDecoration(
              border: OutlineInputBorder(),
              hintText: 'មូលហេតុ...',
              contentPadding: EdgeInsets.all(12),
            ),
            maxLines: 2,
          ),
        ],
        SizedBox(height: 16),
      ],
    );
  }

  Widget _buildSubmitButton() {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton(
        onPressed: _submitForm,
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.blue[500],
          padding: EdgeInsets.symmetric(horizontal: 24, vertical: 16),
        ),
        child: Text(
          'Submit',
          style: TextStyle(fontSize: 16, color: Colors.white),
        ),
      ),
    );
  }

  Future<void> _selectDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate ?? DateTime.now(),
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (picked != null && picked != _selectedDate) {
      setState(() {
        _selectedDate = picked;
      });
    }
  }


  void _submitForm() {
    if (_formKey.currentState!.validate()) {
      if (_selectedDriverId == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Please select a driver')),
        );
        return;
      }
      
      // Prepare data for submission in the new format
      Map<String, dynamic> formData = {
        'date': DateFormat('yyyy-MM-dd').format(_selectedDate!),
        'driverId': int.parse(_selectedDriverId!),
        'categories': _categories.map((category) {
          return {
            'categoryId': category['id'],
            'items': category['items'].map<Map<String, dynamic>>((item) {
              return {
                'itemId': item['id'],
                'passed': _formData['passed_${item['id']}']?['value'] ?? true,
                'note': _formData['note_${item['id']}']?['value'] ?? '',
              };
            }).toList(),
          };
        }).toList(),
      };
      
      // Submit to backend
      ServiceCheckService.createServiceChecker(formData)
          .then((response) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(response["message"].toString()),
                backgroundColor: Colors.green,
              ),
            );
            Navigator.pop(context);
          })
          .catchError((error) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(error.toString()),
                backgroundColor: Colors.red,
              ),
            );
          });
    }
  }

  
}