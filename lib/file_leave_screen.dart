import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class FileLeaveScreen extends StatefulWidget {
  const FileLeaveScreen({super.key});

  @override
  _FileLeaveScreenState createState() => _FileLeaveScreenState();
}

class _FileLeaveScreenState extends State<FileLeaveScreen> {
  int remainingLeave = 15; // Leave credits
  int totalLeaveCredits = 16;
  String? selectedLeaveType;
  DateTime? startDate;
  DateTime? endDate;
  int leaveDays = 0;

  // Function to select a date
  Future<void> _selectDate(BuildContext context, bool isStartDate) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime(2030),
    );

    if (picked != null) {
      setState(() {
        if (isStartDate) {
          startDate = picked;
          if (endDate != null && endDate!.isBefore(startDate!)) {
            endDate = null; // Reset end date if it’s before start date
          }
        } else {
          if (startDate == null) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('Please select a start date first!')),
            );
            return;
          }
          if (picked.isBefore(startDate!)) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('End date cannot be before start date!')),
            );
            return;
          }
          endDate = picked;
        }

        // Calculate leave duration
        if (startDate != null && endDate != null) {
          leaveDays = endDate!.difference(startDate!).inDays + 1;
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('File Leave'),
        backgroundColor: Colors.red,
        leading: IconButton(
          icon: Icon(Icons.close),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Centered Logo & Leave Balance
            Center(
              child: Column(
                children: [
                  Image.asset('images/SFgroup.png', height: 75), // Your logo here
                  SizedBox(height: 10),
                  Text(
                    "Number of leave left: $remainingLeave/$totalLeaveCredits",
                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.red),
                  ),
                ],
              ),
            ),
            SizedBox(height: 20),

            // Leave Type Dropdown
            Text("Select Leave Type:", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            SizedBox(height: 5), // Reduced spacing
            DropdownButtonFormField<String>(
              value: selectedLeaveType,
              items: ["Sick Leave", "Vacation Leave", "Emergency Leave"]
                  .map((type) => DropdownMenuItem(value: type, child: Text(type)))
                  .toList(),
              onChanged: (value) {
                setState(() {
                  selectedLeaveType = value;
                });
              },
              decoration: InputDecoration(
                border: OutlineInputBorder(),
                hintText: "Choose Leave Type",
              ),
            ),
            SizedBox(height: 15), // Reduced spacing

            // Leave Start Date
            Text("Leave Start Date:", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            SizedBox(height: 5), // Reduced spacing
            TextField(
              readOnly: true,
              controller: TextEditingController(
                text: startDate != null ? DateFormat.yMMMd().format(startDate!) : "",
              ),
              decoration: InputDecoration(
                border: OutlineInputBorder(),
                hintText: "Select Start Date",
                suffixIcon: IconButton(
                  icon: Icon(Icons.calendar_today),
                  onPressed: () => _selectDate(context, true),
                ),
              ),
            ),
            SizedBox(height: 15), // Reduced spacing

            // Leave End Date
            Text("Leave End Date:", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            SizedBox(height: 5), // Reduced spacing
            TextField(
              readOnly: true,
              controller: TextEditingController(
                text: endDate != null ? DateFormat.yMMMd().format(endDate!) : "",
              ),
              decoration: InputDecoration(
                border: OutlineInputBorder(),
                hintText: "Select End Date",
                suffixIcon: IconButton(
                  icon: Icon(Icons.calendar_today),
                  onPressed: () => _selectDate(context, false),
                ),
              ),
            ),
            SizedBox(height: 10), // Reduced spacing

            // Display Number of Leave Days
            if (leaveDays > 0)
              Center(
                child: Text(
                  "Total Leave Days: $leaveDays",
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.blue),
                ),
              ),
            SizedBox(height: 5), // Reduced spacing

            // Reason Text Field
            Text("Reason:", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            SizedBox(height: 5), // Reduced spacing
            TextField(
              maxLines: 3,
              decoration: InputDecoration(
                border: OutlineInputBorder(),
                hintText: "Enter your reason for leave",
              ),
            ),
            SizedBox(height: 15), // Reduced spacing

            // Submit Button
            Center(
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red,
                  padding: EdgeInsets.symmetric(horizontal: 30, vertical: 10),
                ),
                onPressed: () {
                  if (selectedLeaveType != null && startDate != null && endDate != null) {
                    if (remainingLeave >= leaveDays) {
                      setState(() {
                        remainingLeave -= leaveDays; // Deduct based on leave duration
                      });

                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('Leave request submitted successfully!')),
                      );
                      Navigator.pop(context); // Close after submitting
                    } else {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('Insufficient leave balance!')),
                      );
                    }
                  } else {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Please complete the form!')),
                    );
                  }
                },
                child: Text("Submit Leave", style: TextStyle(color: Colors.white)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
