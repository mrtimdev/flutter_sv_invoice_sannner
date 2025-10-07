import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import '../core/api/api_endpoints.dart';
import '../models/driver.dart';

class DriverService {
  static const String baseUrl =  '${ApiEndpoints.baseUrl}/drivers';

  Future<List<Driver>> getDrivers() async {
    final response = await http.get(Uri.parse(baseUrl));
    if (response.statusCode == 200) {
      final List<dynamic> data = json.decode(response.body);
      return data.map((json) => Driver.fromJson(json)).toList();
    } else {
      throw Exception('Failed to load drivers');
    }
  }

  Future<Driver> createDriver(Driver driver) async {
    final prefs = await SharedPreferences.getInstance();
    final String? accessToken = prefs.getString("auth_token");
    final response = await http.post(
      Uri.parse(baseUrl),
      headers: {
        'Authorization': 'Bearer $accessToken', 
        'Content-Type': 'application/json',
      },
      body: json.encode(driver.toJson()),
    );
    debugPrint("response $response baseUrl $baseUrl");
    if (response.statusCode == 200) {
      return Driver.fromJson(json.decode(response.body));
    } else {
      throw Exception('Failed to create driver');
    }
  }

  Future<Driver> updateDriver(Driver driver) async {
    final response = await http.put(
      Uri.parse('$baseUrl/${driver.id}'),
      headers: {'Content-Type': 'application/json'},
      body: json.encode(driver.toJson()),
    );
    if (response.statusCode == 200) {
      return Driver.fromJson(json.decode(response.body));
    } else {
      throw Exception('Failed to update driver');
    }
  }

  Future<void> deleteDriver(int id) async {
    final response = await http.delete(Uri.parse('$baseUrl/$id'));
    if (response.statusCode != 200) {
      throw Exception('Failed to delete driver');
    }
  }
}