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

  static Future<void> openEpisodeFromNotification({
    required String episodeId,
    String? category,
  }) async {
    if (_isNavigating) return;
    _isNavigating = true;

    try {
      final audioService = AudioPlayerService();
      Episode? episode = audioService.currentEpisode;
      List<Episode> categoryEpisodes = audioService.currentCategoryEpisodes;

      if (episode?.id != episodeId) {
        episode = await LocalDatabaseService().getEpisodeById(episodeId);
      }

      if (episode == null) {
        debugPrint('MediaNotificationLaunchHandler: episode not found ($episodeId)');
        return;
      }

      if (categoryEpisodes.isEmpty ||
          !categoryEpisodes.any((e) => e.id == episode!.id)) {
        final resolvedCategory = category ?? episode.category;
        if (resolvedCategory.isNotEmpty) {
          categoryEpisodes =
              await FirebaseService().getEpisodesByCategory(resolvedCategory);
        }
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
}
