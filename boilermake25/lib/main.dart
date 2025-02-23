import 'package:flutter/material.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:http/http.dart' as http;
import 'package:googleapis/calendar/v3.dart' as calendar;
import 'package:googleapis_auth/googleapis_auth.dart' as auth;
import 'package:googleapis/tasks/v1.dart' as tasks;

import 'voice.dart';

List<String> globalCalendarEvents = [];
List<String> globalTasks = [];
String? accessToken = "";

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Google Calendar Access',
      theme: ThemeData(primarySwatch: Colors.blue),
      initialRoute: '/',
      routes: {
        '/': (context) => SignInPage(),
        '/voice': (context) => const Voice(),
      },
      debugShowCheckedModeBanner: false,
    );
  }
}

class SignInPage extends StatefulWidget {
  @override
  _SignInPageState createState() => _SignInPageState();
}

class _SignInPageState extends State<SignInPage> {
  final GoogleSignIn _googleSignIn = GoogleSignIn(
    scopes: [
      'https://www.googleapis.com/auth/calendar.readonly',
      'https://www.googleapis.com/auth/calendar.events',
      'https://www.googleapis.com/auth/tasks',
      'https://www.googleapis.com/auth/tasks.readonly'
    ],
  );

  @override
  void initState() {
    super.initState();
    _checkSignInStatus();
  }

  Future<void> _checkSignInStatus() async {
    try {
      final isSignedIn = await _googleSignIn.isSignedIn();
      if (isSignedIn) {
        final account = await _googleSignIn.signInSilently();
        if (account != null) {
          await accessGoogleCalendar(context);
        }
      }
    } catch (e) {
      print('Error checking sign-in status: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Padding(
          padding: EdgeInsets.only(
            top: MediaQuery.of(context).size.height * 0.05,
          ),
          child: const Text(
            'Nova',
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
              const Color(0xFFF8F9FA), // Lightest grey
              const Color(0xFFE9ECEF), // Light grey
              const Color(0xFFDEE2E6), // Medium grey
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
                  foregroundColor: const Color(0xFF495057), // Dark grey
                  padding: const EdgeInsets.symmetric(
                    horizontal: 32,
                    vertical: 16,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                    side: const BorderSide(
                      color: Color(0xFF6C757D),
                      width: 1.5,
                    ), // Medium dark grey
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
                    color: const Color(
                      0xFF6C757D,
                    ), // Medium dark grey for credits text
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
      await _googleSignIn.signOut(); // Sign out first to ensure clean state
      GoogleSignInAccount? account = await _googleSignIn.signIn();
      if (account != null) {
        final auth = await account.authentication;
        accessToken = auth.accessToken;
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
      final account = await _googleSignIn.signInSilently();
      if (account == null) {
        print('No signed in account found');
        return;
      }

      // Get the authentication tokens
      final GoogleSignInAuthentication googleAuth = await account.authentication;

      // Get the access token
      accessToken = googleAuth.accessToken;
      
      if (accessToken == null) {
        print('No access token available');
        return;
      }

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
          [
            'https://www.googleapis.com/auth/calendar.readonly',
            'https://www.googleapis.com/auth/calendar',
            'https://www.googleapis.com/auth/tasks',
            'https://www.googleapis.com/auth/tasks.readonly'
          ],
        ),
      );

      // Create a Calendar API client
      final calendarApi = calendar.CalendarApi(client);

      // Get the user's calendar events
      final events = await calendarApi.events.list(
        'primary',
      ); // 'primary' is the default calendar
      events.items?.forEach((event) {
        // print('Event: ${event.summary} on ${event.start?.dateTime}');
        globalCalendarEvents.add(
          'Event: ${event.summary} on ${event.start?.dateTime}',
        );
      });

      final tasksApi = tasks.TasksApi(client);

      // Get the user's task lists
      final taskLists = await tasksApi.tasklists.list();

      // Fetch tasks for each task list
      for (var taskList in taskLists.items!) {
        final tasks = await tasksApi.tasks.list(taskList.id!);

        tasks.items?.forEach((task) {
          // Add task details to globalCalendarEvents (or create a separate list if needed)
          globalTasks.add('Task: ${task.title} with due date: ${task.due}');
        });
      }

      // Don't forget to close the client when done
      client.close();

      // Navigate to VoicePage after accessing Google Calendar
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (context) => Voice(displayName: account.displayName),
        ),
      );
    } catch (e) {
      print('Failed to access Google Calendar: $e');
    }
  }
}