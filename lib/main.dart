import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'main_dash.dart';
import 'api_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(EmployeeLoginApp());
}

class EmployeeLoginApp extends StatelessWidget {
  const EmployeeLoginApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      home: EmployeeLoginPage(),
    );
  }
}

class EmployeeLoginPage extends StatefulWidget {
  const EmployeeLoginPage({super.key});

  @override
  _EmployeeLoginPageState createState() => _EmployeeLoginPageState();
}

class _EmployeeLoginPageState extends State<EmployeeLoginPage> {
  final TextEditingController employeeIdController = TextEditingController();
  final TextEditingController pinController = TextEditingController();
  final TextEditingController newPinController = TextEditingController();
  final ApiService _apiService = ApiService();
  bool isFirstLogin = false;

  Future<void> attemptLogin() async {
    String employeeId = employeeIdController.text;
    String pin = pinController.text;

    if (isFirstLogin && newPinController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Please enter a new PIN")),
      );
      return;
    }

    // For first login, we need to set a new PIN
    if (isFirstLogin) {
      var response = await _apiService.clockIn(
        employeeId,
        pin,
        {}, // Empty location
        null, // No image
        newPin: newPinController.text, // Pass the new PIN value
      );

      if (response["success"]) {
        // Store user info for later
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('employee_id', employeeId);
        await prefs.setString('pin', newPinController.text);
        await prefs.setString('name', response["name"] ?? "");

        // Navigate to main dashboard
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => MainDash(
            employeeId: employeeId,
            pin: newPinController.text,
          )),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(response["error"] ?? "Login failed")),
        );
      }
      return;
    }

    // Regular login
    var response = await _apiService.login(employeeId, pin);

    if (response["success"]) {
      // Store user info for later
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('employee_id', employeeId);
      await prefs.setString('pin', pin);
      await prefs.setString('name', response["name"] ?? "");

      // Navigate to main dashboard
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => MainDash(
          employeeId: employeeId,
          pin: pin,
        )),
      );
    } else if (response["error"] == "first_login") {
      // Show UI for first login
      setState(() {
        isFirstLogin = true;
      });
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(response["message"] ?? "Login failed")),
      );
    }
  }

  void _testApiConnection() async {
    try {
      final response = await http.get(Uri.parse("http://10.0.2.2:8000/api/test/"));
      print("API Test Response: ${response.body}");
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("API Connection: ${response.statusCode == 200 ? 'Success' : 'Failed'}")),
      );
    } catch (e) {
      print("API Test Error: $e");
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("API Connection Error: $e")),
      );
    }
  }

  @override
  void dispose() {
    employeeIdController.dispose();
    pinController.dispose();
    newPinController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Image.asset('images/SFgroup.png', height: 100),
              const SizedBox(height: 20),
              TextField(
                controller: employeeIdController,
                decoration: const InputDecoration(
                  labelText: 'Employee ID',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: pinController,
                obscureText: true,
                decoration: const InputDecoration(
                  labelText: 'PIN',
                  border: OutlineInputBorder(),
                ),
              ),
              if (isFirstLogin) ...[
                const SizedBox(height: 10),
                TextField(
                  controller: newPinController,
                  obscureText: true,
                  decoration: const InputDecoration(
                    labelText: 'New PIN (required for first login)',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  "First login detected. Please set a new PIN.",
                  style: TextStyle(color: Colors.red),
                ),
              ],
              const SizedBox(height: 20),
              ElevatedButton(
                onPressed: attemptLogin,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red,
                  padding: const EdgeInsets.symmetric(horizontal: 50, vertical: 15),
                ),
                child: Text(
                  isFirstLogin ? 'Set New PIN & Login' : 'Login',
                  style: TextStyle(color: Colors.white)
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
