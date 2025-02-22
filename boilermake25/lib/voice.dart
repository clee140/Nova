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
          "You are an AI assistant and are currently having a conversation with a user\n"
          "Here is the prompt the user wants you to answer:\n"
          "$_text\n"
          "Use the conversation below to help answer the user prompt and do not make response longer than necessary.\n";
          "User conversation history:\n"
          "$userHistoryText\n"
          "Your conversation history:\n"
          "$conversationHistoryText\n";

      // Step 3: Add the new text to the user history
      _userHistory.add(_text); // Add the current user prompt to history
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
          _conversationHistory.add(_responseText);
        });

        // Step 2: Send Modal's output to Cartesia API for TTS
        final cartesiaResponse = await http.post(
          Uri.parse(cartesiaApiUrl),
          headers: {
            "Cartesia-Version": "2024-06-10",
            "X-API-Key": "sk_car_MDvTgDHL0dEsmapX4leKl", // Your API key
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
      appBar: AppBar(title: const Text('Assistant')),
      body: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Center(
            child: Image.asset(
              'assets/microphone.png',
              width: 150,
              height: 150,
              fit: BoxFit.contain,
            ),
          ),
          const SizedBox(height: 20),
          Center(
            child: Text(
              _text,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
          ),
          const SizedBox(height: 20),
          Center(
            child: Text(
              _responseText, // Display AI/Modal response
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 16, color: Colors.blue),
            ),
          ),
          const SizedBox(height: 20),
          // Display conversation history
          Expanded(
            child: ListView.builder(
              itemCount: _conversationHistory.length,
              itemBuilder: (context, index) {
                return ListTile(title: Text(_conversationHistory[index]));
              },
            ),
          ),
          const Spacer(),
          Padding(
            padding: const EdgeInsets.only(bottom: 30),
            child: FloatingActionButton.large(
              onPressed: _listen,
              backgroundColor:
                  _isListening ? Colors.greenAccent : Colors.amberAccent,
              child: Icon(_isListening ? Icons.mic : Icons.mic_none),
            ),
          ),
        ],
      ),
    );
  }
}
