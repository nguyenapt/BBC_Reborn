import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:firebase_auth/firebase_auth.dart' as fb;
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import '../models/daily_activity_summary.dart';
import 'achievement_service.dart';
import 'api_daily_cache_service.dart';
import 'daily_goal_service.dart';
import 'learning_progress_service.dart';
import 'saved_grammar_service.dart';
import 'speaking_review_service.dart';
import 'storage_service.dart';
import 'user_profile_service.dart';
import 'user_service.dart';
import 'vocabulary_practice_service.dart';
import 'vocabulary_service.dart';

/// Đồng bộ dữ liệu học tập lên RTDB `users/{firebaseUid}`.
/// Chỉ hoạt động khi đã đăng nhập Firebase — user chưa login giữ nguyên local-only.
class UserCloudSyncService {
  static const int schemaVersion = 1;
  static const String _legacyBaseUrl = 'https://bbc-listening-english.firebaseio.com';
  static const Duration _debounceDelay = Duration(seconds: 3);

  static final UserCloudSyncService _instance = UserCloudSyncService._internal();
  factory UserCloudSyncService() => _instance;
  UserCloudSyncService._internal();

  Timer? _pushTimer;
  bool _syncing = false;
  String? _lastSyncedUid;
  bool _initialized = false;

  static bool get cloudAvailable =>
      !kIsWeb && (Platform.isAndroid || Platform.isIOS);

  String? get _uid => fb.FirebaseAuth.instance.currentUser?.uid;

  Future<void> initialize() async {
    if (_initialized || !cloudAvailable) return;
    _initialized = true;
  }

  /// Đồng bộ RTDB nền — không chặn cold start.
  Future<void> syncInBackground() async {
    if (!cloudAvailable) return;
    final uid = _uid;
    if (uid == null || uid == _lastSyncedUid) return;
    try {
      await syncOnLogin(uid);
    } catch (e) {
      debugPrint('UserCloudSyncService.syncInBackground error: $e');
    }
  }

  void onUserSignedOut() {
    _pushTimer?.cancel();
    _lastSyncedUid = null;
  }

  void schedulePush() {
    if (!cloudAvailable || _uid == null || _syncing) return;
    _pushTimer?.cancel();
    _pushTimer = Timer(_debounceDelay, () {
      unawaited(_pushIfSignedIn());
    });
  }

  Future<void> syncOnLogin([String? uid]) async {
    final effectiveUid = uid ?? _uid;
    if (!cloudAvailable || effectiveUid == null) return;
    if (_syncing) return;

    _syncing = true;
    _pushTimer?.cancel();
    try {
      await _migrateLegacyFavouritesIntoLocal();
      final local = await _collectLocalSnapshot();
      final cloud = await _pullCloudSnapshot(effectiveUid);
      final merged = _mergeSnapshots(local, cloud);
      await _applySnapshotToLocal(merged);
      if (cloud != null || _snapshotHasContent(merged)) {
        await _pushSnapshot(effectiveUid, merged);
      } else {
        debugPrint(
          'UserCloudSyncService: skip push — cloud unavailable and local empty',
        );
      }
      _lastSyncedUid = effectiveUid;
      debugPrint(
        'UserCloudSyncService: synced for $effectiveUid '
        '(vocab=${_asJsonList(merged['vocabularies']).length}, '
        'favourites=${_asJsonList(merged['favourites']).length})',
      );
    } catch (e, st) {
      debugPrint('UserCloudSyncService syncOnLogin error: $e\n$st');
    } finally {
      _syncing = false;
    }
  }

  Future<void> _pushIfSignedIn() async {
    final uid = _uid;
    if (uid == null || _syncing) return;
    try {
      final snapshot = await _collectLocalSnapshot();
      await _pushSnapshot(uid, snapshot);
    } catch (e) {
      debugPrint('UserCloudSyncService push error: $e');
    }
  }

  Future<Map<String, dynamic>> _collectLocalSnapshot() async {
    final prefs = await SharedPreferences.getInstance();
    final favourites = await StorageService().getFavouriteEpisodes();

    Map<String, dynamic>? episodeProgress;
    final progressRaw = prefs.getString('episode_learning_progress_v1');
    if (progressRaw != null && progressRaw.isNotEmpty) {
      episodeProgress = Map<String, dynamic>.from(json.decode(progressRaw) as Map);
    }

    Map<String, dynamic>? dailyHistory;
    final historyRaw = prefs.getString('learning_daily_history_v1');
    if (historyRaw != null && historyRaw.isNotEmpty) {
      dailyHistory = Map<String, dynamic>.from(json.decode(historyRaw) as Map);
    }

    List<dynamic>? vocabItems;
    final vocabRaw = prefs.getString('saved_vocabulary_items');
    if (vocabRaw != null && vocabRaw.isNotEmpty) {
      vocabItems = json.decode(vocabRaw) as List<dynamic>;
    }

    List<dynamic>? vocabPractice;
    final practiceRaw = prefs.getString('vocabulary_practice_states_v1');
    if (practiceRaw != null && practiceRaw.isNotEmpty) {
      vocabPractice = json.decode(practiceRaw) as List<dynamic>;
    }

    List<dynamic>? grammar;
    final grammarRaw = prefs.getString('saved_grammar_items');
    if (grammarRaw != null && grammarRaw.isNotEmpty) {
      grammar = json.decode(grammarRaw) as List<dynamic>;
    }

    List<dynamic>? speakingReview;
    final speakingRaw = prefs.getString('speaking_review_items_v1');
    if (speakingRaw != null && speakingRaw.isNotEmpty) {
      speakingReview = json.decode(speakingRaw) as List<dynamic>;
    }

    Map<String, dynamic>? profile;
    final profileRaw = prefs.getString('user_learning_profile_v1');
    if (profileRaw != null && profileRaw.isNotEmpty) {
      profile = Map<String, dynamic>.from(json.decode(profileRaw) as Map);
    }

    return {
      'meta': {
        'version': schemaVersion,
        'updatedAt': DateTime.now().toUtc().toIso8601String(),
        'anonymousId': UserService().userId,
      },
      'profile': profile,
      'settings': {
        'profileCompleted': prefs.getBool('user_profile_completed_v1') ?? false,
        'dailyGoalDifficulty': prefs.getString('daily_goal_difficulty_v1'),
      },
      'learning': {
        'streak': {
          'current': prefs.getInt('learning_streak_current_v1') ?? 0,
          'longest': prefs.getInt('learning_streak_longest_v1') ?? 0,
          'lastActive': prefs.getString('learning_streak_last_active_v1'),
        },
        if (episodeProgress != null) 'episodeProgress': episodeProgress,
        if (dailyHistory != null) 'dailyHistory': dailyHistory,
      },
      'favourites': favourites.map((e) => e.toJson()).toList(),
      if (vocabItems != null) 'vocabularies': vocabItems,
      if (vocabPractice != null) 'vocabPractice': vocabPractice,
      if (grammar != null) 'grammar': grammar,
      if (speakingReview != null) 'speakingReview': speakingReview,
      'achievements': prefs.getStringList('achievements_unlocked_v1') ?? [],
    };
  }

  Future<Map<String, dynamic>?> _pullCloudSnapshot(String uid) async {
    final ref = FirebaseDatabase.instance.ref('users/$uid');
    final event = await ref.get();
    if (!event.exists || event.value == null) return null;
    if (event.value is Map) {
      final deep = _deepNormalizeJson(event.value);
      if (deep is Map<String, dynamic>) {
        return _normalizeSnapshot(deep);
      }
    }
    return null;
  }

  /// Chuyển `_Map<Object?, Object?>` từ Firebase sang `Map<String, dynamic>` (đệ quy).
  static dynamic _deepNormalizeJson(dynamic value) {
    if (value is Map) {
      final out = <String, dynamic>{};
      value.forEach((key, child) {
        out[key.toString()] = _deepNormalizeJson(child);
      });
      return out;
    }
    if (value is List) {
      return value.map(_deepNormalizeJson).toList();
    }
    return value;
  }

  static Map<String, dynamic>? _asJsonMap(dynamic value) {
    if (value == null) return null;
    if (value is Map<String, dynamic>) return value;
    if (value is Map) {
      return Map<String, dynamic>.from(
        value.map((k, v) => MapEntry(k.toString(), _deepNormalizeJson(v))),
      );
    }
    return null;
  }

  /// RTDB lưu array thành map `{0: ..., 1: ...}` — chuẩn hóa về List.
  static List<dynamic> _asJsonList(dynamic value) {
    if (value == null) return [];
    if (value is List) {
      return value.map(_deepNormalizeJson).toList();
    }
    if (value is Map) {
      final keys = value.keys.map((k) => k.toString()).toList()
        ..sort((a, b) {
          final ai = int.tryParse(a);
          final bi = int.tryParse(b);
          if (ai != null && bi != null) return ai.compareTo(bi);
          return a.compareTo(b);
        });
      return [
        for (final key in keys)
          if (value[key] != null) _deepNormalizeJson(value[key]),
      ];
    }
    return [];
  }

  static Map<String, dynamic> _normalizeSnapshot(Map<String, dynamic> raw) {
    final out = Map<String, dynamic>.from(raw);
    out['favourites'] = _asJsonList(raw['favourites']);
    out['vocabularies'] = _asJsonList(raw['vocabularies']);
    out['vocabPractice'] = _asJsonList(raw['vocabPractice']);
    out['grammar'] = _asJsonList(raw['grammar']);
    out['speakingReview'] = _asJsonList(raw['speakingReview']);
    out['achievements'] = _asJsonList(raw['achievements']);
    final learning = _asJsonMap(raw['learning']);
    if (learning != null) out['learning'] = learning;
    final settings = _asJsonMap(raw['settings']);
    if (settings != null) out['settings'] = settings;
    final profile = _asJsonMap(raw['profile']);
    if (profile != null) out['profile'] = profile;
    final meta = _asJsonMap(raw['meta']);
    if (meta != null) out['meta'] = meta;
    return out;
  }

  static bool _snapshotHasContent(Map<String, dynamic> snapshot) {
    if (_asJsonList(snapshot['favourites']).isNotEmpty) return true;
    if (_asJsonList(snapshot['vocabularies']).isNotEmpty) return true;
    if (_asJsonList(snapshot['vocabPractice']).isNotEmpty) return true;
    if (_asJsonList(snapshot['grammar']).isNotEmpty) return true;
    if (_asJsonList(snapshot['speakingReview']).isNotEmpty) return true;
    if (_asJsonList(snapshot['achievements']).isNotEmpty) return true;
    final learning = snapshot['learning'];
    if (learning is Map) {
      final progress = learning['episodeProgress'];
      if (progress is Map && progress.isNotEmpty) return true;
    }
    return false;
  }

  Future<void> _pushSnapshot(String uid, Map<String, dynamic> snapshot) async {
    final payload = Map<String, dynamic>.from(snapshot);
    payload['meta'] = {
      ...(_asJsonMap(payload['meta']) ?? {}),
      'version': schemaVersion,
      'updatedAt': DateTime.now().toUtc().toIso8601String(),
      'anonymousId': UserService().userId,
    };
    await FirebaseDatabase.instance.ref('users/$uid').set(payload);
  }

  Map<String, dynamic> _mergeSnapshots(
    Map<String, dynamic> local,
    Map<String, dynamic>? cloud,
  ) {
    if (cloud == null || cloud.isEmpty) return local;

    final merged = Map<String, dynamic>.from(local);

    merged['profile'] = _mergeProfile(
      _asJsonMap(local['profile']),
      _asJsonMap(cloud['profile']),
      localSettings: _asJsonMap(local['settings']),
      cloudSettings: _asJsonMap(cloud['settings']),
    );

    merged['settings'] = _mergeSettings(
      _asJsonMap(local['settings']),
      _asJsonMap(cloud['settings']),
    );

    merged['learning'] = _mergeLearning(
      _asJsonMap(local['learning']) ?? {},
      _asJsonMap(cloud['learning']) ?? {},
    );

    merged['favourites'] = _mergeFavourites(
      _asJsonList(local['favourites']),
      _asJsonList(cloud['favourites']),
    );

    merged['vocabularies'] = _mergeByKey(
      _asJsonList(local['vocabularies']),
      _asJsonList(cloud['vocabularies']),
      keyOf: (m) => (m['vocab'] as String? ?? '').trim().toLowerCase(),
    );

    merged['vocabPractice'] = _mergeByKey(
      _asJsonList(local['vocabPractice']),
      _asJsonList(cloud['vocabPractice']),
      keyOf: (m) => m['key'] as String? ?? '',
      newerOf: (a, b) {
        final aDate = _parseDate(a['lastReviewedAt']);
        final bDate = _parseDate(b['lastReviewedAt']);
        if (aDate == null) return b;
        if (bDate == null) return a;
        return aDate.isAfter(bDate) ? a : b;
      },
    );

    merged['grammar'] = _mergeByKey(
      _asJsonList(local['grammar']),
      _asJsonList(cloud['grammar']),
      keyOf: (m) => m['id'] as String? ?? '',
    );

    merged['speakingReview'] = _mergeByKey(
      _asJsonList(local['speakingReview']),
      _asJsonList(cloud['speakingReview']),
      keyOf: (m) => m['id'] as String? ?? '',
      newerOf: (a, b) {
        final aDate = _parseDate(a['lastAttemptAt']);
        final bDate = _parseDate(b['lastAttemptAt']);
        if (aDate == null) return b;
        if (bDate == null) return a;
        return aDate.isAfter(bDate) ? a : b;
      },
    );

    merged['achievements'] = {
      for (final id in [
        ..._asJsonList(local['achievements']).map((e) => e.toString()),
        ..._asJsonList(cloud['achievements']).map((e) => e.toString()),
      ])
        id: true,
    }.keys.toList();

    return merged;
  }

  Map<String, dynamic>? _mergeProfile(
    Map<String, dynamic>? local,
    Map<String, dynamic>? cloud, {
    Map<String, dynamic>? localSettings,
    Map<String, dynamic>? cloudSettings,
  }) {
    final localDone = localSettings?['profileCompleted'] == true;
    final cloudDone = cloudSettings?['profileCompleted'] == true;
    if (local != null && localDone) return local;
    if (cloud != null && cloudDone) return cloud;
    if (local != null) return local;
    return cloud;
  }

  Map<String, dynamic> _mergeSettings(
    Map<String, dynamic>? local,
    Map<String, dynamic>? cloud,
  ) {
    final l = Map<String, dynamic>.from(local ?? {});
    final c = cloud ?? {};
    if (l['dailyGoalDifficulty'] == null && c['dailyGoalDifficulty'] != null) {
      l['dailyGoalDifficulty'] = c['dailyGoalDifficulty'];
    }
    l['profileCompleted'] =
        (l['profileCompleted'] == true) || (c['profileCompleted'] == true);
    return l;
  }

  Map<String, dynamic> _mergeLearning(
    Map<String, dynamic> local,
    Map<String, dynamic> cloud,
  ) {
    final merged = Map<String, dynamic>.from(local);
    final localStreak = _asJsonMap(local['streak']) ?? {};
    final cloudStreak = _asJsonMap(cloud['streak']) ?? {};

    merged['streak'] = {
      'current': _maxInt(localStreak['current'], cloudStreak['current']),
      'longest': _maxInt(localStreak['longest'], cloudStreak['longest']),
      'lastActive': _latestIso(
        localStreak['lastActive'] as String?,
        cloudStreak['lastActive'] as String?,
      ),
    };

    merged['episodeProgress'] = _mergeEpisodeProgress(
      _asJsonMap(local['episodeProgress']) ?? {},
      _asJsonMap(cloud['episodeProgress']) ?? {},
    );

    merged['dailyHistory'] = _mergeDailyHistory(
      _asJsonMap(local['dailyHistory']) ?? {},
      _asJsonMap(cloud['dailyHistory']) ?? {},
    );

    return merged;
  }

  Map<String, dynamic> _mergeEpisodeProgress(
    Map<String, dynamic> local,
    Map<String, dynamic> cloud,
  ) {
    final merged = Map<String, dynamic>.from(local);
    cloud.forEach((id, cloudEntry) {
      if (cloudEntry is! Map) return;
      final localEntry = merged[id];
      if (localEntry is! Map) {
        merged[id] = _asJsonMap(cloudEntry) ?? cloudEntry;
        return;
      }
      final localMap = _asJsonMap(localEntry) ?? {};
      final cloudMap = _asJsonMap(cloudEntry) ?? {};
      final localDate = _parseDate(localMap['lastOpenedAt']);
      final cloudDate = _parseDate(cloudMap['lastOpenedAt']);
      if (localDate == null) {
        merged[id] = cloudMap;
      } else if (cloudDate == null || cloudDate.isAfter(localDate)) {
        merged[id] = cloudMap;
      }
    });
    return merged;
  }

  Map<String, dynamic> _mergeDailyHistory(
    Map<String, dynamic> local,
    Map<String, dynamic> cloud,
  ) {
    final merged = Map<String, dynamic>.from(local);
    cloud.forEach((dateKey, cloudEntry) {
      if (cloudEntry is! Map) return;
      final localEntry = merged[dateKey];
      if (localEntry is! Map) {
        merged[dateKey] = _asJsonMap(cloudEntry) ?? cloudEntry;
        return;
      }
      try {
        final localSummary = DailyActivitySummary.fromJson(
          _asJsonMap(localEntry) ?? {},
        );
        final cloudSummary = DailyActivitySummary.fromJson(
          _asJsonMap(cloudEntry) ?? {},
        );
        merged[dateKey] = localSummary.copyWith(
          listeningMs: localSummary.listeningMs + cloudSummary.listeningMs,
          vocabReviews: localSummary.vocabReviews + cloudSummary.vocabReviews,
          grammarReviews:
              localSummary.grammarReviews + cloudSummary.grammarReviews,
          speakingAttempts:
              localSummary.speakingAttempts + cloudSummary.speakingAttempts,
          speakingScoreSum:
              localSummary.speakingScoreSum + cloudSummary.speakingScoreSum,
        ).toJson();
      } catch (_) {
        merged[dateKey] = cloudEntry;
      }
    });
    return merged;
  }

  List<dynamic> _mergeFavourites(List<dynamic> local, List<dynamic> cloud) {
    final byId = <String, Map<String, dynamic>>{};
    for (final entry in [...local, ...cloud]) {
      final map = _asJsonMap(entry);
      if (map == null) continue;
      final id = map['id'] as String?;
      if (id == null || id.isEmpty) continue;
      final existing = byId[id];
      if (existing == null) {
        byId[id] = map;
        continue;
      }
      final existingDate = _parseDate(existing['savedAt']);
      final newDate = _parseDate(map['savedAt']);
      if (existingDate == null ||
          (newDate != null && newDate.isAfter(existingDate))) {
        byId[id] = map;
      }
    }
    return byId.values.toList();
  }

  List<dynamic> _mergeByKey(
    List<dynamic> local,
    List<dynamic> cloud, {
    required String Function(Map<String, dynamic>) keyOf,
    Map<String, dynamic> Function(
      Map<String, dynamic>,
      Map<String, dynamic>,
    )? newerOf,
  }) {
    final byKey = <String, Map<String, dynamic>>{};
    for (final entry in [...local, ...cloud]) {
      final map = _asJsonMap(entry);
      if (map == null) continue;
      final key = keyOf(map);
      if (key.isEmpty) continue;
      final existing = byKey[key];
      if (existing == null) {
        byKey[key] = map;
      } else if (newerOf != null) {
        byKey[key] = newerOf(existing, map);
      } else {
        byKey[key] = map;
      }
    }
    return byKey.values.toList();
  }

  Future<void> _applySnapshotToLocal(Map<String, dynamic> snapshot) async {
    final prefs = await SharedPreferences.getInstance();

    final settings = _asJsonMap(snapshot['settings']) ?? {};
    if (settings['profileCompleted'] == true) {
      await prefs.setBool('user_profile_completed_v1', true);
    }
    final difficulty = settings['dailyGoalDifficulty'] as String?;
    if (difficulty != null && difficulty.isNotEmpty) {
      await prefs.setString('daily_goal_difficulty_v1', difficulty);
    }

    final profile = _asJsonMap(snapshot['profile']);
    if (profile != null) {
      await prefs.setString('user_learning_profile_v1', json.encode(profile));
    }

    final learning = _asJsonMap(snapshot['learning']) ?? {};
    final streak = _asJsonMap(learning['streak']) ?? {};
    await prefs.setInt(
      'learning_streak_current_v1',
      (streak['current'] as num?)?.toInt() ?? 0,
    );
    await prefs.setInt(
      'learning_streak_longest_v1',
      (streak['longest'] as num?)?.toInt() ?? 0,
    );
    final lastActive = streak['lastActive'] as String?;
    if (lastActive != null && lastActive.isNotEmpty) {
      await prefs.setString('learning_streak_last_active_v1', lastActive);
    }

    final episodeProgress = _asJsonMap(learning['episodeProgress']);
    if (episodeProgress != null && episodeProgress.isNotEmpty) {
      await prefs.setString(
        'episode_learning_progress_v1',
        json.encode(episodeProgress),
      );
    }

    final dailyHistory = _asJsonMap(learning['dailyHistory']);
    if (dailyHistory != null && dailyHistory.isNotEmpty) {
      await prefs.setString(
        'learning_daily_history_v1',
        json.encode(dailyHistory),
      );
    }

    final favourites = _asJsonList(snapshot['favourites']);
    if (favourites.isNotEmpty) {
      await prefs.setString('favourite_episodes_data', json.encode(favourites));
    }

    final vocabularies = _asJsonList(snapshot['vocabularies']);
    if (vocabularies.isNotEmpty) {
      await prefs.setString('saved_vocabulary_items', json.encode(vocabularies));
    }

    final vocabPractice = _asJsonList(snapshot['vocabPractice']);
    if (vocabPractice.isNotEmpty) {
      await prefs.setString(
        'vocabulary_practice_states_v1',
        json.encode(vocabPractice),
      );
    }

    final grammar = _asJsonList(snapshot['grammar']);
    if (grammar.isNotEmpty) {
      await prefs.setString('saved_grammar_items', json.encode(grammar));
    }

    final speakingReview = _asJsonList(snapshot['speakingReview']);
    if (speakingReview.isNotEmpty) {
      await prefs.setString(
        'speaking_review_items_v1',
        json.encode(speakingReview),
      );
    }

    final achievements = _asJsonList(snapshot['achievements']);
    if (achievements.isNotEmpty) {
      await prefs.setStringList(
        'achievements_unlocked_v1',
        achievements.map((e) => e.toString()).toList(),
      );
    }

    await LearningProgressService().reloadFromStorage();
    await VocabularyService().reloadFromStorage();
    await VocabularyPracticeService().reloadFromStorage();
    await SavedGrammarService().reloadFromStorage();
    await SpeakingReviewService().reloadFromStorage();
    await UserProfileService().reloadFromStorage();
    await DailyGoalService().reloadFromStorage();
    await AchievementService().reloadFromStorage();
  }

  Future<void> _migrateLegacyFavouritesIntoLocal() async {
    try {
      final anonymousId = UserService().userId;
      final response = await http.get(
        Uri.parse('$_legacyBaseUrl/user_favourites/$anonymousId.json'),
        headers: {'Accept': 'application/json'},
      );
      if (response.statusCode != 200) return;

      final data = json.decode(response.body);
      if (data is! List || data.isEmpty) return;

      final legacyIds = data.cast<String>().where((id) => id.isNotEmpty).toList();
      if (legacyIds.isEmpty) return;

      final existing = await StorageService().getFavouriteEpisodes();
      final existingIds = existing.map((e) => e.id).whereType<String>().toSet();
      final missingIds =
          legacyIds.where((id) => !existingIds.contains(id)).toList();
      if (missingIds.isEmpty) return;

      final episodes =
          await ApiDailyCacheService().episodesMatchingFavouriteIds(missingIds);
      if (episodes.isEmpty) return;

      for (final episode in episodes) {
        await StorageService().addFavouriteEpisode(episode);
      }
      debugPrint(
        'UserCloudSyncService: migrated ${episodes.length} legacy favourites',
      );
    } catch (e) {
      debugPrint('UserCloudSyncService legacy migration error: $e');
    }
  }

  static int _maxInt(dynamic a, dynamic b) {
    final ai = (a as num?)?.toInt() ?? 0;
    final bi = (b as num?)?.toInt() ?? 0;
    return ai > bi ? ai : bi;
  }

  static String? _latestIso(String? a, String? b) {
    final ad = _parseDate(a);
    final bd = _parseDate(b);
    if (ad == null) return b;
    if (bd == null) return a;
    return ad.isAfter(bd) ? a : b;
  }

  static DateTime? _parseDate(dynamic value) {
    if (value is! String || value.isEmpty) return null;
    return DateTime.tryParse(value);
  }
}
