import 'package:flutter/services.dart';
import '../models/episode.dart';

class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  static const MethodChannel _channel = MethodChannel('media_notification');
  bool _isInitialized = false;

  /// Initialize notification service
  Future<void> initialize() async {
    if (_isInitialized) return;

    // Set up method call handler for media actions
    _channel.setMethodCallHandler(_handleMethodCall);
    _isInitialized = true;
  }

  /// Handle method calls from Android
  Future<dynamic> _handleMethodCall(MethodCall call) async {
    switch (call.method) {
      case 'onMediaAction':
        final data = Map<String, dynamic>.from(call.arguments);
        _handleMediaAction(data);
        break;
    }
  }

  /// Handle media action from notification
  void _handleMediaAction(Map<String, dynamic> data) {
    final action = data['action'] as String?;
    final episodeId = data['episode_id'] as String?;
    final category = data['category'] as String?;
    final duration = data['duration'] as int? ?? 0;
    final currentPosition = data['current_position'] as int? ?? 0;
    final timestamp = data['timestamp'] as int? ?? 0;

    print('Media action received: $action');
    print('Episode ID: $episodeId');
    print('Category: $category');
    print('Duration: $duration, Position: $currentPosition');
    print('Timestamp: $timestamp');

    // TODO: Implement actual media control logic
    // This should call AudioPlayerService methods based on action
  }

  /// Show audio player notification with full media controls
  Future<void> showAudioNotification(
    Episode episode, 
    bool isPlaying, {
    int duration = 0,
    int currentPosition = 0,
  }) async {
    if (!_isInitialized) await initialize();

    try {
      await _channel.invokeMethod('showNotification', {
        'title': episode.episodeName,
        'content': 'BBC Learning English - ${episode.category}',
        'isPlaying': isPlaying,
        'episodeId': episode.id,
        'category': episode.category,
        'duration': duration,
        'currentPosition': currentPosition,
      });
    } on PlatformException catch (e) {
      print("Failed to show notification: '${e.message}'.");
    }
  }

  /// Update notification with current state
  Future<void> updateNotification(
    Episode episode, 
    bool isPlaying, {
    int duration = 0,
    int currentPosition = 0,
  }) async {
    if (!_isInitialized) await initialize();

    try {
      await _channel.invokeMethod('updateNotification', {
        'title': episode.episodeName,
        'content': 'BBC Learning English - ${episode.category}',
        'isPlaying': isPlaying,
        'episodeId': episode.id,
        'category': episode.category,
        'duration': duration,
        'currentPosition': currentPosition,
      });
    } on PlatformException catch (e) {
      print("Failed to update notification: '${e.message}'.");
    }
  }

  /// Hide notification
  Future<void> hideNotification() async {
    if (!_isInitialized) return;

    try {
      await _channel.invokeMethod('hideNotification');
    } on PlatformException catch (e) {
      print("Failed to hide notification: '${e.message}'.");
    }
  }
}