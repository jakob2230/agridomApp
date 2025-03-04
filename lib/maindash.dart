import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'dart:async';
import 'dart:io'; // Needed for displaying image files

import 'package:mobileapp/time_in_handler.dart';

class MainDash extends StatefulWidget {
  const MainDash({Key? key}) : super(key: key);

  @override
  _MainDashState createState() => _MainDashState();
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
    return Scaffold(
      appBar: AppBar(
        title: const Text("Main Dashboard"),
        backgroundColor: Colors.red,
      ),
      drawer: Drawer(
        child: ListView(
          padding: EdgeInsets.zero,
          children: [
            DrawerHeader(
              decoration: const BoxDecoration(
                color: Colors.red,
              ),
              child: const Text("hello!",
                  style: TextStyle(color: Colors.white, fontSize: 24)),
            ),
            ListTile(
              leading: const Icon(Icons.logout),
              title: const Text("Logout"),
              onTap: () {
                // Implement logout logic if needed
                Navigator.pop(context);
              },
            ),
          ],
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            Text("Current Time: $currentTime", style: const TextStyle(fontSize: 20)),
            Text("Current Date: $currentDate", style: const TextStyle(fontSize: 16)),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: handleTimeIn,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
                padding: const EdgeInsets.symmetric(horizontal: 50, vertical: 15),
              ),
              child: const Text("Time In", style: TextStyle(color: Colors.white)),
            ),
            const SizedBox(height: 10),
            ElevatedButton(
              onPressed: handleTimeOut,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
                padding: const EdgeInsets.symmetric(horizontal: 50, vertical: 15),
              ),
              child: const Text("Time Out", style: TextStyle(color: Colors.white)),
            ),
            const SizedBox(height: 20),
            Expanded(
              child: ListView.builder(
                itemCount: attendanceList.length,
                itemBuilder: (context, index) {
                  final item = attendanceList[index];
                  return Card(
                    child: ListTile(
                      title: Text(item["name"] ?? "Employee"),
                      subtitle: Text("In: ${item["time_in"]}\nOut: ${item["time_out"]}"),
                      leading: item["image"]!.isNotEmpty
                          ? Image.file(File(item["image"]!), width: 50, height: 50, fit: BoxFit.cover)
                          : null,
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    timer?.cancel();
    timeInHandler.dispose();
    super.dispose();
  }
}
