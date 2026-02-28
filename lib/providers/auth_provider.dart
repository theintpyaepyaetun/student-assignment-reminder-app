import 'package:flutter/material.dart';
import 'package:student_assignment_reminder_app/models/user_model.dart';
import 'package:student_assignment_reminder_app/models/user_profile_model.dart';
import 'package:student_assignment_reminder_app/services/firebase_service.dart';
import 'package:student_assignment_reminder_app/services/local_auth_service.dart';
import 'package:student_assignment_reminder_app/services/firestore_service.dart';

// Auth state
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
      error: error ?? this.error,
    );
  }
}

class AuthProvider extends ChangeNotifier {
  final FirebaseService _firebaseService = FirebaseService();
  final FirestoreService _firestoreService = FirestoreService();
  AuthState _state = AuthState();

  AuthProvider() {
    _checkAuthStatus();
  }

  AuthState get state => _state;
  bool get isAuthenticated => _state.isAuthenticated;
  User? get user => _state.user;
  bool get isLoading => _state.isLoading;
  String? get error => _state.error;

  /// When the app is running without a valid Firebase configuration.
  /// This is useful for development/demo purposes; authentication calls are
  /// mocked instead of being sent to Firebase.
  bool get isDemoMode => !_firebaseService.isConfigured;

  void _setState(AuthState newState) {
    _state = newState;
    notifyListeners();
  }

  Future<void> register({
    required String email,
    required String password,
    required String name,
  }) async {
    _setState(_state.copyWith(isLoading: true, error: null));
    try {
      if (isDemoMode) {
        final result = await LocalAuthService.signUp(
          email: email,
          password: password,
        );

        if (result['success'] == true) {
          final registeredEmail = result['email']?.toString() ?? email;
          _setState(
            _state.copyWith(
              isAuthenticated: true,
              user: User(
                email: registeredEmail,
                name: name,
                createdAt: DateTime.now().toIso8601String(),
              ),
              isLoading: false,
            ),
          );
          return;
        }

        final errorMsg = result['error']?.toString() ?? 'Registration failed';
        _setState(_state.copyWith(isLoading: false, error: errorMsg));
        return;
      }

      final credential = await _firebaseService.signUp(
        email: email,
        password: password,
      );

      final userId = credential.user!.uid;

      // Create user document in Firestore
      await _firestoreService.createUserDocument(
        uid: userId,
        email: email,
        username: name,
      );

      await LocalAuthService.signUp(email: email, password: password);

      _setState(
        _state.copyWith(
          isAuthenticated: true,
          user: User(
            email: email,
            name: name,
            createdAt: DateTime.now().toIso8601String(),
          ),
          isLoading: false,
        ),
      );
      return;
    } catch (e) {
      _setState(_state.copyWith(isLoading: false, error: e.toString()));
    }
  }

  Future<void> login({required String email, required String password}) async {
    _setState(_state.copyWith(isLoading: true, error: null));
    try {
      try {
        final credential = await _firebaseService.login(
          email: email,
          password: password,
        );

        final firebaseUser = credential.user;

        // Fetch user profile from Firestore
        UserProfile? userProfile;
        if (firebaseUser != null) {
          try {
            userProfile = await _firestoreService.getUserProfile(
              firebaseUser.uid,
            );
          } catch (e) {
            debugPrint('⚠️ Failed to fetch Firestore profile: $e');
          }
        }

        _setState(
          _state.copyWith(
            isAuthenticated: true,
            user: User(
              email: userProfile?.email ?? firebaseUser?.email ?? email,
              name:
                  userProfile?.username ?? firebaseUser?.displayName ?? 'User',
              createdAt:
                  userProfile?.createdAt.toIso8601String() ??
                  firebaseUser?.metadata.creationTime?.toIso8601String() ??
                  DateTime.now().toIso8601String(),
            ),
            isLoading: false,
          ),
        );
        return;
      } catch (firebaseError) {
        debugPrint(
          '⚠️ Firebase login failed, falling back to local login: $firebaseError',
        );
      }

      final result = await LocalAuthService.signIn(
        email: email,
        password: password,
      );

      if (result['success'] == true) {
        final loggedInEmail = result['email']?.toString() ?? email;
        _setState(
          _state.copyWith(
            isAuthenticated: true,
            user: User(
              email: loggedInEmail,
              name: 'User',
              createdAt: DateTime.now().toIso8601String(),
            ),
            isLoading: false,
          ),
        );
        return;
      }

      final errorMsg = result['error']?.toString() ?? 'Authentication failed';
      _setState(_state.copyWith(isLoading: false, error: errorMsg));
      return;
    } catch (e) {
      _setState(_state.copyWith(isLoading: false, error: e.toString()));
    }
  }

  Future<void> logout() async {
    try {
      await _firebaseService.logout();
    } catch (_) {}
    await LocalAuthService.signOut();
    _setState(AuthState());
  }

  Future<void> _checkAuthStatus() async {
    final firebaseUser = _firebaseService.currentUser;
    if (firebaseUser != null) {
      _setState(
        _state.copyWith(
          isAuthenticated: true,
          user: User(
            email: firebaseUser.email ?? '',
            name: firebaseUser.displayName ?? 'User',
            createdAt:
                firebaseUser.metadata.creationTime?.toIso8601String() ?? '',
          ),
        ),
      );
    }
  }
}
