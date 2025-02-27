// lib/api_service.dart
import 'dart:convert';
import 'dart:io' show Platform;
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class ApiService {
  // Base URL as a getter that adapts based on platform
  String get baseUrl {
    // For web running on Microsoft Edge
    if (kIsWeb) {
      return "http://localhost:8000"; // Use localhost for web
    }
    // For Android emulator
    else if (!kIsWeb && Platform.isAndroid) {
      return "http://10.0.2.2:8000"; // Android emulator pointing to localhost
    }
    // For iOS simulator
    else if (!kIsWeb && Platform.isIOS) {
      return "http://localhost:8000"; // iOS simulator
    }
    // Default fallback
    else {
      return "http://localhost:8000";
    }
  }

  // Check connection to the API
  Future<bool> checkConnection() async {
    try {
      print("Checking connection to: $baseUrl");
      final response = await http.get(
        Uri.parse("$baseUrl"),
      ).timeout(const Duration(seconds: 5));

      return response.statusCode == 200;
    } catch (e) {
      print("API Connection error: $e");
      return false;
    }
  }

  // User authentication and info
  Future<Map<String, dynamic>> login(String employeeId, String pin) async {
    try {
      print("Attempting login: $baseUrl/api/user_info/$employeeId/");

      final response = await http.post(
        Uri.parse("$baseUrl/api/user_info/$employeeId/"),
        headers: {"Content-Type": "application/json"},
        body: json.encode({"pin": pin}),
      ).timeout(const Duration(seconds: 10));

      print("Login response status: ${response.statusCode}");

      if (response.statusCode >= 200 && response.statusCode < 300) {
        return json.decode(response.body);
      } else {
        print("API error: ${response.body}");
        return {
          "success": false,
          "error": "Server returned ${response.statusCode}: ${response.body}"
        };
      }
    } catch (e) {
      print("Login error: $e");
      // Return a friendly error for offline mode
      return {
        "success": false,
        "error": "Cannot connect to server. Check your connection or the server may be down."
      };
    }
  }

  // Clock in with location and image
  Future<Map<String, dynamic>> clockIn(
    String employeeId,
    String pin,
    Map<String, dynamic> location,
    String? imageBase64,
    {String? newPin}  // Add optional newPin parameter
  ) async {
    try {
      var requestBody = {
        "employee_id": employeeId,
        "pin": pin,
        "location": location,
        "image_data": imageBase64,
      };

      // Add new_pin if provided
      if (newPin != null) {
        requestBody["new_pin"] = newPin;
      }

      final response = await http.post(
        Uri.parse("$baseUrl/api/clock_in/"),
        headers: {"Content-Type": "application/json"},
        body: json.encode(requestBody),
      ).timeout(const Duration(seconds: 20));

      return json.decode(response.body);
    } catch (e) {
      print("Clock in error: $e");
      return {
        "success": false,
        "error": "Cannot connect to server: ${e.toString()}"
      };
    }
  }

  // Clock out with location
  Future<Map<String, dynamic>> clockOut(
    String employeeId,
    String pin,
    Map<String, dynamic> location
  ) async {
    try {
      final response = await http.post(
        Uri.parse("$baseUrl/api/clock_out/"),
        headers: {"Content-Type": "application/json"},
        body: json.encode({
          "employee_id": employeeId,
          "pin": pin,
          "location": location,
        }),
      ).timeout(const Duration(seconds: 10));

      return json.decode(response.body);
    } catch (e) {
      print("Clock out error: $e");
      return {
        "success": false,
        "error": "Cannot connect to server. Your time was recorded locally."
      };
    }
  }

  // Upload image separately
  Future<Map<String, dynamic>> uploadImage(
    String employeeId,
    String pin,
    String imageBase64
  ) async {
    try {
      final response = await http.post(
        Uri.parse("$baseUrl/api/upload_image/"),
        headers: {"Content-Type": "application/json"},
        body: json.encode({
          "employee_id": employeeId,
          "pin": pin,
          "image_data": imageBase64,
        }),
      );

      return json.decode(response.body);
    } catch (e) {
      return {"success": false, "error": e.toString()};
    }
  }
}