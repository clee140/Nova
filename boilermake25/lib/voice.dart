import 'dart:convert';
import 'dart:typed_data'; // For handling audio data
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:speech_to_text/speech_to_text.dart' as stt;
import 'package:just_audio/just_audio.dart';
import 'main.dart';
import 'package:path_provider/path_provider.dart';
import 'dart:io';
import 'package:google_sign_in/google_sign_in.dart';

bool count = false;

class Voice extends StatefulWidget {
  final String? displayName;
  const Voice({super.key, this.displayName});

  @override
  _VoiceState createState() => _VoiceState();
}

class _VoiceState extends State<Voice> with WidgetsBindingObserver, SingleTickerProviderStateMixin {
  late stt.SpeechToText _speech;
  bool _isListening = false;
  bool _isPlaying = false;
  late AnimationController _animationController;
  late Animation<double> _scaleAnimation;
  late Animation<double> _rotationAnimation;
  String _text = "Press the microphone button to start speaking";
  String _responseText = ""; // Stores API response
  double _confidence = 1.0;
  AudioPlayer? _audioPlayer;
  List<String> _conversationHistory = []; // To store AI responses
  List<String> _userHistory = [];
  Directory? _tempDir;
  final GoogleSignIn _googleSignIn = GoogleSignIn(
    scopes: [
      'https://www.googleapis.com/auth/calendar.readonly',
      'https://www.googleapis.com/auth/tasks',
      'https://www.googleapis.com/auth/tasks.readonly'
    ],
  );

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _initResources();
    _checkAndRefreshToken();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 3000), // Slower rotation
    );
    _scaleAnimation = Tween<double>(begin: 1.0, end: 1.15).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeInOut),
    );
    _rotationAnimation = Tween<double>(begin: 0, end: 2 * 3.14159).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.linear),
    );
    
    // Play welcome message
    _playWelcomeMessage();
  }

  Future<void> _initResources() async {
    _speech = stt.SpeechToText();
    _audioPlayer = AudioPlayer();
    await _initTempDir();
  }

  Future<void> _checkAndRefreshToken() async {
    try {
      final isSignedIn = await _googleSignIn.isSignedIn();
      if (!isSignedIn) {
        // Navigate back to sign-in page if not signed in
        Navigator.of(context).pushReplacementNamed('/');
        return;
      }

      final account = await _googleSignIn.signInSilently();
      if (account != null) {
        final auth = await account.authentication;
        accessToken = auth.accessToken;
      }
    } catch (e) {
      print('Error refreshing token: $e');
      Navigator.of(context).pushReplacementNamed('/');
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused) {
      // Clean up resources when app is paused
      _cleanupResources();
    } else if (state == AppLifecycleState.resumed) {
      // Reinitialize resources when app is resumed
      _initResources();
      _checkAndRefreshToken();
    }
  }

  Future<void> _cleanupResources() async {
    _isListening = false;
    await _speech.stop();
    await _audioPlayer?.dispose();
    _audioPlayer = null;
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _cleanupResources();
    _animationController.dispose();
    super.dispose();
  }

  Future<void> _initTempDir() async {
    _tempDir = await getTemporaryDirectory();
  }

  Future<void> _playAudio(Uint8List audioBytes) async {
    try {
      if (_tempDir == null) {
        await _initTempDir();
      }

      if (_audioPlayer == null) {
        _audioPlayer = AudioPlayer();
      }

      setState(() {
        _isPlaying = true;
        _animationController.repeat(); // Remove reverse for continuous rotation
      });

      // Create a temporary file with a unique name
      final tempFile = File(
        '${_tempDir!.path}/temp_audio_${DateTime.now().millisecondsSinceEpoch}.wav',
      );
      await tempFile.writeAsBytes(audioBytes);

      // Use the file URL instead of data URL
      await _audioPlayer?.setFilePath(tempFile.path);
      await _audioPlayer?.play();

      // Delete the file after playback completes
      _audioPlayer?.playerStateStream.listen((state) {
        if (state.processingState == ProcessingState.completed) {
          setState(() {
            _isPlaying = false;
            _animationController.stop();
            _animationController.reset();
          });
          tempFile.delete().catchError((error) {
            print('Error deleting temporary file: $error');
          });
        }
      });
    } catch (e) {
      print('Error playing audio: $e');
      setState(() {
        _isPlaying = false;
        _animationController.stop();
        _animationController.reset();
      });
    }
  }

  void _listen() async {
    if (!_isListening) {
      bool available = await _speech.initialize(
        onStatus: (val) => print('onStatus: $val'),
        onError: (val) => print('onError: $val'),
      );

      if (available) {
        setState(() {
          _isListening = true;
          _text = "Listening...";
        });

        _speech.listen(
          onResult:
              (val) => setState(() {
                _text = val.recognizedWords;
                print(_text);
                if (val.hasConfidenceRating && val.confidence > 0) {
                  _confidence = val.confidence;
                }
              }),
        );

        // Auto-stop after 10 seconds
        Future.delayed(const Duration(seconds: 8), () {
          if (_isListening) {
            _stopListening();
          }
        });
      }
    } else {
      _stopListening();
    }
  }

  void _stopListening() {
    setState(() {
      _isListening = false;
      if (_text.isEmpty || _text == "Listening...") {
        _text = "Press the microphone button to start speaking";
      } else {
        _makeApiCall(); // Send the recognized speech to the API
      }
    });
    _speech.stop();
  }

  Future<void> _makeApiCall() async {
    const String modalApiUrl =
        "https://calebbuening--meta-llama-3-8b-instruct-web-dev.modal.run";
    const String cartesiaApiUrl =
        "https://api.cartesia.ai/tts/bytes"; // Cartesia TTS endpoint

    try {
      String conversationHistoryText = _conversationHistory.join('\n');
      String combinedText =
          "Your name is Luna and you are an AI personal assistant. Your job is \n"
          "to answer the user's questions. Don't give incredibly length answers.\n"
          "Be to the point and provide all information necessary/requested.\n\n"
          "Today is Sunday, February 22nd, 2025. The weather is Sunny and clear but cold.\n\n"
          "What's special about you is that you have the ability to call certain functions. These functions\n"
          "will be called when you output this exact format, : ?FUNCTION FUNCTION_NAME ARG1\n"
          "It should be the ONLY thing you output, no other text or content, just the function call as described above including the question mark at the beginning of your response.\n"
          "Here is a list of the exact functions available to you, do not create your own functions:\n"
          "?FUNCTION TODO CREATE <name_of_the_todo> - create a to do with a string title\n"
          "?FUNCTION TODO READ - Get all to dos in to-do list. This information will be passed to you as another prompt, so wait to do anything else until receiving the results of this call\n"
          "?FUNCTION CAL READ - read all user calendar events\n"
          "?FUNCTION CAL CREATE \"title/summary\" MM/DD/YYYY start_time end_time - create a calendar event on a certain day with a start and end time, plus title it\n\n"
          "Below, as the current conversation with the user begins, the transcript will be included as context for you\n"
          "below:\n\n"
          "Current conversation transcript: \n"
          "$conversationHistoryText\n"
          "Here is the newest prompt from the user: $_text\n";

      print(combinedText);
      print("Global tasks: $globalTasks");

      // Step 3: First API Call
      final modalResponse = await http.post(
        Uri.parse(modalApiUrl),
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({
          "prompts": [combinedText],
        }),
      );

      if (modalResponse.statusCode == 200) {
        final List<dynamic> modalData = jsonDecode(modalResponse.body);
        String modalTextOutput =
            modalData.isNotEmpty ? modalData[0] : "No response received.";

        // Update state with first response
        setState(() {
          if (!modalTextOutput.startsWith("?FUNCTION")) {
            _responseText = modalTextOutput;
          }
          _conversationHistory.add("User: $_text");
          _conversationHistory.add("AI: $_responseText");
        });

        // Step 4: If response is "#CAL READ", make second API call
        if (modalTextOutput.contains("CAL READ")) {
          List<String> last10Events =
              globalCalendarEvents.length > 10
                  ? globalCalendarEvents.sublist(
                    globalCalendarEvents.length - 10,
                  )
                  : globalCalendarEvents;

          print(globalCalendarEvents);

          _conversationHistory.add(
            "User calendar events: ${last10Events.join(', ')}",
          );

          // Make second API call
          final modalResponseRead = await http.post(
            Uri.parse(modalApiUrl),
            headers: {"Content-Type": "application/json"},
            body: jsonEncode({
              "prompts": [
                "Here is the user's calendar events: \n"
                    "User calendar events: ${last10Events.join(', ')}\n"
                    "Answer the user's prompt with this calendar information,\n"
                    "making dates, times, and content clean and readable by a text-to-voice ai: $_text\n.",
              ],
            }),
          );

          if (modalResponseRead.statusCode == 200) {
            final List<dynamic> modalDataRead = jsonDecode(
              modalResponseRead.body,
            );
            String modalTextOutputRead =
                modalDataRead.isNotEmpty
                    ? modalDataRead[0]
                    : "No response received.";

            // Update state with second response
            setState(() {
              _responseText = modalTextOutputRead;
              _conversationHistory.add("AI: $_responseText");
              modalTextOutput = _responseText;
            });
          }
        }
        // Step 4: If response is "#CAL READ", make second API call
        if (modalTextOutput.contains("TODO READ")) {
          List<String> last10Tasks =
              globalTasks.length > 10
                  ? globalTasks.sublist(globalTasks.length - 10)
                  : globalTasks;

          print(globalTasks);

          _conversationHistory.add(
            "User calendar events: ${last10Tasks.join(', ')}",
          );

          // Make second API call
          final modalResponseReadTodo = await http.post(
            Uri.parse(modalApiUrl),
            headers: {"Content-Type": "application/json"},
            body: jsonEncode({
              "prompts": [
                "Here is the user's to do list tasks: \n"
                    "User to do list tasks: ${last10Tasks.join(', ')}\n"
                    "Answer the user's prompt with this task information,\n"
                    "making descriptions, due dates, and content clean, human readable, and alphanumeric only by a text-to-voice ai: $_text\n",
              ],
            }),
          );

          if (modalResponseReadTodo.statusCode == 200) {
            final List<dynamic> modalDataReadTodo = jsonDecode(
              modalResponseReadTodo.body,
            );
            String modalTextOutputReadTodo =
                modalDataReadTodo.isNotEmpty
                    ? modalDataReadTodo[0]
                    : "No response received.";

            // Update state with second response
            setState(() {
              _responseText = modalTextOutputReadTodo.replaceAll("*", "");
              _conversationHistory.add("AI: $_responseText");
              modalTextOutput = _responseText;
            });
          }
        }
        // Step 4: If response is "#TODO CREATE", make second API call
        if (modalTextOutput.contains("TODO CREATE")) {
          addGoogleTask("$_text");
          // Make second API call
          final modalResponseRead = await http.post(
            Uri.parse(modalApiUrl),
            headers: {"Content-Type": "application/json"},
            body: jsonEncode({
              "prompts": [
                "The task was created successfully, notify the user briefly\n",
              ],
            }),
          );

          if (modalResponseRead.statusCode == 200) {
            final List<dynamic> modalDataRead = jsonDecode(
              modalResponseRead.body,
            );
            String modalTextOutputRead =
                modalDataRead.isNotEmpty
                    ? modalDataRead[0]
                    : "No response received.";

            // Update state with second response
            setState(() {
              _responseText = modalTextOutputRead;
              _conversationHistory.add("AI: $_responseText");
              modalTextOutput = _responseText;
            });
          }
        }

        if (modalTextOutput.contains("CAL CREATE")) {
          print("CAL CREATE\n");
          List<String> parts = modalTextOutput.split('"'); 
            if (parts.length < 2) throw ArgumentError("Invalid format: Missing title.");

            String title = parts[1].trim(); // Extracts "title name"
            List<String> eventParts = parts.last.trim().split(' ');

            if (eventParts.length < 3) throw ArgumentError("Invalid format: Missing date/time.");

            // Extract Date and Time
            String date = eventParts[0]; // MM/DD/YYYY
            String startTime = eventParts[1]; // HH:MM
            String endTime = eventParts[2];   // HH:MM

            // Parse Date
            List<String> dateParts = date.split('/');
            int month = int.parse(dateParts[0]);
            int day = int.parse(dateParts[1]);
            int year = int.parse(dateParts[2]);

            // Parse Start Time
            List<String> startTimeParts = startTime.split(':');
            int startHour = int.parse(startTimeParts[0]);
            int startMinute = int.parse(startTimeParts[1]);

            // Parse End Time
            List<String> endTimeParts = endTime.split(':');
            int endHour = int.parse(endTimeParts[0]);
            int endMinute = int.parse(endTimeParts[1]);

            // Create DateTime objects (Assume local timezone)
            DateTime startDateTime = DateTime(year, month, day, startHour, startMinute);
            DateTime endDateTime = DateTime(year, month, day, endHour, endMinute);

            // Convert to RFC 3339 format
            String startISO = startDateTime.toIso8601String();
            String endISO = endDateTime.toIso8601String();

            createGoogleCalendarEvent(title, date, startISO, endISO);

          // Make second API call
          final modalResponseRead = await http.post(
            Uri.parse(modalApiUrl),
            headers: {"Content-Type": "application/json"},
            body: jsonEncode({
              "prompts": [
                "The event was created successfully, notify the user briefly\n",
              ],
            }),
          );

          if (modalResponseRead.statusCode == 200) {
            final List<dynamic> modalDataRead = jsonDecode(
              modalResponseRead.body,
            );
            String modalTextOutputRead =
                modalDataRead.isNotEmpty
                    ? modalDataRead[0]
                    : "No response received.";

            // Update state with second response
            setState(() {
              _responseText = modalTextOutputRead;
              _conversationHistory.add("AI: $_responseText");
              modalTextOutput = _responseText;
            });
          }
        }

        // Step 2: Send Modal's output to Cartesia API for TTS
        final cartesiaResponse = await http.post(
          Uri.parse(cartesiaApiUrl),
          headers: {
            "Cartesia-Version": "2024-06-10",
            "X-API-Key": "sk_car_VNUsNAN5a0E_XNUt0tJFp", // Your API key
            "Content-Type": "application/json",
          },
          body: jsonEncode({
            "model_id":
                "sonic", // You can use "sonic" or the appropriate model ID
            "transcript": modalTextOutput, // Use Modal's response as transcript
            "voice": {
              "mode": "id",
              "id": "694f9389-aac1-45b6-b726-9d9369183238", // Voice ID
            },
            "output_format": {
              "container": "wav", // Specify WAV format for compatibility
              "encoding": "pcm_s16le", // Use appropriate encoding
              "sample_rate": 44100, // Sample rate for high-quality audio
            },
            "language": "en",
          }),
        );

        if (cartesiaResponse.statusCode == 200) {
          // Handling audio response (PCM data)
          final audioBytes = Uint8List.fromList(cartesiaResponse.bodyBytes);
          await _playAudio(audioBytes);
        } else {
          setState(() {
            _responseText = "Error in TTS API: ${cartesiaResponse.statusCode}";
          });
        }
      } else {
        setState(() {
          _responseText = "Error in LLM API: ${modalResponse.statusCode}";
        });
      }
    } catch (e) {
      setState(() {
        _responseText = "Failed to connect to API.";
      });
    }
  }

  Future<void> addGoogleTask(String taskTitle) async {
    try {
      await _checkAndRefreshToken();
      if (accessToken == null) {
        print('No access token available');
        return;
      }

      const String url = "https://tasks.googleapis.com/tasks/v1/lists/@default/tasks";
      Map<String, dynamic> taskData = {"title": taskTitle};

      final response = await http.post(
        Uri.parse(url),
        headers: {
          'Authorization': 'Bearer $accessToken',
          'Accept': 'application/json',
          'Content-Type': 'application/json',
        },
        body: jsonEncode(taskData),
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        print("Task added successfully: ${jsonDecode(response.body)}");
      } else {
        print("Failed to add task: ${response.statusCode}");
        print(response.body);
        if (response.statusCode == 401) {
          // Token expired, try to refresh
          await _checkAndRefreshToken();
        }
      }
    } catch (e) {
      print('Error adding task: $e');
    }
  }

  Future<void> createGoogleCalendarEvent(
    String eventTitle, String date, String startDateTime, String endDateTime) async {
  
  const String url = "https://www.googleapis.com/calendar/v3/calendars/primary/events";

  // Construct event data
  const String timeZone = "America/New_York"; // Default to EST/EDT

  // Construct event data
  Map<String, dynamic> eventData = {
    "summary": eventTitle,
    "start": {
      "dateTime": startDateTime,
      "timeZone": timeZone,
    },
    "end": {
      "dateTime": endDateTime,
      "timeZone": timeZone,
    }
  };

  final response = await http.post(
    Uri.parse(url),
    headers: {
      'Authorization': 'Bearer $accessToken',
      'Accept': 'application/json',
      'Content-Type': 'application/json',
    },
    body: jsonEncode(eventData),
  );

  if (response.statusCode == 200 || response.statusCode == 201) {
    print("Event created successfully: ${jsonDecode(response.body)}");
  } else {
    print("Failed to create event: ${response.statusCode}");
    print(response.body);
  }
}

  Future<void> _playWelcomeMessage() async {
    String name = widget.displayName?.split(' ')[0] ?? 'there';
    String welcomeMessage = "Hello $name, how can I help?";
    
    try {
      final cartesiaResponse = await http.post(
        Uri.parse("https://api.cartesia.ai/tts/bytes"),
        headers: {
          "Cartesia-Version": "2024-06-10",
          "X-API-Key": "sk_car_VNUsNAN5a0E_XNUt0tJFp",
          "Content-Type": "application/json",
        },
        body: jsonEncode({
          "model_id": "sonic",
          "transcript": welcomeMessage,
          "voice": {
            "mode": "id",
            "id": "694f9389-aac1-45b6-b726-9d9369183238",
          },
          "output_format": {
            "container": "wav",
            "encoding": "pcm_s16le",
            "sample_rate": 44100,
          },
          "language": "en",
        }),
      );

      if (cartesiaResponse.statusCode == 200) {
        final audioBytes = Uint8List.fromList(cartesiaResponse.bodyBytes);
        await _playAudio(audioBytes);
      }
    } catch (e) {
      print('Error playing welcome message: $e');
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
              const Color(0xFFF8F9FA), // Lightest grey
              const Color(0xFFE9ECEF), // Light grey
              const Color(0xFFDEE2E6), // Medium grey
            ],
            stops: const [0.0, 0.3, 0.6, 1.0],
          ),
        ),
        child: Column(
          children: [
            SizedBox(height: MediaQuery.of(context).size.height * 0.05),
            Center(
              child: Text(
                _text,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w400,
                  letterSpacing: 0.5,
                  color: Color(0xFF495057), // Dark grey
                  height: 1.5,
                ),
              ),
            ),
            const SizedBox(height: 20),
            Center(
              child: Text(
                _responseText,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 16,
                  color: Color(0xFF6C757D), // Medium dark grey
                  fontWeight: FontWeight.w400,
                  letterSpacing: 0.3,
                ),
              ),
            ),
            const Spacer(),
            Padding(
              padding: const EdgeInsets.only(bottom: 30),
              child: AnimatedBuilder(
                animation: _animationController,
                builder: (context, child) {
                  return Transform.scale(
                    scale: _isPlaying ? _scaleAnimation.value : 1.0,
                    child: Transform.rotate(
                      angle: _isPlaying ? _rotationAnimation.value : 0,
                      child: Container(
                        width: 96, // Match FloatingActionButton.large size
                        height: 96,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: _isPlaying ? SweepGradient(
                            center: Alignment.center,
                            startAngle: 0,
                            endAngle: 2 * 3.14159,
                            colors: [
                              Colors.white,
                              const Color(0xFFF8F9FA),
                              const Color(0xFFE9ECEF),
                              const Color(0xFFDEE2E6),
                              Colors.white,
                            ],
                          ) : null,
                          color: _isListening ? const Color(0xFFE9ECEF) : Colors.white,
                          border: Border.all(
                            color: const Color(0xFF6C757D),
                            width: 1.5,
                          ),
                        ),
                        child: Material(
                          color: Colors.transparent,
                          child: InkWell(
                            customBorder: const CircleBorder(),
                            onTap: _listen,
                            child: Container(),
                          ),
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
            const Padding(
              padding: EdgeInsets.only(bottom: 20),
              child: Text(
                'Created by Caleb, Chris, and Ethan',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w400,
                  color: Color(0xFF6C757D),
                  letterSpacing: 0.3,
                  fontStyle: FontStyle.italic,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
