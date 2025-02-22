import 'package:flutter/material.dart';
import 'package:auth0_flutter/auth0_flutter.dart';

class Auth0Service {
  final Auth0 auth0;

  Auth0Service()
      : auth0 = Auth0(
          'dev-62vsviavz05io4lc.us.auth0.com',  // Domain
          'IjpjTSHbQ1K0iyUA10yBIk55aZNDTajH',  // Client ID
        );
  Future<void> login() async {
    try {
      // Trigger login using the browser for OAuth2
      final result = await auth0.webAuthentication().login();

      if (result != null) {
        print('User authenticated! Access Token: ${result.accessToken}');
      }
    } catch (e) {
      print('Error during login: $e');
    }
  }

  Future<void> logout() async {
    await auth0.webAuthentication().logout();
    print('User logged out!');
  }
}

class HomePage extends StatelessWidget {
  final Auth0Service _auth0Service = Auth0Service();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Auth0 Example')),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            ElevatedButton(
              onPressed: () {
                _auth0Service.login();
              },
              child: Text('Login with Auth0'),
            ),
            ElevatedButton(
              onPressed: () {
                _auth0Service.logout();
              },
              child: Text('Logout'),
            ),
          ],
        ),
      ),
    );
  }
}
