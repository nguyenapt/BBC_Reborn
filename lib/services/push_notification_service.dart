import 'dart:convert';
import 'dart:io';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../firebase_options.dart';
import 'media_notification_launch_handler.dart';

/// FCM topic nhận push khi có episode mới (broadcast — phải trùng topic trong playMP3 / Cloud Function).
const String fcmTopicNewEpisodes = 'episodes';

/// SharedPreferences key — đồng bộ với [setEpisodePushEnabled] / [getEpisodePushEnabled].
const String prefKeyEpisodePushEnabled = 'push_episodes_enabled';

const String _androidChannelId = 'bbc_episode_push';
const String _androidChannelName = 'Tập mới';

@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
}

/// Đăng ký FCM topics, foreground notification (Android) và quyền thông báo.
class PushNotificationService {
  PushNotificationService._();
  static final PushNotificationService instance = PushNotificationService._();

  final FlutterLocalNotificationsPlugin _local = FlutterLocalNotificationsPlugin();
  bool _initialized = false;

  bool _permissionSetupDone = false;
  Map<String, dynamic>? _pendingLaunchData;
  bool _pendingLaunchConsumed = false;

  /// [requestPermissions] / [subscribeToTopics] có thể hoãn để không chặn splash.
  Future<void> initialize({
    bool requestPermissions = true,
    bool subscribeToTopics = true,
  }) async {
    if (_initialized) return;
    if (kIsWeb) return;
    if (!Platform.isAndroid && !Platform.isIOS) return;

    final messaging = FirebaseMessaging.instance;
    if (Platform.isIOS) {
      await messaging.setForegroundNotificationPresentationOptions(
        alert: true,
        badge: true,
        sound: true,
      );
    }

    const androidInit = AndroidInitializationSettings('@mipmap/logo');
    const iosInit = DarwinInitializationSettings();
    await _local.initialize(
      const InitializationSettings(android: androidInit, iOS: iosInit),
      onDidReceiveNotificationResponse: _onLocalNotificationTap,
    );

    final androidPlugin = _local.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();
    await androidPlugin?.createNotificationChannel(
      const AndroidNotificationChannel(
        _androidChannelId,
        _androidChannelName,
        description: 'Thông báo khi có episode mới trên 6 Mins Learning English Online',
        importance: Importance.high,
      ),
    );

    FirebaseMessaging.onMessage.listen(_onForegroundMessage);
    FirebaseMessaging.onMessageOpenedApp.listen(_handleEpisodePushTap);

    final initialMessage = await FirebaseMessaging.instance.getInitialMessage();
    if (initialMessage != null) {
      _pendingLaunchData = Map<String, dynamic>.from(initialMessage.data);
    }

    _initialized = true;

    if (requestPermissions || subscribeToTopics) {
      await completePermissionAndTopicSetup(
        requestPermissions: requestPermissions,
        subscribeToTopics: subscribeToTopics,
      );
    }
  }

  Future<void> completePermissionAndTopicSetup({
    bool requestPermissions = true,
    bool subscribeToTopics = true,
  }) async {
    if (!_initialized || kIsWeb) return;
    if (!Platform.isAndroid && !Platform.isIOS) return;

    final messaging = FirebaseMessaging.instance;

    if (requestPermissions && !_permissionSetupDone) {
      if (Platform.isAndroid) {
        await Permission.notification.request();
      } else if (Platform.isIOS) {
        await messaging.requestPermission(alert: true, badge: true, sound: true);
      }
      _permissionSetupDone = true;
    }

    if (subscribeToTopics) {
      final prefs = await SharedPreferences.getInstance();
      final episodePushEnabled =
          prefs.getBool(prefKeyEpisodePushEnabled) ?? true;
      if (episodePushEnabled) {
        await messaging.subscribeToTopic(fcmTopicNewEpisodes);
        debugPrint(
          'PushNotificationService: subscribed to topic "$fcmTopicNewEpisodes"',
        );
      } else {
        await messaging.unsubscribeFromTopic(fcmTopicNewEpisodes);
        debugPrint(
          'PushNotificationService: unsubscribed from topic '
          '"$fcmTopicNewEpisodes" (saved preference)',
        );
      }
    }
  }

  /// Cold start từ notification — gọi sau khi shell chính (navigator) sẵn sàng.
  Future<void> processPendingLaunchNotification() async {
    if (kIsWeb) return;
    if (!Platform.isAndroid && !Platform.isIOS) return;
    if (_pendingLaunchConsumed || _pendingLaunchData == null) return;

    final data = _pendingLaunchData!;
    _pendingLaunchConsumed = true;
    _pendingLaunchData = null;
    _openEpisodeFromPushData(data);
  }

  /// Bật/tắt nhận push tập mới (topic [fcmTopicNewEpisodes]). Lưu [prefKeyEpisodePushEnabled].
  Future<void> setEpisodePushEnabled(bool enabled) async {
    if (kIsWeb) return;
    if (!Platform.isAndroid && !Platform.isIOS) return;

    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(prefKeyEpisodePushEnabled, enabled);

    try {
      final messaging = FirebaseMessaging.instance;
      if (enabled) {
        await messaging.subscribeToTopic(fcmTopicNewEpisodes);
      } else {
        await messaging.unsubscribeFromTopic(fcmTopicNewEpisodes);
      }
      debugPrint(
        'PushNotificationService: topic "$fcmTopicNewEpisodes" '
        '${enabled ? "subscribed" : "unsubscribed"}',
      );
    } catch (e) {
      debugPrint('PushNotificationService: setEpisodePushEnabled failed: $e');
    }
  }

  Future<bool> getEpisodePushEnabled() async {
    if (kIsWeb) return false;
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(prefKeyEpisodePushEnabled) ?? true;
  }

  void _onLocalNotificationTap(NotificationResponse response) {
    final payload = response.payload;
    if (payload == null || payload.isEmpty) return;

    try {
      final map = jsonDecode(payload) as Map<String, dynamic>;
      _openEpisodeFromPushData(map);
    } catch (e) {
      debugPrint('PushNotificationService: invalid local notification payload: $e');
    }
  }

  void _handleEpisodePushTap(RemoteMessage message) {
    _openEpisodeFromPushData(message.data);
  }

  void _openEpisodeFromPushData(Map<String, dynamic> data) {
    final episodeId = data['episodeId'] as String?;
    final category = data['category'] as String?;
    if (episodeId == null || episodeId.isEmpty) return;

    MediaNotificationLaunchHandler.openEpisodeFromNotification(
      episodeId: episodeId,
      category: category,
      year: data['year'] as String?,
      episodeKey: data['episodeKey'] as String?,
    );
  }

  String? _episodePushPayload(RemoteMessage message) {
    final episodeId = message.data['episodeId'] as String?;
    if (episodeId == null || episodeId.isEmpty) return null;

    return jsonEncode({
      'episodeId': episodeId,
      'category': message.data['category'],
      'year': message.data['year'],
      'episodeKey': message.data['episodeKey'],
    });
  }

  Future<void> _onForegroundMessage(RemoteMessage message) async {
    final n = message.notification;
    final title = n?.title ?? message.data['title'] as String? ?? '6 Mins Learning English Online';
    final body = n?.body ?? message.data['body'] as String? ?? '';
    final id = message.messageId?.hashCode ?? DateTime.now().millisecondsSinceEpoch ~/ 1000;

    await _local.show(
      id,
      title,
      body.isNotEmpty ? body : 'Có tập phát sóng mới',
      NotificationDetails(
        android: AndroidNotificationDetails(
          _androidChannelId,
          _androidChannelName,
          channelDescription: 'Thông báo episode mới',
          importance: Importance.high,
          priority: Priority.high,
          icon: '@mipmap/logo',
        ),
        iOS: const DarwinNotificationDetails(),
      ),
      payload: _episodePushPayload(message),
    );
  }
}
