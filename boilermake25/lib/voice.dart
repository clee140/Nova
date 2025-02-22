import 'package:flutter/material.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;

class Voice extends StatefulWidget {
  const Voice({super.key});

  @override
  _VoiceState createState() => _VoiceState();
}

class _VoiceState extends State<Voice> {
  late stt.SpeechToText _speech;
  bool _isListening = false;
  String _text = "Press the microphone button to start speaking";
  double _confidence = 1.0;

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

        // Auto-stop after a certain amount of silence or time
        Future.delayed(Duration(seconds: 10), () {
          if (_isListening) {
            setState(() {
              _isListening = false;
              _text = "Press the microphone button to start speaking";
            });
            _speech.stop();
          }
        });
      }
    } else {
      setState(() {
        _isListening = false;
        _text = "Press the microphone button to start speaking";
      });
      _speech.stop();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Assistant')),
      body: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // Image in the middle of the screen
          Center(
            child: Image.asset(
              'assets/microphone.png', // Change this to your image path
              width: 150, // Adjust size as needed
              height: 150,
              fit: BoxFit.contain,
            ),
          ),

          const SizedBox(height: 20), // Adds spacing between image and text

          Center(
            child: Text(
              _text,
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
          ),

          const SizedBox(
            height: 30,
          ), // Adds some spacing between text and button

          const Spacer(), // Pushes button to the bottom

          Padding(
            padding: const EdgeInsets.only(bottom: 30), // Adds bottom padding
            child: FloatingActionButton.large(
              onPressed:
                  _listen, // Start/stop listening when the button is pressed
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