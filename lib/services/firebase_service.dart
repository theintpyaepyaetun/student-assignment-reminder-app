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
  static FirebaseDatabase? _database;

  // Get database instance lazily (only when needed)
  static FirebaseDatabase get database {
    _database ??= FirebaseDatabase.instance;
    return _database!;
  }

  // Initialize Firebase
  static Future<void> initialize() async {
    try {
      // Initialize Firebase with the platform-specific options
      await Firebase.initializeApp(
        options: DefaultFirebaseOptions.currentPlatform,
      );
      debugPrint('✅ Firebase initialized successfully');
      debugPrint('✅ Firebase Auth ready');
      debugPrint(
        '✅ Project: ${DefaultFirebaseOptions.currentPlatform.projectId}',
      );
    } catch (e) {
      debugPrint('❌ Firebase initialization error: $e');
      rethrow;
    }
  }

  // Auth Methods
  FirebaseAuth get auth => _auth;

  Future<UserCredential> signUp({
    required String email,
    required String password,
  }) async {
    try {
      debugPrint('📝 Creating new user: $email');
      final result = await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );
      debugPrint('✅ User created successfully: $email');
      return result;
    } on FirebaseAuthException catch (e) {
      debugPrint('❌ Sign up error [${e.code}]: ${e.message}');
      throw _handleAuthException(e);
    }
  }

  Future<UserCredential> login({
    required String email,
    required String password,
  }) async {
    try {
      debugPrint('🔐 Attempting Firebase login for: $email');
      final result = await _auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );
      debugPrint('✅ Login successful for: $email');
      return result;
    } on FirebaseAuthException catch (e) {
      debugPrint('❌ Firebase Auth Error [${e.code}]: ${e.message}');
      throw _handleAuthException(e);
    } catch (e) {
      debugPrint('❌ Unexpected error during login: $e');
      rethrow;
    }
  }

  Future<void> logout() async {
    await _auth.signOut();
  }

  User? get currentUser {
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
      await database
          .ref('users/$userId/assignments/$assignmentId')
          .set(assignmentData);
    } catch (e) {
      throw 'Failed to save assignment: $e';
    }
  }

  Future<List<Map<String, dynamic>>> getAssignments(String userId) async {
    try {
      final snapshot = await database.ref('users/$userId/assignments').get();

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
      await database
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
      await database.ref('users/$userId/assignments/$assignmentId').remove();
    } catch (e) {
      throw 'Failed to delete assignment: $e';
    }
  }

  // Stream for real-time assignment updates
  Stream<DatabaseEvent> getAssignmentsStream(String userId) {
    return database.ref('users/$userId/assignments').onValue;
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
