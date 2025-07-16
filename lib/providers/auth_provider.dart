// providers/auth_provider.dart
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/auth_service.dart';

enum AuthStatus {
  initial,
  loading,
  authenticated,
  unauthenticated,
  error,
}

class AuthProvider with ChangeNotifier {
  final AuthService _authService;
  AuthStatus _status = AuthStatus.unauthenticated; // Initial state
  String? _errorMessage;
  String? _accessToken; // To store the JWT
  Map<String, dynamic>? _user; // To store user data
  String? _username; 

  AuthProvider(this._authService);

  AuthStatus get status => _status;
  String? get errorMessage => _errorMessage;
  bool get isAuthenticated => _status == AuthStatus.authenticated;
  String? get accessToken => _accessToken;
  String? get username => _username;
  Map<String, dynamic>? get user => _user;

  Future<void> initialAuthCheck() async {
    _status = AuthStatus.loading;
    notifyListeners();
    SharedPreferences prefs = await SharedPreferences.getInstance();

    try {
      final String? storedToken = await _authService.getStoredToken();
      final int? storedUserId = await _authService.getStoredUserId();
      final String? storedUsername = await _authService.getStoredUsername(); // Get stored username
      final String? storedEmail = await _authService.getStoredUserEmail(); // Get stored email

      if (storedToken != null && storedUserId != null && storedUsername != null) {
        _accessToken = storedToken;
        _username = storedUsername;
        // Reconstruct a basic user map from stored data for consistency
        _user = {
          'id': storedUserId,
          'username': storedUsername,
          'email': storedEmail, // Include email if stored
        };
        _status = AuthStatus.authenticated;
        await prefs.setBool("isAuthenticated", true);
      } else {
        _status = AuthStatus.unauthenticated;
        await prefs.setBool("isAuthenticated", false);
      }
    } catch (e) {
      _errorMessage = 'Failed to load session: ${e.toString()}';
      _status = AuthStatus.error;
    } finally {
      notifyListeners();
    }
  }

  Future<bool> login(String identifier, String password) async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    _status = AuthStatus.loading;
    _errorMessage = null;
    notifyListeners();

    try {
      final response = await _authService.login(identifier, password);
      if (response['success'] == true) {
        _accessToken = response['access_token'];
        _user = response['user'];
        _username = _user?['username'] ?? _user?['email'] ?? 'User';
        _status = AuthStatus.authenticated;
        await prefs.setBool("isAuthenticated", true);
        notifyListeners();
        return true;
      } else {
        // This case should ideally be caught by the service throwing an exception
        _errorMessage = 'Login failed: ${response['message']}';
        _status = AuthStatus.error;
        await prefs.setBool("isAuthenticated", false);
        notifyListeners();
        return false;
      }
    } catch (e) {
      _errorMessage = e.toString().replaceFirst('Exception: ', ''); // Clean up error message
      _status = AuthStatus.error;
      notifyListeners();
      return false;
    }
  }

  Future<void> logout() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    _authService.logout(); // Call the service logout (e.g., clear token)
    _accessToken = null;
    _user = null;
    _username = null; 
    _status = AuthStatus.unauthenticated;
    await prefs.setBool("isAuthenticated", false);
    notifyListeners();
  }

  // Potentially add a check for a stored token on app start
  void checkAuthStatus() {
    // In a real app, you'd check for a stored access token here
    // If found and valid, set _status to AuthStatus.authenticated
    // Otherwise, keep as AuthStatus.unauthenticated
    _status = AuthStatus.unauthenticated; // For now, always start unauthenticated
    notifyListeners();
  }
}
