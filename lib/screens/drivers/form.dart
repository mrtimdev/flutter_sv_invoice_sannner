import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter/services.dart';

import '../../models/driver.dart';
import '../../providers/driver_provider.dart';

class DriverFormScreen extends StatefulWidget {
  final Driver? driver;

  const DriverFormScreen({Key? key, this.driver}) : super(key: key);

  @override
  State<DriverFormScreen> createState() => _DriverFormScreenState();
}

class _DriverFormScreenState extends State<DriverFormScreen> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _firstNameController;
  late TextEditingController _lastNameController;
  late TextEditingController _phoneController;
  late TextEditingController _plateNumberController;
  String? _fieldError;

  @override
  void initState() {
    super.initState();
    _firstNameController = TextEditingController(text: widget.driver?.firstName ?? '');
    _lastNameController = TextEditingController(text: widget.driver?.lastName ?? '');
    _phoneController = TextEditingController(text: widget.driver?.phone ?? '');
    _plateNumberController = TextEditingController(text: widget.driver?.plateNumber ?? '');
  }

  @override
  void dispose() {
    _firstNameController.dispose();
    _lastNameController.dispose();
    _phoneController.dispose();
    _plateNumberController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<DriverProvider>(context);
    final theme = Theme.of(context);

    // Listen for provider error changes
    if (provider.error != null && _fieldError == null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        setState(() {
          _fieldError = provider.error;
        });
      });
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(
          widget.driver == null ? 'Add New Driver' : 'Edit Driver',
          style: TextStyle(color: theme.colorScheme.onPrimary),
        ),
        backgroundColor: theme.primaryColor,
        iconTheme: IconThemeData(color: theme.colorScheme.onPrimary),
      ),
      body: GestureDetector(
        onTap: () {
          FocusScope.of(context).unfocus();
          setState(() => _fieldError = null);
        },
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Form(
            key: _formKey,
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const SizedBox(height: 16),
                  _buildTextField(
                    controller: _firstNameController,
                    label: 'First Name',
                    icon: Icons.person,
                    errorText: _fieldError?.contains('firstName') ?? false ? _fieldError : null,
                    validator: (value) => value!.isEmpty ? 'Required field' : null,
                  ),
                  const SizedBox(height: 20),
                  _buildTextField(
                    controller: _lastNameController,
                    label: 'Last Name',
                    icon: Icons.person_outline,
                    errorText: _fieldError?.contains('lastName') ?? false ? _fieldError : null,
                    validator: (value) => value!.isEmpty ? 'Required field' : null,
                  ),
                  const SizedBox(height: 20),
                  _buildTextField(
                    controller: _phoneController,
                    label: 'Phone Number',
                    icon: Icons.phone,
                    errorText: _fieldError?.contains('phone') ?? false ? _fieldError : null,
                    keyboardType: TextInputType.phone,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    validator: (value) {
                      if (value!.isEmpty) return 'Required field';
                      if (value.length < 9) return 'Minimum 9 digits';
                      return null;
                    },
                  ),
                  const SizedBox(height: 20),
                  _buildTextField(
                    controller: _plateNumberController,
                    label: 'License Plate',
                    icon: Icons.directions_car,
                    errorText: _fieldError?.contains('plateNumber') ?? false ? _fieldError : null,
                    validator: (value) {
                      if (value!.isEmpty) return 'Required field';
                      if (value.length < 3) return 'Too short';
                      return null;
                    },
                  ),
                  const SizedBox(height: 32),
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    onPressed: provider.isLoading ? null : _submitForm,
                    child: provider.isLoading
                        ? const CircularProgressIndicator(
                            valueColor: AlwaysStoppedAnimation(Colors.white),
                          )
                        : Text(
                            widget.driver == null ? 'SAVE DRIVER' : 'UPDATE DRIVER',
                            style: const TextStyle(fontSize: 16),
                          ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    String? errorText,
    String? Function(String?)? validator,
    TextInputType? keyboardType,
    List<TextInputFormatter>? inputFormatters,
  }) {
    return TextFormField(
      controller: controller,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        contentPadding: const EdgeInsets.symmetric(
          vertical: 16, horizontal: 16),
        errorText: errorText,
        errorMaxLines: 2,
      ),
      keyboardType: keyboardType,
      inputFormatters: inputFormatters,
      validator: validator,
    );
  }

  Future<void> _submitForm() async {
    if (_formKey.currentState!.validate()) {
      final driver = Driver(
        id: widget.driver?.id,
        firstName: _firstNameController.text.trim(),
        lastName: _lastNameController.text.trim(),
        phone: _phoneController.text.trim(),
        plateNumber: _plateNumberController.text.trim().toUpperCase(),
      );

      final provider = Provider.of<DriverProvider>(context, listen: false);
      bool success = false;
      
      setState(() => _fieldError = null);
      
      if (widget.driver?.id != null) {
        success = await provider.updateDriver(driver);
      } else {
        success = await provider.addDriver(driver);
      }

      if (success && mounted) {
        Navigator.pop(context, true);
      } else if (provider.error != null) {
        setState(() => _fieldError = provider.error);
      }
    }
  }
}