import 'package:flutter/material.dart';

import '../models/episode.dart';
import '../screens/episode_detail_screen.dart';
import 'audio_player_service.dart';
import 'firebase_service.dart';
import 'local_database_service.dart';
import 'navigation_service.dart';

class MediaNotificationLaunchHandler {
  MediaNotificationLaunchHandler._();

  static bool _isNavigating = false;

  static const Duration _navigatorPollInterval = Duration(milliseconds: 100);
  static const int _navigatorMaxAttempts = 30;

  static Future<void> openEpisodeFromNotification({
    required String episodeId,
    String? category,
    String? year,
    String? episodeKey,
    String? rtdbPath,
  }) async {
    if (_isNavigating) return;
    _isNavigating = true;

    try {
      final navigatorReady = await _waitForNavigator();
      if (!navigatorReady) {
        debugPrint('MediaNotificationLaunchHandler: navigator not ready');
        return;
      }

      final audioService = AudioPlayerService();
      Episode? episode = audioService.currentEpisode;
      List<Episode> categoryEpisodes = audioService.currentCategoryEpisodes;

      if (episode?.id != episodeId) {
        episode = await LocalDatabaseService().getEpisodeById(episodeId);
      }

      episode ??= await FirebaseService.fetchEpisodeFromPushNotification(
        episodeId: episodeId,
        category: category,
        year: year,
        episodeKey: episodeKey,
        rtdbPath: rtdbPath,
      );

      if (episode == null) {
        debugPrint(
          'MediaNotificationLaunchHandler: episode not found ($episodeId, '
          'category=$category, year=$year, key=$episodeKey, rtdbPath=$rtdbPath)',
        );
        return;
      }

      if (categoryEpisodes.isEmpty ||
          !categoryEpisodes.any((e) => e.id == episode!.id)) {
        categoryEpisodes = await _loadCategoryEpisodes(episode, category);
      }

      if (categoryEpisodes.isEmpty) {
        categoryEpisodes = [episode];
      }

      // App đã mở từ background trong khi đang phát episode này — không push trùng.
      if (audioService.currentEpisode?.id == episodeId &&
          (audioService.isPlaying || audioService.isPaused)) {
        return;
      }

      final navigator = NavigationService.navigatorKey.currentState;
      if (navigator == null) {
        debugPrint('MediaNotificationLaunchHandler: navigator not ready');
        return;
      }

      await navigator.push(
        MaterialPageRoute(
          builder: (ctx) => EpisodeDetailScreen(
            episode: episode!,
            categoryEpisodes: categoryEpisodes,
          ),
        ),
      );
    } catch (e, st) {
      debugPrint('MediaNotificationLaunchHandler failed: $e\n$st');
    } finally {
      _isNavigating = false;
    }
  }

  static Future<bool> _waitForNavigator() async {
    for (var attempt = 0; attempt < _navigatorMaxAttempts; attempt++) {
      if (NavigationService.navigatorKey.currentState != null) {
        return true;
      }
      await Future<void>.delayed(_navigatorPollInterval);
    }
    return NavigationService.navigatorKey.currentState != null;
  }

  static Future<List<Episode>> _loadCategoryEpisodes(
    Episode episode,
    String? category,
  ) async {
    final resolvedCategory = category ?? episode.category;
    if (resolvedCategory.isEmpty) return [episode];

    final yearParsed = int.tryParse(episode.year ?? '');
    if (yearParsed != null && yearParsed > 1800) {
      try {
        return await FirebaseService.getCategoryDataLegacyFull(
          resolvedCategory,
          yearParsed,
        );
      } catch (_) {}

      try {
        return await FirebaseService.getCategoryData(
          resolvedCategory,
          yearParsed,
        );
      } catch (_) {}
    }

    try {
      return await FirebaseService().getEpisodesByCategory(resolvedCategory);
    } catch (e) {
      debugPrint('MediaNotificationLaunchHandler: category load failed: $e');
      return [episode];
    }
  }
}
