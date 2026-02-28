import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter/foundation.dart';

class FirebaseRestAuth {
  // Your Firebase Web API Key
  static const String apiKey = 'AIzaSyAaXhNSOTHu8Df26Q_ykLCx6KfmCZ6Khjc';

  // Firebase Auth REST API endpoints
  static const String signInUrl =
      'https://identitytoolkit.googleapis.com/v1/accounts:signInWithPassword';
  static const String signUpUrl =
      'https://identitytoolkit.googleapis.com/v1/accounts:signUp';

  /// Sign in with email and password using Firebase REST API
  static Future<Map<String, dynamic>> signIn({
    required String email,
    required String password,
  }) async {
    try {
      debugPrint('🔐 REST API: Attempting login for $email');

      final response = await http.post(
        Uri.parse('$signInUrl?key=$apiKey'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'email': email,
          'password': password,
          'returnSecureToken': true,
        }),
      );

      debugPrint('📡 REST API Response status: ${response.statusCode}');

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        debugPrint('✅ REST API: Login successful!');
        return {
          'success': true,
          'idToken': data['idToken'],
          'refreshToken': data['refreshToken'],
          'email': data['email'],
          'localId': data['localId'],
          'expiresIn': data['expiresIn'],
        };
      } else {
        final error = jsonDecode(response.body);
        final errorMessage = error['error']['message'] ?? 'Unknown error';
        debugPrint('❌ REST API Error: $errorMessage');
        return {'success': false, 'error': errorMessage};
      }
    } catch (e) {
      debugPrint('❌ REST API Exception: $e');
      return {'success': false, 'error': e.toString()};
    }
  }

  /// Sign up with email and password using Firebase REST API
  static Future<Map<String, dynamic>> signUp({
    required String email,
    required String password,
  }) async {
    try {
      debugPrint('📝 REST API: Creating account for $email');

      final response = await http.post(
        Uri.parse('$signUpUrl?key=$apiKey'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'email': email,
          'password': password,
          'returnSecureToken': true,
        }),
      );

      debugPrint('📡 REST API Response status: ${response.statusCode}');

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        debugPrint('✅ REST API: Account created!');
        return {
          'success': true,
          'idToken': data['idToken'],
          'refreshToken': data['refreshToken'],
          'email': data['email'],
          'localId': data['localId'],
          'expiresIn': data['expiresIn'],
        };
      } else {
        final error = jsonDecode(response.body);
        final errorMessage = error['error']['message'] ?? 'Unknown error';
        debugPrint('❌ REST API Error: $errorMessage');
        return {'success': false, 'error': errorMessage};
      }
    } catch (e) {
      debugPrint('❌ REST API Exception: $e');
      return {'success': false, 'error': e.toString()};
    }
  }
}
