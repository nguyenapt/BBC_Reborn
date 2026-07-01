import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/speaking_attempt.dart';
import '../models/speaking_review_item.dart';
import 'review_reminder_service.dart';
import 'user_cloud_sync_service.dart';

class SpeakingReviewService extends ChangeNotifier {
  static final SpeakingReviewService _instance =
      SpeakingReviewService._internal();
  factory SpeakingReviewService() => _instance;
  SpeakingReviewService._internal();

  static const String _itemsKey = 'speaking_review_items_v1';
  static const double weakScoreThreshold = 70.0;
  static const List<int> _reviewIntervalsDays = [1, 3, 7];

  final List<SpeakingReviewItem> _items = [];
  bool _initialized = false;

  List<SpeakingReviewItem> get items => List.unmodifiable(_items);

  List<SpeakingReviewItem> get dueReviewItems {
    final now = DateTime.now();
    final due = _items.where((item) {
      final next = item.nextReviewAt;
      return next != null && !next.isAfter(now);
    }).toList();
    due.sort((a, b) =>
        (a.nextReviewAt ?? DateTime.now()).compareTo(b.nextReviewAt ?? DateTime.now()));
    return due;
  }

  Future<void> initialize() async {
    if (_initialized) return;
    await ReviewReminderService().initialize();
    await _load();
    _initialized = true;
    notifyListeners();
  }

  Future<void> reloadFromStorage() async {
    await _load();
    notifyListeners();
  }

  Future<void> scheduleFromAttempt({
    required SpeakingAttempt attempt,
    required String episodeTitle,
  }) async {
    if (attempt.score >= weakScoreThreshold) return;
    if (attempt.lineText.trim().isEmpty) return;

    final id = _buildId(attempt.episodeId, attempt.lineIndex, attempt.lineText);
    final now = DateTime.now();
    final existingIndex = _items.indexWhere((item) => item.id == id);

    if (existingIndex >= 0) {
      final existing = _items[existingIndex];
      final stage = existing.reviewStage.clamp(0, _reviewIntervalsDays.length - 1);
      _items[existingIndex] = existing.copyWith(
        episodeTitle: episodeTitle,
        lastScore: attempt.score,
        lastAttemptAt: now,
        nextReviewAt: now.add(Duration(days: _reviewIntervalsDays[stage])),
      );
    } else {
      _items.add(
        SpeakingReviewItem(
          id: id,
          episodeId: attempt.episodeId,
          episodeTitle: episodeTitle,
          lineText: attempt.lineText,
          lineIndex: attempt.lineIndex,
          mode: attempt.mode,
          lastScore: attempt.score,
          reviewStage: 0,
          reviewCount: 0,
          nextReviewAt: now.add(Duration(days: _reviewIntervalsDays.first)),
          lastAttemptAt: now,
        ),
      );
    }

    await _saveAndSyncNotifications();
  }

  Future<void> markReviewed(String id, {required double newScore}) async {
    final index = _items.indexWhere((item) => item.id == id);
    if (index < 0) return;

    final existing = _items[index];
    final now = DateTime.now();

    if (newScore >= weakScoreThreshold) {
      _items.removeAt(index);
    } else {
      final nextStage =
          (existing.reviewStage + 1).clamp(0, _reviewIntervalsDays.length - 1);
      _items[index] = existing.copyWith(
        lastScore: newScore,
        reviewStage: nextStage,
        reviewCount: existing.reviewCount + 1,
        lastAttemptAt: now,
        nextReviewAt: now.add(Duration(days: _reviewIntervalsDays[nextStage])),
      );
    }

    await _saveAndSyncNotifications();
  }

  String _buildId(String episodeId, int? lineIndex, String lineText) {
    return '$episodeId:${lineIndex ?? -1}:${lineText.hashCode}';
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_itemsKey);
    _items.clear();
    if (raw == null || raw.isEmpty) return;
    try {
      final decoded = json.decode(raw);
      if (decoded is List) {
        for (final entry in decoded) {
          if (entry is Map) {
            _items.add(SpeakingReviewItem.fromJson(
              Map<String, dynamic>.from(entry),
            ));
          }
        }
      }
    } catch (e) {
      debugPrint('SpeakingReviewService load error: $e');
    }
  }

  Future<void> _saveAndSyncNotifications() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _itemsKey,
      json.encode(_items.map((e) => e.toJson()).toList()),
    );
    await ReviewReminderService().syncSpeakingReviewReminder(
      dueCount: dueReviewItems.length,
      episodeTitle: dueReviewItems.isNotEmpty
          ? dueReviewItems.first.episodeTitle
          : null,
    );
    UserCloudSyncService().schedulePush();
    notifyListeners();
  }
}
