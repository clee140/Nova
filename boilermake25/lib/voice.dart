import 'dart:convert';
import 'dart:typed_data'; // For handling audio data
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:speech_to_text/speech_to_text.dart' as stt;
import 'package:just_audio/just_audio.dart';
import 'main.dart';

bool count = false;

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
          "will be called when you output this exact format, without the backticks: #FUNCTION FUNCTION_NAME ARG1 ARG2 ...\n"
          "It should be the ONLY thing you output, no other text or content.\n"
          "If there's a function in your result, we will execute the function and show you the results in the transcript. Otherwise we will treat your output as dialogue.\n\n"
          "Here is a list of the exact APIs available to you:\n"
          "#FUNCTION TODO CREATE <name_of_the_todo> - create a todo with a string title\n"
          "#FUNCTION TODO READ - Get all to dos in to-do list. This information will be passed to you as another prompt, so wait to do anything else until receiving the results of this call\n"
          "#FUNCTION CAL READ - read all user calendar events\n"
          "#FUNCTION CAL WRITE day start_time end_time title - create a calendar event on a certain day with a start and end time, plus title it\n\n"
          "Do not use markdown for results, but only hashtags for functions\n"
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
          _responseText = modalTextOutput;
          _conversationHistory.add("User: $_text");
          _conversationHistory.add("AI: $_responseText");
        });

        // Step 4: If response is "#CAL READ", make second API call
        if (modalTextOutput == "#CAL READ") {
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
                    "making dates, times, and content clean and readable by a text-to-voice ai: $_text\n"
                    "Do not use markdown for results\n",
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
        if (modalTextOutput == "#TODO READ") {
          List<String> last10Tasks =
              globalTasks.length > 10
                  ? globalTasks.sublist(
                    globalTasks.length - 10,
                  )
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
                    "making descriptions, due dates, and content clean, readable, and alphanumeric only by a text-to-voice ai: $_text\n"
                    "Do not use markdown for results\n",
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
              _responseText = modalTextOutputReadTodo;
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
            "X-API-Key": "sk_car_uX0fyjZsROA65SDQeufjF", // Your API key
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
