import 'dart:convert';
import 'dart:typed_data'; // For handling audio data
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:speech_to_text/speech_to_text.dart' as stt;
import 'package:just_audio/just_audio.dart';

class Voice extends StatefulWidget {
  const Voice({super.key});

  @override
  _VoiceState createState() => _VoiceState();
}

class _VoiceState extends State<Voice> {
  late stt.SpeechToText _speech;
  bool _isListening = false;
  String _text = "Press the microphone button to start speaking";
  String _responseText = "AI response will appear here"; // Stores API response
  double _confidence = 1.0;
  final AudioPlayer _audioPlayer = AudioPlayer(); // Audio player instance
  List<String> _conversationHistory = []; // To store AI responses
  List<String> _userHistory = [];

  @override
  void initState() {
    super.initState();
    _speech = stt.SpeechToText();
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
        "https://calebbuening--meta-llama-3-8b-instruct-web-dev.modal.run"; // Modal LLM endpoint
    const String cartesiaApiUrl =
        "https://api.cartesia.ai/tts/bytes"; // Cartesia TTS endpoint

    try {
      String userHistoryText = _userHistory.join(
        '\n',
      ); // Convert _userHistory to string
      String conversationHistoryText = _conversationHistory.join(
        '\n',
      ); // Convert _conversationHistory to string

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

      // "Use the conversation below to help answer the user prompt and do not make response longer than necessary.\n";
      // "$conversationHistoryText\n";

      print(combinedText);

      // Step 3: Add the new text to the user history
      // Add the current user prompt to history
      final modalResponse = await http.post(
        Uri.parse(modalApiUrl),
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({
          "prompts": [
            combinedText,
          ], // Send recognized speech as prompt to Modal
        }),
      );

      if (modalResponse.statusCode == 200) {
        final List<dynamic> modalData = jsonDecode(
          modalResponse.body,
        ); // Parse the response

        String modalTextOutput =
            modalData.isNotEmpty
                ? modalData[0]
                : "No response received."; // Extract first element

        setState(() {
          _responseText = modalTextOutput; // Display Modal's response
          // Add AI response to the conversation history
          _conversationHistory.add("User: $_text");
          _conversationHistory.add("AI: $_responseText");
        });

        // Step 2: Send Modal's output to Cartesia API for TTS
        final cartesiaResponse = await http.post(
          Uri.parse(cartesiaApiUrl),
          headers: {
            "Cartesia-Version": "2024-06-10",
            "X-API-Key": "sk_car_P9bFt1kAzKenZV_fMgVve", // Your API key
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

          // Create a temporary URL for the audio data
          final audioSource = AudioSource.uri(
            Uri.dataFromBytes(
              audioBytes,
              mimeType: 'audio/wav', // Use the appropriate mime type
            ),
          );

          final player = AudioPlayer();

          // Load and play the audio
          await player.setAudioSource(audioSource).then((_) {
            player.play();
          });

          setState(() {
            _responseText = "Audio playing!";
          });
          print("Audio is playing!");
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Luna',
          style: TextStyle(
            fontSize: 32,
            fontWeight: FontWeight.w500,
            letterSpacing: 1.0,
            fontStyle: FontStyle.italic,
            color: Colors.black,
            fontFamily: 'serif',
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
              Colors.white,
              Colors.grey[200]!,
              Colors.grey[300]!,
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
                Expanded(
                  child: ListView.builder(
                    itemCount: _conversationHistory.length,
                    itemBuilder: (context, index) {
                      return ListTile(
                        title: Text(
                          _conversationHistory[index],
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w400,
                            color: _conversationHistory[index].startsWith('User:') 
                              ? Colors.black87 
                              : Colors.black87,
                            height: 1.5,
                            letterSpacing: 0.3,
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
            Positioned(
              bottom: 30,
              left: 0,
              right: 0,
              child: Center(
                child: FloatingActionButton.large(
                  onPressed: _listen,
                  backgroundColor: Colors.transparent,
                  elevation: 0.5,
                  shape: const CircleBorder(),
                  child: Container(
                    width: 105,
                    height: 105,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: _isListening 
                        ? null
                        : LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: [Colors.white, Colors.grey[200]!],
                          ),
                      color: _isListening ? Colors.black : null,
                      border: Border.all(
                        color: _isListening ? Colors.white : Colors.black,
                        width: 3.5,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
