class _SignInPageState extends State<SignInPage> {
  final GoogleSignIn _googleSignIn = GoogleSignIn(
    scopes: ['https://www.googleapis.com/auth/tasks'],
  );

  bool _isSigningIn = false;

  Future<void> _handleSignIn() async {
    try {
      setState(() {
        _isSigningIn = true;
      });

      final GoogleSignInAccount? googleUser = await _googleSignIn.signIn();
      if (googleUser == null) {
        setState(() {
          _isSigningIn = false;
        });
        return; // User canceled sign-in
      }

      final GoogleSignInAuthentication googleAuth = await googleUser.authentication;
      final auth.AuthClient client = auth.authenticatedClient(
        http.Client(),
        auth.AccessCredentials(
          auth.AccessToken(
            'Bearer',
            googleAuth.accessToken!,
            DateTime.now().toUtc().add(const Duration(hours: 1)), // Token expiry
          ),
          googleAuth.idToken,
          ['https://www.googleapis.com/auth/tasks'],
        ),
      );

      print("Signed in as: ${googleUser.displayName}");
      setState(() {
        _isSigningIn = false;
      });

      // Navigate to next screen or perform actions after sign-in

    } catch (error) {
      print("Sign-in error: $error");
      setState(() {
        _isSigningIn = false;
      });
      // Show error to user
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Sign-in failed. Please try again.'),
          duration: Duration(seconds: 3),
        ),
      );
    }
  }
} 