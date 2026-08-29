import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/heart_system_config.dart';
import 'ai/exceptions.dart';
import 'heart_remote_config_service.dart';

/// Hearts + optional Episode Pass / Speaking Ticket credits.
class HeartService extends ChangeNotifier {
  static final HeartService _instance = HeartService._internal();
  factory HeartService() => _instance;
  HeartService._internal();

  static const String _heartsKey = 'ai_hearts_count';
  static const String _lastResetDateKey = 'ai_hearts_last_reset_date';
  static const String _episodeCreditsKey = 'ai_episode_credits_v1';
  static const String _episodePassOpenedKey = 'ai_episode_pass_opened_v1';
  static const String _speakingAttemptsKey = 'ai_speaking_attempts_v1';
  static const String _liveAiCallsKey = 'ai_live_calls_v1';
  static const String _adTopupsKey = 'ai_ad_topups_v1';
  static const String _passHintShownKey = 'ai_pass_hint_shown_v1';
  static const String _episodeHeartRefillsKey = 'ai_episode_heart_refills_v1';

  static const String miscScopeId = '_misc';

  HeartSystemConfig _config = HeartSystemConfig.defaults;
  int _hearts = HeartSystemConfig.defaults.heartNumber;
  DateTime? _lastResetDate;

  /// episodeId -> remaining credits (same calendar day).
  Map<String, int> _episodeCredits = {};
  Set<String> _episodePassOpened = {};
  /// episodeId -> heart refill count after initial Pass open (same day).
  Map<String, int> _episodeHeartRefills = {};

  int _speakingAttempts = 0;
  bool _speakingTicketOpened = false;

  int _liveAiCallsToday = 0;
  int _adTopupsToday = 0;
  Set<String> _passHintShown = {};

  /// Last credit delta for UI animation (-1 when a credit was spent).
  int _lastCreditDelta = 0;
  String? _lastCreditEpisodeId;

  HeartSystemConfig get config => _config;
  bool get allowCredit => _config.allowCredit;
  bool get allowCreditEpisodePass => _config.allowCreditEpisodePass;
  bool get allowCreditSpeaking => _config.allowCreditSpeaking;
  /// Credit mode + episode pass module enabled.
  bool get useEpisodeCredits => allowCredit && allowCreditEpisodePass;
  /// Credit mode + speaking ticket module enabled.
  bool get useSpeakingTicket => allowCredit && allowCreditSpeaking;
  int get speakingMaxRecordingMs =>
      _config.speakingMaxRecordingSeconds * 1000;

  int get hearts => _hearts;
  int get maxHearts => _config.heartNumber;
  bool get hasHearts => _hearts > 0;
  bool get canEarnMoreHearts => _hearts < maxHearts;

  int get liveAiCallsToday => _liveAiCallsToday;
  int get dailyLiveCap => _config.dailyLiveCap;
  bool get isAtDailyLiveCap => _liveAiCallsToday >= _config.dailyLiveCap;
  int get adTopupsToday => _adTopupsToday;
  bool get canAdTopup => _adTopupsToday < _config.adTopupMaxPerDay;

  /// Trần credits / episode / ngày (= [HeartSystemConfig.creditNumber], mặc định 10).
  int get maxEpisodeCredits => _config.creditNumber;

  /// Còn chỗ nạp credits trên episode (chưa chạm trần).
  bool hasEpisodeCreditRoom(String episodeId) =>
      episodeCreditsRemaining(episodeId) < maxEpisodeCredits;

  bool canAdRefillEpisodeCredits(String episodeId) =>
      canAdTopup && hasEpisodeCreditRoom(episodeId);

  int get speakingAttemptsRemaining => _speakingAttempts;
  bool get hasSpeakingTicketOpened => _speakingTicketOpened;

  int get lastCreditDelta => _lastCreditDelta;
  String? get lastCreditEpisodeId => _lastCreditEpisodeId;

  Future<void> initialize() async {
    try {
      await HeartRemoteConfigService.instance.ensureLoaded();
      _config = HeartRemoteConfigService.instance.config;

      final prefs = await SharedPreferences.getInstance();
      _hearts = prefs.getInt(_heartsKey) ?? _config.heartNumber;
      if (_hearts > maxHearts) {
        _hearts = maxHearts;
      }

      final lastResetDateString = prefs.getString(_lastResetDateKey);
      if (lastResetDateString != null) {
        _lastResetDate = DateTime.parse(lastResetDateString);
      }

      await _loadDayScopedState(prefs);
      _checkAndResetIfNeeded();
      notifyListeners();
      debugPrint(
        '✅ HeartService initialized: $_hearts/$maxHearts '
        'allowCredit=$allowCredit epPass=$allowCreditEpisodePass speaking=$allowCreditSpeaking',
      );
    } catch (e) {
      debugPrint('❌ Error initializing HeartService: $e');
      _hearts = _config.heartNumber;
    }
  }

  /// Refresh remote config (e.g. deferred bootstrap). Does not reset hearts mid-day.
  Future<void> refreshRemoteConfig() async {
    await HeartRemoteConfigService.instance.refresh(bypassCache: true);
    _config = HeartRemoteConfigService.instance.config;
    if (_hearts > maxHearts) {
      _hearts = maxHearts;
      await _saveHearts();
    }
    // Clamp credits nếu remote hạ credit_number.
    var creditsChanged = false;
    for (final e in _episodeCredits.entries.toList()) {
      final capped = e.value.clamp(0, maxEpisodeCredits);
      if (capped != e.value) {
        _episodeCredits[e.key] = capped;
        creditsChanged = true;
      }
    }
    if (creditsChanged) {
      await _persistDayScoped();
    }
    notifyListeners();
  }

  String _todayKey() {
    final now = DateTime.now();
    return '${now.year.toString().padLeft(4, '0')}-'
        '${now.month.toString().padLeft(2, '0')}-'
        '${now.day.toString().padLeft(2, '0')}';
  }

  Future<void> _loadDayScopedState(SharedPreferences prefs) async {
    final today = _todayKey();

    final creditsRaw = prefs.getString(_episodeCreditsKey);
    _episodeCredits = {};
    if (creditsRaw != null) {
      try {
        final map = json.decode(creditsRaw) as Map<String, dynamic>;
        if (map['date'] == today && map['credits'] is Map) {
          final c = map['credits'] as Map;
          c.forEach((k, v) {
            final n = (v as num).toInt();
            // Clamp dữ liệu cũ nếu từng cộng vượt trần.
            _episodeCredits[k.toString()] =
                n.clamp(0, _config.creditNumber);
          });
        }
      } catch (_) {}
    }

    final openedRaw = prefs.getString(_episodePassOpenedKey);
    _episodePassOpened = {};
    if (openedRaw != null) {
      try {
        final map = json.decode(openedRaw) as Map<String, dynamic>;
        if (map['date'] == today && map['ids'] is List) {
          _episodePassOpened = (map['ids'] as List).map((e) => '$e').toSet();
        }
      } catch (_) {}
    }

    final speakingRaw = prefs.getString(_speakingAttemptsKey);
    _speakingAttempts = 0;
    _speakingTicketOpened = false;
    if (speakingRaw != null) {
      try {
        final map = json.decode(speakingRaw) as Map<String, dynamic>;
        if (map['date'] == today) {
          _speakingAttempts = (map['attempts'] as num?)?.toInt() ?? 0;
          _speakingTicketOpened = map['opened'] == true;
        }
      } catch (_) {}
    }

    final liveRaw = prefs.getString(_liveAiCallsKey);
    _liveAiCallsToday = 0;
    if (liveRaw != null) {
      try {
        final map = json.decode(liveRaw) as Map<String, dynamic>;
        if (map['date'] == today) {
          _liveAiCallsToday = (map['count'] as num?)?.toInt() ?? 0;
        }
      } catch (_) {}
    }

    final adRaw = prefs.getString(_adTopupsKey);
    _adTopupsToday = 0;
    if (adRaw != null) {
      try {
        final map = json.decode(adRaw) as Map<String, dynamic>;
        if (map['date'] == today) {
          _adTopupsToday = (map['count'] as num?)?.toInt() ?? 0;
        }
      } catch (_) {}
    }

    final hintRaw = prefs.getString(_passHintShownKey);
    _passHintShown = {};
    if (hintRaw != null) {
      try {
        final map = json.decode(hintRaw) as Map<String, dynamic>;
        if (map['date'] == today && map['ids'] is List) {
          _passHintShown = (map['ids'] as List).map((e) => '$e').toSet();
        }
      } catch (_) {}
    }

    final refillRaw = prefs.getString(_episodeHeartRefillsKey);
    _episodeHeartRefills = {};
    if (refillRaw != null) {
      try {
        final map = json.decode(refillRaw) as Map<String, dynamic>;
        if (map['date'] == today && map['refills'] is Map) {
          final r = map['refills'] as Map;
          r.forEach((k, v) {
            _episodeHeartRefills[k.toString()] = (v as num).toInt();
          });
        }
      } catch (_) {}
    }
  }

  void _checkAndResetIfNeeded() {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    if (_lastResetDate == null) {
      _lastResetDate = today;
      _saveLastResetDate();
      return;
    }

    final lastReset = DateTime(
      _lastResetDate!.year,
      _lastResetDate!.month,
      _lastResetDate!.day,
    );

    if (today.isAfter(lastReset)) {
      debugPrint('🔄 New day detected, resetting hearts to $maxHearts');
      _hearts = maxHearts;
      _lastResetDate = today;
      _episodeCredits = {};
      _episodePassOpened = {};
      _speakingAttempts = 0;
      _speakingTicketOpened = false;
      _liveAiCallsToday = 0;
      _adTopupsToday = 0;
      _passHintShown = {};
      _episodeHeartRefills = {};
      _saveHearts();
      _saveLastResetDate();
      _persistDayScoped();
      notifyListeners();
    }
  }

  Future<void> _persistDayScoped() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final today = _todayKey();
      await prefs.setString(
        _episodeCreditsKey,
        json.encode({'date': today, 'credits': _episodeCredits}),
      );
      await prefs.setString(
        _episodePassOpenedKey,
        json.encode({'date': today, 'ids': _episodePassOpened.toList()}),
      );
      await prefs.setString(
        _speakingAttemptsKey,
        json.encode({
          'date': today,
          'attempts': _speakingAttempts,
          'opened': _speakingTicketOpened,
        }),
      );
      await prefs.setString(
        _liveAiCallsKey,
        json.encode({'date': today, 'count': _liveAiCallsToday}),
      );
      await prefs.setString(
        _adTopupsKey,
        json.encode({'date': today, 'count': _adTopupsToday}),
      );
      await prefs.setString(
        _passHintShownKey,
        json.encode({'date': today, 'ids': _passHintShown.toList()}),
      );
      await prefs.setString(
        _episodeHeartRefillsKey,
        json.encode({'date': today, 'refills': _episodeHeartRefills}),
      );
    } catch (e) {
      debugPrint('❌ Error saving heart day state: $e');
    }
  }

  int episodeCreditsRemaining(String episodeId) =>
      _episodeCredits[_normalizeScope(episodeId)] ?? 0;

  bool hasEpisodePassOpened(String episodeId) =>
      _episodePassOpened.contains(_normalizeScope(episodeId));

  /// Show credit badge on episode AppBar when Pass is open for this episode today.
  bool shouldShowEpisodeCreditBadge(String episodeId) {
    if (!useEpisodeCredits) return false;
    return hasEpisodePassOpened(episodeId);
  }

  int episodeHeartRefillsUsed(String episodeId) =>
      _episodeHeartRefills[_normalizeScope(episodeId)] ?? 0;

  /// After Pass opened: may spend another heart to refill (capped per episode/day).
  bool canHeartRefillEpisode(String episodeId) {
    if (!useEpisodeCredits || !hasHearts) return false;
    final id = _normalizeScope(episodeId);
    if (!hasEpisodePassOpened(id)) return true; // opening Pass lần đầu
    if (!hasEpisodeCreditRoom(id)) return false;
    return episodeHeartRefillsUsed(id) < _config.heartRefillMaxPerEpisode;
  }

  bool shouldShowPassOpenedHint(String episodeId) {
    final id = _normalizeScope(episodeId);
    return !_passHintShown.contains(id);
  }

  Future<void> markPassOpenedHintShown(String episodeId) async {
    _passHintShown.add(_normalizeScope(episodeId));
    await _persistDayScoped();
  }

  void clearCreditDeltaHint() {
    _lastCreditDelta = 0;
    _lastCreditEpisodeId = null;
  }

  String _normalizeScope(String episodeId) {
    final t = episodeId.trim();
    return t.isEmpty ? miscScopeId : t;
  }

  /// Legacy: 1 heart per Firebase/live AI call.
  Future<void> consumeForAIFeature() async {
    if (!hasHearts) {
      throw NoHeartsException();
    }
    final used = await useHeart();
    if (!used) {
      throw NoHeartsException();
    }
  }

  /// Credit mode: spend 1 episode credit (Firebase or live). Local callers skip this.
  Future<void> consumeEpisodeCredit(
    String episodeId, {
    required bool isLiveApi,
  }) async {
    _checkAndResetIfNeeded();
    if (!useEpisodeCredits) {
      await consumeForAIFeature();
      return;
    }

    final id = _normalizeScope(episodeId);
    final credits = episodeCreditsRemaining(id);

    if (credits <= 0) {
      if (!hasEpisodePassOpened(id)) {
        if (!hasHearts) throw NoHeartsException();
        throw NeedsEpisodePassException(id);
      }
      throw NoEpisodeCreditsException(id);
    }

    if (isLiveApi && isAtDailyLiveCap) {
      throw DailyLiveAiCapException();
    }

    _episodeCredits[id] = credits - 1;
    _lastCreditDelta = -1;
    _lastCreditEpisodeId = id;
    if (isLiveApi) {
      _liveAiCallsToday++;
    }
    await _persistDayScoped();
    notifyListeners();
    debugPrint(
      '🎟️ Episode credit used ($id). Remaining: ${_episodeCredits[id]}'
      '${isLiveApi ? ' liveToday=$_liveAiCallsToday' : ''}',
    );
  }

  /// Cộng credits, không vượt [maxEpisodeCredits]. Trả về số thực sự được cộng.
  int _grantEpisodeCredits(String id, int grant) {
    if (grant <= 0) return 0;
    final current = episodeCreditsRemaining(id);
    final next = (current + grant).clamp(0, maxEpisodeCredits);
    final actual = next - current;
    _episodeCredits[id] = next;
    return actual;
  }

  /// Open Pass lần đầu (+[creditNumber]) hoặc refill bằng heart (+[rewardedCredits], cap [heartRefillMaxPerEpisode]).
  /// Tổng credits sau grant luôn ≤ [maxEpisodeCredits].
  Future<bool> openOrRefillEpisodePassWithHeart(String episodeId) async {
    _checkAndResetIfNeeded();
    if (!useEpisodeCredits) return false;
    if (!hasHearts) return false;

    final id = _normalizeScope(episodeId);
    final alreadyOpened = hasEpisodePassOpened(id);
    if (alreadyOpened && !canHeartRefillEpisode(id)) {
      debugPrint('❌ Heart refill cap reached for episode $id');
      return false;
    }
    if (alreadyOpened && !hasEpisodeCreditRoom(id)) {
      debugPrint('❌ Episode credits already at max for $id');
      return false;
    }

    final used = await useHeart();
    if (!used) return false;

    // Lần đầu mở Pass: full creditNumber. Refill sau đó: cùng mức ad (rewardedCredits).
    final wanted =
        alreadyOpened ? _config.rewardedCredits : _config.creditNumber;
    final actual = _grantEpisodeCredits(id, wanted);
    _episodePassOpened.add(id);
    if (alreadyOpened) {
      _episodeHeartRefills[id] = episodeHeartRefillsUsed(id) + 1;
    }
    _lastCreditDelta = actual;
    _lastCreditEpisodeId = id;
    await _persistDayScoped();
    notifyListeners();
    debugPrint(
      '🎟️ Episode pass +$actual (wanted $wanted) for $id '
      '(total ${_episodeCredits[id]}, refill=$alreadyOpened, max=$maxEpisodeCredits)',
    );
    return true;
  }

  /// Rewarded ad: +[rewardedCredits] on episode, trần [maxEpisodeCredits].
  Future<bool> refillEpisodeCreditsWithAd(String episodeId) async {
    _checkAndResetIfNeeded();
    if (!useEpisodeCredits) return false;
    if (!canAdTopup) return false;

    final id = _normalizeScope(episodeId);
    if (!hasEpisodeCreditRoom(id)) {
      debugPrint('❌ Episode credits already at max for $id');
      return false;
    }

    final actual = _grantEpisodeCredits(id, _config.rewardedCredits);
    if (actual <= 0) return false;

    _episodePassOpened.add(id);
    _adTopupsToday++;
    _lastCreditDelta = actual;
    _lastCreditEpisodeId = id;
    await _persistDayScoped();
    notifyListeners();
    debugPrint(
      '🎟️ Ad credits +$actual for $id (total ${_episodeCredits[id]}, max=$maxEpisodeCredits)',
    );
    return true;
  }

  /// Soft-cap path: ad grants credits even at live cap (still increments ad top-ups).
  Future<bool> topUpCreditsPastLiveCapWithAd(String episodeId) async {
    return refillEpisodeCreditsWithAd(episodeId);
  }

  Future<void> consumeSpeakingAttempt() async {
    _checkAndResetIfNeeded();
    if (!useSpeakingTicket) {
      await consumeForAIFeature();
      return;
    }

    if (_speakingAttempts <= 0) {
      if (!_speakingTicketOpened) {
        if (!hasHearts) throw NoHeartsException();
        throw NeedsSpeakingTicketException();
      }
      throw NoSpeakingAttemptsException();
    }

    if (isAtDailyLiveCap) {
      throw DailyLiveAiCapException();
    }

    _speakingAttempts--;
    _liveAiCallsToday++;
    await _persistDayScoped();
    notifyListeners();
  }

  Future<bool> openOrRefillSpeakingTicketWithHeart() async {
    _checkAndResetIfNeeded();
    if (!useSpeakingTicket) return false;
    if (!hasHearts) return false;
    final used = await useHeart();
    if (!used) return false;
    _speakingAttempts += _config.speakingTicketNumber;
    _speakingTicketOpened = true;
    await _persistDayScoped();
    notifyListeners();
    return true;
  }

  Future<bool> refillSpeakingTicketWithAd() async {
    _checkAndResetIfNeeded();
    if (!useSpeakingTicket) return false;
    if (!canAdTopup) return false;
    _speakingAttempts += _config.speakingTicketNumber;
    _speakingTicketOpened = true;
    _adTopupsToday++;
    await _persistDayScoped();
    notifyListeners();
    return true;
  }

  Future<bool> useHeart() async {
    _checkAndResetIfNeeded();

    if (_hearts <= 0) {
      debugPrint('❌ No hearts available');
      return false;
    }

    _hearts--;
    await _saveHearts();
    notifyListeners();
    debugPrint('❤️ Heart used. Remaining: $_hearts');
    return true;
  }

  Future<bool> earnHeart() async {
    final earned = await earnHearts(1);
    return earned > 0;
  }

  /// Earn hearts from rewarded ad using remote [rewardedHearts] count.
  Future<int> earnRewardedHearts() async {
    return earnHearts(_config.rewardedHearts);
  }

  Future<int> earnHearts(int count) async {
    if (count <= 0) return 0;
    _checkAndResetIfNeeded();

    if (_hearts >= maxHearts) {
      debugPrint('❌ Already at max hearts');
      return 0;
    }

    final added = count.clamp(0, maxHearts - _hearts);
    if (added == 0) return 0;

    _hearts += added;
    await _saveHearts();
    notifyListeners();
    debugPrint('❤️ Hearts earned: +$added (total: $_hearts)');
    return added;
  }

  Future<void> _saveHearts() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt(_heartsKey, _hearts);
    } catch (e) {
      debugPrint('❌ Error saving hearts: $e');
    }
  }

  Future<void> _saveLastResetDate() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      if (_lastResetDate != null) {
        await prefs.setString(
          _lastResetDateKey,
          _lastResetDate!.toIso8601String(),
        );
      }
    } catch (e) {
      debugPrint('❌ Error saving last reset date: $e');
    }
  }

  Duration getTimeUntilReset() {
    final now = DateTime.now();
    final tomorrow = DateTime(now.year, now.month, now.day + 1);
    return tomorrow.difference(now);
  }

  String getTimeUntilResetString() {
    final duration = getTimeUntilReset();
    final hours = duration.inHours;
    final minutes = duration.inMinutes.remainder(60);

    if (hours > 0) {
      return '${hours}h ${minutes}m';
    } else {
      return '${minutes}m';
    }
  }
}
