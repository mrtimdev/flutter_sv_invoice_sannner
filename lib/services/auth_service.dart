// services/auth_service.dart
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart'; // Import for local storage

class AuthService {
  static const String _authTokenKey = 'auth_token';
  static const String _authUserIdKey = 'auth_user_id';
  static const String _authUsernameKey = 'auth_username';
  static const String _authUserEmailKey = 'auth_user_email'; // Example: store user email too

  // Method to save token and user ID after successful login
  Future<void> _saveAuthData(String token, Map<String, dynamic> user) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_authTokenKey, token);
    await prefs.setInt(_authUserIdKey, user['id']); 
    await prefs.setString(_authUserEmailKey, user['email']); 
    await prefs.setString(_authUsernameKey, user['username']); 
    // You can save other user data as needed, ensure data types match prefs methods
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

  // Method to retrieve stored user ID
  Future<int?> getStoredUserId() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt(_authUserIdKey);
  }

  // Method to retrieve stored user email (example)
  Future<String?> getStoredUserEmail() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_authUserEmailKey);
  }

  Future<Map> login(String identifier, String password) async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    String? baseUrl = prefs.getString('baseUrl');
    final url = Uri.parse('${baseUrl!}/auth/login'); 
    debugPrint("url: $url");
    try {
      final response = await http.post(
        url,
        headers: {
          'Content-Type': 'application/json',
        },
        body: json.encode({
          'identifier': identifier,
          'password': password,
        }),
      );

      if (response.statusCode == 200) {
        final responseData = json.decode(utf8.decode(response.bodyBytes));
        // Assuming responseData contains 'access_token' and 'user' object with 'id'
        if (responseData is Map && responseData.containsKey('access_token') && responseData.containsKey('user')) {
          final String token = responseData['access_token'];
          final Map<String, dynamic> user = responseData['user'];

          // Save authentication data locally
          await _saveAuthData(token, user);

          return responseData; // Return the full response data
        } else {
          throw Exception('Invalid login response format from server.');
        }
      } else if (response.statusCode == 401) {
        final errorData = json.decode(utf8.decode(response.bodyBytes));
        throw Exception(errorData['message'] ?? 'Invalid credentials');
      } else {
        final errorData = json.decode(utf8.decode(response.bodyBytes));
        throw Exception(errorData['message'] ?? 'Failed to login: ${response.statusCode}');
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
    await prefs.remove(_authUserIdKey);
    await prefs.remove(_authUserEmailKey); 
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
