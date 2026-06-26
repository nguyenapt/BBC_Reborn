import 'dart:convert';
import 'dart:io';

import 'package:firebase_auth/firebase_auth.dart' as fb;
import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'user_cloud_sync_service.dart';

class AuthService extends ChangeNotifier {
  static final AuthService _instance = AuthService._internal();
  factory AuthService() => _instance;
  AuthService._internal();

  static const String _userKey = 'current_user';
  static const String _isLoggedInKey = 'is_logged_in';
  static const String _googleWebClientId =
      '128498222438-altvtff6csvmb4npdf1fujn2vgjeb272.apps.googleusercontent.com';

  static bool get _useFirebaseAuth =>
      !kIsWeb && (Platform.isAndroid || Platform.isIOS);

  User? _currentUser;
  bool _isLoggedIn = false;

  final GoogleSignIn _googleSignIn = GoogleSignIn(
    scopes: ['email', 'profile'],
    serverClientId: _useFirebaseAuth ? _googleWebClientId : null,
  );

  User? get currentUser => _currentUser;
  bool get isLoggedIn => _isLoggedIn;
  String? get firebaseUid =>
      _useFirebaseAuth ? fb.FirebaseAuth.instance.currentUser?.uid : null;

  Future<void> initialize() async {
    final prefs = await SharedPreferences.getInstance();

    if (_useFirebaseAuth) {
      final fbUser = fb.FirebaseAuth.instance.currentUser;
      if (fbUser != null) {
        _applyFirebaseUser(fbUser);
      } else {
        final hadLegacyMock = prefs.getBool(_isLoggedInKey) ?? false;
        if (hadLegacyMock) {
          await prefs.remove(_userKey);
          await prefs.remove(_isLoggedInKey);
        }
        _currentUser = null;
        _isLoggedIn = false;
      }
    } else {
      _currentUser = null;
      _isLoggedIn = false;
    }

    notifyListeners();
  }

  Future<AuthResult> loginWithEmail(String email, String password) async {
    if (!_useFirebaseAuth) {
      return AuthResult.error('Đăng nhập cloud chỉ khả dụng trên Android/iOS');
    }

    try {
      final credential = await fb.FirebaseAuth.instance.signInWithEmailAndPassword(
        email: email.trim(),
        password: password,
      );
      final user = credential.user;
      if (user == null) {
        return AuthResult.error('Đăng nhập thất bại');
      }
      _applyFirebaseUser(user);
      await _cacheUserDisplay(user);
      await UserCloudSyncService().syncOnLogin(user.uid);
      return AuthResult.success(_currentUser!);
    } on fb.FirebaseAuthException catch (e) {
      return AuthResult.error(_mapFirebaseAuthError(e));
    } catch (e) {
      return AuthResult.error('Lỗi đăng nhập: $e');
    }
  }

  Future<AuthResult> registerWithEmail(
    String email,
    String password,
    String name,
  ) async {
    if (!_useFirebaseAuth) {
      return AuthResult.error('Đăng ký cloud chỉ khả dụng trên Android/iOS');
    }

    if (!_isValidEmail(email)) {
      return AuthResult.error('Email không hợp lệ');
    }
    if (password.length < 6) {
      return AuthResult.error('Mật khẩu phải có ít nhất 6 ký tự');
    }
    if (name.trim().isEmpty) {
      return AuthResult.error('Tên không được để trống');
    }

    try {
      final credential =
          await fb.FirebaseAuth.instance.createUserWithEmailAndPassword(
        email: email.trim(),
        password: password,
      );
      final user = credential.user;
      if (user == null) {
        return AuthResult.error('Đăng ký thất bại');
      }
      await user.updateDisplayName(name.trim());
      await user.reload();
      final refreshed = fb.FirebaseAuth.instance.currentUser;
      if (refreshed != null) {
        _applyFirebaseUser(refreshed);
        await _cacheUserDisplay(refreshed);
        await UserCloudSyncService().syncOnLogin(refreshed.uid);
        return AuthResult.success(_currentUser!);
      }
      return AuthResult.error('Đăng ký thất bại');
    } on fb.FirebaseAuthException catch (e) {
      return AuthResult.error(_mapFirebaseAuthError(e));
    } catch (e) {
      return AuthResult.error('Lỗi đăng ký: $e');
    }
  }

  Future<AuthResult> loginWithGoogle() async {
    if (!_useFirebaseAuth) {
      return AuthResult.error('Đăng nhập Google chỉ khả dụng trên Android/iOS');
    }

    try {
      final GoogleSignInAccount? googleUser = await _googleSignIn.signIn();
      if (googleUser == null) {
        return AuthResult.error('Đăng nhập bị hủy');
      }

      final GoogleSignInAuthentication googleAuth =
          await googleUser.authentication;
      final credential = fb.GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      final userCredential =
          await fb.FirebaseAuth.instance.signInWithCredential(credential);
      final user = userCredential.user;
      if (user == null) {
        return AuthResult.error('Đăng nhập Google thất bại');
      }

      _applyFirebaseUser(user);
      await _cacheUserDisplay(user);
      await UserCloudSyncService().syncOnLogin(user.uid);
      return AuthResult.success(_currentUser!);
    } on fb.FirebaseAuthException catch (e) {
      return AuthResult.error(_mapFirebaseAuthError(e));
    } catch (e) {
      debugPrint('Google Sign-In Error: $e');
      return AuthResult.error('Lỗi đăng nhập Google: $e');
    }
  }

  Future<void> logout() async {
    try {
      UserCloudSyncService().onUserSignedOut();
      if (_useFirebaseAuth) {
        await _googleSignIn.signOut();
        await fb.FirebaseAuth.instance.signOut();
      }

      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_userKey);
      await prefs.remove(_isLoggedInKey);

      _currentUser = null;
      _isLoggedIn = false;
      notifyListeners();
    } catch (e) {
      debugPrint('Logout Error: $e');
      _currentUser = null;
      _isLoggedIn = false;
      notifyListeners();
    }
  }

  void _applyFirebaseUser(fb.User fbUser) {
    final provider = fbUser.providerData.isNotEmpty
        ? _providerLabel(fbUser.providerData.first.providerId)
        : 'firebase';

    _currentUser = User(
      id: fbUser.uid,
      email: fbUser.email ?? '',
      name: fbUser.displayName ??
          fbUser.email?.split('@').first ??
          'User',
      provider: provider,
      avatarUrl: fbUser.photoURL,
    );
    _isLoggedIn = true;
    notifyListeners();
  }

  Future<void> _cacheUserDisplay(fb.User fbUser) async {
    if (_currentUser == null) return;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_userKey, _currentUser!.toJsonString());
    await prefs.setBool(_isLoggedInKey, true);
  }

  String _providerLabel(String providerId) {
    if (providerId.contains('google')) return 'google';
    if (providerId.contains('password')) return 'email';
    return providerId;
  }

  String _mapFirebaseAuthError(fb.FirebaseAuthException e) {
    switch (e.code) {
      case 'user-not-found':
        return 'Tài khoản không tồn tại';
      case 'wrong-password':
      case 'invalid-credential':
        return 'Email hoặc mật khẩu không đúng';
      case 'email-already-in-use':
        return 'Email đã được sử dụng';
      case 'weak-password':
        return 'Mật khẩu quá yếu';
      case 'invalid-email':
        return 'Email không hợp lệ';
      case 'user-disabled':
        return 'Tài khoản đã bị vô hiệu hóa';
      case 'too-many-requests':
        return 'Quá nhiều lần thử. Vui lòng thử lại sau';
      default:
        return e.message ?? 'Lỗi xác thực (${e.code})';
    }
  }

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

  String toJsonString() => jsonEncode(toJson());
}

class AuthResult {
  final bool isSuccess;
  final String? error;
  final User? user;

  AuthResult.success(this.user) : isSuccess = true, error = null;
  AuthResult.error(this.error) : isSuccess = false, user = null;
}
