import 'package:flutter/material.dart';
import 'main.dart'; // Ensure that main.dart exports EmployeeLoginPage if needed

class AppDrawer extends StatelessWidget {
  final String fullName; // Add a field to hold the user's full name

  const AppDrawer({Key? key, required this.fullName}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Drawer(
      child: Container(
        color: const Color(0xFFF44336),
        child: Column(
          children: [
            DrawerHeader(
              margin: EdgeInsets.zero,
              padding: const EdgeInsets.all(16.0),
              decoration: const BoxDecoration(color: Color(0xFFF44336)),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  const CircleAvatar(
                    radius: 30,
                    backgroundColor: Colors.white,
                    child: Icon(Icons.person, color: Color(0xFFF44336), size: 30),
                  ),
                  const SizedBox(width: 16),
                  // Display the passed fullName here
                  Text(
                    fullName,
                    style: const TextStyle(color: Colors.white, fontSize: 20),
                  ),
                ],
              ),
            ),
            ListTile(
              leading: const Icon(Icons.calendar_today, color: Colors.white),
              title: const Text('Leave approval', style: TextStyle(color: Colors.white)),
              onTap: () {
                Navigator.pop(context);
              },
            ),
            ListTile(
              leading: const Icon(Icons.info, color: Colors.white),
              title: const Text('About', style: TextStyle(color: Colors.white)),
              onTap: () {
                Navigator.pop(context);
              },
            ),
            const Spacer(),
            ListTile(
              leading: const Icon(Icons.logout, color: Colors.white),
              title: const Text('Sign Out', style: TextStyle(color: Colors.white)),
              onTap: () {
                Navigator.pushAndRemoveUntil(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const EmployeeLoginPage(),
                  ),
                  (Route<dynamic> route) => false,
                );
              },
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }
}
