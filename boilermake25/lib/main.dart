import 'package:flutter/material.dart';
import 'voice.dart';
import 'login.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Flutter Demo',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
      ),
      home: SignInPage(),
      debugShowCheckedModeBanner: false,
    );
  }
}

class SignInPage extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Sign In')),
      body: Center(
        child: ElevatedButton(
          onPressed: () async {
            // Simulating sign-in process
            bool isSignedIn = await signInWithGoogle(); // Replace with your sign-in logic

            if (isSignedIn) {
              // Navigate to the VoicePage after successful sign-in
              Navigator.pushReplacement(
                context,
                MaterialPageRoute(builder: (context) => Voice()),
              );
            } else {
              // Handle sign-in failure
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('Sign-in failed!')),
              );
            }
          },
          child: const Text('Sign In with Google'),
        ),
      ),
    );
  }

  Future<bool> signInWithGoogle() async {
    // Implement your Google Sign-In logic here
    // For now, let's just simulate a successful sign-in
    await Future.delayed(Duration(seconds: 2)); // Simulate a delay
    return true; // Simulate a successful sign-in
  }
}