import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import '../models/user_profile_model.dart';

class FirestoreService {
  static final FirestoreService _instance = FirestoreService._internal();
  factory FirestoreService() => _instance;
  FirestoreService._internal();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  // Reference to users collection
  CollectionReference get _usersCollection => _firestore.collection('users');

  // Get current user ID
  String? get currentUserId => _auth.currentUser?.uid;

  /// Create a new user document in Firestore when they sign up
  Future<void> createUserDocument({
    required String uid,
    required String email,
    required String username,
    String? photoUrl,
  }) async {
    try {
      final userProfile = UserProfile(
        uid: uid,
        email: email,
        username: username,
        photoUrl: photoUrl,
        preferences: {
          'theme': 'light',
          'notifications': true,
          'language': 'en',
        },
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      await _usersCollection.doc(uid).set(userProfile.toMap());
      debugPrint('✅ User document created in Firestore: $uid');
    } catch (e) {
      debugPrint('❌ Error creating user document: $e');
      rethrow;
    }
  }

  /// Get user profile by UID
  Future<UserProfile?> getUserProfile(String uid) async {
    try {
      final doc = await _usersCollection.doc(uid).get();
      if (doc.exists) {
        return UserProfile.fromFirestore(doc);
      }
      return null;
    } catch (e) {
      debugPrint('❌ Error getting user profile: $e');
      rethrow;
    }
  }

  /// Get current logged-in user's profile
  Future<UserProfile?> getCurrentUserProfile() async {
    if (currentUserId == null) return null;
    return getUserProfile(currentUserId!);
  }

  /// Update user profile
  Future<void> updateUserProfile({
    String? username,
    String? photoUrl,
    Map<String, dynamic>? preferences,
  }) async {
    if (currentUserId == null) {
      throw Exception('No user logged in');
    }

    try {
      final updates = <String, dynamic>{'updatedAt': Timestamp.now()};

      if (username != null) updates['username'] = username;
      if (photoUrl != null) updates['photoUrl'] = photoUrl;
      if (preferences != null) updates['preferences'] = preferences;

      await _usersCollection.doc(currentUserId).update(updates);
      debugPrint('✅ User profile updated: $currentUserId');
    } catch (e) {
      debugPrint('❌ Error updating user profile: $e');
      rethrow;
    }
  }

  /// Update specific preference
  Future<void> updatePreference(String key, dynamic value) async {
    if (currentUserId == null) {
      throw Exception('No user logged in');
    }

    try {
      await _usersCollection.doc(currentUserId).update({
        'preferences.$key': value,
        'updatedAt': Timestamp.now(),
      });
      debugPrint('✅ Preference updated: $key = $value');
    } catch (e) {
      debugPrint('❌ Error updating preference: $e');
      rethrow;
    }
  }

  /// Stream user profile changes (real-time updates)
  Stream<UserProfile?> streamUserProfile(String uid) {
    return _usersCollection.doc(uid).snapshots().map((snapshot) {
      if (snapshot.exists) {
        return UserProfile.fromFirestore(snapshot);
      }
      return null;
    });
  }

  /// Stream current user's profile
  Stream<UserProfile?> streamCurrentUserProfile() {
    if (currentUserId == null) {
      return Stream.value(null);
    }
    return streamUserProfile(currentUserId!);
  }

  /// Delete user document (use with caution)
  Future<void> deleteUserDocument(String uid) async {
    try {
      await _usersCollection.doc(uid).delete();
      debugPrint('✅ User document deleted: $uid');
    } catch (e) {
      debugPrint('❌ Error deleting user document: $e');
      rethrow;
    }
  }

  /// Check if user document exists
  Future<bool> userDocumentExists(String uid) async {
    try {
      final doc = await _usersCollection.doc(uid).get();
      return doc.exists;
    } catch (e) {
      debugPrint('❌ Error checking user document: $e');
      return false;
    }
  }
}
