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
import 'package:intl/intl.dart';

bool count = false;
const String CARTESIA_API_KEY = "sk_car_m6xIVM_v-FRktrq_tI1vF";
const String cartesiaApiUrl = "https://api.cartesia.ai/tts/bytes";

class Voice extends StatefulWidget {
  final String? displayName;
  const Voice({super.key, this.displayName});

  @override
  _VoiceState createState() => _VoiceState();
}

class _VoiceState extends State<Voice>
    with WidgetsBindingObserver, SingleTickerProviderStateMixin {
  late stt.SpeechToText _speech;
  bool _isListening = false;
  bool _isPlaying = false;
  late AnimationController _animationController;
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
      'https://www.googleapis.com/auth/tasks.readonly',
    ],
  );
  String _currentWeather = "Weather information unavailable";
  String _dateAndWeather = "";

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 3000),
    );
    _rotationAnimation = Tween<double>(begin: 0, end: 2 * 3.14159).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.linear),
    );

    // Initialize all resources before playing welcome message
    _initializeAndWelcome();
  }

  Future<void> _initializeAndWelcome() async {
    try {
      // Initialize audio player first
      _audioPlayer = AudioPlayer();
      await _audioPlayer?.setVolume(1.0);
      
      // Initialize other resources
      await _initResources();
      await _checkAndRefreshToken();
      await _initWeather();
      
      // Get date and weather once during initialization
      _dateAndWeather = await _getDateAndWeather();
      
      // Ensure temp directory is initialized
      if (_tempDir == null) {
        _tempDir = await getTemporaryDirectory();
      }
      
      // Play welcome message after all initialization is complete
      if (!mounted) return; // Check if widget is still mounted
      await _playWelcomeMessage();
    } catch (e) {
      print('Error in initialization: $e');
      // If there's an error, still try to play welcome message
      if (mounted) {
        await _playWelcomeMessage();
      }
    }
  }

  Future<void> _initResources() async {
    _speech = stt.SpeechToText();
    if (_tempDir == null) {
      _tempDir = await getTemporaryDirectory();
    }
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
        await _audioPlayer?.setVolume(1.0);
      }

      setState(() {
        _isPlaying = true;
      });

      // Start the animation
      _animationController.repeat();

      // Create a temporary file with a unique name
      final tempFile = File(
        '${_tempDir!.path}/temp_audio_${DateTime.now().millisecondsSinceEpoch}.wav',
      );
      await tempFile.writeAsBytes(audioBytes);

      // Play the audio and wait for completion
      await _audioPlayer?.setFilePath(tempFile.path);
      await _audioPlayer?.play();

      // Wait for the audio to complete playing
      await for (final state in _audioPlayer!.playerStateStream) {
        if (state.processingState == ProcessingState.completed) {
          break;
        }
      }

      // Stop the animation
      _animationController.stop();

      // Cleanup
      await tempFile.delete().catchError((error) {
        print('Error deleting temporary file: $error');
      });

      if (!mounted) return;

      setState(() {
        _isPlaying = false;
      });

      // Start listening after audio is fully complete
      if (mounted) {
        _listen();
      }
    } catch (e) {
      print('Error playing audio: $e');
      setState(() {
        _isPlaying = false;
      });
      _animationController.stop();
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
          _responseText = ""; // Clear response text while listening
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

  Future<void> _handleLogout() async {
    try {
      await _googleSignIn.signOut();
      accessToken = null;
      Navigator.of(context).pushReplacementNamed('/');
    } catch (e) {
      print('Error during logout: $e');
    }
  }

  Future<void> _initWeather() async {
    try {
      // West Lafayette coordinates
      const double latitude = 40.4237;
      const double longitude = -86.9212;
      
      final response = await http.get(
        Uri.parse('https://api.open-meteo.com/v1/forecast?latitude=$latitude&longitude=$longitude&current=temperature_2m,weather_code'),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final current = data['current'];
        final temp = current['temperature_2m'];
        final weatherCode = current['weather_code'];
        
        // Convert weather code to description
        final String weatherDesc = _getWeatherDescription(weatherCode);
        
        setState(() {
          _currentWeather = "$weatherDesc, temperature: ${temp.round()}°C";
        });
      } else {
        throw Exception('Failed to load weather');
      }
    } catch (e) {
      print('Error getting weather: $e');
      setState(() {
        _currentWeather = "Weather information unavailable";
      });
    }
  }

  String _getWeatherDescription(int code) {
    // WMO Weather interpretation codes (https://open-meteo.com/en/docs)
    switch (code) {
      case 0:
        return "Clear sky";
      case 1:
        return "Mainly clear";
      case 2:
        return "Partly cloudy";
      case 3:
        return "Overcast";
      case 45:
      case 48:
        return "Foggy";
      case 51:
      case 53:
      case 55:
        return "Drizzle";
      case 61:
      case 63:
      case 65:
        return "Rain";
      case 71:
      case 73:
      case 75:
        return "Snow";
      case 77:
        return "Snow grains";
      case 80:
      case 81:
      case 82:
        return "Rain showers";
      case 85:
      case 86:
        return "Snow showers";
      case 95:
        return "Thunderstorm";
      case 96:
      case 99:
        return "Thunderstorm with hail";
      default:
        return "Unknown weather";
    }
  }

  Future<String> _getDateAndWeather() async {
    String formattedDate = DateFormat('EEEE, MMMM d, y').format(DateTime.now());
    return "Today is $formattedDate. The weather is $_currentWeather.\n\n";
  }

  Future<void> _makeApiCall() async {
    const String modalApiUrl =
        "https://calebbuening--meta-llama-3-8b-instruct-web-dev.modal.run";

    try {
      String userMessage = _text;
      // Use stored date and weather instead of getting it again
      String combinedText = "Your name is Nova and you are a voice-to-voice AI personal assistant. Your job is \n"
          "to answer the user's questions. Don't give incredibly length answers.\n"
          "Be to the point and provide all information necessary/requested.\n\n"
          "$_dateAndWeather"
          "What's special about you is that you have the ability to call certain functions. These functions\n"
          "will be called when you output this exact format, : ?FUNCTION FUNCTION_NAME ARG1\n"
          "It should be the ONLY thing you output, no other text or content, just the function call as described above including the question mark at the beginning of your response.\n"
          "Ask clarifying questions if you don't have enough info to call a function, but don't ask too many. Ask for confirmation before booking things that cost money.\n"
          "Here is a list of the exact functions available to you, do not create your own functions:\n"
          "`?FUNCTION TODO CREATE \"name of the to do\" - create a to do for the user's personal to-do list with a string title. The to do list is part of another organization app the user uses.\n"
          "`?FUNCTION TODO READ` - Get all to dos in the user's personal to-do list. This information will be passed to you as another prompt, so wait to do anything else until receiving the results of this call\n"
          "`?FUNCTION CAL READ` - read all user calendar events\n"
          "`?FUNCTION CAL CREATE \"title/summary\" MM/DD/YYYY start_time end_time` - create a calendar event on a certain day with a start and end time, plus title it. (QUOTES NEEDED TO SET TITLE APART)\n"
          "`?FUNCTION LOGOUT` - log the user out of their Google account and return to the sign-in screen\n"
          "`?FUNCTION BOOK_UBER \"pickup_location\" \"dropoff_location\" \"car_type\"` - Book an Uber ride (sandbox mode) with specified pickup and dropoff locations, and car type (UberX, Black, etc)\n"
          "`?FUNCTION BOOK_AIRBNB \"location\" \"check_in_date\" \"check_out_date\" \"guests\"` - Book an Airbnb stay (sandbox mode) with location, dates, and number of guests\n"
          "`?FUNCTION BOOK_FLIGHT \"from\" \"to\" \"departure_date\" \"return_date\" \"passengers\"` - Book a flight (sandbox mode) with departure and arrival cities, dates, and number of passengers\n\n"
          "Below, as the current conversation with the user begins, the transcript will be included as context for you\n"
          "below:\n\n"
          "Current conversation transcript: \n"
          "${_conversationHistory.join('\n')}\n"
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
            _text = modalTextOutput;
            _conversationHistory.add("User: $userMessage");
            _conversationHistory.add("AI: $_responseText");
          }
        });

        // Handle LOGOUT function
        if (modalTextOutput.contains("?FUNCTION LOGOUT")) {
          setState(() {
            _responseText = "Logging you out. Goodbye!";
            _text = "Logging you out. Goodbye!";
            _conversationHistory.add("User: $userMessage");
            _conversationHistory.add("AI: $_responseText");
          });

          // Play goodbye message
          final cartesiaResponse = await http.post(
            Uri.parse(cartesiaApiUrl),
            headers: {
              "Cartesia-Version": "2024-06-10",
              "X-API-Key": CARTESIA_API_KEY,
              "Content-Type": "application/json",
            },
            body: jsonEncode({
              "model_id": "sonic",
              "transcript": "Logging you out. Goodbye!",
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
            // Wait for audio to finish before logging out
            await Future.delayed(const Duration(seconds: 2));
            await _handleLogout();
            return;
          }
        }

        // Handle BOOK_UBER function
        if (modalTextOutput.contains("?FUNCTION BOOK_UBER")) {
          List<String> parts = modalTextOutput.split('"');
          if (parts.length < 6)
            throw ArgumentError(
              "Invalid format: Missing required arguments for Uber booking.",
            );

          String pickupLocation = parts[1].trim();
          String dropoffLocation = parts[3].trim();
          String carType = parts[5].trim();

          // Here you would implement the actual Uber API call
          // For now, we'll simulate a successful booking
          setState(() {
            _responseText =
                "I've booked an $carType from $pickupLocation to $dropoffLocation. Your driver will arrive in approximately 5 minutes.";
            _text =
                _responseText; // Show Uber booking confirmation in the text display
          });

          // Play the booking confirmation
          final cartesiaResponse = await http.post(
            Uri.parse(cartesiaApiUrl),
            headers: {
              "Cartesia-Version": "2024-06-10",
              "X-API-Key": CARTESIA_API_KEY,
              "Content-Type": "application/json",
            },
            body: jsonEncode({
              "model_id": "sonic",
              "transcript": _responseText,
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
            return;
          }
        }

        // Handle BOOK_AIRBNB function
        if (modalTextOutput.contains("?FUNCTION BOOK_AIRBNB")) {
          List<String> parts = modalTextOutput.split('"');
          if (parts.length < 8)
            throw ArgumentError(
              "Invalid format: Missing required arguments for Airbnb booking.",
            );

          String location = parts[1].trim();
          String checkIn = parts[3].trim();
          String checkOut = parts[5].trim();
          String guests = parts[7].trim();

          // Here you would implement the actual Airbnb API call
          // For now, we'll simulate a successful booking
          setState(() {
            _responseText =
                "I've found and booked a great place in $location for $guests guests. Your stay is scheduled from $checkIn to $checkOut. I'll send the confirmation details to your email.";
            _text =
                _responseText; // Show Airbnb booking confirmation in the text display
          });

          // Play the booking confirmation
          final cartesiaResponse = await http.post(
            Uri.parse(cartesiaApiUrl),
            headers: {
              "Cartesia-Version": "2024-06-10",
              "X-API-Key": CARTESIA_API_KEY,
              "Content-Type": "application/json",
            },
            body: jsonEncode({
              "model_id": "sonic",
              "transcript": _responseText,
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
            return;
          }
        }

        // Handle BOOK_FLIGHT function
        if (modalTextOutput.contains("?FUNCTION BOOK_FLIGHT")) {
          List<String> parts = modalTextOutput.split('"');
          if (parts.length < 10)
            throw ArgumentError(
              "Invalid format: Missing required arguments for flight booking.",
            );

          String fromCity = parts[1].trim();
          String toCity = parts[3].trim();
          String departureDate = parts[5].trim();
          String returnDate = parts[7].trim();
          String passengers = parts[9].trim();

          // Here you would implement the actual Google Flights API call
          // For now, we'll simulate a successful booking
          setState(() {
            _responseText =
                "I've booked a round-trip flight for $passengers passenger(s) from $fromCity to $toCity. Departing on $departureDate and returning on $returnDate. The confirmation will be sent to your email.";
            _text =
                _responseText; // Show flight booking confirmation in the text display
          });

          // Play the booking confirmation
          final cartesiaResponse = await http.post(
            Uri.parse(cartesiaApiUrl),
            headers: {
              "Cartesia-Version": "2024-06-10",
              "X-API-Key": CARTESIA_API_KEY,
              "Content-Type": "application/json",
            },
            body: jsonEncode({
              "model_id": "sonic",
              "transcript": _responseText,
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
            return;
          }
        }

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
              _text =
                  modalTextOutputRead; // Show AI response in the text display
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
              _text = _responseText; // Show AI response in the text display
              _conversationHistory.add("AI: $_responseText");
              modalTextOutput = _responseText;
            });
          }
        }
        // Step 4: If response is "#TODO CREATE", make second API call
        if (modalTextOutput.contains("TODO CREATE")) {
          addGoogleTask(modalTextOutput.split('"')[1]);
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
              _text =
                  modalTextOutputRead; // Show AI response in the text display
              _conversationHistory.add("AI: $_responseText");
              modalTextOutput = _responseText;
            });
          }
        }

        if (modalTextOutput.contains("CAL CREATE")) {
          print("CAL CREATE\n");
          List<String> parts = modalTextOutput.split('"');
          if (parts.length < 2)
            throw ArgumentError("Invalid format: Missing title.");

          String title = parts[1].trim(); // Extracts "title name"
          List<String> eventParts = parts.last.trim().split(' ');

          if (eventParts.length < 3)
            throw ArgumentError("Invalid format: Missing date/time.");

          // Extract Date and Time
          String date = eventParts[0]; // MM/DD/YYYY
          String startTime = eventParts[1]; // HH:MM
          String endTime = eventParts[2]; // HH:MM

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
          DateTime startDateTime = DateTime(
            year,
            month,
            day,
            startHour,
            startMinute,
          );
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
              _text =
                  modalTextOutputRead; // Show AI response in the text display
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
            "X-API-Key": CARTESIA_API_KEY,
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

      const String url =
          "https://tasks.googleapis.com/tasks/v1/lists/@default/tasks";
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
    String eventTitle,
    String date,
    String startDateTime,
    String endDateTime,
  ) async {
    const String url =
        "https://www.googleapis.com/calendar/v3/calendars/primary/events";

    // Construct event data
    const String timeZone = "America/New_York"; // Default to EST/EDT

    // Construct event data
    Map<String, dynamic> eventData = {
      "summary": eventTitle,
      "start": {"dateTime": startDateTime, "timeZone": timeZone},
      "end": {"dateTime": endDateTime, "timeZone": timeZone},
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
    String welcomeMessage = "Hello $name, I'm Nova! How can I help you today?";

    try {
      // Ensure audio player is initialized
      if (_audioPlayer == null) {
        _audioPlayer = AudioPlayer();
        await _audioPlayer?.setVolume(1.0);
      }

      // Ensure temp directory is initialized
      if (_tempDir == null) {
        _tempDir = await getTemporaryDirectory();
      }

      setState(() {
        _text = welcomeMessage;
        if (_isListening) {
          _isListening = false;
          _speech.stop();
        }
      });

      final cartesiaResponse = await http.post(
        Uri.parse(cartesiaApiUrl),
        headers: {
          "Cartesia-Version": "2024-06-10",
          "X-API-Key": CARTESIA_API_KEY,
          "Content-Type": "application/json",
        },
        body: jsonEncode({
          "model_id": "sonic",
          "transcript": welcomeMessage,
          "voice": {"mode": "id", "id": "694f9389-aac1-45b6-b726-9d9369183238"},
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
      } else {
        print('Error from Cartesia API: ${cartesiaResponse.statusCode}');
        throw Exception('Failed to get audio from Cartesia');
      }
    } catch (e) {
      print('Error playing welcome message: $e');
      setState(() {
        _isPlaying = false;
      });
      // If welcome message fails, start listening anyway
      if (mounted) {
        _listen();
      }
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
          child: Image.asset(
            'assets/icon/nova_logo_white_big.png',
            width: 300,
            height: 300,
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
              const Color(0xFFF8F9FA),
              const Color(0xFFE9ECEF),
              const Color(0xFFDEE2E6),
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
                  color: Color(0xFF495057),
                  height: 1.5,
                ),
              ),
            ),
            const Spacer(),
            Padding(
              padding: const EdgeInsets.only(bottom: 30),
              child: AnimatedBuilder(
                animation: _animationController,
                builder: (context, child) {
                  return Transform.rotate(
                    angle: _isPlaying ? _rotationAnimation.value : 0,
                    child: Container(
                      width: 96,
                      height: 96,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: _isPlaying
                            ? SweepGradient(
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
                              )
                            : null,
                        color: _isListening
                            ? const Color(0xFFE9ECEF)
                            : Colors.white,
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
