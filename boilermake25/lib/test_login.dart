import 'package:flutter/material.dart';
import 'Auth0Service.dart';  // Import the Auth0Service class

void main() {
  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  final Auth0Service auth0Service = Auth0Service();

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      home: Scaffold(
        appBar: AppBar(title: Text('Auth0 Flutter')),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              ElevatedButton(
                onPressed: () {
                  auth0Service.login();
                },
                child: Text('Login with Auth0'),
              ),
              SizedBox(height: 20),
              ElevatedButton(
                onPressed: () {
                  auth0Service.logout();
                },
                child: Text('Logout'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}