import 'package:flutter/material.dart';
import 'package:auth0_flutter/auth0_flutter.dart';

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: Login(),
    );
  }
}

class Login extends StatefulWidget {
  @override
  _LoginState createState() => _LoginState();
}

class _LoginState extends State<Login> {
  Credentials? _credentials;
  late Auth0 auth0;

  @override
  void initState() {
    super.initState();
    auth0 = Auth0('dev-62vsviavz05io4lc.us.auth0.com', 'Opnt5PJcZWfTlZMp75dFhD4YS7PWC3kB');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white, // Light background like the image
      floatingActionButton: FloatingActionButton(
        onPressed: () {},
        backgroundColor: Colors.black,
        child: const Icon(Icons.arrow_forward, color: Colors.white,),
      ),
      body: Center(
        child: Padding(
          padding: EdgeInsets.all(24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min, // Shrink-wrap content
            children: [
              // Title
              Text(
                "Connect your accounts",
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  fontStyle: FontStyle.italic,
                ),
              ),
              SizedBox(height: 20),

              // First section
              _buildSection("Travel", [
                "Sign in with Uber",
                "Sign in with Lyft",
                "Sign in with AirBnB",
              ]),

              SizedBox(height: 20),

              // Second section
              _buildSection("Calendar", [
                "Sign in with Microsoft",
                "Sign in with Apple",
                _buildGoogleSignIn(),
              ]),

              SizedBox(height: 20),

              // Second section
              _buildSection("Delivery", [
                "Sign in with DoorDash",
                "Sign in with GrubHub",
                "Sign in with Uber Eats",
              ]),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildGoogleSignIn() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: SizedBox(
        width: double.infinity,
        child: ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.black,
            foregroundColor: Colors.white,
            padding: EdgeInsets.symmetric(vertical: 14),
          ),
          onPressed: () async {
            try {
              final credentials = await auth0.webAuthentication(scheme: 'com.example.boilermake25').login(useHTTPS: true);
              setState(() {
                _credentials = credentials;
              });
              // Handle successful login
              print('Logged in: ${credentials.user.name}');
            } catch (e) {
              print('Login error: $e');
            }
          },
          child: Text("Sign in with Google"),
        ),
      ),
    );
  }

  Widget _buildSection(String title, List<dynamic> buttons) {
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
          children: buttons.map((button) {
            if (button is Widget) {
              return button;
            }
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
                  child: Text(button),
                ),
              ),
            );
          }).toList(),
        ),
      ],
    );
  }
}