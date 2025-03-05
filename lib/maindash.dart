import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'dart:async';

import 'file_leave_screen.dart';
import 'time_in_handler.dart';
import 'drawer_widget.dart';

class MainDash extends StatefulWidget {
  final String fullName; // New parameter for user's full name

  const MainDash({Key? key, required this.fullName}) : super(key: key);

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
    timer = Timer.periodic(const Duration(seconds: 1), (Timer t) {
      if (mounted) {
        setState(() {
          currentTime = DateFormat('hh : mm : ss a').format(DateTime.now());
          currentDate = DateFormat('MMMM dd, yyyy EEEE').format(DateTime.now());
        });
      }
    });
  }

  Future<void> handleTimeIn() async {
    String capturedImagePath = await timeInHandler.captureTimeIn();
    String timeIn = DateFormat('hh:mm:ss a').format(DateTime.now());
    setState(() {
      attendanceList.add({
        "name": "Employee ${attendanceList.length + 1}",
        "time_in": timeIn,
        "time_out": "Not Yet Out",
        "image": capturedImagePath,
      });
    });
  }

  void handleTimeOut() {
    if (attendanceList.isNotEmpty) {
      setState(() {
        int index = attendanceList.length - 1;
        attendanceList[index]["time_out"] =
            DateFormat('hh:mm:ss a').format(DateTime.now());
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.black),
        leading: Builder(
          builder: (context) => IconButton(
            icon: const Icon(Icons.menu, color: Colors.black),
            onPressed: () {
              Scaffold.of(context).openDrawer();
            },
          ),
        ),
        centerTitle: true,
        title: Image.asset(
          'images/SFgroup.png',
          height: 60,
          fit: BoxFit.contain,
        ),
      ),
      // Pass the user's full name to the AppDrawer here:
      drawer: AppDrawer(fullName: widget.fullName),
      body: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          children: [
            const SizedBox(height: 20),
            // Live Camera Preview
            Container(
              decoration: BoxDecoration(
                border: Border.all(color: const Color(0xFFF44336), width: 3),
                borderRadius: BorderRadius.circular(8),
              ),
              child: SizedBox(
                height: 200,
                width: 300,
                child: (timeInHandler.cameraController != null &&
                        timeInHandler.cameraController!.value.isInitialized)
                    ? CameraPreview(timeInHandler.cameraController!)
                    : Container(color: Colors.grey),
              ),
            ),
            const SizedBox(height: 20),
            // Current Time & Date
            Text(
              currentTime,
              style: const TextStyle(fontSize: 32, fontWeight: FontWeight.bold),
            ),
            Text(
              currentDate,
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 20),
            // Action Buttons: Time In, Time Out, File Leave
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.red,
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8)),
                  ),
                  onPressed: handleTimeIn,
                  child: const Text('Time In', style: TextStyle(color: Colors.white)),
                ),
                const SizedBox(width: 10),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.red,
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8)),
                  ),
                  onPressed: handleTimeOut,
                  child: const Text('Time Out', style: TextStyle(color: Colors.white)),
                ),
                const SizedBox(width: 10),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.red,
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8)),
                  ),
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (context) => const FileLeaveScreen()),
                    );
                  },
                  child: const Text('File Leave', style: TextStyle(color: Colors.white)),
                ),
              ],
            ),
            const SizedBox(height: 20),
            // Attendance List Header
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(10),
              decoration: const BoxDecoration(
                color: Colors.red,
                borderRadius: BorderRadius.only(
                    topLeft: Radius.circular(8), topRight: Radius.circular(8)),
              ),
              child: const Center(
                child: Text(
                  'Attendance List',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white),
                ),
              ),
            ),
            // Attendance List Table wrapped in scroll views
            Expanded(
              child: SingleChildScrollView(
                scrollDirection: Axis.vertical,
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: DataTable(
                    columnSpacing: 20,
                    columns: const [
                      DataColumn(
                        label: Text('Name', style: TextStyle(fontWeight: FontWeight.bold)),
                      ),
                      DataColumn(
                        label: Text('Time IN', style: TextStyle(fontWeight: FontWeight.bold)),
                      ),
                      DataColumn(
                        label: Text('Time OUT', style: TextStyle(fontWeight: FontWeight.bold)),
                      ),
                    ],
                    rows: List.generate(
                      attendanceList.length,
                      (index) => DataRow(
                        cells: [
                          DataCell(Text(attendanceList[index]['name']!)),
                          DataCell(Text(attendanceList[index]['time_in']!)),
                          DataCell(Text(attendanceList[index]['time_out']!)),
                        ],
                      ),
                    ),
                  ),
                ),
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
    timeInHandler.disposeCamera();
    super.dispose();
  }
}
