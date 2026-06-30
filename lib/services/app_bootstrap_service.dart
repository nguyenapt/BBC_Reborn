import 'dart:async';
import 'dart:io';

import 'package:firebase_app_check/firebase_app_check.dart';
import 'package:flutter/foundation.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

import 'achievement_service.dart';
import 'admob_service.dart';
import 'audio_player_service.dart';
import 'auth_service.dart';
import 'consent_service.dart';
import 'daily_goal_service.dart';
import 'heart_service.dart';
import 'learning_analytics_service.dart';
import 'learning_progress_service.dart';
import 'push_notification_service.dart';
import 'saved_grammar_service.dart';
import 'speaking_review_service.dart';
import 'user_cloud_sync_service.dart';
import 'user_profile_service.dart';
import 'user_service.dart';
import 'vocabulary_practice_service.dart';
import 'vocabulary_service.dart';

/// Khởi tạo app theo 2 phase:
/// - Critical path (chặn navigation từ splash): service local.
/// - Deferred (nền sau khi vào app): App Check, mạng, ads, sync, push permission.
class AppBootstrapService {
  AppBootstrapService._();
  static final AppBootstrapService instance = AppBootstrapService._();

  static bool get _isMobile =>
      !kIsWeb && (Platform.isAndroid || Platform.isIOS);

  Future<void>? _criticalFuture;
  Future<void>? _deferredFuture;
  bool _readyForNavigation = false;

  bool get isReadyForNavigation => _readyForNavigation;

  /// Gọi từ splash — chờ critical path, deferred chạy nền.
  Future<void> ensureReadyForNavigation() async {
    if (_readyForNavigation) return;
    await (_criticalFuture ??= _runCriticalPath());
    _readyForNavigation = true;
    unawaited(_deferredFuture ??= _runDeferredWork());
  }

  Future<void> _runCriticalPath() async {
    try {
      debugPrint('🔧 Bootstrap critical path...');
      await _initLocalServices();
      debugPrint('✅ Bootstrap critical path done');
    } catch (e) {
      debugPrint('❌ Bootstrap critical path error: $e');
    }
  }

  /// App Check trước cloud sync; achievement sau sync (không chặn UI).
  Future<void> _runMobileFollowUp() async {
    try {
      await _initFirebaseAppCheck();
      await UserCloudSyncService().syncInBackground();
      await AchievementService().evaluateAll();
    } catch (e) {
      debugPrint('❌ Mobile follow-up error: $e');
    }
  }

  Future<void> _initFirebaseAppCheck() async {
    try {
      await FirebaseAppCheck.instance.activate(
        androidProvider:
            kDebugMode ? AndroidProvider.debug : AndroidProvider.playIntegrity,
        appleProvider:
            kDebugMode ? AppleProvider.debug : AppleProvider.appAttest,
      );
      if (kDebugMode) {
        try {
          await FirebaseAppCheck.instance.getToken(true);
          debugPrint('✅ App Check debug token OK');
        } catch (e) {
          debugPrint(
            '⚠️ App Check chưa có debug token. Mở Logcat, filter '
            '"DebugAppCheckProvider", copy UUID → Firebase Console → '
            'App Check → Manage debug tokens → Add.',
          );
          debugPrint('   Chi tiết: $e');
        }
      }
    } catch (e) {
      debugPrint('❌ Firebase App Check error: $e');
    }
  }

  Future<void> _initLocalServices() async {
    await UserService().initialize();
    await AuthService().initialize();

    await Future.wait([
      HeartService().initialize(),
      VocabularyService().initialize(),
      LearningAnalyticsService().initialize(),
      LearningProgressService().initialize(),
      VocabularyPracticeService().initialize(),
      UserProfileService().initialize(),
      DailyGoalService().initialize(),
      UserCloudSyncService().initialize(),
    ]);

    await SavedGrammarService().initialize();
    await SpeakingReviewService().initialize();

    await AudioPlayerService().initialize();
    await AchievementService().initialize();

    debugPrint('✅ Local services initialized');
  }

  Future<void> _runDeferredWork() async {
    try {
      debugPrint('🔧 Bootstrap deferred work...');

      if (_isMobile) {
        await Future.wait([
          _initPushCore(),
          _initConsentAndAds(),
        ]);
        unawaited(_completePushSetup());
        unawaited(_runMobileFollowUp());
      }

      debugPrint('✅ Bootstrap deferred work scheduled');
    } catch (e) {
      debugPrint('❌ Bootstrap deferred work error: $e');
    }
  }

  Future<void> _initPushCore() async {
    try {
      await PushNotificationService.instance.initialize(
        requestPermissions: false,
        subscribeToTopics: false,
      );
    } catch (e) {
      debugPrint('❌ Push core init error: $e');
    }
  }

  Future<void> _completePushSetup() async {
    try {
      await PushNotificationService.instance.completePermissionAndTopicSetup();
    } catch (e) {
      debugPrint('❌ Push permission/topic setup error: $e');
    }
  }

  Future<void> _initConsentAndAds() async {
    final consentService = ConsentService();
    try {
      debugPrint('🛡️ Running UMP consent flow...');
      await consentService.initializeConsentFlow();
      debugPrint(
        '🛡️ UMP completed. canRequestAds=${consentService.canRequestAds}, '
        'status=${consentService.consentStatus}',
      );

      if (consentService.canRequestAds) {
        debugPrint('📱 Initializing MobileAds...');
        await MobileAds.instance.initialize();
        debugPrint('✅ MobileAds initialized');
        _scheduleAdPreload();
      } else {
        debugPrint('⚠️ MobileAds init skipped — consent not granted');
      }
    } catch (e) {
      debugPrint('❌ Consent/ads init error: $e');
    }
  }

  void _scheduleAdPreload() {
    Future.delayed(const Duration(milliseconds: 1200), () {
      if (!ConsentService().canRequestAds) return;
      AdMobService().createInterstitialAd();
      AdMobService().createRewardedAd();
      debugPrint('✅ Ads preloaded (deferred)');
    });
  }
}
