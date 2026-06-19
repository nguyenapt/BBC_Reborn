import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:permission_handler/permission_handler.dart';
import '../models/episode.dart';
import '../utils/category_names.dart';
import 'image_cache_service.dart';

typedef MediaActionCallback = void Function(Map<String, dynamic> data);
typedef NotificationTapCallback = void Function(String episodeId, String? category);

class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  static const MethodChannel _channel = MethodChannel('media_notification');
  bool _isInitialized = false;
  bool _notificationPermissionGranted = false;
  String? _cachedThumbEpisodeId;
  String? _cachedThumbLocalPath;
  MediaActionCallback? _onMediaAction;
  NotificationTapCallback? _onNotificationTap;

  void setMediaActionCallback(MediaActionCallback callback) {
    _onMediaAction = callback;
  }

  void setNotificationTapCallback(NotificationTapCallback callback) {
    _onNotificationTap = callback;
  }

  Future<void> initialize() async {
    if (_isInitialized) return;

    _channel.setMethodCallHandler(_handleMethodCall);
    _isInitialized = true;
  }

  Future<dynamic> _handleMethodCall(MethodCall call) async {
    switch (call.method) {
      case 'onMediaAction':
        final data = Map<String, dynamic>.from(call.arguments as Map);
        _handleMediaAction(data);
        break;
      case 'onNotificationTap':
        final data = Map<String, dynamic>.from(call.arguments as Map);
        final episodeId = data['episode_id'] as String?;
        final category = data['category'] as String?;
        if (episodeId != null && episodeId.isNotEmpty) {
          _onNotificationTap?.call(episodeId, category);
        }
        break;
    }
    return null;
  }

  void _handleMediaAction(Map<String, dynamic> data) {
    _onMediaAction?.call(data);
  }

  Future<bool> _ensureNotificationPermission({bool requestIfNeeded = true}) async {
    if (kIsWeb || !Platform.isAndroid) return true;
    if (_notificationPermissionGranted) return true;

    final status = await Permission.notification.status;
    if (status.isGranted) {
      _notificationPermissionGranted = true;
      return true;
    }
    if (!requestIfNeeded) return false;
    if (status.isDenied || status.isLimited) {
      final result = await Permission.notification.request();
      _notificationPermissionGranted = result.isGranted;
      return result.isGranted;
    }
    if (status.isPermanentlyDenied) {
      debugPrint(
        'NotificationService: POST_NOTIFICATIONS permanently denied — '
        'media controls will not appear in notification shade.',
      );
    }
    return false;
  }

  /// Lấy file thumbnail đã cache (cùng nguồn với episode detail).
  Future<String?> _resolveThumbLocalPath(String url) async {
    return ImageCacheService().cachedImageLocalPath(url);
  }

  Future<void> showAudioNotification(
    Episode episode,
    bool isPlaying, {
    int duration = 0,
    int currentPosition = 0,
  }) async {
    if (!_isInitialized) await initialize();
    if (kIsWeb) return;
    if (!await _ensureNotificationPermission()) return;

    try {
      await _channel.invokeMethod(
        'showNotification',
        await _notificationPayload(
          episode,
          isPlaying,
          duration: duration,
          currentPosition: currentPosition,
        ),
      );
    } on PlatformException catch (e) {
      debugPrint("Failed to show notification: '${e.message}'.");
    }
  }

  Future<void> updateNotification(
    Episode episode,
    bool isPlaying, {
    int duration = 0,
    int currentPosition = 0,
  }) async {
    if (!_isInitialized) await initialize();
    if (kIsWeb) return;
    if (!await _ensureNotificationPermission(requestIfNeeded: false)) return;

    try {
      await _channel.invokeMethod(
        'updateNotification',
        await _notificationPayload(
          episode,
          isPlaying,
          duration: duration,
          currentPosition: currentPosition,
        ),
      );
    } on PlatformException catch (e) {
      debugPrint("Failed to update notification: '${e.message}'.");
    }
  }

  Future<Map<String, dynamic>> _notificationPayload(
    Episode episode,
    bool isPlaying, {
    required int duration,
    required int currentPosition,
  }) async {
    final episodeId = episode.id ?? '';
    if (_cachedThumbEpisodeId != episodeId) {
      _cachedThumbEpisodeId = episodeId;
      _cachedThumbLocalPath = await _resolveThumbLocalPath(episode.thumbImage);
    }

    return {
      'title': episode.episodeName,
      'content': CategoryNames.getDisplayName(episode.category),
      'isPlaying': isPlaying,
      'episodeId': episode.id,
      'category': episode.category,
      'duration': duration,
      'currentPosition': currentPosition,
      'thumbImageUrl': episode.thumbImage,
      'thumbImageLocalPath': _cachedThumbLocalPath,
    };
  }

  Future<void> hideNotification() async {
    if (!_isInitialized) return;
    if (kIsWeb) return;

    _cachedThumbEpisodeId = null;
    _cachedThumbLocalPath = null;

    try {
      await _channel.invokeMethod('hideNotification');
    } on PlatformException catch (e) {
      debugPrint("Failed to hide notification: '${e.message}'.");
    }
  }
}
