import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'heart_service.dart';

class LearningRewardService {
  static final LearningRewardService _instance = LearningRewardService._internal();
  factory LearningRewardService() => _instance;
  LearningRewardService._internal();

  static const String _dailyGoalRewardDateKey =
      'learning_reward_daily_goal_date_v1';
  static const String _streak7RewardedKey = 'learning_reward_streak7_v1';

  Future<int> onDailyGoalCompleted(int heartReward) async {
    final prefs = await SharedPreferences.getInstance();
    final today = _dateKey(DateTime.now());
    if (prefs.getString(_dailyGoalRewardDateKey) == today) return 0;

    final earned = await HeartService().earnHearts(heartReward);
    if (earned > 0) {
      await prefs.setString(_dailyGoalRewardDateKey, today);
      debugPrint('❤️ Daily goal reward: +$earned heart(s)');
    }
    return earned;
  }

  Future<bool> onStreakMilestone(int streak) async {
    if (streak != 7) return false;
    final prefs = await SharedPreferences.getInstance();
    if (prefs.getBool(_streak7RewardedKey) == true) return false;

    final earned = await HeartService().earnHeart();
    if (earned) {
      await prefs.setBool(_streak7RewardedKey, true);
      debugPrint('❤️ Heart earned for 7-day streak');
    }
    return earned;
  }

  static String _dateKey(DateTime dt) =>
      '${dt.year}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')}';
}
