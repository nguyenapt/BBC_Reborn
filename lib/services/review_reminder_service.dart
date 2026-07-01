import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:timezone/data/latest.dart' as tz;
import 'package:timezone/timezone.dart' as tz;
import '../models/saved_grammar_item.dart';

class ReviewReminderService {
  static final ReviewReminderService _instance =
      ReviewReminderService._internal();
  factory ReviewReminderService() => _instance;
  ReviewReminderService._internal();

  final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();
  static const String _channelId = 'learning_reminders';
  static const String _scheduledIdsKey = 'review_scheduled_notification_ids';
  static const String _askedPermissionKey =
      'review_reminders_permission_asked_v1';

  static const String prefGrammarReview = 'notif_grammar_review_enabled';
  static const String prefStreakRisk = 'notif_streak_risk_enabled';
  static const String prefDailyPractice = 'notif_daily_practice_enabled';
  static const String prefWordOfDay = 'notif_word_of_day_enabled';
  static const String prefSpeakingReview = 'notif_speaking_review_enabled';

  static const int _streakNotificationId = 910001;
  static const int _dailyPracticeNotificationId = 910002;
  static const int _wordOfDayNotificationId = 910003;
  static const int _speakingReviewNotificationId = 910004;

  bool _initialized = false;

  Future<bool> hasAskedPermission() async {
    if (kIsWeb) return true;
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_askedPermissionKey) ?? false;
  }

  Future<void> markAskedPermission() async {
    if (kIsWeb) return;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_askedPermissionKey, true);
  }

  Future<bool> getPreference(String key, {bool defaultValue = true}) async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(key) ?? defaultValue;
  }

  Future<void> setPreference(String key, bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(key, value);
  }

  Future<bool> requestNotificationPermission() async {
    if (kIsWeb) return false;
    if (!Platform.isAndroid && !Platform.isIOS) return false;
    final status = await Permission.notification.request();
    return status.isGranted;
  }

  Future<void> initialize() async {
    if (_initialized) return;
    if (kIsWeb) return;
    if (!Platform.isAndroid && !Platform.isIOS) return;

    const androidInit = AndroidInitializationSettings('@mipmap/logo');
    const iosInit = DarwinInitializationSettings();
    await _plugin.initialize(
      const InitializationSettings(android: androidInit, iOS: iosInit),
    );

    final androidPlugin = _plugin.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();
    await androidPlugin?.createNotificationChannel(
      const AndroidNotificationChannel(
        _channelId,
        'Learning Reminders',
        description: 'Practice, review, and streak reminders',
        importance: Importance.high,
      ),
    );

    tz.initializeTimeZones();
    _initialized = true;
  }

  NotificationDetails get _details => NotificationDetails(
        android: const AndroidNotificationDetails(
          _channelId,
          'Learning Reminders',
          channelDescription: 'Practice, review, and streak reminders',
          importance: Importance.high,
          priority: Priority.high,
          icon: '@mipmap/logo',
        ),
        iOS: const DarwinNotificationDetails(),
      );

  Future<void> syncReviewNotifications(List<SavedGrammarItem> items) async {
    await initialize();
    if (!_initialized) return;
    if (!await getPreference(prefGrammarReview)) {
      await _clearGrammarScheduled();
      return;
    }

    await _clearGrammarScheduled();

    final now = DateTime.now();
    final newIds = <int>[];
    for (final item in items) {
      if (!item.isPinned) continue;
      if (item.nextReviewAt == null) continue;
      if (!item.nextReviewAt!.isAfter(now)) continue;

      final id = _notificationIdForItem(item.id);
      final scheduledAt = tz.TZDateTime.from(item.nextReviewAt!, tz.local);
      await _plugin.zonedSchedule(
        id,
        'Grammar review time',
        item.grammarPoint,
        scheduledAt,
        _details,
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
        uiLocalNotificationDateInterpretation:
            UILocalNotificationDateInterpretation.absoluteTime,
      );
      newIds.add(id);
    }

    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(
      _scheduledIdsKey,
      newIds.map((id) => id.toString()).toList(),
    );
  }

  int _notificationIdForItem(String itemId) {
    return itemId.hashCode.abs() % 2147480000;
  }

  Future<void> _clearGrammarScheduled() async {
    final prefs = await SharedPreferences.getInstance();
    final ids = prefs.getStringList(_scheduledIdsKey) ?? [];
    for (final idStr in ids) {
      final id = int.tryParse(idStr);
      if (id != null) {
        await _plugin.cancel(id);
      }
    }
    await prefs.remove(_scheduledIdsKey);
  }

  Future<void> syncStreakRiskReminder({required bool isActiveToday}) async {
    await initialize();
    if (!_initialized) return;
    await _plugin.cancel(_streakNotificationId);
    if (isActiveToday) return;
    if (!await getPreference(prefStreakRisk)) return;

    final now = DateTime.now();
    var scheduled = DateTime(now.year, now.month, now.day, 21);
    if (!scheduled.isAfter(now)) return;

    final scheduledAt = tz.TZDateTime.from(scheduled, tz.local);
    await _plugin.zonedSchedule(
      _streakNotificationId,
      'Keep your streak alive',
      'Practice a few minutes today to continue your learning streak.',
      scheduledAt,
      _details,
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
    );
  }

  Future<void> syncDailyPracticeReminder() async {
    await initialize();
    if (!_initialized) return;
    await _plugin.cancel(_dailyPracticeNotificationId);
    if (!await getPreference(prefDailyPractice)) return;

    final now = DateTime.now();
    var scheduled = DateTime(now.year, now.month, now.day, 9);
    if (!scheduled.isAfter(now)) {
      scheduled = scheduled.add(const Duration(days: 1));
    }

    await _plugin.zonedSchedule(
      _dailyPracticeNotificationId,
      'Time to practice',
      'Complete your daily goal: listen and review vocabulary.',
      tz.TZDateTime.from(scheduled, tz.local),
      _details,
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
      matchDateTimeComponents: DateTimeComponents.time,
    );
  }

  Future<void> syncWordOfTheDayReminder({String? word}) async {
    await initialize();
    if (!_initialized) return;
    await _plugin.cancel(_wordOfDayNotificationId);
    if (!await getPreference(prefWordOfDay)) return;

    final now = DateTime.now();
    var scheduled = DateTime(now.year, now.month, now.day, 8);
    if (!scheduled.isAfter(now)) {
      scheduled = scheduled.add(const Duration(days: 1));
    }

    final body = word != null && word.isNotEmpty
        ? 'Today\'s word: $word'
        : 'Open the app to learn today\'s vocabulary.';

    await _plugin.zonedSchedule(
      _wordOfDayNotificationId,
      'Word of the day',
      body,
      tz.TZDateTime.from(scheduled, tz.local),
      _details,
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
      matchDateTimeComponents: DateTimeComponents.time,
    );
  }

  Future<void> syncSpeakingReviewReminder({
    required int dueCount,
    String? episodeTitle,
  }) async {
    await initialize();
    if (!_initialized) return;
    await _plugin.cancel(_speakingReviewNotificationId);
    if (!await getPreference(prefSpeakingReview)) return;
    if (dueCount <= 0) return;

    final now = DateTime.now();
    var scheduled = DateTime(now.year, now.month, now.day, 18);
    if (!scheduled.isAfter(now)) return;

    final title = episodeTitle != null && episodeTitle.isNotEmpty
        ? episodeTitle
        : 'Speaking practice';
    final body =
        'Review $dueCount speaking line${dueCount == 1 ? '' : 's'} from $title';

    await _plugin.zonedSchedule(
      _speakingReviewNotificationId,
      'Speaking review',
      body,
      tz.TZDateTime.from(scheduled, tz.local),
      _details,
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
    );
  }

  Future<void> syncAllLocalReminders({
    required bool isActiveToday,
    required List<SavedGrammarItem> grammarItems,
    String? wordOfTheDay,
    int speakingDueCount = 0,
    String? speakingEpisodeTitle,
  }) async {
    await syncReviewNotifications(grammarItems);
    await syncStreakRiskReminder(isActiveToday: isActiveToday);
    await syncDailyPracticeReminder();
    await syncWordOfTheDayReminder(word: wordOfTheDay);
    await syncSpeakingReviewReminder(
      dueCount: speakingDueCount,
      episodeTitle: speakingEpisodeTitle,
    );
  }
}
