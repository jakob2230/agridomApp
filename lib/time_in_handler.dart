import 'package:camera/camera.dart';
import 'package:intl/intl.dart';
import 'dart:convert';
import 'dart:io';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:mobileapp/api_service.dart';
import 'package:mobileapp/location_service.dart';

class TimeInHandler {
  final ApiService _apiService = ApiService();
  final LocationService _locationService = LocationService();
  CameraController? _cameraController;
  List<CameraDescription>? cameras;

  Future<void> initializeCamera() async {
    cameras = await availableCameras();
    if (cameras != null && cameras!.isNotEmpty) {
      _cameraController = CameraController(cameras![0], ResolutionPreset.medium);
      await _cameraController!.initialize();
    }
  }

  Future<Map<String, dynamic>> clockIn(String employeeId, String pin) async {
    String timeIn = DateFormat('hh:mm:ss a').format(DateTime.now());
    String? base64Image;

    // Take picture if camera is available
    if (_cameraController != null && _cameraController!.value.isInitialized) {
      try {
        final XFile file = await _cameraController!.takePicture();
        // Convert to base64
        final bytes = await File(file.path).readAsBytes();
        base64Image = base64Encode(bytes);
      } catch (e) {
        print("Error taking picture: $e");
      }
    }

    // Get location
    final locationData = await _locationService.getCurrentLocation();

    // Call the API
    final response = await _apiService.clockIn(
      employeeId,
      pin,
      locationData,
      base64Image
    );

    // Return combined response
    return {
      "api_response": response,
      "local_time": timeIn,
    };
  }

  Future<Map<String, dynamic>> clockOut(String employeeId, String pin) async {
    String timeOut = DateFormat('hh:mm:ss a').format(DateTime.now());

    // Get location
    final locationData = await _locationService.getCurrentLocation();

    // Call the API
    final response = await _apiService.clockOut(employeeId, pin, locationData);

    // Return combined response
    return {
      "api_response": response,
      "local_time": timeOut,
    };
  }

  void dispose() {
    _cameraController?.dispose();
  }
}
