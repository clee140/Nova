# Nova - The AI Assistant We Deserve

Siri is stupid. ChatGPT is sandboxed. Nova, on the other hand, is the perfect AI Assistant. Filling the gap between stupidity and incompetence, Nova embodies the pinnacle of the opposites. The idea is to bring the power of a truly intelligent personal assistant to the common man.

🚀 # What It Does

Nova leverages LLM technology to interact with APIs and execute various tasks without requiring users to say exact phrases to trigger incredibly specific actions. Examples of its capabilities include:

Calendar event creation 📅

Task management ✅

Seamless voice interaction 🎙️

🛠️ How We Built It

Nova consists of multiple integrated technologies to create a smooth and intelligent user experience:

Flutter App (iOS & Android): Users interact with Nova via a mobile app built with Flutter.

Google Authentication: Secure user login is handled via Google Auth.

Voice-to-Text (Flutter Plugin): Converts spoken input into text.

Llama-8B on Modal: Processes the input and generates intelligent responses.

Function Execution: Nova intelligently parses and executes function calls for API interactions.

Cartesia for TTS: Converts AI-generated text into Nova’s voice.

Audio Streaming: The generated audio response is streamed back to the user via a temporary file.

⚠️ Challenges We Faced

API Interactions: APIs were significantly harder to integrate than anticipated, leading to various roadblocks that required creative solutions.

Llama-8B Optimization: The model isn't always the brightest and requires occasional prompt engineering to stay on track.

🏗️ Technologies Used

Flutter (Mobile App - iOS & Android)

Google Firebase (Authentication)

Llama-8B (LLM-powered AI running on Modal)

Cartesia (Text-to-Speech Engine)

Audio Streaming (Efficient voice response delivery)

Nova is a step toward making AI-powered personal assistants truly intelligent and useful.
