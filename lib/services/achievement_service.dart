import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/achievement.dart';
import 'learning_progress_service.dart';
import 'local_database_service.dart';
import 'vocabulary_practice_service.dart';
import 'user_cloud_sync_service.dart';

class AchievementService extends ChangeNotifier {
  static final AchievementService _instance = AchievementService._internal();
  factory AchievementService() => _instance;
  AchievementService._internal();

  static const String _unlockedKey = 'achievements_unlocked_v1';

  final Set<String> _unlocked = {};
  bool _initialized = false;

  Set<String> get unlockedIds => Set.unmodifiable(_unlocked);

  bool isUnlocked(AchievementId id) => _unlocked.contains(id.name);

  Future<void> initialize() async {
    if (_initialized) return;
    final prefs = await SharedPreferences.getInstance();
    final stored = prefs.getStringList(_unlockedKey) ?? [];
    _unlocked.addAll(stored);
    _initialized = true;
  }

  Future<void> reloadFromStorage() async {
    final prefs = await SharedPreferences.getInstance();
    final stored = prefs.getStringList(_unlockedKey) ?? [];
    _unlocked
      ..clear()
      ..addAll(stored);
    notifyListeners();
  }

  Future<void> evaluateAll() async {
    final progress = LearningProgressService();
    await progress.initialize();

    if (progress.longestStreak >= 7 || progress.currentStreak >= 7) {
      await _unlock(AchievementId.streak7);
    }

    final vocabService = VocabularyPracticeService();
    await vocabService.initialize();
    final masteredCount = vocabService.allStates
        .where((s) => s.repetitions >= 3)
        .length;
    if (masteredCount >= 50) {
      await _unlock(AchievementId.vocab50);
    }

    final completedEpisodes = progress.allProgress
        .where((p) => p.checklistCompletedCount >= 4)
        .length;
    if (completedEpisodes >= 10) {
      await _unlock(AchievementId.episodes10);
    }

    final stats = await LocalDatabaseService().getSpeakingStats();
    if (stats.averageScore >= 80 && stats.totalAttempts >= 5) {
      await _unlock(AchievementId.speaking80);
    }
  }

  Future<void> _unlock(AchievementId id) async {
    if (_unlocked.contains(id.name)) return;
    _unlocked.add(id.name);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(_unlockedKey, _unlocked.toList());
    UserCloudSyncService().schedulePush();
    notifyListeners();
  }
}
