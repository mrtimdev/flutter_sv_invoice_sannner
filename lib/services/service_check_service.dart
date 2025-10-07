import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sv_service_checker/enum/dateFilter.dart';

import '../core/api/api_endpoints.dart';

class ServiceCheckService {
  static const String baseUrl =  ApiEndpoints.baseUrl;

  // static Future<List<dynamic>> getServiceCheckers({String? filter}) async {
  //   final url = Uri.parse("$baseUrl/service-checkers${filter != null ? '/filters?dateFilter=$filter' : ''}");
  //   final prefs = await SharedPreferences.getInstance();
  //   final String? accessToken = prefs.getString("auth_token");
  //   final res = await http.get(url, 
  //     headers: {
  //       'Authorization': 'Bearer $accessToken', 
  //       'Content-Type': 'application/json',
  //     },
  //   );

  //   debugPrint("url $url");
  //   if (res.statusCode == 200) {
  //     return jsonDecode(res.body);
  //   } else {
  //     throw Exception("Failed to load service checkers");
  //   }
  // }


  // Get service checkers with pagination and filtering
  static Future<Map<String, dynamic>> getServiceCheckers({
    int page = 1,
    int limit = 20,
    DateFilter dateFilter = DateFilter.all,
    String? driverId,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final String? accessToken = prefs.getString("auth_token");
    
    // Build query parameters
    Map<String, String> queryParams = {
      'page': page.toString(),
      'limit': limit.toString(),
    };
    
    // Add date filter if not "all"
    if (dateFilter != DateFilter.all) {
      queryParams['dateFilter'] = dateFilter.toString().split('.').last;
    }
    
    // Add driver filter if provided
    if (driverId != null && driverId.isNotEmpty) {
      queryParams['driverId'] = driverId;
    }
    
    final uri = Uri.parse("$baseUrl/service-checkers/list").replace(
      queryParameters: queryParams,
    );
    
    final res = await http.get(
      uri,
      headers: {
        'Authorization': 'Bearer $accessToken',
        'Content-Type': 'application/json',
      },
    );
    
    if (res.statusCode != 200) {
      throw Exception("Failed to fetch service checkers");
    }
    
    return jsonDecode(res.body);
  }

  static Future<List<dynamic>> getDrivers() async {
    final prefs = await SharedPreferences.getInstance();
    final String? accessToken = prefs.getString("auth_token");
    final url = Uri.parse("$baseUrl/drivers/list");
    final res = await http.get(url, 
      headers: {
        'Authorization': 'Bearer $accessToken', 
        'Content-Type': 'application/json',
      },
    );
    if (res.statusCode == 200) {
      return jsonDecode(res.body);
    } else {
      throw Exception("Failed to load drivers");
    }
  }

  // static Future<void> createServiceChecker(Map<String, dynamic> data) async {
  //   final prefs = await SharedPreferences.getInstance();
  //   final String? accessToken = prefs.getString("auth_token");
  //   final res = await http.post(
  //     Uri.parse("$baseUrl/service-checkers"),
  //     headers: {
  //       'Authorization': 'Bearer $accessToken', 
  //       'Content-Type': 'application/json',
  //     },
  //     body: jsonEncode(data),
  //   );
  //   if (res.statusCode != 200 && res.statusCode != 201) {
  //     throw Exception("Failed to create service checker");
  //   }
  // }

  // static Future<void> updateServiceChecker(int id, Map<String, dynamic> data) async {
  //   final prefs = await SharedPreferences.getInstance();
  //   final String? accessToken = prefs.getString("auth_token");
  //   final res = await http.put(
  //     Uri.parse("$baseUrl/service-checkers/$id"),
  //     headers: {
  //       'Authorization': 'Bearer $accessToken', 
  //       'Content-Type': 'application/json',
  //     },
  //     body: jsonEncode(data),
  //   );
  //   if (res.statusCode != 200) {
  //     throw Exception("Failed to update service checker");
  //   }
  // }

  static Future<void> deleteServiceChecker(String id) async {
    final prefs = await SharedPreferences.getInstance();
    final String? accessToken = prefs.getString("auth_token");
    final res = await http.delete(Uri.parse("$baseUrl/service-checkers/$id"), 
      headers: {
        'Authorization': 'Bearer $accessToken', 
        'Content-Type': 'application/json',
      },);
    if (res.statusCode != 200 && res.statusCode != 204) {
      throw Exception("Failed to delete service checker");
    }
  }



  static Future<List<dynamic>> getCategories() async {
    final prefs = await SharedPreferences.getInstance();
    final String? accessToken = prefs.getString("auth_token");
    
    final res = await http.get(
      Uri.parse("$baseUrl/categories"),
      headers: {
        'Authorization': 'Bearer $accessToken',
      },
    );
    
    if (res.statusCode != 200) {
      throw Exception("Failed to fetch categories");
    }
    
    return jsonDecode(res.body);
  }

  static Future<Map<String, dynamic>> createServiceChecker(Map<String, dynamic> data) async {
    final prefs = await SharedPreferences.getInstance();
    final String? accessToken = prefs.getString("auth_token");
    
    final res = await http.post(
      Uri.parse("$baseUrl/service-checkers"),
      headers: {
        'Authorization': 'Bearer $accessToken', 
        'Content-Type': 'application/json',
      },
      body: jsonEncode(data),
    );
    
    if (res.statusCode != 200 && res.statusCode != 201) {
      throw Exception("Failed to create service checker");
    }
    return jsonDecode(res.body);
  }


  // Update an existing service checker
  static Future<Map<String, dynamic>> updateServiceChecker(String id, Map<String, dynamic> data) async {
    final prefs = await SharedPreferences.getInstance();
    final String? accessToken = prefs.getString("auth_token");
    
    final res = await http.put(
      Uri.parse("$baseUrl/api/v1/service-checkers/$id"),
      headers: {
        'Authorization': 'Bearer $accessToken', 
        'Content-Type': 'application/json',
      },
      body: jsonEncode(data),
    );
    
    if (res.statusCode != 200) {
      final errorResponse = jsonDecode(res.body);
      throw Exception(errorResponse['error'] ?? "Failed to update service checker");
    }
    
    return jsonDecode(res.body);
  }


  // Get a specific service checker by ID
  static Future<Map<String, dynamic>> getServiceChecker(String id) async {
    final prefs = await SharedPreferences.getInstance();
    final String? accessToken = prefs.getString("auth_token");
    
    final res = await http.get(
      Uri.parse("$baseUrl/service-checkers/$id"),
      headers: {
        'Authorization': 'Bearer $accessToken',
        'Content-Type': 'application/json',
      },
    );

    debugPrint("id: $id");
    
    if (res.statusCode != 200) {
      throw Exception("Failed to fetch service checker");
    }
    
    return jsonDecode(res.body);
  }
}
