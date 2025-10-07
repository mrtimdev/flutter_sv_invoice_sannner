import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';

import '../core/api/api_endpoints.dart';
import '../models/driver.dart';

class DriverProvider with ChangeNotifier {
  List<Driver> _drivers = [];
  bool _isLoading = false;
  String? _error;

  List<Driver> get drivers => _drivers;
  bool get isLoading => _isLoading;
  String? get error => _error;

 final baseUrl = ApiEndpoints.baseUrl;

  Future<void> loadDrivers() async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      SharedPreferences prefs = await SharedPreferences.getInstance();
      final String? accessToken = prefs.getString("auth_token");
      final response = await http.get(
        Uri.parse('$baseUrl/drivers'), 
        headers: {
          'Authorization': 'Bearer $accessToken', 
          'Content-Type': 'application/json',
        },
      );

      if (response.statusCode == 200) {
        final List<dynamic> data = json.decode(response.body);
        _drivers = data.map((json) => Driver.fromJson(json)).toList();
      } else {
        _handleError(response);
      }
    } catch (e) {
      _error = 'Failed to load drivers: ${e.toString()}';
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<bool> addDriver(Driver driver) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      SharedPreferences prefs = await SharedPreferences.getInstance();
      final String? accessToken = prefs.getString("auth_token");
      final response = await http.post(
        Uri.parse('$baseUrl/drivers'),
        headers: {
          'Authorization': 'Bearer $accessToken', 
          'Content-Type': 'application/json',
        },
        body: json.encode(driver.toJson()),
      );

      if (response.statusCode == 201) {
        final newDriver = Driver.fromJson(json.decode(response.body));
        _drivers.add(newDriver);
        return true;
      } else {
        _handleError(response);
        return false;
      }
    } catch (e) {
      _error = 'Failed to add driver: ${e.toString()}';
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<bool> updateDriver(Driver driver) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      SharedPreferences prefs = await SharedPreferences.getInstance();
      final String? accessToken = prefs.getString("auth_token");
      final response = await http.put(
        Uri.parse('$baseUrl/drivers/${driver.id}'),
        headers: {
          'Authorization': 'Bearer $accessToken', 
          'Content-Type': 'application/json',
        },
        body: json.encode(driver.toJson()),
      );

      if (response.statusCode == 200) {
        final updatedDriver = Driver.fromJson(json.decode(response.body));
        final index = _drivers.indexWhere((d) => d.id == driver.id);
        if (index != -1) {
          _drivers[index] = updatedDriver;
        }
        return true;
      } else {
        _handleError(response);
        return false;
      }
    } catch (e) {
      _error = 'Failed to update driver: ${e.toString()}';
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<bool> deleteDriver(int id) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      SharedPreferences prefs = await SharedPreferences.getInstance();
      final String? accessToken = prefs.getString("auth_token");
      final response = await http.delete(
        Uri.parse('$baseUrl/drivers/$id'),
        headers: {
          'Authorization': 'Bearer $accessToken', 
          'Content-Type': 'application/json',
        },
      );

      if (response.statusCode == 204) {
        _drivers.removeWhere((driver) => driver.id == id);
        return true;
      } else {
        _handleError(response);
        return false;
      }
    } catch (e) {
      _error = 'Failed to delete driver: ${e.toString()}';
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  void _handleError(http.Response response) {
    try {
      final errorData = json.decode(response.body);
      debugPrint("errorData $errorData");
      
      if (errorData is Map<String, dynamic>) {
        if (errorData.containsKey('error')) {
          _error = errorData['error'];
          if (errorData.containsKey('field')) {
            _error = '${errorData['field']}: ${errorData['error']}';
          }
        } else {
          _error = 'Error: ${response.statusCode}';
        }
      } else {
        _error = 'Error: ${response.statusCode}';
      }
    } catch (e) {
      _error = 'Error: ${response.statusCode}';
    }
  }
}