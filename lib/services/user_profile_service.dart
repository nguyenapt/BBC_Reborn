import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/daily_goal_config.dart';
import '../models/user_learning_profile.dart';
import 'daily_goal_service.dart';
import 'user_cloud_sync_service.dart';

class UserProfileService extends ChangeNotifier {
  static final UserProfileService _instance = UserProfileService._internal();
  factory UserProfileService() => _instance;
  UserProfileService._internal();

  static const String _profileKey = 'user_learning_profile_v1';
  static const String _profileCompletedKey = 'user_profile_completed_v1';

  UserLearningProfile? _profile;
  bool _profileCompleted = false;
  bool _initialized = false;

  UserLearningProfile? get profile => _profile;
  bool get hasCompletedProfile => _profileCompleted;
  EnglishLevel get level => _profile?.level ?? EnglishLevel.intermediate;
  LearningFocus get focus => _profile?.focus ?? LearningFocus.listening;
  String? get recommendedEpisodeId => _profile?.recommendedEpisodeId;

  Future<void> initialize() async {
    if (_initialized) return;
    final prefs = await SharedPreferences.getInstance();
    _profileCompleted = prefs.getBool(_profileCompletedKey) ?? false;
    if (!_profileCompleted) {
      final onboardingDone = prefs.getBool('onboarding_completed') ?? false;
      if (onboardingDone) {
        _profileCompleted = true;
      }
    }
    final raw = prefs.getString(_profileKey);
    if (raw != null && raw.isNotEmpty) {
      try {
        _profile = UserLearningProfile.fromJson(
          Map<String, dynamic>.from(json.decode(raw) as Map),
        );
      } catch (e) {
        debugPrint('UserProfileService load error: $e');
      }
    }
    _initialized = true;
    notifyListeners();
  }

  Future<void> reloadFromStorage() async {
    final prefs = await SharedPreferences.getInstance();
    _profileCompleted = prefs.getBool(_profileCompletedKey) ?? false;
    final raw = prefs.getString(_profileKey);
    if (raw != null && raw.isNotEmpty) {
      try {
        _profile = UserLearningProfile.fromJson(
          Map<String, dynamic>.from(json.decode(raw) as Map),
        );
      } catch (e) {
        debugPrint('UserProfileService reload error: $e');
      }
    } else {
      _profile = null;
    }
    notifyListeners();
  }

  DailyGoalDifficulty defaultDailyGoalDifficulty() {
    return switch (level) {
      EnglishLevel.beginner => DailyGoalDifficulty.easy,
      EnglishLevel.intermediate => DailyGoalDifficulty.normal,
      EnglishLevel.advanced => DailyGoalDifficulty.hard,
    };
  }

  Future<void> saveProfile({
    required EnglishLevel level,
    required LearningFocus focus,
    String? recommendedEpisodeId,
  }) async {
    _profile = UserLearningProfile(
      level: level,
      focus: focus,
      recommendedEpisodeId: recommendedEpisodeId,
      savedAt: DateTime.now(),
    );
    _profileCompleted = true;

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_profileKey, json.encode(_profile!.toJson()));
    await prefs.setBool(_profileCompletedKey, true);

    await DailyGoalService().setDifficulty(defaultDailyGoalDifficulty());
    UserCloudSyncService().schedulePush();
    notifyListeners();
  }
}
