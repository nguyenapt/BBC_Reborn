import 'package:flutter/material.dart';
import '../models/episode.dart';
import '../models/grammar_explanation.dart';
import '../models/saved_grammar_item.dart';
import 'storage_service.dart';
import 'review_reminder_service.dart';

class SavedGrammarService extends ChangeNotifier {
  static final SavedGrammarService _instance = SavedGrammarService._internal();
  factory SavedGrammarService() => _instance;
  SavedGrammarService._internal();

  final StorageService _storageService = StorageService();
  final ReviewReminderService _reviewReminderService = ReviewReminderService();
  static const List<int> _reviewIntervalsDays = [1, 3, 7];
  List<SavedGrammarItem> _items = [];

  List<SavedGrammarItem> get items {
    final copied = List<SavedGrammarItem>.from(_items);
    copied.sort((a, b) {
      if (a.isPinned != b.isPinned) {
        return a.isPinned ? -1 : 1;
      }
      return b.lastViewedAt.compareTo(a.lastViewedAt);
    });
    return copied;
  }

  List<SavedGrammarItem> get dueReviewItems {
    final now = DateTime.now();
    final due = _items.where((item) {
      if (!item.isPinned) return false;
      final next = item.nextReviewAt;
      return next != null && !next.isAfter(now);
    }).toList();
    due.sort((a, b) {
      final aQuizPriority = a.miniQuiz != null && a.reviewCount == 0 ? 0 : 1;
      final bQuizPriority = b.miniQuiz != null && b.reviewCount == 0 ? 0 : 1;
      if (aQuizPriority != bQuizPriority) {
        return aQuizPriority.compareTo(bQuizPriority);
      }
      return (a.nextReviewAt ?? DateTime.now()).compareTo(b.nextReviewAt ?? DateTime.now());
    });
    return due;
  }

  Future<void> initialize() async {
    await _reviewReminderService.initialize();
    await _load();
  }

  Future<void> reloadFromStorage() async {
    await _load();
    notifyListeners();
  }

  SavedGrammarItem? getBySentence(String sentence, String episodeId) {
    final lookupId = _buildId(sentence, episodeId);
    try {
      return _items.firstWhere((item) => item.id == lookupId);
    } catch (_) {
      return null;
    }
  }

  Future<void> recordViewed({
    required GrammarExplanation explanation,
    required Episode episode,
  }) async {
    final now = DateTime.now();
    final episodeId = episode.id ?? '';
    final id = _buildId(explanation.passageText ?? explanation.sentence, episodeId);
    final existingIndex = _items.indexWhere((item) => item.id == id);
    if (existingIndex >= 0) {
      _items[existingIndex] = _items[existingIndex].copyWith(
        grammarPoint: explanation.grammarPoint,
        explanation: explanation.explanation,
        highlightedWords: explanation.highlightedWords,
        passageText: explanation.passageText,
        overall: explanation.overall,
        sentenceAnalyses: explanation.sentenceAnalyses,
        rulePattern: explanation.rulePattern,
        whyThisForm: explanation.whyThisForm,
        commonMistakes: explanation.commonMistakes,
        miniQuiz: explanation.miniQuiz,
        lastViewedAt: now,
        episodeName: episode.episodeName,
        category: episode.category,
        nextReviewAt: _items[existingIndex].isPinned
            ? _items[existingIndex].nextReviewAt ??
                now.add(const Duration(days: 1))
            : null,
      );
    } else {
      _items.add(
        SavedGrammarItem(
          id: id,
          sentence: explanation.sentence,
          grammarPoint: explanation.grammarPoint,
          explanation: explanation.explanation,
          highlightedWords: explanation.highlightedWords,
          passageText: explanation.passageText,
          overall: explanation.overall,
          sentenceAnalyses: explanation.sentenceAnalyses,
          rulePattern: explanation.rulePattern,
          whyThisForm: explanation.whyThisForm,
          commonMistakes: explanation.commonMistakes,
          miniQuiz: explanation.miniQuiz,
          episodeId: episodeId,
          episodeName: episode.episodeName,
          category: episode.category,
          isPinned: false,
          reviewStage: 0,
          reviewCount: 0,
          nextReviewAt: null,
          lastReviewedAt: null,
          createdAt: now,
          lastViewedAt: now,
        ),
      );
    }
    await _saveAndNotify();
  }

  Future<bool> togglePinnedForExplanation({
    required GrammarExplanation explanation,
    required Episode episode,
  }) async {
    await recordViewed(explanation: explanation, episode: episode);
    final item = getBySentence(explanation.sentence, episode.id ?? '');
    if (item == null) return false;
    final targetPinState = !item.isPinned;
    await setPinned(item.id, targetPinState);
    return targetPinState;
  }

  Future<void> setPinned(String id, bool isPinned) async {
    final index = _items.indexWhere((item) => item.id == id);
    if (index < 0) return;
    final now = DateTime.now();
    final current = _items[index];
    _items[index] = current.copyWith(
      isPinned: isPinned,
      reviewStage: isPinned
          ? (current.reviewStage == 0 ? 1 : current.reviewStage)
          : current.reviewStage,
      nextReviewAt: isPinned
          ? current.nextReviewAt ??
              now.add(Duration(days: _reviewIntervalsDays.first))
          : current.nextReviewAt,
    );
    await _saveAndNotify();
  }

  Future<void> markReviewed(String id) async {
    final index = _items.indexWhere((item) => item.id == id);
    if (index < 0) return;
    final now = DateTime.now();
    final current = _items[index];
    final nextStage = current.reviewStage <= 0
        ? 1
        : (current.reviewStage >= _reviewIntervalsDays.length
            ? _reviewIntervalsDays.length
            : current.reviewStage + 1);
    final intervalIndex =
        (nextStage - 1).clamp(0, _reviewIntervalsDays.length - 1);
    final nextReviewAt = now.add(Duration(days: _reviewIntervalsDays[intervalIndex]));
    _items[index] = current.copyWith(
      reviewStage: nextStage,
      reviewCount: current.reviewCount + 1,
      lastReviewedAt: now,
      nextReviewAt: nextReviewAt,
    );
    await _saveAndNotify();
  }

  Future<void> removeById(String id) async {
    _items.removeWhere((item) => item.id == id);
    await _saveAndNotify();
  }

  Future<void> _load() async {
    _items = await _storageService.getSavedGrammarItems();
    notifyListeners();
  }

  Future<void> _saveAndNotify() async {
    await _storageService.saveSavedGrammarItems(_items);
    try {
      await _reviewReminderService.syncReviewNotifications(_items);
    } catch (e) {
      debugPrint('syncReviewNotifications failed: $e');
    }
    notifyListeners();
  }

  String _buildId(String sentence, String episodeId) {
    final normalizedSentence = sentence.trim().toLowerCase();
    return '${episodeId.trim()}::${normalizedSentence.replaceAll('|', ' ')}';
  }
}
