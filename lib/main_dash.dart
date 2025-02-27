import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'dart:async';
import 'package:mobileapp/time_in_handler.dart';
import 'package:mobileapp/api_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

class MainDash extends StatefulWidget {
  final String employeeId;
  final String pin;

  const MainDash({
    super.key,
    required this.employeeId,
    required this.pin
  });

  @override
  State<MainDash> createState() => _MainDashState();
}

class _MainDashState extends State<MainDash> {
  TimeInHandler timeInHandler = TimeInHandler();
  ApiService apiService = ApiService();
  List<Map<String, String>> attendanceList = [];

  String currentTime = "";
  String currentDate = "";
  String userName = "";
  String companyName = "";
  bool isClockingIn = false;
  bool isClockingOut = false;
  bool isClocked = false;
  Timer? timer;

  @override
  void initState() {
    super.initState();
    initializeCamera();
    updateTime();
    loadUserInfo();
    checkCurrentStatus();
  }

  Future<void> loadUserInfo() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      userName = prefs.getString('name') ?? "Employee";
    });

    try {
      // Get user info from API
      final response = await apiService.login(widget.employeeId, widget.pin);
      if (response["success"]) {
        setState(() {
          userName = response["name"] ?? userName;
          companyName = response["company"] ?? "";
        });

        // Save updated info to preferences
        await prefs.setString('name', userName);
        await prefs.setString('company', companyName);
      } else {
        // If API fails, just show a message and continue with local data
        print("API error: ${response["error"]}");
      }
    } catch (e) {
      print("Error loading user info: $e");
      // Continue with locally stored data
    }
  }

  Future<void> checkCurrentStatus() async {
    try {
      final response = await apiService.login(widget.employeeId, widget.pin);
      if (response["success"] && response["status"] != null) {
        setState(() {
          isClocked = response["status"]["clocked_in"] ?? false;
        });

        // If there's an entry and it has time_in, add it to the list
        if (response["status"]["clocked_in"] && response["status"]["time_in"] != null) {
          setState(() {
            attendanceList.add({
              "name": userName,
              "time_in": DateFormat('hh:mm:ss a').format(
                DateTime.parse(response["status"]["time_in"])
              ),
              "time_out": response["status"]["clocked_out"] ?
                DateFormat('hh:mm:ss a').format(DateTime.parse(response["status"]["time_out"])) :
                "Not Yet Out"
            });
          });
        }
      } else {
        // If API call fails, check if we have local data for today's status
        final prefs = await SharedPreferences.getInstance();
        final isLocalClocked = prefs.getBool('is_clocked_in') ?? false;
        final localTimeIn = prefs.getString('local_time_in');

        if (isLocalClocked && localTimeIn != null) {
          setState(() {
            isClocked = true;
            attendanceList.add({
              "name": userName,
              "time_in": localTimeIn,
              "time_out": "Not Yet Out (Offline)"
            });
          });
        }
      }
    } catch (e) {
      print("Error checking status: $e");
      // Continue in offline mode
    }
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
    if (isClocked) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("You are already clocked in")),
      );
      return;
    }

    setState(() {
      isClockingIn = true;
    });

    String localTime = DateFormat('hh:mm:ss a').format(DateTime.now());

    // Try to clock in via API
    Map<String, dynamic> result = await timeInHandler.clockIn(
      widget.employeeId,
      widget.pin
    );

    // Save local record regardless of API success
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('is_clocked_in', true);
    await prefs.setString('local_time_in', localTime);

    setState(() {
      isClockingIn = false;
      isClocked = true;

      // Add to attendance list
      attendanceList.add({
        "name": result["api_response"]["success"] ?
          (result["api_response"]["name"] ?? userName) :
          userName,
        "time_in": localTime,
        "time_out": "Not Yet Out"
      });

      if (result["api_response"]["success"] == true) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Successfully clocked in")),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Clocked in locally: ${result["api_response"]["error"] ?? "Failed to connect to server"}"),
            backgroundColor: Colors.orange,
          ),
        );
      }
    });
  }

  Future<void> handleTimeOut() async {
    if (!isClocked) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("You are not clocked in")),
      );
      return;
    }

    setState(() {
      isClockingOut = true;
    });

    String localTime = DateFormat('hh:mm:ss a').format(DateTime.now());

    // Try to clock out via API
    Map<String, dynamic> result = await timeInHandler.clockOut(
      widget.employeeId,
      widget.pin
    );

    // Update local record regardless of API success
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('is_clocked_in', false);
    await prefs.setString('local_time_out', localTime);

    setState(() {
      isClockingOut = false;
      isClocked = false;

      // Update attendance list
      if (attendanceList.isNotEmpty) {
        int index = attendanceList.length - 1;
        attendanceList[index]["time_out"] = localTime;
      }

      if (result["api_response"]["success"] == true) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Successfully clocked out")),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Clocked out locally: ${result["api_response"]["error"] ?? "Failed to connect to server"}"),
            backgroundColor: Colors.orange,
          ),
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    // Your existing UI code
    return Scaffold(
      appBar: AppBar(
        title: Text('Dashboard'),
        backgroundColor: Colors.red,
      ),
      body: Column(
        children: [
          // Time display
          Container(
            padding: EdgeInsets.all(20),
            child: Column(
              children: [
                Text(currentTime, style: TextStyle(fontSize: 30, fontWeight: FontWeight.bold)),
                Text(currentDate, style: TextStyle(fontSize: 18)),
              ],
            ),
          ),

          // Clock in/out buttons
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                ElevatedButton(
                  onPressed: isClockingIn ? null : handleTimeIn,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green,
                    padding: EdgeInsets.symmetric(horizontal: 30, vertical: 15),
                  ),
                  child: isClockingIn
                    ? CircularProgressIndicator(color: Colors.white)
                    : Text('Clock In', style: TextStyle(color: Colors.white)),
                ),
                ElevatedButton(
                  onPressed: isClockingOut ? null : handleTimeOut,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.red,
                    padding: EdgeInsets.symmetric(horizontal: 30, vertical: 15),
                  ),
                  child: isClockingOut
                    ? CircularProgressIndicator(color: Colors.white)
                    : Text('Clock Out', style: TextStyle(color: Colors.white)),
                ),
              ],
            ),
          ),

          // Attendance list
          Expanded(
            child: ListView.builder(
              itemCount: attendanceList.length,
              itemBuilder: (context, index) {
                return ListTile(
                  title: Text(attendanceList[index]["name"] ?? ""),
                  subtitle: Text("In: ${attendanceList[index]["time_in"]} - Out: ${attendanceList[index]["time_out"]}"),
                );
              },
            ),
          ),
        ],
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
