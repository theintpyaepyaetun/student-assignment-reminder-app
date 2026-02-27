import 'package:flutter/material.dart';
import 'package:student_assignment_reminder_app/models/user_model.dart';
import 'package:student_assignment_reminder_app/services/api_service.dart';
import 'package:student_assignment_reminder_app/services/token_storage_service.dart';

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
  late ApiService _apiService;
  AuthState _state = AuthState();

  AuthProvider() {
    _apiService = ApiService(tokenStorage: TokenStorageService());
    _checkAuthStatus();
  }

  AuthState get state => _state;
  bool get isAuthenticated => _state.isAuthenticated;
  User? get user => _state.user;
  bool get isLoading => _state.isLoading;
  String? get error => _state.error;

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
    final result = await _apiService.register(
      email: email,
      password: password,
      name: name,
    );

    if (result['success']) {
      _setState(_state.copyWith(
        isAuthenticated: true,
        user: User(
          email: email,
          name: name,
          createdAt: DateTime.now().toIso8601String(),
        ),
        isLoading: false,
      ));
    } else {
      _setState(_state.copyWith(
        isLoading: false,
        error: result['message'] ?? 'Registration failed',
      ));
    }
  }

  Future<void> login({
    required String email,
    required String password,
  }) async {
    _setState(_state.copyWith(isLoading: true, error: null));
    final result = await _apiService.login(
      email: email,
      password: password,
    );

    if (result['success']) {
      _setState(_state.copyWith(
        isAuthenticated: true,
        user: result['user'] ?? User(email: email, name: '', createdAt: ''),
        isLoading: false,
      ));
    } else {
      _setState(_state.copyWith(
        isLoading: false,
        error: result['message'] ?? 'Login failed',
      ));
    }
  }

  Future<void> logout() async {
    await _apiService.logout();
    _setState(AuthState());
  }

  Future<void> _checkAuthStatus() async {
    final hasToken = await _apiService.tokenStorage.hasToken();
    if (hasToken) {
      try {
        final user = await _apiService.getUserProfile();
        _setState(_state.copyWith(
          isAuthenticated: true,
          user: user,
        ));
      } catch (e) {
        _setState(_state.copyWith(
          isAuthenticated: false,
          error: e.toString(),
        ));
      }
    }
  }
}
