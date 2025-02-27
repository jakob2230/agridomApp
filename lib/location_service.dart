// lib/location_service.dart
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';

class LocationService {
  // Get current location with address
  Future<Map<String, dynamic>> getCurrentLocation() async {
    try {
      // Request location permission
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          return {"error": "Location permissions are denied"};
        }
      }

      if (permission == LocationPermission.deniedForever) {
        return {"error": "Location permissions are permanently denied"};
      }

      // Get position
      Position position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high
      );

      // Get address from coordinates
      String address = "Unknown location";
      try {
        List<Placemark> placemarks = await placemarkFromCoordinates(
          position.latitude, position.longitude
        );
        if (placemarks.isNotEmpty) {
          Placemark place = placemarks[0];
          address = '${place.street}, ${place.locality}, ${place.country}';
        }
      } catch (e) {
        print("Error getting address: $e");
      }

      return {
        "latitude": position.latitude,
        "longitude": position.longitude,
        "accuracy": position.accuracy,
        "address": address
      };
    } catch (e) {
      return {"error": e.toString()};
    }
  }
}