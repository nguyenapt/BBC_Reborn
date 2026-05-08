import 'package:flutter/foundation.dart';
import '../models/episode.dart';
import '../utils/debug_source_log.dart';
import 'firebase_service.dart';
import 'local_database_service.dart';

class EpisodeCacheService {
  static final EpisodeCacheService _instance = EpisodeCacheService._internal();
  factory EpisodeCacheService() => _instance;
  EpisodeCacheService._internal();

  final LocalDatabaseService _db = LocalDatabaseService();

  Future<List<Episode>> getCategoryEpisodes(String category, int year) async {
    if (kIsWeb) {
      debugLogDataSource(
        'Category',
        '$category/$year | Web — RTDB (no SQLite)',
      );
      return FirebaseService.getCategoryData(category, year);
    }

    final cached = await _db.getEpisodesByCategoryYear(category, year);
    final lastFetched = await _db.getCategoryLastFetched(category, year);
    final fetchedToday = _isFetchedToday(lastFetched);

    if (cached.isNotEmpty && fetchedToday) {
      debugLogDataSource(
        'Category',
        '$category/$year | SQLite episodes (fetched today) — skip RTDB',
      );
      return cached;
    }

    if (!fetchedToday) {
      try {
        debugLogDataSource(
          'Category',
          '$category/$year | RTDB REST GET .../$category/$year.json',
        );
        final apiEpisodes = await FirebaseService.getCategoryData(category, year);
        // Tránh negative-cache: nếu API trả rỗng (do lỗi mạng/timeout/đang migrate dữ liệu),
        // không đánh dấu fetchedToday để lần sau còn retry.
        if (apiEpisodes.isNotEmpty) {
          await _db.insertEpisodesIfMissing(category, year, apiEpisodes);
          await _db.upsertCategoryFetch(category, year, DateTime.now());
        }
      } catch (e) {
        debugPrint('Error fetching category $category/$year: $e');
      }
    }

    final refreshed = await _db.getEpisodesByCategoryYear(category, year);
    return refreshed.isNotEmpty ? refreshed : cached;
  }

  Future<List<Episode>> getCategoryEpisodesWithoutYear(String category) async {
    if (kIsWeb) {
      debugLogDataSource(
        'Category',
        '$category (no year) | Web — RTDB (no SQLite)',
      );
      return FirebaseService.getCategoryDataWithoutYear(category);
    }

    final year = LocalDatabaseService.noYear;
    final cached = await _db.getEpisodesByCategoryYear(category, year);
    final lastFetched = await _db.getCategoryLastFetched(category, year);
    final fetchedToday = _isFetchedToday(lastFetched);

    if (cached.isNotEmpty && fetchedToday) {
      debugLogDataSource(
        'Category',
        '$category (no year) | SQLite episodes (fetched today) — skip RTDB',
      );
      return cached;
    }

    if (!fetchedToday) {
      try {
        debugLogDataSource(
          'Category',
          '$category (no year) | RTDB REST GET .../$category.json',
        );
        final apiEpisodes = await FirebaseService.getCategoryDataWithoutYear(category);
        // Tránh negative-cache: nếu API trả rỗng (do lỗi mạng/timeout/đang migrate dữ liệu),
        // không đánh dấu fetchedToday để lần sau còn retry.
        if (apiEpisodes.isNotEmpty) {
          await _db.insertEpisodesIfMissing(category, year, apiEpisodes);
          await _db.upsertCategoryFetch(category, year, DateTime.now());
        }
      } catch (e) {
        debugPrint('Error fetching category $category: $e');
      }
    }

    final refreshed = await _db.getEpisodesByCategoryYear(category, year);
    return refreshed.isNotEmpty ? refreshed : cached;
  }

  /// Another Series: slim `List/HomePage/AS/{sub}` vs `List/AS/{sub}` — cache tách biệt.
  Future<List<Episode>> getAnotherSeriesSubEpisodes(
    String sub, {
    required bool forHomePage,
  }) async {
    final cacheCategory =
        forHomePage ? 'AS|home|$sub' : 'AS|list|$sub';

    if (kIsWeb) {
      debugLogDataSource(
        'Category',
        '$cacheCategory (Another Series) | Web — RTDB (no SQLite)',
      );
      return FirebaseService.getAnotherSeriesListEpisodes(
        sub,
        forHomePage: forHomePage,
      );
    }

    final year = LocalDatabaseService.noYear;
    final cached = await _db.getEpisodesByCategoryYear(cacheCategory, year);
    final lastFetched = await _db.getCategoryLastFetched(cacheCategory, year);
    final fetchedToday = _isFetchedToday(lastFetched);

    if (cached.isNotEmpty && fetchedToday) {
      debugLogDataSource(
        'Category',
        '$cacheCategory | SQLite episodes (fetched today) — skip RTDB',
      );
      return cached;
    }

    if (!fetchedToday) {
      try {
        debugLogDataSource(
          'Category',
          '$cacheCategory | RTDB Another Series slim list',
        );
        final apiEpisodes = await FirebaseService.getAnotherSeriesListEpisodes(
          sub,
          forHomePage: forHomePage,
        );
        // Tránh negative-cache: nếu API trả rỗng (do lỗi mạng/timeout/đang migrate dữ liệu),
        // không đánh dấu fetchedToday để lần sau còn retry.
        if (apiEpisodes.isNotEmpty) {
          await _db.insertEpisodesIfMissing(cacheCategory, year, apiEpisodes);
          await _db.upsertCategoryFetch(cacheCategory, year, DateTime.now());
        }
      } catch (e) {
        debugPrint('Error fetching Another Series $cacheCategory: $e');
      }
    }

    final refreshed = await _db.getEpisodesByCategoryYear(cacheCategory, year);
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
