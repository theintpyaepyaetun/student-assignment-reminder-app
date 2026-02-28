import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Local authentication service that works offline
/// Perfect for development/testing without network dependency
class LocalAuthService {
  static const String _usersKey = 'app_users';
  static const String _currentUserKey = 'app_current_user';

  /// Sign up locally (stores credentials in SharedPreferences for demo)
  static Future<Map<String, dynamic>> signUp({
    required String email,
    required String password,
  }) async {
    try {
      debugPrint('📝 Local Auth: Creating account for $email');

      final prefs = await SharedPreferences.getInstance();
      final usersJson = prefs.getString(_usersKey) ?? '{}';
      final Map<String, dynamic> users = Map.from(
        (usersJson.isNotEmpty ? usersJson.split(',') : []).asMap(),
      );

      // Check if user already exists
      if (users.containsKey(email)) {
        debugPrint('❌ Local Auth: Email already registered');
        return {'success': false, 'error': 'Email already registered'};
      }

      // Store user (in real app, this would be hashed)
      users[email] = password;
      await prefs.setString(
        _usersKey,
        users.entries.map((e) => '${e.key}:${e.value}').join(','),
      );

      debugPrint('✅ Local Auth: Account created!');
      return {
        'success': true,
        'email': email,
        'idToken': 'local_token_$email',
        'localId': email.hashCode.toString(),
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
      final usersJson = prefs.getString(_usersKey) ?? '';

      if (usersJson.isEmpty) {
        debugPrint('❌ Local Auth: No users registered');
        return {
          'success': false,
          'error': 'User not found. Please register first.',
        };
      }

      // Parse users
      final usersList = usersJson.split(',');
      String? storedPassword;

      for (var userEntry in usersList) {
        if (userEntry.isNotEmpty && userEntry.contains(':')) {
          final parts = userEntry.split(':');
          if (parts[0] == email) {
            storedPassword = parts[1];
            break;
          }
        }
      }

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
      return {
        'success': true,
        'email': email,
        'idToken': 'local_token_$email',
        'localId': email.hashCode.toString(),
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
