import 'dart:async';
import 'dart:io';

import 'package:firebase_app_check/firebase_app_check.dart';
import 'package:flutter/foundation.dart';

import 'ai/exceptions.dart';

/// Debug token cố định cho simulator (Debug build) — đăng ký trong Firebase Console.
const String kIosSimulatorAppCheckDebugToken =
    'A1B2C3D4-E5F6-7890-ABCD-EF1234567890';

/// Firebase App Check — phải sẵn sàng trước mọi Callable (aiRequest enforceAppCheck).
class AppCheckService {
  AppCheckService._();
  static final AppCheckService instance = AppCheckService._();

  Future<void>? _activateFuture;
  bool _activated = false;

  Future<void> activate() => _activateFuture ??= _activateImpl();

  Future<void> ensureTokenBeforeCall() async {
    await activate();
    Object? lastError;
    for (var attempt = 0; attempt < 5; attempt++) {
      try {
        if (attempt > 0) {
          await _configureProviders();
        }
        final token = await FirebaseAppCheck.instance.getToken(attempt > 0);
        if (token != null && token.isNotEmpty) {
          return;
        }
      } catch (e) {
        lastError = e;
        debugPrint('AppCheck ensureToken attempt ${attempt + 1}: $e');
      }
      if (attempt < 4) {
        await Future<void>.delayed(Duration(milliseconds: 300 * (attempt + 1)));
      }
    }

    final message = kDebugMode
        ? 'App Check debug token chưa đăng ký. Firebase Console → App Check → '
            'Manage debug tokens → thêm: $kIosSimulatorAppCheckDebugToken'
        : 'App Check verification failed';
    throw AppCheckException(message, lastError);
  }

  Future<void> _activateImpl() async {
    if (kIsWeb || (!Platform.isAndroid && !Platform.isIOS)) {
      return;
    }

    final appCheck = FirebaseAppCheck.instance;

    try {
      await appCheck.setTokenAutoRefreshEnabled(false);
    } catch (e) {
      debugPrint('AppCheck setTokenAutoRefreshEnabled(false): $e');
    }

    await _configureProviders();

    // Workaround race: native factory mặc định deviceCheck trước activate().
    await Future<void>.delayed(const Duration(milliseconds: 50));
    await _configureProviders();

    try {
      await appCheck.setTokenAutoRefreshEnabled(true);
    } catch (e) {
      debugPrint('AppCheck setTokenAutoRefreshEnabled(true): $e');
    }

    _activated = true;

    try {
      final token = await appCheck.getToken(false);
      if (token != null && token.isNotEmpty) {
        debugPrint('✅ App Check token ready');
        return;
      }
    } catch (e) {
      debugPrint('⚠️ App Check initial token: $e');
    }

    if (kDebugMode) {
      debugPrint(
        'Đăng ký debug token trong Firebase Console: $kIosSimulatorAppCheckDebugToken',
      );
    }
  }

  Future<void> _configureProviders() async {
    await FirebaseAppCheck.instance.activate(
      androidProvider:
          kDebugMode ? AndroidProvider.debug : AndroidProvider.playIntegrity,
      appleProvider: kDebugMode
          ? AppleProvider.debug
          : AppleProvider.appAttestWithDeviceCheckFallback,
    );
  }

  bool get isActivated => _activated;
}
