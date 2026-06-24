import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/episode.dart';
import '../models/episode_learning_progress.dart';
import 'local_database_service.dart';

class LearningProgressService extends ChangeNotifier {
  static final LearningProgressService _instance =
      LearningProgressService._internal();
  factory LearningProgressService() => _instance;
  LearningProgressService._internal();

  static const String _progressKey = 'episode_learning_progress_v1';
  static const String _streakCurrentKey = 'learning_streak_current_v1';
  static const String _streakLongestKey = 'learning_streak_longest_v1';
  static const String _streakLastActiveKey = 'learning_streak_last_active_v1';
  static const String _todayListeningMsKey = 'learning_today_listening_ms_v1';
  static const String _todayListeningDateKey = 'learning_today_listening_date_v1';
  static const int activeListeningThresholdMs = 180000; // 3 minutes

  final Map<String, EpisodeLearningProgress> _progressByEpisodeId = {};
  int _currentStreak = 0;
  int _longestStreak = 0;
  DateTime? _lastActiveDate;
  int _todayListeningMs = 0;
  bool _initialized = false;
  bool _legacyLearningDetected = false;
  Future<void> _mutationChain = Future.value();

  Future<T> _runMutation<T>(Future<T> Function() action) {
    final run = _mutationChain.then((_) => action());
    _mutationChain = run.then((_) {}, onError: (_) {});
    return run;
  }

  int get currentStreak => _currentStreak;
  int get longestStreak => _longestStreak;
  int get todayListeningMs => _todayListeningMs;

  bool get isActiveToday {
    final today = _dateOnly(DateTime.now());
    return _lastActiveDate != null && _isSameDay(_lastActiveDate!, today);
  }

  Future<void> initialize() async {
    if (_initialized) return;
    await _load();
    _initialized = true;
    notifyListeners();
  }

  static bool _prefsHasNonEmptyPayload(String? raw) {
    if (raw == null || raw.isEmpty || raw == 'null') return false;
    try {
      final decoded = json.decode(raw);
      if (decoded is List) return decoded.isNotEmpty;
      if (decoded is Map) return decoded.isNotEmpty;
    } catch (_) {
      return false;
    }
    return false;
  }

  void _detectLegacyLearningSignals(SharedPreferences prefs) {
    if (_progressByEpisodeId.isNotEmpty ||
        _lastActiveDate != null ||
        _longestStreak > 0) {
      _legacyLearningDetected = true;
      return;
    }

    const legacyKeys = <String>[
      'vocabulary_practice_states_v1',
      'saved_vocabulary_items',
      'saved_vocabularies',
      'saved_grammar_items',
      'favourite_episodes_data',
      'learning_event_counts',
    ];
    for (final key in legacyKeys) {
      if (_prefsHasNonEmptyPayload(prefs.getString(key))) {
        _legacyLearningDetected = true;
        return;
      }
    }

    final onboardingDone = prefs.getBool('onboarding_completed') ?? false;
    final appUsageCount = prefs.getInt('app_usage_count') ?? 0;
    if (onboardingDone && appUsageCount >= 2) {
      _legacyLearningDetected = true;
    }
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_progressKey);
    if (raw != null && raw.isNotEmpty) {
      try {
        final decoded = json.decode(raw);
        if (decoded is Map) {
          _progressByEpisodeId.clear();
          for (final entry in decoded.entries) {
            final value = entry.value;
            if (value is! Map) continue;
            try {
              final progress = EpisodeLearningProgress.fromJson(
                Map<String, dynamic>.from(value),
              );
              if (progress.episodeId.isNotEmpty) {
                _progressByEpisodeId[progress.episodeId] = progress;
              }
            } catch (e) {
              debugPrint('LearningProgressService skip entry: $e');
            }
          }
        }
      } catch (e) {
        debugPrint('LearningProgressService load error: $e');
      }
    }

    _currentStreak = prefs.getInt(_streakCurrentKey) ?? 0;
    _longestStreak = prefs.getInt(_streakLongestKey) ?? 0;
    final lastActive = prefs.getString(_streakLastActiveKey);
    if (lastActive != null) {
      _lastActiveDate = DateTime.tryParse(lastActive);
    }
    _refreshTodayListeningBucket(prefs);
    _detectLegacyLearningSignals(prefs);
    if (_syncStreakDisplayWithCalendar()) {
      await _saveStreak();
    }
  }

  /// Chuỗi chỉ còn hiệu lực nếu học hôm nay hoặc hôm qua. Trả về true nếu đã reset streak.
  bool _syncStreakDisplayWithCalendar() {
    if (_lastActiveDate == null) {
      if (_currentStreak == 0) return false;
      _currentStreak = 0;
      return true;
    }
    final today = _dateOnly(DateTime.now());
    final yesterday = today.subtract(const Duration(days: 1));
    if (_isSameDay(_lastActiveDate!, today) ||
        _isSameDay(_lastActiveDate!, yesterday)) {
      return false;
    }
    if (_currentStreak == 0) return false;
    _currentStreak = 0;
    return true;
  }

  void _refreshTodayListeningBucket(SharedPreferences prefs) {
    final today = _dateKey(DateTime.now());
    final storedDate = prefs.getString(_todayListeningDateKey);
    if (storedDate == today) {
      _todayListeningMs = prefs.getInt(_todayListeningMsKey) ?? 0;
    } else {
      _todayListeningMs = 0;
    }
  }

  Future<void> _saveProgressMap() async {
    final prefs = await SharedPreferences.getInstance();
    final payload = <String, dynamic>{
      for (final e in _progressByEpisodeId.entries) e.key: e.value.toJson(),
    };
    await prefs.setString(_progressKey, json.encode(payload));
  }

  Future<void> _saveStreak() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_streakCurrentKey, _currentStreak);
    await prefs.setInt(_streakLongestKey, _longestStreak);
    if (_lastActiveDate != null) {
      await prefs.setString(
        _streakLastActiveKey,
        _lastActiveDate!.toIso8601String(),
      );
    }
  }

  EpisodeLearningProgress? getProgress(String episodeId) {
    if (episodeId.isEmpty) return null;
    return _progressByEpisodeId[episodeId];
  }

  EpisodeLearningProgress? getProgressForEpisode(Episode episode) {
    final byStorageId = getProgress(episode.resolvedStorageId);
    if (byStorageId != null) return byStorageId;
    final episodeId = episode.id;
    if (episodeId != null &&
        episodeId.isNotEmpty &&
        episodeId != episode.resolvedStorageId) {
      return getProgress(episodeId);
    }
    return null;
  }

  EpisodeLearningProgress? getMostRecentContinue() {
    final candidates = _progressByEpisodeId.values
        .where((p) => p.episodeId.isNotEmpty && p.isInProgress)
        .toList()
      ..sort((a, b) => b.lastOpenedAt.compareTo(a.lastOpenedAt));
    return candidates.isEmpty ? null : candidates.first;
  }

  /// User đã từng học hoặc đã dùng app trước Phase 1 (upgrade-safe).
  bool get hasEverLearned =>
      _legacyLearningDetected ||
      _progressByEpisodeId.isNotEmpty ||
      _lastActiveDate != null ||
      _longestStreak > 0;

  static String episodeKey(Episode episode) => episode.resolvedStorageId;

  static Episode episodeFromProgress(EpisodeLearningProgress progress) {
    return Episode(
      actor: '',
      category: progress.category,
      duration: '0:00',
      publishedDate: progress.lastOpenedAt,
      episodeName: progress.episodeTitle,
      transcript: '',
      thumbImage: progress.thumbImage ?? '',
      id: progress.episodeId,
    );
  }

  Future<Episode?> resolveEpisodeForProgress(
    EpisodeLearningProgress progress,
  ) async {
    final fromDb = await LocalDatabaseService().getEpisodeById(progress.episodeId);
    if (fromDb != null) return fromDb;
    return episodeFromProgress(progress);
  }

  Future<void> flushEpisodeState({
    required Episode episode,
    required int positionMs,
    required int totalDurationMs,
    required int tabIndex,
  }) {
    return _runMutation(() async {
      final id = episodeKey(episode);
      if (id.isEmpty) return;

      final listenedComplete = totalDurationMs > 0 &&
          positionMs >= (totalDurationMs * 0.92).round();

      final existing = _progressByEpisodeId[id];
      var updated = (existing ??
              EpisodeLearningProgress(
                episodeId: id,
                episodeTitle: episode.episodeName,
                category: episode.category,
                thumbImage: episode.thumbImage,
                lastOpenedAt: DateTime.now(),
              ))
          .copyWith(
        episodeTitle: episode.episodeName,
        category: episode.category,
        thumbImage: episode.thumbImage,
        lastPositionMs: positionMs,
        totalDurationMs: totalDurationMs,
        lastTabIndex: tabIndex,
        listenedComplete:
            listenedComplete || (existing?.listenedComplete ?? false),
        lastOpenedAt: DateTime.now(),
      );

      if (tabIndex == 2) {
        updated = updated.copyWith(vocabViewed: true);
      } else if (tabIndex == 3) {
        updated = updated.copyWith(questionsViewed: true);
      }

      _progressByEpisodeId[id] = updated;
      await _saveProgressMap();

      if (positionMs >= 15000) {
        await _recordActivityImpl(
          LearningActivityType.listening,
          listeningDeltaMs: 5000,
        );
      }
      notifyListeners();
    });
  }

  Future<void> touchEpisode(Episode episode) {
    return _runMutation(() async {
      final id = episodeKey(episode);
      if (id.isEmpty) return;
      final existing = _progressByEpisodeId[id];
      final updated = (existing ??
              EpisodeLearningProgress(
                episodeId: id,
                episodeTitle: episode.episodeName,
                category: episode.category,
                thumbImage: episode.thumbImage,
                lastOpenedAt: DateTime.now(),
              ))
          .copyWith(
        episodeTitle: episode.episodeName,
        category: episode.category,
        thumbImage: episode.thumbImage,
        lastOpenedAt: DateTime.now(),
      );
      _progressByEpisodeId[id] = updated;
      await _saveProgressMap();
      notifyListeners();
    });
  }

  Future<void> updateListeningProgress({
    required Episode episode,
    required int positionMs,
    required int totalDurationMs,
  }) {
    return _runMutation(() async {
      final id = episodeKey(episode);
      if (id.isEmpty) return;

      final listenedComplete = totalDurationMs > 0 &&
          positionMs >= (totalDurationMs * 0.92).round();

      final existing = _progressByEpisodeId[id];
      final updated = (existing ??
              EpisodeLearningProgress(
                episodeId: id,
                episodeTitle: episode.episodeName,
                category: episode.category,
                thumbImage: episode.thumbImage,
                lastOpenedAt: DateTime.now(),
              ))
          .copyWith(
        episodeTitle: episode.episodeName,
        category: episode.category,
        thumbImage: episode.thumbImage,
        lastPositionMs: positionMs,
        totalDurationMs: totalDurationMs,
        listenedComplete:
            listenedComplete || (existing?.listenedComplete ?? false),
        lastOpenedAt: DateTime.now(),
      );
      _progressByEpisodeId[id] = updated;
      await _saveProgressMap();

      if (positionMs >= 15000) {
        await _recordActivityImpl(
          LearningActivityType.listening,
          listeningDeltaMs: 5000,
        );
      }
      notifyListeners();
    });
  }

  Future<void> updateTabIndex({
    required Episode episode,
    required int tabIndex,
  }) {
    return _runMutation(() async {
      final id = episodeKey(episode);
      if (id.isEmpty) return;

      final existing = _progressByEpisodeId[id];
      var updated = (existing ??
              EpisodeLearningProgress(
                episodeId: id,
                episodeTitle: episode.episodeName,
                category: episode.category,
                thumbImage: episode.thumbImage,
                lastOpenedAt: DateTime.now(),
              ))
          .copyWith(
        lastTabIndex: tabIndex,
        lastOpenedAt: DateTime.now(),
      );

      if (tabIndex == 2) {
        updated = updated.copyWith(vocabViewed: true);
      } else if (tabIndex == 3) {
        updated = updated.copyWith(questionsViewed: true);
      }

      _progressByEpisodeId[id] = updated;
      await _saveProgressMap();
      notifyListeners();
    });
  }

  Future<void> markTranscriptViewed(Episode episode) {
    return _runMutation(() async {
      final id = episodeKey(episode);
      if (id.isEmpty) return;

      final existing = _progressByEpisodeId[id];
      if (existing?.transcriptViewed == true) return;

      final updated = (existing ??
              EpisodeLearningProgress(
                episodeId: id,
                episodeTitle: episode.episodeName,
                category: episode.category,
                thumbImage: episode.thumbImage,
                lastOpenedAt: DateTime.now(),
              ))
          .copyWith(
        episodeTitle: episode.episodeName,
        category: episode.category,
        thumbImage: episode.thumbImage,
        transcriptViewed: true,
        lastOpenedAt: DateTime.now(),
      );
      _progressByEpisodeId[id] = updated;
      await _saveProgressMap();
      notifyListeners();
    });
  }

  Future<void> markSpeakingDone(Episode episode) {
    return _runMutation(() async {
      final id = episodeKey(episode);
      if (id.isEmpty) return;
      final existing = _progressByEpisodeId[id];
      if (existing?.speakingDone == true) return;

      final updated = (existing ??
              EpisodeLearningProgress(
                episodeId: id,
                episodeTitle: episode.episodeName,
                category: episode.category,
                thumbImage: episode.thumbImage,
                lastOpenedAt: DateTime.now(),
              ))
          .copyWith(speakingDone: true, lastOpenedAt: DateTime.now());
      _progressByEpisodeId[id] = updated;
      await _saveProgressMap();
      await _recordActivityImpl(LearningActivityType.speaking);
      notifyListeners();
    });
  }

  Future<void> recordActivity(
    LearningActivityType type, {
    int listeningDeltaMs = 0,
  }) {
    return _runMutation(
      () => _recordActivityImpl(type, listeningDeltaMs: listeningDeltaMs),
    );
  }

  Future<void> _recordActivityImpl(
    LearningActivityType type, {
    int listeningDeltaMs = 0,
  }) async {
    if (listeningDeltaMs > 0) {
      await _addListeningMs(listeningDeltaMs);
    }

    final qualifies = switch (type) {
      LearningActivityType.listening =>
        _todayListeningMs >= activeListeningThresholdMs,
      LearningActivityType.vocabReview => true,
      LearningActivityType.grammarReview => true,
      LearningActivityType.speaking => true,
    };

    if (!qualifies && type != LearningActivityType.listening) {
      await _markActiveDay();
      return;
    }
    if (type == LearningActivityType.listening &&
        _todayListeningMs < activeListeningThresholdMs) {
      return;
    }
    await _markActiveDay();
  }

  Future<void> _addListeningMs(int deltaMs) async {
    final prefs = await SharedPreferences.getInstance();
    _refreshTodayListeningBucket(prefs);
    _todayListeningMs += deltaMs;
    await prefs.setInt(_todayListeningMsKey, _todayListeningMs);
    await prefs.setString(_todayListeningDateKey, _dateKey(DateTime.now()));
  }

  Future<void> _markActiveDay() async {
    final today = _dateOnly(DateTime.now());
    if (_lastActiveDate != null && _isSameDay(_lastActiveDate!, today)) {
      return;
    }

    if (_lastActiveDate == null) {
      _currentStreak = 1;
    } else {
      final yesterday = today.subtract(const Duration(days: 1));
      if (_isSameDay(_lastActiveDate!, yesterday)) {
        _currentStreak += 1;
      } else if (!_isSameDay(_lastActiveDate!, today)) {
        _currentStreak = 1;
      }
    }

    _lastActiveDate = today;
    if (_currentStreak > _longestStreak) {
      _longestStreak = _currentStreak;
    }
    await _saveStreak();
    notifyListeners();
  }

  static DateTime _dateOnly(DateTime dt) => DateTime(dt.year, dt.month, dt.day);

  static bool _isSameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;

  static String _dateKey(DateTime dt) =>
      '${dt.year}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')}';
}
