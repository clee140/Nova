import 'dart:convert';
import 'dart:typed_data';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:speech_to_text/speech_to_text.dart' as stt;
import 'package:audioplayers/audioplayers.dart';
import 'package:path_provider/path_provider.dart';

class Voice extends StatefulWidget {
  const Voice({super.key});

  @override
  _VoiceState createState() => _VoiceState();
}

class _VoiceState extends State<Voice> with SingleTickerProviderStateMixin {
  late stt.SpeechToText _speech;
  bool _isListening = false;
  bool _isPlaying = false;
  String _text = "";  // Removed default text
  String _responseText = ""; // Removed default text
  double _confidence = 1.0;
  final AudioPlayer _audioPlayer = AudioPlayer();
  List<String> _conversationHistory = [];
  List<String> _userHistory = [];
  late AnimationController _animationController;

  @override
  void initState() {
    super.initState();
    _speech = stt.SpeechToText();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat();
    
    _audioPlayer.onPlayerStateChanged.listen((state) {
      setState(() {
        _isPlaying = state == PlayerState.playing;
        if (_isPlaying) {
          _animationController.repeat();
        } else {
          _animationController.stop();
        }
      });
    });
    
    print("Voice widget initialized"); // Added debug log
  }

  @override
  void dispose() {
    _animationController.dispose();
    _audioPlayer.dispose();
    super.dispose();
  }

  void _listen() async {
    if (!_isListening) {
      bool available = await _speech.initialize(
        onStatus: (val) => print('Speech recognition status: $val'),
        onError: (val) => print('Speech recognition error: $val'),
      );

      if (available) {
        setState(() {
          _isListening = true;
          _text = "";
        });
        print("Started listening"); // Added debug log

        _speech.listen(
          onResult: (val) => setState(() {
            _text = val.recognizedWords;
            print("Recognized text: $_text"); // Added debug log
            if (val.hasConfidenceRating && val.confidence > 0) {
              _confidence = val.confidence;
              print("Recognition confidence: $_confidence"); // Added debug log
            }
          }),
        );

        Future.delayed(const Duration(seconds: 8), () {
          if (_isListening) {
            print("Auto-stopping listening after 8 seconds"); // Added debug log
            _stopListening();
          }
        });
      } else {
        print("Speech recognition not available"); // Added debug log
      }
    } else {
      _stopListening();
    }
  }

  void _stopListening() {
    print("Stopping listening"); // Added debug log
    setState(() {
      _isListening = false;
      if (_text.isNotEmpty) {
        print("Making API call with text: $_text"); // Added debug log
        _makeApiCall();
      }
    });
    _speech.stop();
  }

  Future<void> _makeApiCall() async {
    const String modalApiUrl = "https://calebbuening--meta-llama-3-8b-instruct-web-dev.modal.run";
    const String cartesiaApiUrl = "https://api.cartesia.ai/tts/bytes";

    try {
      String userHistoryText = _userHistory.join('\n');
      String conversationHistoryText = _conversationHistory.join('\n');
      print("Conversation history: $conversationHistoryText"); // Added debug log

      // Step 2: Combine the history and current speech into a prompt
      String combinedText =
          "Your name is Luna and you are an AI personal assistant. Your job is \n"
          "to answer the user's questions. Don't give incredibly length answers.\n"
          "Be to the point and provide all information necessary/requested.\n\n"
          "Today is Sunday, February 22nd, 2025. The weather is Sunny and clear but cold.\n\n"
          "What's special about you is that you have the ability to call certain functions. These functions\n"
          "will be called when you output this exact format: #FUNCTION FUNCTION_NAME ARG1 ARG2 ...\n"
          "If there's a function in your result, we will execute the function and show you the results in the transcript. Otherwise we will treat your output as dialogue.\n"
          "#FUNCTION FUNCTION_NAME ARG1 ARG2 ...\n\n"
          "Here is a list of the exact APIs available to you:\n"
          "#FUNCTION TODO CREATE <name_of_the_todo> - create a todo with a string title\n"
          "#FUNCTION TODO READ - Get all todos. This information will be passed to you as another prompt, so wait to do anything else until receiving the results of this call\n"
          "#FUNCTION CAL READ - read all user calendar events\n"
          "#FUNCTION CAL WRITE day start_time end_time title - create a calendar event on a certain day with a start and end time, plus title it\n\n"
          "Below, as the current conversation with the user begins, the transcript will be included as context for you\n"
          "below:\n\n"
          "Current conversation transcript: \n"
          "$conversationHistoryText\n"
          "Here is the newest prompt from the user: $_text\n";

      print("Sending request to Modal API"); // Added debug log
      final modalResponse = await http.post(
        Uri.parse(modalApiUrl),
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({
          "prompts": [combinedText],
        }),
      );

      print("Modal API response status: ${modalResponse.statusCode}"); // Added debug log

      if (modalResponse.statusCode == 200) {
        final List<dynamic> modalData = jsonDecode(modalResponse.body);
        String modalTextOutput = modalData.isNotEmpty ? modalData[0] : "No response received.";
        print("Modal API response text: $modalTextOutput"); // Added debug log

        setState(() {
          _responseText = modalTextOutput;
          _conversationHistory.add("User: $_text");
          _conversationHistory.add("AI: $_responseText");
        });

        print("Sending request to Cartesia API"); // Added debug log
        final cartesiaResponse = await http.post(
          Uri.parse(cartesiaApiUrl),
          headers: {
            "Cartesia-Version": "2024-06-10",
            "X-API-Key": "sk_car_P9bFt1kAzKenZV_fMgVve",
            "Content-Type": "application/json",
          },
          body: jsonEncode({
            "model_id": "sonic",
            "transcript": modalTextOutput,
            "voice": {
              "mode": "id",
              "id": "694f9389-aac1-45b6-b726-9d9369183238",
            },
            "output_format": {
              "container": "wav",
              "encoding": "pcm_s16le",
              "sample_rate": 44100,
              "bit_depth": 16,
              "channels": 1
            },
            "language": "en",
          }),
        );

        print("Cartesia API response status: ${cartesiaResponse.statusCode}"); // Added debug log

        if (cartesiaResponse.statusCode == 200) {
          try {
            final Uint8List audioBytes = cartesiaResponse.bodyBytes;
            print("Received audio bytes length: ${audioBytes.length}"); // Added debug log
            
            final tempDir = await getTemporaryDirectory();
            final tempFile = File('${tempDir.path}/temp_audio.wav');
            
            await tempFile.writeAsBytes(audioBytes);
            print("Audio file written to: ${tempFile.path}"); // Added debug log
            
            await _audioPlayer.stop();
            await _audioPlayer.play(DeviceFileSource(tempFile.path));
            print("Audio playback started from file: ${tempFile.path}");

          } catch (e, stackTrace) {
            print("Audio playback error: $e"); // Added stack trace
            print("Stack trace: $stackTrace"); // Added stack trace
            setState(() {
              _responseText = "Audio playback error: $e";
            });
          }
        } else {
          print("Cartesia API error: ${cartesiaResponse.statusCode}"); // Added debug log
          setState(() {
            _responseText = "Error in TTS API: ${cartesiaResponse.statusCode}";
          });
        }
      } else {
        print("Modal API error: ${modalResponse.statusCode}"); // Added debug log
        setState(() {
          _responseText = "Error in LLM API: ${modalResponse.statusCode}";
        });
      }
    } catch (e, stackTrace) {
      print("API call error: $e"); // Added debug log
      print("Stack trace: $stackTrace"); // Added stack trace
      setState(() {
        _responseText = "Failed to connect to API.";
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Padding(
          padding: EdgeInsets.only(top: MediaQuery.of(context).size.height * 0.02),
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
              const Color(0xFFF8F9FA),  // Lightest grey
              const Color(0xFFE9ECEF),  // Light grey
              const Color(0xFFDEE2E6),  // Medium grey
            ],
            stops: const [0.0, 0.3, 0.6, 1.0],
          ),
        ),
        child: Stack(
          children: [
            Column(
              mainAxisAlignment: MainAxisAlignment.start,
              children: [
                SizedBox(height: MediaQuery.of(context).size.height * 0.17),
                Center(
                  child: Text(
                    _text,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w400,
                      letterSpacing: 0.5,
                      color: Colors.black87,
                      height: 1.5,
                    ),
                  ),
                ),
                const SizedBox(height: 40),
              ],
            ),
            Positioned(
              bottom: 135,  // Changed from 30 to 135 (30 + button diameter of 105)
              left: 0,
              right: 0,
              child: Center(
                child: AnimatedBuilder(
                  animation: _animationController,
                  builder: (context, child) {
                    return FloatingActionButton.large(
                      onPressed: _listen,
                      backgroundColor: Colors.transparent,
                      elevation: 0.5,
                      shape: const CircleBorder(),
                      child: Container(
                        width: 105,
                        height: 105,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: _isPlaying
                              ? SweepGradient(
                                  colors: const [
                                    Color(0xFF495057),  // Dark grey
                                    Color(0xFF6C757D),  // Medium dark grey
                                    Color(0xFFADB5BD),  // Medium grey
                                    Color(0xFFCED4DA),  // Light medium grey
                                    Color(0xFF495057),  // Back to dark grey
                                  ],
                                  stops: const [0.0, 0.25, 0.5, 0.75, 1.0],
                                  transform: GradientRotation(_animationController.value * 2 * 3.14159),
                                )
                              : _isListening
                                  ? LinearGradient(
                                      begin: Alignment.topLeft,
                                      end: Alignment.bottomRight,
                                      colors: [
                                        const Color(0xFF495057),  // Dark grey
                                        const Color(0xFF343A40),  // Darker grey
                                      ],
                                    )
                                  : LinearGradient(
                                      begin: Alignment.topLeft,
                                      end: Alignment.bottomRight,
                                      colors: [Colors.white, const Color(0xFFF8F9FA)],  // White to lightest grey
                                    ),
                          border: Border.all(
                            color: _isListening ? Colors.white : const Color(0xFF6C757D),  // White or medium dark grey
                            width: _isListening ? 2.5 : 2.0,
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
