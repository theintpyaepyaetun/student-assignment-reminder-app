import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:student_assignment_reminder_app/models/user_model.dart';
import 'package:student_assignment_reminder_app/models/user_profile_model.dart';
import 'package:student_assignment_reminder_app/services/assignment_notification_service.dart';
import 'package:student_assignment_reminder_app/services/firebase_service.dart';
import 'package:student_assignment_reminder_app/services/firebase_messaging_service.dart';
import 'package:student_assignment_reminder_app/services/firestore_service.dart';

class AuthState {
  final bool isAuthenticated;
  final User? user;
  final bool isLoading;
  final String? error;

  AuthState({
    this.isAuthenticated = false,
    this.user,
    this.isLoading = false,
    this.error,
  });

  AuthState copyWith({
    bool? isAuthenticated,
    User? user,
    bool? isLoading,
    String? error,
  }) {
    return AuthState(
      isAuthenticated: isAuthenticated ?? this.isAuthenticated,
      user: user ?? this.user,
      isLoading: isLoading ?? this.isLoading,
      error: error,
    );
  }
}

class AuthProvider extends ChangeNotifier {
  final FirebaseService _firebaseService = FirebaseService();
  final FirebaseMessagingService _firebaseMessagingService =
      FirebaseMessagingService();
  final FirestoreService _firestoreService = FirestoreService();
  AuthState _state = AuthState();

  AuthProvider() {
    // Don't call _checkAuthStatus() here - it blocks UI startup
    // Will be called when needed
  }

  AuthState get state => _state;
  bool get isAuthenticated => _state.isAuthenticated;
  User? get user => _state.user;
  bool get isLoading => _state.isLoading;
  String? get error => _state.error;

  bool get isDemoMode => !_firebaseService.isConfigured;

  // Initialize auth status asynchronously (called from LoginScreen)
  Future<void> initializeAuthStatus() async {
    if (_state.isAuthenticated || _state.isLoading) return;
    await _checkAuthStatus();
  }

  void _setState(AuthState newState) {
    _state = newState;
    notifyListeners();
  }

  Future<void> _ensureUserDocument({
    required String uid,
    required String email,
    required String username,
  }) async {
    final exists = await _firestoreService.userDocumentExists(uid);
    if (!exists) {
      await _firestoreService.createUserDocument(
        uid: uid,
        email: email,
        username: username,
      );
    }
  }

  Future<void> register({
    required String email,
    required String password,
    required String name,
  }) async {
    _setState(_state.copyWith(isLoading: true, error: null));
    try {
      final credential = await _firebaseService.signUp(
        email: email,
        password: password,
      );

      final firebaseUser = credential.user;
      if (firebaseUser == null) {
        throw Exception(
          'Registration succeeded but no authenticated user found',
        );
      }

      await _ensureUserDocument(
        uid: firebaseUser.uid,
        email: email,
        username: name,
      );

      _setState(
        _state.copyWith(
          isAuthenticated: true,
          user: User(
            email: email,
            name: name,
            createdAt: DateTime.now().toIso8601String(),
          ),
          isLoading: false,
          error: null,
        ),
      );

      await AssignmentNotificationService.instance
          .syncCurrentUserAssignmentReminders();
      await _firebaseMessagingService.syncTokenForCurrentUser();
    } catch (e) {
      _setState(_state.copyWith(isLoading: false, error: e.toString()));
    }
  }

  Future<void> login({required String email, required String password}) async {
    _setState(_state.copyWith(isLoading: true, error: null));
    try {
      final credential = await _firebaseService.login(
        email: email,
        password: password,
      );

      final firebaseUser = credential.user;
      if (firebaseUser == null) {
        throw Exception('Login succeeded but no authenticated user found');
      }

      UserProfile? userProfile;
      try {
        userProfile = await _firestoreService.getUserProfile(firebaseUser.uid);
      } catch (_) {}

      await _ensureUserDocument(
        uid: firebaseUser.uid,
        email: firebaseUser.email ?? email,
        username:
            userProfile?.username ??
            firebaseUser.displayName ??
            (firebaseUser.email?.split('@').first ?? 'User'),
      );

      userProfile ??= await _firestoreService.getUserProfile(firebaseUser.uid);

      _setState(
        _state.copyWith(
          isAuthenticated: true,
          user: User(
            email: userProfile?.email ?? firebaseUser.email ?? email,
            name: userProfile?.username ?? firebaseUser.displayName ?? 'User',
            createdAt:
                userProfile?.createdAt.toIso8601String() ??
                firebaseUser.metadata.creationTime?.toIso8601String() ??
                DateTime.now().toIso8601String(),
          ),
          isLoading: false,
          error: null,
        ),
      );
      await _firebaseMessagingService.syncTokenForCurrentUser();
    } catch (e) {
      _setState(_state.copyWith(isLoading: false, error: e.toString()));
    }
  }

  Future<void> logout() async {
    final uid = _firebaseService.currentUser?.uid;
    final firestore = FirebaseFirestore.instance;
    try {
      await _firebaseMessagingService.clearTokenForCurrentUser(uid: uid);
      await _firebaseService.logout();

      try {
        await firestore.terminate();
        await firestore.clearPersistence();
        debugPrint('✅ Firestore local cache cleared on logout');
      } catch (e) {
        debugPrint('⚠️ Firestore cache clear skipped: $e');
      }
    } finally {
      _setState(AuthState());
    }
  }

  Future<void> _checkAuthStatus() async {
    final firebaseUser = _firebaseService.currentUser;
    if (firebaseUser == null) {
      _setState(AuthState());
      return;
    }

    try {
      await _ensureUserDocument(
        uid: firebaseUser.uid,
        email: firebaseUser.email ?? '',
        username:
            firebaseUser.displayName ??
            (firebaseUser.email?.split('@').first ?? 'User'),
      );

      final userProfile = await _firestoreService.getUserProfile(
        firebaseUser.uid,
      );

      _setState(
        _state.copyWith(
          isAuthenticated: true,
          user: User(
            email: userProfile?.email ?? firebaseUser.email ?? '',
            name: userProfile?.username ?? firebaseUser.displayName ?? 'User',
            createdAt:
                userProfile?.createdAt.toIso8601String() ??
                firebaseUser.metadata.creationTime?.toIso8601String() ??
                DateTime.now().toIso8601String(),
          ),
          isLoading: false,
          error: null,
        ),
      );

      await AssignmentNotificationService.instance
          .syncCurrentUserAssignmentReminders();
      await _firebaseMessagingService.syncTokenForCurrentUser();
    } catch (e) {
      _setState(_state.copyWith(isLoading: false, error: e.toString()));
    }
  }
}
