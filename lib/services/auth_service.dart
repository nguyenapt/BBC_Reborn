import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'dart:convert';

class AuthService extends ChangeNotifier {
  static final AuthService _instance = AuthService._internal();
  factory AuthService() => _instance;
  AuthService._internal();

  static const String _userKey = 'current_user';
  static const String _isLoggedInKey = 'is_logged_in';

  User? _currentUser;
  bool _isLoggedIn = false;
  final GoogleSignIn _googleSignIn = GoogleSignIn(
    scopes: ['email', 'profile'],
  );

  User? get currentUser => _currentUser;
  bool get isLoggedIn => _isLoggedIn;

  /// Initialize service
  Future<void> initialize() async {
    final prefs = await SharedPreferences.getInstance();
    _isLoggedIn = prefs.getBool(_isLoggedInKey) ?? false;
    
    if (_isLoggedIn) {
      final userJson = prefs.getString(_userKey);
      if (userJson != null) {
        final userData = json.decode(userJson);
        _currentUser = User.fromJson(userData);
      }
    }
    
    notifyListeners();
  }

  /// Login with email and password
  Future<AuthResult> loginWithEmail(String email, String password) async {
    try {
      // Simulate API call - in real app, call Firebase Auth
      await Future.delayed(const Duration(seconds: 1));
      
      // For demo purposes, accept any email/password
      if (email.isNotEmpty && password.isNotEmpty) {
        final user = User(
          id: 'user_${DateTime.now().millisecondsSinceEpoch}',
          email: email,
          name: email.split('@')[0],
          provider: 'email',
        );
        
        await _saveUserSession(user);
        return AuthResult.success(user);
      } else {
        return AuthResult.error('Email và password không được để trống');
      }
    } catch (e) {
      return AuthResult.error('Lỗi đăng nhập: $e');
    }
  }

  /// Register with email and password
  Future<AuthResult> registerWithEmail(String email, String password, String name) async {
    try {
      // Simulate API call - in real app, call Firebase Auth
      await Future.delayed(const Duration(seconds: 1));
      
      // For demo purposes, accept any valid email
      if (email.isNotEmpty && password.isNotEmpty && name.isNotEmpty) {
        if (!_isValidEmail(email)) {
          return AuthResult.error('Email không hợp lệ');
        }
        
        if (password.length < 6) {
          return AuthResult.error('Mật khẩu phải có ít nhất 6 ký tự');
        }
        
        final user = User(
          id: 'user_${DateTime.now().millisecondsSinceEpoch}',
          email: email,
          name: name,
          provider: 'email',
        );
        
        await _saveUserSession(user);
        return AuthResult.success(user);
      } else {
        return AuthResult.error('Tất cả các trường đều bắt buộc');
      }
    } catch (e) {
      return AuthResult.error('Lỗi đăng ký: $e');
    }
  }

  /// Login with Google
  Future<AuthResult> loginWithGoogle() async {
    try {
      // Trigger the authentication flow
      final GoogleSignInAccount? googleUser = await _googleSignIn.signIn();
      
      if (googleUser == null) {
        // User cancelled the login
        return AuthResult.error('Đăng nhập bị hủy');
      }

      // Obtain the auth details from the request
      final GoogleSignInAuthentication googleAuth = await googleUser.authentication;

      // Create user object from Google account
      final user = User(
        id: googleUser.id,
        email: googleUser.email,
        name: googleUser.displayName ?? 'Google User',
        provider: 'google',
        avatarUrl: googleUser.photoUrl,
      );
      
      await _saveUserSession(user);
      return AuthResult.success(user);
    } catch (e) {
      debugPrint('Google Sign-In Error: $e');
      return AuthResult.error('Lỗi đăng nhập Google: $e');
    }
  }

  /// Logout
  Future<void> logout() async {
    try {
      // Sign out from Google if user was signed in with Google
      if (_currentUser?.provider == 'google') {
        await _googleSignIn.signOut();
      }
      
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_userKey);
      await prefs.remove(_isLoggedInKey);
      
      _currentUser = null;
      _isLoggedIn = false;
      notifyListeners();
    } catch (e) {
      debugPrint('Logout Error: $e');
      // Still clear local data even if Google sign out fails
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_userKey);
      await prefs.remove(_isLoggedInKey);
      
      _currentUser = null;
      _isLoggedIn = false;
      notifyListeners();
    }
  }

  /// Save user session
  Future<void> _saveUserSession(User user) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_userKey, json.encode(user.toJson()));
    await prefs.setBool(_isLoggedInKey, true);
    
    _currentUser = user;
    _isLoggedIn = true;
    notifyListeners();
  }

  /// Validate email format
  bool _isValidEmail(String email) {
    return RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$').hasMatch(email);
  }
}

class User {
  final String id;
  final String email;
  final String name;
  final String provider;
  final String? avatarUrl;

  User({
    required this.id,
    required this.email,
    required this.name,
    required this.provider,
    this.avatarUrl,
  });

  factory User.fromJson(Map<String, dynamic> json) {
    return User(
      id: json['id'] ?? '',
      email: json['email'] ?? '',
      name: json['name'] ?? '',
      provider: json['provider'] ?? '',
      avatarUrl: json['avatarUrl'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'email': email,
      'name': name,
      'provider': provider,
      'avatarUrl': avatarUrl,
    };
  }
}

class AuthResult {
  final bool isSuccess;
  final String? error;
  final User? user;

  AuthResult.success(this.user) : isSuccess = true, error = null;
  AuthResult.error(this.error) : isSuccess = false, user = null;
}
