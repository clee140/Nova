import 'package:flutter/material.dart';
class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: Login(),
    );
  }
}
class Login extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade100, // Light background like the image
      body: Center(
        child: Padding(
          padding: EdgeInsets.all(24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min, // Shrink-wrap content
            children: [
              // Title
              Text(
                "Welcome, let’s set up:",
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  fontStyle: FontStyle.italic,
                ),
              ),
              SizedBox(height: 20),

              // First section
              _buildSection("Email + Calendar + More:", [
                "Sign in with Microsoft",
                "Sign in with Apple",
                "Sign in with Google",
                "Sign in with Microsoft",
              ]),

              SizedBox(height: 20),

              // Second section
              _buildSection("Trip Planning + Convenience", [
                "Sign in with Uber",
                "Sign in with AirBnB",
                "Sign in with Vrbo",
                "Sign in with DoorDash",
              ]),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSection(String title, List<String> buttons) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Section title
        Text(
          title,
          style: TextStyle(fontSize: 16, fontStyle: FontStyle.italic),
        ),
        SizedBox(height: 10),

        // Buttons
        Column(
          children: buttons.map((label) {
            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 5),
              child: SizedBox(
                width: double.infinity, // Full width
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.black, // Matches the image
                    foregroundColor: Colors.white, // White text
                    padding: EdgeInsets.symmetric(vertical: 14),
                  ),
                  onPressed: () {},
                  child: Text(label),
                ),
              ),
            );
          }).toList(),
        ),
      ],
    );
  }
}