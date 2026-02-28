import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Local authentication service that works offline
/// Perfect for development/testing without network dependency
class LocalAuthService {
  static const String _usersKey = 'app_users';
  static const String _currentUserKey = 'app_current_user';

  static Map<String, String> _parseLegacyUsers(String raw) {
    final users = <String, String>{};
    if (raw.isEmpty) return users;

    for (final entry in raw.split(',')) {
      if (entry.isEmpty || !entry.contains(':')) continue;
      final separatorIndex = entry.indexOf(':');
      final email = entry.substring(0, separatorIndex).trim();
      final password = entry.substring(separatorIndex + 1);
      if (email.isNotEmpty) {
        users[email] = password;
      }
    }

    return users;
  }

  static Map<String, String> _readUsers(String raw) {
    if (raw.isEmpty) return <String, String>{};

    try {
      final decoded = jsonDecode(raw);
      if (decoded is Map) {
        return decoded.map(
          (key, value) => MapEntry(key.toString(), value.toString()),
        );
      }
    } catch (_) {
      return _parseLegacyUsers(raw);
    }

    return _parseLegacyUsers(raw);
  }

  /// Sign up locally (stores credentials in SharedPreferences for demo)
  static Future<Map<String, dynamic>> signUp({
    required String email,
    required String password,
  }) async {
    try {
      debugPrint('📝 Local Auth: Creating account for $email');

      final prefs = await SharedPreferences.getInstance();
      final usersRaw = prefs.getString(_usersKey) ?? '';
      final users = _readUsers(usersRaw);

      // Check if user already exists
      if (users.containsKey(email)) {
        debugPrint('❌ Local Auth: Email already registered');
        return {'success': false, 'error': 'Email already registered'};
      }

      // Store user (in real app, this would be hashed)
      users[email] = password;
      await prefs.setString(_usersKey, jsonEncode(users));

      debugPrint('✅ Local Auth: Account created!');
      return <String, dynamic>{
        'success': true,
        'email': email,
        'idToken': 'local_token_$email',
        'localId': email.hashCode.abs().toString(),
      };
    } catch (e) {
      debugPrint('❌ Local Auth Exception: $e');
      return {'success': false, 'error': e.toString()};
    }
  }

  /// Sign in locally
  static Future<Map<String, dynamic>> signIn({
    required String email,
    required String password,
  }) async {
    try {
      debugPrint('🔐 Local Auth: Attempting login for $email');

      final prefs = await SharedPreferences.getInstance();
      final usersRaw = prefs.getString(_usersKey) ?? '';

      if (usersRaw.isEmpty) {
        debugPrint('❌ Local Auth: No users registered');
        return {
          'success': false,
          'error': 'User not found. Please register first.',
        };
      }

      final users = _readUsers(usersRaw);
      final storedPassword = users[email];

      if (storedPassword == null) {
        debugPrint('❌ Local Auth: User not found');
        return {'success': false, 'error': 'User not found'};
      }

      if (storedPassword != password) {
        debugPrint('❌ Local Auth: Wrong password');
        return {'success': false, 'error': 'Wrong password'};
      }

      // Store current user
      await prefs.setString(_currentUserKey, email);

      debugPrint('✅ Local Auth: Login successful!');
      return <String, dynamic>{
        'success': true,
        'email': email,
        'idToken': 'local_token_$email',
        'localId': email.hashCode.abs().toString(),
      };
    } catch (e) {
      debugPrint('❌ Local Auth Exception: $e');
      return {'success': false, 'error': e.toString()};
    }
  }

  /// Sign out locally
  static Future<void> signOut() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_currentUserKey);
      debugPrint('✅ Local Auth: Signed out');
    } catch (e) {
      debugPrint('❌ Local Auth Signout Error: $e');
    }
  }

  /// Get current user
  static Future<String?> getCurrentUser() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getString(_currentUserKey);
    } catch (e) {
      debugPrint('❌ Local Auth Get Current User Error: $e');
      return null;
    }
  }
}
