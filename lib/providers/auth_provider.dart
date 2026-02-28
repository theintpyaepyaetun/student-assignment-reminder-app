import 'package:flutter/material.dart';
import 'package:student_assignment_reminder_app/models/user_model.dart';
import 'package:student_assignment_reminder_app/services/firebase_service.dart';
import 'package:student_assignment_reminder_app/services/firebase_rest_auth.dart';

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
      // Use REST API for sign up
      final result = await FirebaseRestAuth.signUp(
        email: email,
        password: password,
      );

      if (result['success'] == true) {
        _setState(
          _state.copyWith(
            isAuthenticated: true,
            user: User(
              email: result['email'] as String? ?? email,
              name: name,
              createdAt: DateTime.now().toIso8601String(),
            ),
            isLoading: false,
          ),
        );
        return;
      } else {
        final errorMsg = result['error'] as String? ?? 'Registration failed';
        _setState(_state.copyWith(isLoading: false, error: errorMsg));
        return;
      }
    } catch (e) {
      _setState(_state.copyWith(isLoading: false, error: e.toString()));
    }
  }

  Future<void> login({required String email, required String password}) async {
    _setState(_state.copyWith(isLoading: true, error: null));
    try {
      // Try REST API first (more reliable than Firebase SDK on emulator)
      final result = await FirebaseRestAuth.signIn(
        email: email,
        password: password,
      );

      if (result['success'] == true) {
        _setState(
          _state.copyWith(
            isAuthenticated: true,
            user: User(
              email: result['email'] as String? ?? email,
              name: 'User',
              createdAt: DateTime.now().toIso8601String(),
            ),
            isLoading: false,
          ),
        );
        return;
      } else {
        final errorMsg = result['error'] as String? ?? 'Authentication failed';
        _setState(_state.copyWith(isLoading: false, error: errorMsg));
        return;
      }
    } catch (e) {
      _setState(_state.copyWith(isLoading: false, error: e.toString()));
    }
  }

  Future<void> logout() async {
    await _firebaseService.logout();
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
