import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
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
  static const String _channelId = 'grammar_review_reminders';
  static const String _scheduledIdsKey = 'review_scheduled_notification_ids';
  bool _initialized = false;

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
        'Grammar Review Reminders',
        description: 'Reminds users to review saved grammar',
        importance: Importance.high,
      ),
    );

    tz.initializeTimeZones();
    _initialized = true;
  }

  Future<void> syncReviewNotifications(List<SavedGrammarItem> items) async {
    await initialize();
    if (!_initialized) return;

    await _clearPreviouslyScheduled();

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
        NotificationDetails(
          android: const AndroidNotificationDetails(
            _channelId,
            'Grammar Review Reminders',
            channelDescription: 'Reminds users to review saved grammar',
            importance: Importance.high,
            priority: Priority.high,
            icon: '@mipmap/logo',
          ),
          iOS: const DarwinNotificationDetails(),
        ),
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

  Future<void> _clearPreviouslyScheduled() async {
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
}
