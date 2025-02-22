import 'package:google_sign_in/google_sign_in.dart';

class Google {
  // Create a GoogleSignIn instance
  final GoogleSignIn _googleSignIn = GoogleSignIn(scopes: ['email']);

  // Sign-in method
  Future<GoogleSignInAccount?> signIn() async {
    try {
      // Trigger the Google Sign-In flow
      final GoogleSignInAccount? googleUser = await _googleSignIn.signIn();
      if (googleUser == null) {
        // User canceled the sign-in
        return null;
      }

      // Return the signed-in user
      return googleUser;
    } catch (e) {
      print("Error during Google sign-in: $e");
      return null;
    }
  }

  // Sign-out method
  Future<void> signOut() async {
    await _googleSignIn.signOut();
    print("User signed out");
  }

  // Get the Google authentication tokens
  Future<Map<String, String>?> getAuthTokens(GoogleSignInAccount? googleUser) async {
    if (googleUser == null) {
      return null;
    }

    try {
      final GoogleSignInAuthentication googleAuth = await googleUser.authentication;
      return {
        'accessToken': googleAuth.accessToken ?? '',
        'idToken': googleAuth.idToken ?? '',
      };
    } catch (e) {
      print("Error getting auth tokens: $e");
      return null;
    }
  }

  // Check if the user is already signed in
  Future<bool> isSignedIn() async {
    return await _googleSignIn.isSignedIn();
  }

  // Get current signed-in user
  Future<GoogleSignInAccount?> getCurrentUser() async {
    return await _googleSignIn.currentUser;
  }
}
