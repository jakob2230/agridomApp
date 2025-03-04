import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'maindash.dart'; 

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

Future<void> attemptLogin() async {
  print("Attempting login with employeeId: ${employeeIdController.text} and pin: ${pinController.text}");

  var response = await http.post(
    Uri.parse("http://10.0.2.2:8000/api/login/"),
    headers: {"Content-Type": "application/json"},
    body: json.encode({"username": employeeIdController.text, "password": pinController.text}),
  );

    print("Response status: ${response.statusCode}");
    print("Response body: ${response.body}");

    var data = json.decode(response.body);
    print("Decoded JSON: $data");

    if (data["success"]) {
      print("Login successful. Received data: $data");
      // Check for the redirect field value if needed; update the string if your Django view sends a different one.
      if (data["redirect"] == "maindash") {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => MainDash()),
        );
      } else {
        // Fallback: navigate to MainDash regardless
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => MainDash()),
        );
      }
    } else {
      print("Login failed: ${data["message"]}");
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(data["message"])),
      );
    }
  }

  @override
  void dispose() {
    employeeIdController.dispose();
    pinController.dispose();
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
              const SizedBox(height: 20),
              ElevatedButton(
                onPressed: () {
                print("Button pressed!");
                attemptLogin();
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red,
                  padding: const EdgeInsets.symmetric(horizontal: 50, vertical: 15),
                ),
                child: const Text('Login', style: TextStyle(color: Colors.white)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
