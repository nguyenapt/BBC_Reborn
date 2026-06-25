import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/daily_goal_config.dart';
import 'learning_progress_service.dart';
import 'learning_reward_service.dart';
import 'user_cloud_sync_service.dart';

class DailyGoalService extends ChangeNotifier {
  static final DailyGoalService _instance = DailyGoalService._internal();
  factory DailyGoalService() => _instance;
  DailyGoalService._internal();

  static const String _difficultyKey = 'daily_goal_difficulty_v1';
  static const String _todayVocabKey = 'daily_goal_vocab_reviews_v1';
  static const String _todayVocabDateKey = 'daily_goal_vocab_date_v1';
  static const String _celebratedDatePrefsKey = 'daily_goal_celebrated_date_v1';

  DailyGoalDifficulty _difficulty = DailyGoalDifficulty.normal;
  int _todayVocabReviews = 0;
  String? _celebratedDate;
  bool _initialized = false;

  DailyGoalDifficulty get difficulty => _difficulty;
  DailyGoalTargets get targets => DailyGoalTargets.forDifficulty(_difficulty);

  Future<void> initialize() async {
    if (_initialized) return;
    final prefs = await SharedPreferences.getInstance();
    final stored = prefs.getString(_difficultyKey);
    if (stored != null) {
      _difficulty = DailyGoalDifficulty.values.firstWhere(
        (d) => d.name == stored,
        orElse: () => DailyGoalDifficulty.normal,
      );
    }
    _refreshTodayVocabBucket(prefs);
    _celebratedDate = prefs.getString(_celebratedDatePrefsKey);
    _initialized = true;
    notifyListeners();
  }

  Future<void> reloadFromStorage() async {
    final prefs = await SharedPreferences.getInstance();
    final stored = prefs.getString(_difficultyKey);
    if (stored != null) {
      _difficulty = DailyGoalDifficulty.values.firstWhere(
        (d) => d.name == stored,
        orElse: () => DailyGoalDifficulty.normal,
      );
    }
    _refreshTodayVocabBucket(prefs);
    _celebratedDate = prefs.getString(_celebratedDatePrefsKey);
    notifyListeners();
  }

  Future<void> setDifficulty(DailyGoalDifficulty difficulty) async {
    _difficulty = difficulty;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_difficultyKey, difficulty.name);
    UserCloudSyncService().schedulePush();
    notifyListeners();
  }

  int get todayListeningMinutes {
    final ms = LearningProgressService().todayListeningMs;
    return (ms / 60000).floor();
  }

  int get todayVocabReviews => _todayVocabReviews;

  double get listeningProgress {
    final target = targets.listeningMinutes;
    if (target <= 0) return 1;
    return (todayListeningMinutes / target).clamp(0.0, 1.0);
  }

  double get vocabProgress {
    final target = targets.vocabReviews;
    if (target <= 0) return 1;
    return (_todayVocabReviews / target).clamp(0.0, 1.0);
  }

  double get overallProgress {
    final listenDone = listeningProgress >= 1.0 ? 1.0 : listeningProgress;
    final vocabDone = vocabProgress >= 1.0 ? 1.0 : vocabProgress;
    return ((listenDone + vocabDone) / 2).clamp(0.0, 1.0);
  }

  bool get isListeningGoalMet => listeningProgress >= 1.0;
  bool get isVocabGoalMet => vocabProgress >= 1.0;
  bool get isCompletedToday => isListeningGoalMet && isVocabGoalMet;

  bool get celebratedToday {
    final today = _dateKey(DateTime.now());
    return _celebratedDate == today;
  }

  Future<void> recordVocabReview() async {
    final prefs = await SharedPreferences.getInstance();
    _refreshTodayVocabBucket(prefs);
    _todayVocabReviews++;
    await prefs.setInt(_todayVocabKey, _todayVocabReviews);
    await prefs.setString(_todayVocabDateKey, _dateKey(DateTime.now()));
    await _checkCompletion();
    notifyListeners();
  }

  Future<void> onListeningProgressChanged() async {
    await _checkCompletion();
    notifyListeners();
  }

  Future<void> _checkCompletion() async {
    if (!isCompletedToday || celebratedToday) return;
    final prefs = await SharedPreferences.getInstance();
    final today = _dateKey(DateTime.now());
    _celebratedDate = today;
    await prefs.setString(_celebratedDatePrefsKey, today);
    await LearningRewardService().onDailyGoalCompleted();
    notifyListeners();
  }

  void _refreshTodayVocabBucket(SharedPreferences prefs) {
    final today = _dateKey(DateTime.now());
    final storedDate = prefs.getString(_todayVocabDateKey);
    if (storedDate == today) {
      _todayVocabReviews = prefs.getInt(_todayVocabKey) ?? 0;
    } else {
      _todayVocabReviews = 0;
    }
  }

  static String _dateKey(DateTime dt) =>
      '${dt.year}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')}';
}
