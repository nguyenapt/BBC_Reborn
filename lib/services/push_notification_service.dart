import 'dart:io';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:permission_handler/permission_handler.dart';

import '../firebase_options.dart';

/// FCM topic nhận push khi có episode mới (broadcast — phải trùng topic trong Cloud Function).
const String fcmTopicNewEpisodes = 'episodes';

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

  Future<void> initialize() async {
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
    );

    final androidPlugin = _local.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();
    await androidPlugin?.createNotificationChannel(
      const AndroidNotificationChannel(
        _androidChannelId,
        _androidChannelName,
        description: 'Thông báo khi có episode mới trên BBC Learning English',
        importance: Importance.high,
      ),
    );

    if (Platform.isAndroid) {
      await Permission.notification.request();
    } else if (Platform.isIOS) {
      await messaging.requestPermission(alert: true, badge: true, sound: true);
    }

    FirebaseMessaging.onMessage.listen(_onForegroundMessage);

    await messaging.subscribeToTopic(fcmTopicNewEpisodes);
    debugPrint('PushNotificationService: subscribed to topic "$fcmTopicNewEpisodes"');
    _initialized = true;
  }

  Future<void> _onForegroundMessage(RemoteMessage message) async {
    final n = message.notification;
    final title = n?.title ?? message.data['title'] as String? ?? 'BBC Learning English';
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
    );
  }
}
