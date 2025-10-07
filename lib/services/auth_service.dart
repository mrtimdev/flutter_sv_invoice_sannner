// services/auth_service.dart
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import '../core/api/api_endpoints.dart'; // Import for local storage

class AuthService {
  static const String _authTokenKey = 'auth_token';
  static const String _authUsernameKey = 'auth_username';
  static const String _auth = 'auth'; 

  // Method to save token and user ID after successful login
  Future<void> _saveAuthData(String token, Map<String, dynamic> user) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_authTokenKey, token);
    await prefs.setString(_authUsernameKey, user['username']); 
    await prefs.setString(_auth, json.encode(user)); 
    // You can save other user data as needed, ensure data types match prefs methods
  }

  Future<Map<String, dynamic>?> getUser() async {
    final prefs = await SharedPreferences.getInstance();
    final userJson = prefs.getString(_auth);
    if (userJson == null) return null;
    return json.decode(userJson) as Map<String, dynamic>;
  }

  // Method to retrieve stored token
  Future<String?> getStoredToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_authTokenKey);
  }

  Future<String?> getStoredUsername() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_authUsernameKey);
  }


  Future<Map<String, dynamic>> login(String identifier, String password) async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    String? baseUrl = prefs.getString('baseUrl');
    final loginRoute = Uri.parse(ApiEndpoints.login);
    debugPrint("loginRoute: $loginRoute");
    try {
      final response = await http.post(
        loginRoute,
        headers: {
          'Content-Type': 'application/json',
        },
        body: json.encode({
          'identifier': identifier,
          'password': password,
        }),
      );

      final responseData = json.decode(utf8.decode(response.bodyBytes));
      debugPrint("responseData $responseData");
      if (response.statusCode == 200) {
        // Successful login with token
        if (responseData['success'] == true && responseData.containsKey('token')) {
          // Save auth data locally (you implement _saveAuthData)
          await _saveAuthData(responseData['token'], {
            'username': responseData['username'],
            'role': responseData['role'],
          });
          return responseData;
        } else {
          throw Exception('Unexpected success response format.');
        }
      } else if (response.statusCode == 401 || response.statusCode == 404) {
        // Error with identify or password
        String errorMessage = '';

        if (responseData['identifyError'] != null) {
          errorMessage = responseData['identifyError'];
        } else if (responseData['passwordError'] != null) {
          errorMessage = responseData['passwordError'];
        } else {
          errorMessage = 'Authentication failed.';
        }

        throw Exception(errorMessage);
      } else {
        throw Exception('Failed to login. Status: ${response.statusCode}');
      }
    } on http.ClientException catch (e) {
      throw Exception('Network error: ${e.message}');
    } catch (e) {
      throw Exception('An unexpected error occurred: $e');
    }
  }


  Future<void> logout() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_authTokenKey);
    await prefs.remove("isAuthenticated"); 
    print('User data cleared and logged out');
  }

  Future<Map<String, dynamic>?> fetchUserDetails(String token) async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    String? baseUrl = prefs.getString('baseUrl');
    final url = Uri.parse('$baseUrl/me'); 
    try {
      final response = await http.get(
        url,
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
      );
      if (response.statusCode == 200) {
        return json.decode(utf8.decode(response.bodyBytes));
      }
      return null;
    } catch (e) {
      print('Error fetching user details: $e');
      return null;
    }
  }
}
