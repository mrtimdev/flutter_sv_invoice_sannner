// lib/services/scan_service.dart
// ignore: depend_on_referenced_packages
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../enum/dateFilter.dart';
import '../models/scan_item.dart';

class ScanService {

  
  Future<Map<String, dynamic>?> uploadScan(String imagePath, String recognizedText, String scanType) async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    String? baseUrl = prefs.getString('baseUrl');
    try {
      final uri = Uri.parse("${baseUrl!}/scans");
      var request = http.MultipartRequest('POST', uri);
      final prefs = await SharedPreferences.getInstance();
      final String? accessToken = prefs.getString("auth_token");

      if (accessToken == null) {
        debugPrint('No access token available to fetch scans.');
        // Handle unauthenticated state, maybe redirect to login
        return null;
      }
      // Add the Authorization header with the access token
      request.headers['Authorization'] = 'Bearer $accessToken';

      // Add the image file
      request.files.add(await http.MultipartFile.fromPath('image', imagePath));

      // Add the recognized text as a field
      request.fields['text'] = recognizedText;
      request.fields['scanType'] = scanType;

      final streamedResponse = await request.send();
      final response = await http.Response.fromStream(streamedResponse);

      if (response.statusCode == 200 || response.statusCode == 201) {
        // Successfully uploaded
        return json.decode(utf8.decode(response.bodyBytes));
      } else {
        // Handle API errors
        print('Failed to upload scan. Status code: ${response.statusCode}');
        print('Response body: ${response.body}');
        return null;
      }
    } catch (e) {
      print('Error uploading scan: $e');
      return null;
    }
  }


  Future<List<ScanItem>> fetchScans({
    required DateFilter filter,
    required String search,
    String? before,
    int limit = 20,
  }) async {
    final filterMap = {
      DateFilter.today: 'today',
      DateFilter.yesterday: 'yesterday',
      DateFilter.last7Days: 'last7Days',
      DateFilter.last30Days: 'last30Days',
      DateFilter.all: '',
    };

    SharedPreferences prefs = await SharedPreferences.getInstance();
    String? baseUrl = prefs.getString('baseUrl');
    final String? accessToken = prefs.getString("auth_token");

    final uri = Uri.parse('$baseUrl/scans').replace(queryParameters: {
      if (filterMap[filter]!.isNotEmpty)
        'filter': filterMap[filter]!,
      if (search.isNotEmpty) 'search': search,
      if (before != null) 'before': before,
        'limit': '20',
    });

    final response = await http.get(uri, headers: {
      'Authorization': 'Bearer $accessToken', // Add the Authorization header
        'Content-Type': 'application/json',
    });

    if (response.statusCode == 200) {
      final List<dynamic> data = jsonDecode(response.body);
      return data.map((json) => ScanItem.fromJson(json)).toList();
    } else {
      throw Exception('Failed to fetch scans');
    }
  }

  
  Future<List<ScanItem>?> fetchScans_old() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    String? baseUrl = prefs.getString('baseUrl');
    try {
      final uri = Uri.parse("${baseUrl!}/scans"); // GET request to the base /api/scans endpoint
      final prefs = await SharedPreferences.getInstance();
      final String? accessToken = prefs.getString("auth_token"); // Retrieve token for fetch

      if (accessToken == null) {
        debugPrint('No access token available to fetch scans.');
        return null;
      }

      final response = await http.get(
        uri,
        headers: {
          'Authorization': 'Bearer $accessToken', // Add the Authorization header
          'Content-Type': 'application/json',
        },
      );

      if (response.statusCode == 200) {
        final List<dynamic> responseData = json.decode(utf8.decode(response.bodyBytes));
        return responseData.map((item) => ScanItem.fromJson(item)).toList();
      } else if (response.statusCode == 401) {
        debugPrint('Authentication failed for fetching scans. Token might be invalid or expired.');
        return null;
      } else {
        debugPrint('Failed to fetch scans. Status code: ${response.statusCode}');
        debugPrint('Response body: ${response.body}');
        return null;
      }
    } catch (e) {
      debugPrint('Error fetching scans: $e');
      return null;
    }
  }



  



  Future<ScanItem?> getScanById(String scanId) async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    String? baseUrl = prefs.getString('baseUrl');
    try {
      final uri = Uri.parse('${baseUrl!}/$scanId'); // GET /api/scans/{id}
      final prefs = await SharedPreferences.getInstance();
      final String? accessToken = prefs.getString("auth_token");

      if (accessToken == null) {
        debugPrint('No access token available to fetch scan');
        return null;
      }

      final response = await http.get(
        uri,
        headers: {
          'Authorization': 'Bearer $accessToken',
          'Content-Type': 'application/json',
        },
      );

      if (response.statusCode == 200) {
        final responseData = json.decode(utf8.decode(response.bodyBytes));
        return ScanItem.fromJson(responseData);
      } else if (response.statusCode == 401) {
        debugPrint('Authentication failed for fetching scan');
        return null;
      } else if (response.statusCode == 404) {
        debugPrint('Scan not found');
        return null;
      } else {
        debugPrint('Failed to fetch scan. Status code: ${response.statusCode}');
        debugPrint('Response body: ${response.body}');
        return null;
      }
    } catch (e) {
      debugPrint('Error fetching scan: $e');
      return null;
    }
  }

  

  /// Deletes all scans for the authenticated user.
  /// Backend expects DELETE /api/scans/user
  /// Returns the number of affected rows, or null on failure.
  Future<int?> deleteScansByUserId() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    String? baseUrl = prefs.getString('baseUrl');
    try {
      final uri = Uri.parse('${baseUrl!}/user'); // Assuming backend endpoint is /api/scans/user
      final prefs = await SharedPreferences.getInstance();
      final String? accessToken = prefs.getString("auth_token");

      if (accessToken == null) {
        debugPrint('No access token available to delete scans by user ID.');
        return null;
      }

      final response = await http.delete(
        uri,
        headers: {
          'Authorization': 'Bearer $accessToken',
          'Content-Type': 'application/json',
        },
      );

      if (response.statusCode == 200) {
        final Map<String, dynamic> responseData = json.decode(response.body);
        return responseData['affectedRows'] as int?; // Assuming backend returns { affectedRows: X }
      } else if (response.statusCode == 401) {
        debugPrint('Authentication failed for deleting scans by user ID.');
        return null;
      } else {
        debugPrint('Failed to delete scans by user ID. Status code: ${response.statusCode}');
        debugPrint('Response body: ${response.body}');
        return null;
      }
    } catch (e) {
      debugPrint('Error deleting scans by user ID: $e');
      return null;
    }
  }

  Future<bool?> deleteScanById(int id) async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    String? baseUrl = prefs.getString('baseUrl');
    
    try {
      final uri = Uri.parse('${baseUrl!}/scans/$id');
      final String? accessToken = prefs.getString("auth_token");

      if (accessToken == null) {
        debugPrint('No access token available to delete scan by ID.');
        return null;
      }

      final response = await http.delete(
        uri,
        headers: {
          'Authorization': 'Bearer $accessToken',
        },
      );

      if (response.statusCode == 204) { // 204 means successful deletion with no content
        return true;
      } 
      else if (response.statusCode == 200) { // If backend changes to return 200 with a body
        try {
          if (response.body.isNotEmpty) {
            final Map<String, dynamic> responseData = json.decode(response.body);
            return true; // Adapt based on your backend's response structure
          }
          return true;
        } catch (e) {
          debugPrint('Error parsing response body: $e');
          return null;
        }
      }
      else if (response.statusCode == 401) {
        debugPrint('Authentication failed for deleting scan by ID.');
        return null;
      } 
      else if (response.statusCode == 404) {
        debugPrint('Scan with ID $id not found.');
        return false;
      } 
      else {
        debugPrint('Failed to delete scan by ID. Status code: ${response.statusCode}');
        debugPrint('Response body: ${response.body}');
        return null;
      }
    } catch (e) {
      debugPrint('Error deleting scan by ID: $e');
      return null;
    }
  }

  /// Deletes all scans from the database. (Admin-level operation)
  /// Backend expects DELETE /api/scans/all
  /// Returns the number of affected rows, or null on failure.
  Future<int?> deleteAllScans() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    String? baseUrl = prefs.getString('baseUrl');
    try {
      final uri = Uri.parse('${baseUrl!}/all'); // Assuming backend endpoint is /api/scans/all
      final prefs = await SharedPreferences.getInstance();
      final String? accessToken = prefs.getString("auth_token");

      if (accessToken == null) {
        debugPrint('No access token available to delete all scans.');
        return null;
      }

      final response = await http.delete(
        uri,
        headers: {
          'Authorization': 'Bearer $accessToken',
          'Content-Type': 'application/json',
        },
      );

      if (response.statusCode == 200) {
        final Map<String, dynamic> responseData = json.decode(response.body);
        return responseData['affectedRows'] as int?; // Assuming backend returns { affectedRows: X }
      } else if (response.statusCode == 401) {
        debugPrint('Authentication failed for deleting all scans.');
        return null;
      } else {
        debugPrint('Failed to delete all scans. Status code: ${response.statusCode}');
        debugPrint('Response body: ${response.body}');
        return null;
      }
    } catch (e) {
      debugPrint('Error deleting all scans: $e');
      return null;
    }
  }

  /// Deletes multiple scans by their IDs.
  /// Backend expects DELETE /api/scans/bulk or similar with IDs in body.
  /// Returns the number of affected rows, or null on failure.
  Future<int?> deleteScansByIds(List<int> ids) async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    String? baseUrl = prefs.getString('baseUrl');
    if (ids.isEmpty) {
      debugPrint('No IDs provided for bulk deletion.');
      return 0; // No rows affected
    }
    try {
      final uri = Uri.parse('${baseUrl!}/bulk'); // Assuming backend endpoint like /api/scans/bulk
      final prefs = await SharedPreferences.getInstance();
      final String? accessToken = prefs.getString("auth_token");

      if (accessToken == null) {
        debugPrint('No access token available to delete scans by IDs.');
        return null;
      }

      final response = await http.delete(
        uri,
        headers: {
          'Authorization': 'Bearer $accessToken',
          'Content-Type': 'application/json',
        },
        body: json.encode({'ids': ids}), // Send IDs in the request body
      );

      if (response.statusCode == 200) {
        final Map<String, dynamic> responseData = json.decode(response.body);
        return responseData['affectedRows'] as int?; // Assuming backend returns { affectedRows: X }
      } else if (response.statusCode == 401) {
        debugPrint('Authentication failed for deleting scans by IDs.');
        return null;
      } else {
        debugPrint('Failed to delete scans by IDs. Status code: ${response.statusCode}');
        debugPrint('Response body: ${response.body}');
        return null;
      }
    } catch (e) {
      debugPrint('Error deleting scans by IDs: $e');
      return null;
    }
  }
}
