import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart' show debugPrint;
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'firebase_options.dart';

class FirebaseService {
  static final FirebaseService _instance = FirebaseService._internal();

  factory FirebaseService() {
    return _instance;
  }

  FirebaseService._internal();

  static final FirebaseAuth _auth = FirebaseAuth.instance;
  static final FirebaseDatabase _database = FirebaseDatabase.instance;

  // Initialize Firebase
  static Future<void> initialize() async {
    // check if options are still placeholders before attempting to initialize
    if (!_instance.isConfigured) {
      debugPrint(
        '⚠️ FirebaseService.initialize(): the FirebaseOptions look like the default placeholders.\n'
        'Authentication and database calls will be mocked until you provide real config.\n'
        'See FIREBASE_SETUP.md for instructions.',
      );
      return;
    }

    // Only initialize Firebase if we have real credentials
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );

    // Enable offline persistence for database when real config is present
    _database.setPersistenceEnabled(true);
  }

  // Auth Methods
  FirebaseAuth get auth => _auth;

  Future<UserCredential> signUp({
    required String email,
    required String password,
  }) async {
    try {
      if (!isConfigured) {
        throw Exception('Firebase not configured');
      }
      return await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );
    } on FirebaseAuthException catch (e) {
      throw _handleAuthException(e);
    }
  }

  Future<UserCredential> login({
    required String email,
    required String password,
  }) async {
    try {
      if (!isConfigured) {
        throw Exception('Firebase not configured');
      }
      return await _auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );
    } on FirebaseAuthException catch (e) {
      throw _handleAuthException(e);
    }
  }

  Future<void> logout() async {
    await _auth.signOut();
  }

  User? get currentUser {
    if (!isConfigured) {
      return null;
    }
    return _auth.currentUser;
  }

  /// `true` when the Firebase options appear to have been replaced with
  /// actual project values instead of the template placeholders or demo keys.
  /// For demo/development, returns false if using the demo key pattern.
  bool get isConfigured {
    final opts = DefaultFirebaseOptions.currentPlatform;
    // Demo mode if they still have YOUR_ placeholders or the demo key
    final hasDemoKey = opts.apiKey.contains('DemoKeyForTesting');
    final hasPlaceholders =
        opts.apiKey.startsWith('YOUR_') || opts.projectId.startsWith('YOUR_');
    return !(hasPlaceholders || hasDemoKey);
  }

  // Database Methods
  Future<void> saveAssignment({
    required String userId,
    required String assignmentId,
    required Map<String, dynamic> assignmentData,
  }) async {
    try {
      await _database
          .ref('users/$userId/assignments/$assignmentId')
          .set(assignmentData);
    } catch (e) {
      throw 'Failed to save assignment: $e';
    }
  }

  Future<List<Map<String, dynamic>>> getAssignments(String userId) async {
    try {
      final snapshot = await _database.ref('users/$userId/assignments').get();

      if (!snapshot.exists) {
        return [];
      }

      final List<Map<String, dynamic>> assignments = [];
      final data = snapshot.value as Map?;

      if (data != null) {
        data.forEach((key, value) {
          assignments.add({
            'id': key,
            ...Map<String, dynamic>.from(value as Map),
          });
        });
      }

      return assignments;
    } catch (e) {
      throw 'Failed to fetch assignments: $e';
    }
  }

  Future<void> updateAssignment({
    required String userId,
    required String assignmentId,
    required Map<String, dynamic> updates,
  }) async {
    try {
      await _database
          .ref('users/$userId/assignments/$assignmentId')
          .update(updates);
    } catch (e) {
      throw 'Failed to update assignment: $e';
    }
  }

  Future<void> deleteAssignment({
    required String userId,
    required String assignmentId,
  }) async {
    try {
      await _database.ref('users/$userId/assignments/$assignmentId').remove();
    } catch (e) {
      throw 'Failed to delete assignment: $e';
    }
  }

  // Stream for real-time assignment updates
  Stream<DatabaseEvent> getAssignmentsStream(String userId) {
    return _database.ref('users/$userId/assignments').onValue;
  }

  String _handleAuthException(FirebaseAuthException e) {
    switch (e.code) {
      case 'weak-password':
        return 'The password provided is too weak.';
      case 'email-already-in-use':
        return 'An account already exists with this email.';
      case 'invalid-email':
        return 'The email address is invalid.';
      case 'user-disabled':
        return 'This user account has been disabled.';
      case 'user-not-found':
        return 'No user found with this email.';
      case 'wrong-password':
        return 'Incorrect password.';
      default:
        return 'Authentication failed: ${e.message}';
    }
  }
}
