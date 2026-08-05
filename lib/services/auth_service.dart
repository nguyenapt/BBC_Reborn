import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:crypto/crypto.dart';
import 'package:firebase_auth/firebase_auth.dart' as fb;
import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sign_in_with_apple/sign_in_with_apple.dart';

import 'user_cloud_sync_service.dart';

class AuthService extends ChangeNotifier {
  static final AuthService _instance = AuthService._internal();
  factory AuthService() => _instance;
  AuthService._internal();

  static const String _userKey = 'current_user';
  static const String _isLoggedInKey = 'is_logged_in';

  /// UI dùng mã này để hiện dialog nhập mật khẩu trước khi xóa account email.
  static const String requiresRecentLoginCode = 'requires-recent-login';

  /// Web client ID — Firebase Console → voa-learning-english-c75fe (OAuth Web client).
  static const String? _googleWebClientId =
      '666526516629-l51evdqrp1l1uq8pkcpjem6v33kjahm0.apps.googleusercontent.com';

  static bool get _useFirebaseAuth =>
      !kIsWeb && (Platform.isAndroid || Platform.isIOS);

  User? _currentUser;
  bool _isLoggedIn = false;

  final GoogleSignIn _googleSignIn = GoogleSignIn(
    scopes: const ['email', 'profile', 'openid'],
    serverClientId: _useFirebaseAuth ? _googleWebClientId : null,
    forceCodeForRefreshToken: true,
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
      await _googleSignIn.signOut();

      final GoogleSignInAccount? googleUser;
      try {
        googleUser = await _googleSignIn.signIn();
      } catch (e) {
        debugPrint('Google Sign-In signIn() failed: $e');
        return AuthResult.error(
          'Không mở được màn hình Google (SHA/package). Chi tiết: $e',
        );
      }

      if (googleUser == null) {
        return AuthResult.error('Đăng nhập bị hủy');
      }

      final GoogleSignInAuthentication googleAuth;
      try {
        googleAuth = await googleUser.authentication;
      } catch (e) {
        debugPrint('Google Sign-In authentication() failed: $e');
        final message = e.toString();
        if (message.contains('ApiException: 10') ||
            message.contains('DEVELOPER_ERROR')) {
          return AuthResult.error(
            'Google đã chọn tài khoản nhưng không lấy được token (lỗi 10). '
            'Kiểm tra Web client ID trên Firebase Authentication → Google '
            '(phải là l51evd...). Tắt/bật lại Google provider rồi build AAB mới.',
          );
        }
        return AuthResult.error('Lỗi lấy token Google: $e');
      }

      if (googleAuth.idToken == null) {
        debugPrint(
          'Google Sign-In: idToken null — accessToken=${googleAuth.accessToken != null}',
        );
        return AuthResult.error(
          'Không lấy được idToken. Web client ID hoặc OAuth consent chưa đúng.',
        );
      }

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
      debugPrint('FirebaseAuth Google sign-in failed: ${e.code} ${e.message}');
      if (e.code == 'app-check-failed' ||
          (e.message ?? '').toLowerCase().contains('app check')) {
        return AuthResult.error(
          'Firebase App Check chặn đăng nhập. Vào Firebase → App Check → '
          'tạm thời tắt Enforce cho Authentication hoặc cấu hình Play Integrity.',
        );
      }
      return AuthResult.error(_mapFirebaseAuthError(e));
    } catch (e) {
      debugPrint('Google Sign-In Error: $e');
      return AuthResult.error('Lỗi đăng nhập Google: $e');
    }
  }

  /// Sign in with Apple — primarily for iOS (App Store Guideline 4.8).
  Future<AuthResult> loginWithApple() async {
    if (!_useFirebaseAuth) {
      return AuthResult.error('Đăng nhập Apple chỉ khả dụng trên Android/iOS');
    }

    try {
      final isAvailable = await SignInWithApple.isAvailable();
      if (!isAvailable) {
        return AuthResult.error('Sign in with Apple không khả dụng trên thiết bị này');
      }

      final rawNonce = _generateNonce();
      final nonce = _sha256ofString(rawNonce);

      final appleCredential = await SignInWithApple.getAppleIDCredential(
        scopes: [
          AppleIDAuthorizationScopes.email,
          AppleIDAuthorizationScopes.fullName,
        ],
        nonce: nonce,
      );

      final idToken = appleCredential.identityToken;
      if (idToken == null) {
        return AuthResult.error('Không nhận được token từ Apple');
      }

      final oauthCredential = fb.OAuthProvider('apple.com').credential(
        idToken: idToken,
        rawNonce: rawNonce,
        accessToken: appleCredential.authorizationCode,
      );

      final userCredential =
          await fb.FirebaseAuth.instance.signInWithCredential(oauthCredential);
      final user = userCredential.user;
      if (user == null) {
        return AuthResult.error('Đăng nhập Apple thất bại');
      }

      // Apple chỉ trả tên lần đăng nhập đầu; lưu luôn nếu có.
      final givenName = appleCredential.givenName;
      final familyName = appleCredential.familyName;
      final fullName = [
        if (givenName != null && givenName.isNotEmpty) givenName,
        if (familyName != null && familyName.isNotEmpty) familyName,
      ].join(' ');
      if (fullName.isNotEmpty &&
          (user.displayName == null || user.displayName!.isEmpty)) {
        await user.updateDisplayName(fullName);
        await user.reload();
      }

      final refreshed = fb.FirebaseAuth.instance.currentUser ?? user;
      _applyFirebaseUser(refreshed);
      await _cacheUserDisplay(refreshed);
      await UserCloudSyncService().syncOnLogin(refreshed.uid);
      return AuthResult.success(_currentUser!);
    } on SignInWithAppleAuthorizationException catch (e) {
      if (e.code == AuthorizationErrorCode.canceled) {
        return AuthResult.error('Đăng nhập bị hủy');
      }
      debugPrint('Apple Sign-In Error: $e');
      return AuthResult.error('Lỗi đăng nhập Apple: ${e.message}');
    } on fb.FirebaseAuthException catch (e) {
      return AuthResult.error(_mapFirebaseAuthError(e));
    } catch (e) {
      debugPrint('Apple Sign-In Error: $e');
      return AuthResult.error('Lỗi đăng nhập Apple: $e');
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

  /// Xóa tài khoản vĩnh viễn: đảm bảo session còn hợp lệ → xóa RTDB → xóa Auth → clear local.
  /// Với email, nếu Firebase yêu cầu đăng nhập lại mà chưa có [password],
  /// trả về [requiresRecentLoginCode] để UI hỏi mật khẩu rồi gọi lại.
  Future<AuthResult> deleteAccount({String? password}) async {
    if (!_useFirebaseAuth) {
      return AuthResult.error('Xóa tài khoản chỉ khả dụng trên Android/iOS');
    }

    final user = fb.FirebaseAuth.instance.currentUser;
    if (user == null) {
      return AuthResult.error('Bạn chưa đăng nhập');
    }

    final uid = user.uid;
    final provider = _primaryProvider(user);

    try {
      // Apple: re-auth + revoke + delete Auth trong một sheet; RTDB xóa sau khi re-auth OK
      // để tránh mất data nếu user hủy Sign in with Apple.
      if (provider == 'apple') {
        final appleResult = await _deleteAppleAccount(user, uid: uid);
        if (!appleResult.isSuccess) return appleResult;
        await _clearLocalSessionAfterDelete();
        return AuthResult.success(null);
      }

      // Email / Google: thử xóa Auth; nếu cần re-auth thì xử lý rồi mới xóa RTDB + Auth.
      try {
        await UserCloudSyncService().deleteUserCloudData(uid);
        await user.delete();
      } on fb.FirebaseAuthException catch (e) {
        if (e.code != requiresRecentLoginCode) {
          return AuthResult.error(_mapFirebaseAuthError(e));
        }

        if (provider == 'email' &&
            (password == null || password.isEmpty)) {
          return AuthResult.error(requiresRecentLoginCode);
        }

        final reauth = await _reauthenticate(
          user,
          provider: provider,
          password: password,
        );
        if (!reauth.isSuccess) {
          return reauth;
        }

        final refreshed = fb.FirebaseAuth.instance.currentUser;
        if (refreshed == null) {
          return AuthResult.error('Xác thực lại thất bại');
        }

        // RTDB có thể đã bị xóa ở lần thử trước — gọi lại an toàn.
        await UserCloudSyncService().deleteUserCloudData(uid);
        await refreshed.delete();
      }

      await _clearLocalSessionAfterDelete();
      return AuthResult.success(null);
    } on SignInWithAppleAuthorizationException catch (e) {
      if (e.code == AuthorizationErrorCode.canceled) {
        return AuthResult.error('Đăng nhập bị hủy');
      }
      return AuthResult.error('Lỗi xác thực Apple: ${e.message}');
    } on fb.FirebaseAuthException catch (e) {
      return AuthResult.error(_mapFirebaseAuthError(e));
    } catch (e) {
      debugPrint('Delete account error: $e');
      return AuthResult.error('Lỗi xóa tài khoản: $e');
    }
  }

  String _primaryProvider(fb.User user) {
    if (_currentUser?.provider != null &&
        _currentUser!.provider.isNotEmpty) {
      return _currentUser!.provider;
    }
    if (user.providerData.isEmpty) return 'firebase';
    return _providerLabel(user.providerData.first.providerId);
  }

  /// Một lần Apple sheet: re-auth → xóa RTDB → revoke token → delete Auth.
  Future<AuthResult> _deleteAppleAccount(
    fb.User user, {
    required String uid,
  }) async {
    try {
      final isAvailable = await SignInWithApple.isAvailable();
      if (!isAvailable) {
        return AuthResult.error(
          'Sign in with Apple không khả dụng trên thiết bị này',
        );
      }

      final rawNonce = _generateNonce();
      final nonce = _sha256ofString(rawNonce);
      final appleCredential = await SignInWithApple.getAppleIDCredential(
        scopes: const [
          AppleIDAuthorizationScopes.email,
          AppleIDAuthorizationScopes.fullName,
        ],
        nonce: nonce,
      );

      final idToken = appleCredential.identityToken;
      if (idToken == null) {
        return AuthResult.error('Không nhận được token từ Apple');
      }

      final oauthCredential = fb.OAuthProvider('apple.com').credential(
        idToken: idToken,
        rawNonce: rawNonce,
        accessToken: appleCredential.authorizationCode,
      );
      await user.reauthenticateWithCredential(oauthCredential);

      await UserCloudSyncService().deleteUserCloudData(uid);

      if (appleCredential.authorizationCode.isNotEmpty) {
        try {
          await fb.FirebaseAuth.instance.revokeTokenWithAuthorizationCode(
            appleCredential.authorizationCode,
          );
        } catch (e) {
          debugPrint('Apple token revoke failed: $e');
        }
      }

      final refreshed = fb.FirebaseAuth.instance.currentUser ?? user;
      await refreshed.delete();
      return AuthResult.success(null);
    } on SignInWithAppleAuthorizationException catch (e) {
      if (e.code == AuthorizationErrorCode.canceled) {
        return AuthResult.error('Đăng nhập bị hủy');
      }
      return AuthResult.error('Lỗi xác thực Apple: ${e.message}');
    } on fb.FirebaseAuthException catch (e) {
      return AuthResult.error(_mapFirebaseAuthError(e));
    } catch (e) {
      return AuthResult.error('Lỗi xóa tài khoản Apple: $e');
    }
  }

  Future<AuthResult> _reauthenticate(
    fb.User user, {
    required String provider,
    String? password,
  }) async {
    try {
      if (provider == 'email') {
        final email = user.email;
        if (email == null || email.isEmpty) {
          return AuthResult.error('Không tìm thấy email tài khoản');
        }
        if (password == null || password.isEmpty) {
          return AuthResult.error(requiresRecentLoginCode);
        }
        final credential = fb.EmailAuthProvider.credential(
          email: email,
          password: password,
        );
        await user.reauthenticateWithCredential(credential);
        return AuthResult.success(_currentUser);
      }

      if (provider == 'google') {
        await _googleSignIn.signOut();
        final googleUser = await _googleSignIn.signIn();
        if (googleUser == null) {
          return AuthResult.error('Đăng nhập bị hủy');
        }
        final googleAuth = await googleUser.authentication;
        if (googleAuth.idToken == null) {
          return AuthResult.error('Không lấy được idToken Google');
        }
        final credential = fb.GoogleAuthProvider.credential(
          accessToken: googleAuth.accessToken,
          idToken: googleAuth.idToken,
        );
        await user.reauthenticateWithCredential(credential);
        return AuthResult.success(_currentUser);
      }

      return AuthResult.error('Không hỗ trợ xác thực lại cho nhà cung cấp này');
    } on fb.FirebaseAuthException catch (e) {
      return AuthResult.error(_mapFirebaseAuthError(e));
    } catch (e) {
      return AuthResult.error('Lỗi xác thực lại: $e');
    }
  }

  Future<void> _clearLocalSessionAfterDelete() async {
    UserCloudSyncService().onUserSignedOut();
    try {
      await _googleSignIn.signOut();
    } catch (_) {}

    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_userKey);
    await prefs.remove(_isLoggedInKey);

    _currentUser = null;
    _isLoggedIn = false;
    notifyListeners();
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
    if (providerId.contains('apple')) return 'apple';
    if (providerId.contains('password')) return 'email';
    return providerId;
  }

  String _generateNonce([int length = 32]) {
    const charset =
        '0123456789ABCDEFGHIJKLMNOPQRSTUVXYZabcdefghijklmnopqrstuvwxyz-._';
    final random = Random.secure();
    return List.generate(
      length,
      (_) => charset[random.nextInt(charset.length)],
    ).join();
  }

  String _sha256ofString(String input) {
    final bytes = utf8.encode(input);
    return sha256.convert(bytes).toString();
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
      case 'requires-recent-login':
        return requiresRecentLoginCode;
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
