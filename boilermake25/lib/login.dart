import 'package:flutter/material.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:googleapis_auth/googleapis_auth.dart' as auth;
import 'package:http/http.dart' as http;

class SignInPage extends StatefulWidget {
  @override
  _SignInPageState createState() => _SignInPageState();
}

class _SignInPageState extends State<SignInPage> {
  final GoogleSignIn _googleSignIn = GoogleSignIn(
    scopes: ['https://www.googleapis.com/auth/tasks'],
  );

  bool _isSigningIn = false;

  Future<void> _handleSignIn() async {
    try {
      setState(() {
        _isSigningIn = true;
      });

      final GoogleSignInAccount? googleUser = await _googleSignIn.signIn();
      if (googleUser == null) {
        setState(() {
          _isSigningIn = false;
        });
        return; // User canceled sign-in
      }

      final GoogleSignInAuthentication googleAuth = await googleUser.authentication;
      final auth.AuthClient client = auth.authenticatedClient(
        http.Client(),
        auth.AccessCredentials(
          auth.AccessToken(
            'Bearer',
            googleAuth.accessToken!,
            DateTime.now().toUtc().add(const Duration(hours: 1)), // Token expiry
          ),
          googleAuth.idToken,
          ['https://www.googleapis.com/auth/tasks'],
        ),
      );

      print("Signed in as: ${googleUser.displayName}");
      setState(() {
        _isSigningIn = false;
      });

      // Navigate to next screen or perform actions after sign-in

    } catch (error) {
      print("Sign-in error: $error");
      setState(() {
        _isSigningIn = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Logo
            
              SizedBox(height: 50),

              // Google Sign-In Button
              ElevatedButton(
                onPressed: _isSigningIn ? null : _handleSignIn,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.white,
                  foregroundColor: Colors.black,
                  padding: EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  elevation: 3,
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                   
                    SizedBox(width: 10),
                    _isSigningIn
                        ? CircularProgressIndicator(color: Colors.black)
                        : Text("Sign in with Google"),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}