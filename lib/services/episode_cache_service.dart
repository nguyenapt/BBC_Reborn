import 'package:flutter/foundation.dart';
import '../models/episode.dart';
import 'firebase_service.dart';
import 'local_database_service.dart';

class EpisodeCacheService {
  static final EpisodeCacheService _instance = EpisodeCacheService._internal();
  factory EpisodeCacheService() => _instance;
  EpisodeCacheService._internal();

  final LocalDatabaseService _db = LocalDatabaseService();

  Future<List<Episode>> getCategoryEpisodes(String category, int year) async {
    final cached = await _db.getEpisodesByCategoryYear(category, year);
    final lastFetched = await _db.getCategoryLastFetched(category, year);
    final fetchedToday = _isFetchedToday(lastFetched);

    if (cached.isNotEmpty && fetchedToday) {
      return cached;
    }

    if (!fetchedToday) {
      try {
        final apiEpisodes = await FirebaseService.getCategoryData(category, year);
        await _db.insertEpisodesIfMissing(category, year, apiEpisodes);
        await _db.upsertCategoryFetch(category, year, DateTime.now());
      } catch (e) {
        debugPrint('Error fetching category $category/$year: $e');
      }
    }

    final refreshed = await _db.getEpisodesByCategoryYear(category, year);
    return refreshed.isNotEmpty ? refreshed : cached;
  }

  Future<List<Episode>> getCategoryEpisodesWithoutYear(String category) async {
    final year = LocalDatabaseService.noYear;
    final cached = await _db.getEpisodesByCategoryYear(category, year);
    final lastFetched = await _db.getCategoryLastFetched(category, year);
    final fetchedToday = _isFetchedToday(lastFetched);

    if (cached.isNotEmpty && fetchedToday) {
      return cached;
    }

    if (!fetchedToday) {
      try {
        final apiEpisodes = await FirebaseService.getCategoryDataWithoutYear(category);
        await _db.insertEpisodesIfMissing(category, year, apiEpisodes);
        await _db.upsertCategoryFetch(category, year, DateTime.now());
      } catch (e) {
        debugPrint('Error fetching category $category: $e');
      }
    }

    final refreshed = await _db.getEpisodesByCategoryYear(category, year);
    return refreshed.isNotEmpty ? refreshed : cached;
  }

  bool _isFetchedToday(DateTime? lastFetched) {
    if (lastFetched == null) return false;
    final now = DateTime.now();
    return now.year == lastFetched.year &&
        now.month == lastFetched.month &&
        now.day == lastFetched.day;
  }
}
