import 'dart:convert';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/vocabulary_item.dart';
import '../models/vocabulary_practice_state.dart';

class VocabularyPracticeService extends ChangeNotifier {
  static final VocabularyPracticeService _instance =
      VocabularyPracticeService._internal();
  factory VocabularyPracticeService() => _instance;
  VocabularyPracticeService._internal();

  static const String _statesKey = 'vocabulary_practice_states_v1';

  final Map<String, VocabularyPracticeState> _states = {};
  bool _initialized = false;

  Future<void> initialize() async {
    if (_initialized) return;
    await _loadStates();
    _initialized = true;
  }

  Future<void> _loadStates() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_statesKey);
    if (raw == null || raw.isEmpty) return;

    try {
      final decoded = json.decode(raw);
      if (decoded is! List) return;
      _states.clear();
      for (final item in decoded) {
        if (item is! Map<String, dynamic>) continue;
        final state = VocabularyPracticeState.fromJson(item);
        if (state.key.isNotEmpty) {
          _states[state.key] = state;
        }
      }
    } catch (e) {
      debugPrint('Error loading vocabulary practice states: $e');
    }
  }

  Future<void> _saveStates() async {
    final prefs = await SharedPreferences.getInstance();
    final payload = _states.values.map((e) => e.toJson()).toList();
    await prefs.setString(_statesKey, json.encode(payload));
  }

  static String keyForVocabulary(VocabularyItem item) {
    final word = item.vocab.trim().toLowerCase();
    final mean = item.mean.trim().toLowerCase();
    return '$word::$mean';
  }

  VocabularyPracticeState? getState(VocabularyItem item) {
    return _states[keyForVocabulary(item)];
  }

  bool isDue(VocabularyItem item, {DateTime? nowUtc}) {
    final state = getState(item);
    if (state?.nextReviewAt == null) return false;
    final now = (nowUtc ?? DateTime.now().toUtc()).toUtc();
    return !state!.nextReviewAt!.isAfter(now);
  }

  bool isWeak(VocabularyItem item, {DateTime? nowUtc}) {
    final state = getState(item);
    if (state == null) return false;
    if (state.lastOutcome == VocabularyPracticeOutcome.stillLearning) {
      return true;
    }
    return isDue(item, nowUtc: nowUtc);
  }

  VocabularyPracticeState? wordStateByKey(String key) => _states[key];

  @visibleForTesting
  void setStateForTesting(String key, VocabularyPracticeState state) {
    _states[key] = state;
  }

  @visibleForTesting
  void clearStateForTesting() {
    _states.clear();
    _initialized = true;
  }

  static VocabularyItem? pickWordOfTheDay(
    List<VocabularyItem> items, {
    DateTime? nowUtc,
    DateTime? epochUtc,
  }) {
    if (items.isEmpty) return null;
    final now = (nowUtc ?? DateTime.now().toUtc()).toUtc();
    final epoch = (epochUtc ?? DateTime.utc(2020)).toUtc();
    final dayIndex = now.difference(epoch).inDays.abs();
    return items[dayIndex % items.length];
  }

  List<VocabularyItem> buildPracticeDeck(
    List<VocabularyItem> pool, {
    int sessionSize = 20,
    int maxWeakInSession = 8,
    DateTime? nowUtc,
    Random? random,
  }) {
    final rnd = random ?? Random();
    final now = (nowUtc ?? DateTime.now().toUtc()).toUtc();
    final normalized = List<VocabularyItem>.from(pool);
    if (normalized.isEmpty) return [];

    normalized.shuffle(rnd);
    final weak = normalized.where((w) => isWeak(w, nowUtc: now)).toList();
    final strong = normalized.where((w) => !isWeak(w, nowUtc: now)).toList();

    final targetSize = min(sessionSize, normalized.length);
    final weakCount = min(maxWeakInSession, min(weak.length, targetSize));

    final deck = <VocabularyItem>[
      ...weak.take(weakCount),
    ];

    final remaining = targetSize - deck.length;
    if (remaining > 0) {
      deck.addAll(strong.take(remaining));
    }

    if (deck.length < targetSize) {
      final used = deck.map(keyForVocabulary).toSet();
      final fallback = normalized.where((e) => !used.contains(keyForVocabulary(e)));
      deck.addAll(fallback.take(targetSize - deck.length));
    }

    deck.shuffle(rnd);
    return deck;
  }

  static VocabularyPracticeState applyOutcome({
    required String key,
    VocabularyPracticeState? previous,
    required VocabularyPracticeOutcome outcome,
    DateTime? nowUtc,
  }) {
    final now = (nowUtc ?? DateTime.now().toUtc()).toUtc();
    final prev = previous ?? VocabularyPracticeState(key: key);

    if (outcome == VocabularyPracticeOutcome.stillLearning) {
      final newEase = max(1.3, prev.easeFactor - 0.2);
      return prev.copyWith(
        repetitions: 0,
        intervalDays: 1,
        easeFactor: newEase,
        nextReviewAt: now.add(const Duration(days: 1)),
        lastReviewedAt: now,
        lastOutcome: outcome,
      );
    }

    final nextRepetitions = prev.repetitions + 1;
    int nextInterval;
    if (nextRepetitions <= 1) {
      nextInterval = 1;
    } else if (nextRepetitions == 2) {
      nextInterval = 6;
    } else {
      nextInterval = max(1, (prev.intervalDays * prev.easeFactor).round());
    }

    final newEase = min(2.8, prev.easeFactor + 0.1);
    return prev.copyWith(
      repetitions: nextRepetitions,
      intervalDays: nextInterval,
      easeFactor: newEase,
      nextReviewAt: now.add(Duration(days: nextInterval)),
      lastReviewedAt: now,
      lastOutcome: outcome,
    );
  }

  Future<VocabularyPracticeState> recordOutcome(
    VocabularyItem item,
    VocabularyPracticeOutcome outcome, {
    DateTime? nowUtc,
  }) async {
    await initialize();
    final key = keyForVocabulary(item);
    final next = applyOutcome(
      key: key,
      previous: _states[key],
      outcome: outcome,
      nowUtc: nowUtc,
    );
    _states[key] = next;
    await _saveStates();
    notifyListeners();
    return next;
  }
}
