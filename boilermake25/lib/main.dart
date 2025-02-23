import 'package:flutter/material.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:http/http.dart' as http;
import 'package:googleapis/calendar/v3.dart' as calendar;
import 'package:googleapis_auth/googleapis_auth.dart' as auth;
import 'voice.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Voice Assistant',
      theme: ThemeData(primarySwatch: Colors.blue),
      home: SignInPage(),
      debugShowCheckedModeBanner: false,
    );
  }
}

class SignInPage extends StatelessWidget {
  final GoogleSignIn _googleSignIn = GoogleSignIn(
    scopes: ['https://www.googleapis.com/auth/calendar.readonly'],
  );

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Padding(
          padding: EdgeInsets.only(top: MediaQuery.of(context).size.height * 0.05),
          child: const Text(
            'Luna',
            style: TextStyle(
              fontSize: 48,
              fontWeight: FontWeight.w500,
              letterSpacing: 0.8,
              fontStyle: FontStyle.italic,
              color: Colors.black,
              fontFamily: 'Times New Roman',
            ),
          ),
        ),
        centerTitle: true,
        toolbarHeight: MediaQuery.of(context).size.height * 0.2,
        backgroundColor: Colors.white,
        elevation: 0,
        foregroundColor: Colors.black,
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Colors.white,
              Colors.white,
              Colors.grey[200]!,
              Colors.grey[300]!,
            ],
            stops: const [0.0, 0.3, 0.6, 1.0],
          ),
        ),
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.start,
            children: [
              SizedBox(height: MediaQuery.of(context).size.height * 0.17),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.white,
                  foregroundColor: Colors.black87,
                  padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                    side: const BorderSide(color: Colors.black, width: 1.5),
                  ),
                ),
                onPressed: () async {
                  bool isSignedIn = await signInWithGoogle();
                  if (isSignedIn) {
                    // Access Google Calendar after sign-in
                    await accessGoogleCalendar(context);
                  } else {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Sign-in failed!')),
                    );
                  }
                },
                child: const Text(
                  'Sign In with Google',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w400,
                    letterSpacing: 0.5,
                  ),
                ),
              ),
              const Spacer(),
              const Padding(
                padding: EdgeInsets.only(bottom: 40),
                child: Text(
                  'Created by Caleb, Chris, and Ethan',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w400,
                    color: Colors.black54,
                    letterSpacing: 0.3,
                    fontStyle: FontStyle.italic,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<bool> signInWithGoogle() async {
    try {
      GoogleSignInAccount? account = await _googleSignIn.signIn();
      if (account != null) {
        print('User signed in: ${account.displayName}');
        print('User email: ${account.email}');
        return true;
      } else {
        return false;
      }
    } catch (e) {
      print('Sign-in failed: $e');
      return false;
    }
  }

  Future<void> accessGoogleCalendar(BuildContext context) async {
    try {
      // Get the current Google Sign-In account
      final GoogleSignInAccount? googleUser = _googleSignIn.currentUser;

      // Get the authentication tokens
      final GoogleSignInAuthentication googleAuth =
          await googleUser!.authentication;

      // Get the access token
      final accessToken = googleAuth.accessToken;

      // Use the access token to authenticate with Google Calendar API
      final client = auth.authenticatedClient(
        http.Client(),
        auth.AccessCredentials(
          auth.AccessToken(
            'Bearer',
            accessToken!,
            DateTime.now().toUtc().add(Duration(hours: 1)),
          ),
          '', // Refresh token not needed in this case
          ['https://www.googleapis.com/auth/calendar.readonly'],
        ),
      );

      // Create a Calendar API client
      final calendarApi = calendar.CalendarApi(client);

      // Get the user's calendar events
      final events = await calendarApi.events.list(
        'primary',
      ); // 'primary' is the default calendar
      events.items?.forEach((event) {
        print('Event: ${event.summary} on ${event.start?.dateTime}');
      });

      // Don't forget to close the client when done
      client.close();

      // Navigate to VoicePage after accessing Google Calendar
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => Voice()),
      );
    } catch (e) {
      print('Failed to access Google Calendar: $e');
    }
  }
}