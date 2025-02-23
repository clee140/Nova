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
      appBar: AppBar(title: const Text('Sign In')),
      body: Center(
        child: ElevatedButton(
          onPressed: () async {
            bool isSignedIn = await signInWithGoogle();
            if (isSignedIn) {
              // Access Google Calendar after sign-in
              await accessGoogleCalendar(context);
            } else {
              ScaffoldMessenger.of(
                context,
              ).showSnackBar(SnackBar(content: Text('Sign-in failed!')));
            }
          },
          child: const Text('Sign In with Google'),
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