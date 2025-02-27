import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'dart:async';

import 'package:mobileapp/time_in_handler.dart';

class MainDash extends StatefulWidget {
  const MainDash({super.key});

  @override
  State<MainDash> createState() => _MainDashState();
}

class _MainDashState extends State<MainDash> {
  TimeInHandler timeInHandler = TimeInHandler();
  List<Map<String, String>> attendanceList = [];
  
  String currentTime = "";
  String currentDate = "";
  Timer? timer;

  @override
  void initState() {
    super.initState();
    initializeCamera();
    updateTime();
  }

  Future<void> initializeCamera() async {
    await timeInHandler.initializeCamera();
    if (mounted) {
      setState(() {});
    }
  }

  void updateTime() {
    timer = Timer.periodic(Duration(seconds: 1), (Timer t) {
      if (mounted) {
        setState(() {
          currentTime = DateFormat('hh : mm : ss a').format(DateTime.now());
          currentDate = DateFormat('MMMM dd, yyyy EEEE').format(DateTime.now());
        });
      }
    });
  }

  Future<void> handleTimeIn() async {
    Map<String, String> entry = await timeInHandler.captureTimeIn();
    setState(() {
      attendanceList.add({
        "name": "Employee ${attendanceList.length + 1}",
        "time_in": entry["time"]!,
        "time_out": "Not Yet Out",
        "image": entry["image"]!
      });
    });
  }

  void handleTimeOut() {
    if (attendanceList.isNotEmpty) {
      setState(() {
        int index = attendanceList.length - 1;
        attendanceList[index]["time_out"] = DateFormat('hh:mm:ss a').format(DateTime.now());
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    // ... (UI code remains unchanged)
    return Scaffold(
      // (AppBar, Drawer, body, etc.)
      // The rest of the UI is unchanged from the original version.
    );
  }

  @override
  void dispose() {
    timer?.cancel();
    timeInHandler.dispose(); // Dispose of the camera controller
    super.dispose();
  }
}
