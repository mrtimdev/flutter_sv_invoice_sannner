import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

class SettingsProvider with ChangeNotifier {
  bool _isScanWithAi = false;
  String _description = '';
  bool _loading = false;

  bool get isScanWithAi => _isScanWithAi;
  String get description => _description;
  bool get isLoading => _loading;

  set isScanWithAi(bool value) {
    _isScanWithAi = value;
    notifyListeners();
  }

  set description(String value) {
    _description = value;
    notifyListeners();
  }

  Future<void> fetchSettings() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    String? baseUrl = prefs.getString('baseUrl');
    String? rootUrl = prefs.getString('rootUrl');
    final String? accessToken = prefs.getString("auth_token");
    final uri = Uri.parse('${rootUrl!}/admin/settings/api');
    if (accessToken == null) {
      debugPrint('No access token available to fetch scan');
      return null;
    }
    final response = await http.get(
      Uri.parse(uri.toString()),
      headers: {'Accept': 'application/json'},
    );

    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      _isScanWithAi = data['setting']['is_scan_with_ai'];
      _description = data['setting']['description'];
      notifyListeners();
    }
  }

  Future<void> updateSettings(BuildContext context) async {
    _loading = true;
    notifyListeners();

    SharedPreferences prefs = await SharedPreferences.getInstance();
    String? baseUrl = prefs.getString('baseUrl');
    String? rootUrl = prefs.getString('rootUrl');
    

    try {
      final String? accessToken = prefs.getString("auth_token");
      final uri = Uri.parse('${rootUrl!}/admin/settings/api/update');
      if (accessToken == null) {
        debugPrint('No access token available to fetch scan');
        return null;
      }
      final response = await http.post(
        Uri.parse(uri.toString()),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
        body: jsonEncode({
          'is_scan_with_ai': _isScanWithAi,
          'description': _description,
        }),
      );

      if (response.statusCode == 200) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Settings updated successfully')),
        );
      } else {
        throw Exception('Failed to update settings');
      }
    } catch (e) {
      print('Update error: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed: $e')),
      );
    } finally {
      _loading = false;
      notifyListeners();
    }
  }

  Future<void> toggleScanWithAi(BuildContext context) async {
    isScanWithAi = !isScanWithAi;
    await updateSettings(context);
  }
}
