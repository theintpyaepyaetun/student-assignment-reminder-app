import 'dart:convert';

import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart' show debugPrint;
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:http/http.dart' as http;
import '../firebase_options.dart';

class FirebaseService {
  static final FirebaseService _instance = FirebaseService._internal();

  factory FirebaseService() {
    return _instance;
  }

  FirebaseService._internal();

  static final FirebaseAuth _auth = FirebaseAuth.instance;
  static FirebaseDatabase? _database;
  static FirebaseFirestore? _firestore;

  // Get database instance lazily (only when needed)
  static FirebaseDatabase get database {
    _database ??= FirebaseDatabase.instance;
    return _database!;
  }

  // Get Firestore instance lazily (only when needed)
  static FirebaseFirestore get firestore {
    _firestore ??= FirebaseFirestore.instance;
    return _firestore!;
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

      debugPrint('✅ Firebase services ready');
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
      debugPrint('📝 Attempting Firebase sign up for: $email');
      final result = await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );
      debugPrint('✅ User created successfully: $email');
      return result;
    } on FirebaseAuthException catch (e) {
      debugPrint('❌ Sign up error [${e.code}]: ${e.message}');
      throw _handleAuthException(e);
    } on TypeError catch (e) {
      debugPrint('❌ Firebase plugin type error during sign up: $e');
      throw Exception(
        'Firebase plugin sync error detected. Please stop the app, run Flutter clean, rebuild, and try signing up again.',
      );
    } catch (e) {
      debugPrint('❌ Unexpected sign up error: $e');
      rethrow;
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
    } on TypeError catch (e) {
      debugPrint('❌ Firebase plugin type error during login: $e');
      throw Exception(
        'Firebase plugin sync error detected. Please stop the app, run Flutter clean, rebuild, and try logging in again.',
      );
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
  String userKeyFromEmail(String email) {
    final normalized = email.trim().toLowerCase();
    return base64Url.encode(utf8.encode(normalized)).replaceAll('=', '');
  }

  Future<void> saveUserProfile({
    required String userId,
    required String email,
    required String name,
    String source = 'firebase-auth',
  }) async {
    try {
      // Try SDK first
      await database.ref('users/$userId/profile').set({
        'email': email,
        'name': name,
        'source': source,
        'createdAt': DateTime.now().toIso8601String(),
      });
      debugPrint('✅ User profile saved to Firebase: $email');
    } catch (e) {
      debugPrint('⚠️  SDK write failed, trying REST API: $e');

      // Fallback to REST API
      try {
        final projectId = DefaultFirebaseOptions.currentPlatform.projectId;
        final url =
            'https://$projectId-default-rtdb.firebaseio.com/users/$userId/profile.json';

        final response = await http.put(
          Uri.parse(url),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({
            'email': email,
            'name': name,
            'source': source,
            'createdAt': DateTime.now().toIso8601String(),
          }),
        );

        if (response.statusCode == 200) {
          debugPrint('✅ User profile saved via REST API: $email');
        } else {
          debugPrint(
            '❌ REST API failed: ${response.statusCode} ${response.body}',
          );
          throw 'Failed to save user profile via REST API';
        }
      } catch (restError) {
        debugPrint('❌ Both SDK and REST failed: $restError');
        rethrow;
      }
    }
  }

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

  /// Add a new assignment to Firebase (creates new entry with auto ID)
  Future<void> addAssignment(
    String userId,
    Map<String, dynamic> assignmentData,
  ) async {
    try {
      // Add timestamp when assignment is created
      final dataWithTimestamp = {
        ...assignmentData,
        'createdAt': DateTime.now().toIso8601String(),
        'updatedAt': DateTime.now().toIso8601String(),
      };

      // Use push() to auto-generate a unique ID
      await database
          .ref('users/$userId/assignments')
          .push()
          .set(dataWithTimestamp);

      debugPrint('✅ Assignment added to Firebase for user: $userId');
    } catch (e) {
      debugPrint('❌ Error adding assignment: $e');
      throw 'Failed to add assignment: $e';
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
