class _VoiceState extends State<Voice> with SingleTickerProviderStateMixin {
  late stt.SpeechToText _speech;
  bool _isListening = false;
  bool _isPlaying = false;
  String _text = "";
  String _responseText = "";
  double _confidence = 1.0;
  final AudioPlayer _audioPlayer = AudioPlayer();
  List<String> _conversationHistory = [];
  List<String> _userHistory = [];
  late AnimationController _animationController;
  bool _isInitialized = false;
  StreamSubscription? _playerStateSubscription;

  @override
  void initState() {
    super.initState();
    _initializeServices();
  }

  Future<void> _initializeServices() async {
    try {
      // Initialize speech recognition
      _speech = stt.SpeechToText();
      bool available = await _speech.initialize(
        onStatus: (val) => print('Speech recognition status: $val'),
        onError: (val) => print('Speech recognition error: $val'),
      );
      
      if (mounted) {
        setState(() {
          _isInitialized = available;
        });
      }
      
      // Initialize animation controller
      _animationController = AnimationController(
        vsync: this,
        duration: const Duration(seconds: 2),
      );
      
      // Initialize audio player state listener
      _playerStateSubscription = _audioPlayer.onPlayerStateChanged.listen((state) {
        if (mounted) {
          setState(() {
            _isPlaying = state == PlayerState.playing;
            if (_isPlaying) {
              _animationController.repeat();
            } else {
              _animationController.stop();
            }
          });
        }
      });
      
      print("Voice services initialized. Speech recognition available: $available");
    } catch (e) {
      print("Error initializing services: $e");
      if (mounted) {
        setState(() {
          _isInitialized = false;
        });
      }
    }
  }

  @override
  void dispose() {
    print("Disposing Voice widget");
    _cleanupResources();
    super.dispose();
  }

  Future<void> _cleanupResources() async {
    try {
      // Stop and cleanup speech recognition
      if (_speech.isListening) {
        await _speech.stop();
      }
      
      // Stop and cleanup audio player
      await _audioPlayer.stop();
      await _audioPlayer.dispose();
      
      // Cancel audio player subscription
      await _playerStateSubscription?.cancel();
      
      // Dispose animation controller
      _animationController.stop();
      _animationController.dispose();
      
      // Cleanup temp files
      await _cleanupTempFiles();
      
      print("Resources cleaned up successfully");
    } catch (e) {
      print("Error cleaning up resources: $e");
    }
  }

  Future<void> _cleanupTempFiles() async {
    try {
      final tempDir = await getTemporaryDirectory();
      final tempFile = File('${tempDir.path}/temp_audio.wav');
      if (await tempFile.exists()) {
        await tempFile.delete();
        print("Cleaned up temporary audio file");
      }
    } catch (e) {
      print("Error cleaning up temp files: $e");
    }
  }

  void _listen() async {
    if (!_isInitialized) {
      print("Reinitializing speech recognition");
      await _initializeServices();
    }

    if (!_isListening && _isInitialized) {
      try {
        setState(() {
          _isListening = true;
          _text = "";
        });
        print("Started listening");

        await _speech.listen(
          onResult: (val) {
            if (mounted) {
              setState(() {
                _text = val.recognizedWords;
                print("Recognized text: $_text");
                if (val.hasConfidenceRating && val.confidence > 0) {
                  _confidence = val.confidence;
                  print("Recognition confidence: $_confidence");
                }
              });
            }
          },
        );

        Future.delayed(const Duration(seconds: 8), () {
          if (_isListening && mounted) {
            print("Auto-stopping listening after 8 seconds");
            _stopListening();
          }
        });
      } catch (e) {
        print("Error starting speech recognition: $e");
        if (mounted) {
          setState(() {
            _isListening = false;
          });
        }
      }
    } else {
      _stopListening();
    }
  }

  void _stopListening() async {
    print("Stopping listening");
    try {
      if (mounted) {
        setState(() {
          _isListening = false;
        });
      }
      await _speech.stop();
      
      if (_text.isNotEmpty && mounted) {
        print("Making API call with text: $_text");
        await _makeApiCall();
      }
    } catch (e) {
      print("Error stopping speech recognition: $e");
    }
  }

  Future<void> _makeApiCall() async {
    const String modalApiUrl = "https://calebbuening--meta-llama-3-8b-instruct-web-dev.modal.run";
    const String cartesiaApiUrl = "https://api.cartesia.ai/tts/bytes";

    if (!mounted) return;

    try {
      // Prepare conversation history
      String userHistoryText = _userHistory.join('\n');
      String conversationHistoryText = _conversationHistory.join('\n');
      print("Making API call with conversation history: $conversationHistoryText");

      // Prepare prompt
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

      // Make Modal API call
      print("Sending request to Modal API");
      final modalResponse = await http.post(
        Uri.parse(modalApiUrl),
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({
          "prompts": [combinedText],
        }),
      ).timeout(
        const Duration(seconds: 30),
        onTimeout: () {
          throw TimeoutException('Modal API request timed out');
        },
      );

      print("Modal API response status: ${modalResponse.statusCode}");

      if (!mounted) return;

      if (modalResponse.statusCode == 200) {
        final List<dynamic> modalData = jsonDecode(modalResponse.body);
        String modalTextOutput = modalData.isNotEmpty ? modalData[0] : "No response received.";
        print("Modal API response text: $modalTextOutput");

        if (!mounted) return;

        setState(() {
          _responseText = modalTextOutput;
          _conversationHistory.add("User: $_text");
          _conversationHistory.add("AI: $_responseText");
        });

        // Make Cartesia API call
        print("Sending request to Cartesia API");
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
        ).timeout(
          const Duration(seconds: 30),
          onTimeout: () {
            throw TimeoutException('Cartesia API request timed out');
          },
        );

        print("Cartesia API response status: ${cartesiaResponse.statusCode}");

        if (!mounted) return;

        if (cartesiaResponse.statusCode == 200) {
          try {
            // Clean up any existing audio file and stop current playback
            await _cleanupTempFiles();
            await _audioPlayer.stop();
            
            // Get audio data
            final Uint8List audioBytes = cartesiaResponse.bodyBytes;
            if (audioBytes.isEmpty) {
              throw Exception('Received empty audio data');
            }
            print("Received audio bytes length: ${audioBytes.length}");
            
            // Save to temp file
            final tempDir = await getTemporaryDirectory();
            final tempFile = File('${tempDir.path}/temp_audio.wav');
            await tempFile.writeAsBytes(audioBytes);
            print("Audio file written to: ${tempFile.path}");
            
            if (!mounted) return;

            // Play audio with retry logic
            int retryCount = 0;
            const maxRetries = 3;
            
            while (retryCount < maxRetries) {
              try {
                await _audioPlayer.stop();
                await Future.delayed(const Duration(milliseconds: 200));
                if (!mounted) return;
                
                await _audioPlayer.play(DeviceFileSource(tempFile.path));
                print("Audio playback started from file: ${tempFile.path}");
                break;
              } catch (e) {
                retryCount++;
                print("Audio playback attempt $retryCount failed: $e");
                if (retryCount == maxRetries) {
                  throw e;
                }
                await Future.delayed(const Duration(seconds: 1));
              }
            }
          } catch (e, stackTrace) {
            print("Audio playback error: $e");
            print("Stack trace: $stackTrace");
            if (mounted) {
              setState(() {
                _responseText = "Audio playback error: $e";
              });
            }
          }
        } else {
          print("Cartesia API error: ${cartesiaResponse.statusCode}");
          if (mounted) {
            setState(() {
              _responseText = "Error in TTS API: ${cartesiaResponse.statusCode}";
            });
          }
        }
      } else {
        print("Modal API error: ${modalResponse.statusCode}");
        if (mounted) {
          setState(() {
            _responseText = "Error in LLM API: ${modalResponse.statusCode}";
          });
        }
      }
    } catch (e, stackTrace) {
      print("API call error: $e");
      print("Stack trace: $stackTrace");
      if (mounted) {
        setState(() {
          _responseText = "Failed to connect to API: $e";
        });
      }
    }
  }
} 