import 'dart:async';

import 'package:flutter/foundation.dart';

import '../services/language_manager.dart';

/// User-visible error messages — never expose hostnames, URLs, Firebase paths,
/// or raw exception text (ClientException / SocketException / uri=…).
class UserFacingError {
  UserFacingError._();

  static final LanguageManager _lm = LanguageManager();

  /// Localized message safe to show in UI / SnackBar.
  static String message(Object? error) {
    final raw = error?.toString() ?? '';
    if (kDebugMode && raw.isNotEmpty) {
      debugPrint('UserFacingError (hidden from UI): $raw');
    }

    if (_isNetworkFailure(error, raw)) {
      return _lm.getText('aiNetworkError');
    }
    return _lm.getText('errorOccurred');
  }

  static bool _isNetworkFailure(Object? error, String raw) {
    if (error is TimeoutException) return true;

    final typeName = error?.runtimeType.toString() ?? '';
    if (typeName.contains('SocketException') ||
        typeName.contains('ClientException') ||
        typeName.contains('HttpException') ||
        typeName.contains('HandshakeException')) {
      return true;
    }

    final lower = raw.toLowerCase();
    const markers = [
      'socketexception',
      'clientexception',
      'failed host lookup',
      'network is unreachable',
      'connection refused',
      'connection reset',
      'connection timed out',
      'timed out',
      'timeout',
      'no address associated with hostname',
      'network_error',
      'network error',
      'errno =',
      'uri=',
      'firebaseio.com',
      'googleapis.com',
      'http://',
      'https://',
    ];
    for (final m in markers) {
      if (lower.contains(m)) return true;
    }
    return false;
  }
}
