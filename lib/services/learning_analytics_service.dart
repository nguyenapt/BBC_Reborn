import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

class LearningAnalyticsService extends ChangeNotifier {
  static final LearningAnalyticsService _instance =
      LearningAnalyticsService._internal();
  factory LearningAnalyticsService() => _instance;
  LearningAnalyticsService._internal();

  static const String _countsKey = 'learning_event_counts';

  Map<String, int> _counts = {};
  Map<String, int> get counts => Map<String, int>.from(_counts);

  Future<void> initialize() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_countsKey);
    if (raw == null || raw.isEmpty) {
      _counts = {};
      return;
    }
    try {
      final decoded = json.decode(raw) as Map<String, dynamic>;
      _counts = decoded.map(
        (key, value) => MapEntry(key, int.tryParse(value.toString()) ?? 0),
      );
    } catch (_) {
      _counts = {};
    }
  }

  Future<void> trackEvent(String eventName) async {
    final now = DateTime.now();
    final dateKey = '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
    final dailyKey = 'daily:$dateKey:$eventName';
    _counts[eventName] = (_counts[eventName] ?? 0) + 1;
    _counts[dailyKey] = (_counts[dailyKey] ?? 0) + 1;
    await _persist();
  }

  int getTotal(String eventName) => _counts[eventName] ?? 0;

  Future<void> _persist() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_countsKey, json.encode(_counts));
    notifyListeners();
  }
}
