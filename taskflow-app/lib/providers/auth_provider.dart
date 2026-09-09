import 'package:flutter/material.dart';

import '../core/api_client.dart';
import '../core/api_exceptions.dart';
import '../core/secure_storage.dart';
import '../models/user.dart';

enum AuthStatus {
  initial,
  authenticating,
  authenticated,
  unauthenticated,
  error,
}

class AuthProvider extends ChangeNotifier {
  final ApiClient _client;
  final SecureStorageService _storage;

  User? _user;
  AuthStatus _status = AuthStatus.initial;
  String? _errorMessage;

  AuthProvider({
    ApiClient? client,
    ApiClient? apiClient,
    SecureStorageService? storage,
    SecureStorageService? storageService,
  }) : _client = client ?? apiClient ?? ApiClient(),
       _storage = storage ?? storageService ?? SecureStorageService() {
    _client.onUnauthorized = _handleUnauthorized;
  }

  User? get user => _user;
  AuthStatus get status => _status;
  bool get isAuthenticated =>
      _status == AuthStatus.authenticated && _user != null;
  bool get isLoading => _status == AuthStatus.authenticating;
  String? get errorMessage => _errorMessage;

  @visibleForTesting
  void setUserForTesting(User? user) {
    _user = user;
    _status = user != null
        ? AuthStatus.authenticated
        : AuthStatus.unauthenticated;
    notifyListeners();
  }

  void _handleUnauthorized() {
    _user = null;
    _status = AuthStatus.unauthenticated;
    _storage.deleteToken();
    notifyListeners();
  }

  Future<void> loadCurrentUser() async {
    _status = AuthStatus.authenticating;
    notifyListeners();

    try {
      final token = await _storage.getToken();
      if (token == null || token.isEmpty) {
        _status = AuthStatus.unauthenticated;
        notifyListeners();
        return;
      }

      final response = await _client.get('/auth/me');
      if (response != null && response is Map<String, dynamic>) {
        _user = User.fromJson(response);
        _status = AuthStatus.authenticated;
      } else {
        _status = AuthStatus.unauthenticated;
      }
    } catch (_) {
      await _storage.deleteToken();
      _user = null;
      _status = AuthStatus.unauthenticated;
    }
    notifyListeners();
  }

  Future<bool> login(String email, String password) async {
    _status = AuthStatus.authenticating;
    _errorMessage = null;
    notifyListeners();

    try {
      final response = await _client.post(
        '/auth/login',
        body: {'email': email, 'password': password},
        requiresAuth: false,
      );

      final token = response['access_token'] as String;
      await _storage.saveToken(token);

      if (response['user'] != null &&
          response['user'] is Map<String, dynamic>) {
        _user = User.fromJson(response['user'] as Map<String, dynamic>);
      } else {
        final userResponse = await _client.get('/auth/me');
        _user = User.fromJson(userResponse as Map<String, dynamic>);
      }
      _status = AuthStatus.authenticated;
      notifyListeners();
      return true;
    } on ApiException catch (e) {
      _status = AuthStatus.unauthenticated;
      _errorMessage = e.message;
      notifyListeners();
      return false;
    } catch (e) {
      _status = AuthStatus.unauthenticated;
      _errorMessage = 'Invalid email or password';
      notifyListeners();
      return false;
    }
  }

  Future<bool> register({
    required String name,
    required String email,
    required String password,
  }) async {
    _status = AuthStatus.authenticating;
    _errorMessage = null;
    notifyListeners();

    try {
      await _client.post(
        '/auth/register',
        body: {'name': name, 'email': email, 'password': password},
        requiresAuth: false,
      );

      _status = AuthStatus.unauthenticated;
      notifyListeners();
      return true;
    } on ApiException catch (e) {
      _status = AuthStatus.unauthenticated;
      _errorMessage = e.message;
      notifyListeners();
      return false;
    } catch (e) {
      _status = AuthStatus.unauthenticated;
      _errorMessage = 'Registration failed';
      notifyListeners();
      return false;
    }
  }

  Future<bool> changePassword({
    required String oldPassword,
    required String newPassword,
  }) async {
    _errorMessage = null;
    try {
      await _client.put(
        '/auth/password',
        body: {'current_password': oldPassword, 'new_password': newPassword},
      );
      return true;
    } on ApiException catch (e) {
      _errorMessage = e.message;
      notifyListeners();
      return false;
    } catch (e) {
      _errorMessage = 'Failed to change password';
      notifyListeners();
      return false;
    }
  }

  Future<void> logout() async {
    await _storage.deleteToken();
    _user = null;
    _status = AuthStatus.unauthenticated;
    _errorMessage = null;
    notifyListeners();
  }
}
