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

  /// Gộp `/{category}/{year}.json` cho năm hiện tại và [yearsBack] năm trước (trùng id gộp một).
  Future<List<Episode>> getCategoryEpisodesYearMerged(
    String category, {
    int yearsBack = 1,
  }) async {
    final currentYear = DateTime.now().year;
    final unique = <String, Episode>{};
    for (var i = 0; i <= yearsBack; i++) {
      final year = currentYear - i;
      try {
        final list = await getCategoryEpisodes(category, year);
        for (final e in list) {
          final key =
              e.id ?? '${e.episodeName}-${e.publishedDate.toIso8601String()}';
          unique[key] = e;
        }
      } catch (e) {
        debugPrint('getCategoryEpisodesYearMerged $category/$year: $e');
      }
    }
    final merged = unique.values.toList()
      ..sort((a, b) => b.publishedDate.compareTo(a.publishedDate));
    return merged;
  }

  /// Slot cố định trên Another Series: hầu hết dùng `/CAT.json`; **BSA** dùng `/BSA/{year}.json`.
  Future<List<Episode>> getAnotherSeriesFixedCategoryEpisodes(
    String category,
  ) async {
    if (category == 'BSA') {
      return getCategoryEpisodesYearMerged(category);
    }
    return getCategoryEpisodesWithoutYear(category);
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
      final slim = await FirebaseService.getAnotherSeriesListEpisodes(
        sub,
        forHomePage: forHomePage,
      );
      // Nếu node List/AS chưa sẵn sàng hoặc rỗng, fallback sang tree đầy đủ AS/{sub}.
      if (slim.isNotEmpty) return slim;
      return FirebaseService.getAnotherSeriesFullBulk(sub);
    }

    // Lưu entity episode theo `id` một lần (episodes table),
    // và lưu membership + thứ tự theo collection_key (collection tables).
    final lastFetched = await _db.getCollectionLastFetched(cacheCategory);
    final fetchedToday = _isFetchedToday(lastFetched);
    final cached = await _db.getEpisodesByCollectionKey(cacheCategory);

    if (cached.isNotEmpty && fetchedToday) {
      debugLogDataSource(
        'Category',
        '$cacheCategory | SQLite episodes (fetched today) — skip RTDB',
      );
      return cached;
    }

    if (!fetchedToday || cached.isEmpty) {
      try {
        debugLogDataSource(
          'Category',
          '$cacheCategory | RTDB Another Series slim list',
        );
        final apiEpisodes = await FirebaseService.getAnotherSeriesListEpisodes(
          sub,
          forHomePage: forHomePage,
        );
        final resolved = apiEpisodes.isNotEmpty
            ? apiEpisodes
            : await FirebaseService.getAnotherSeriesFullBulk(sub);
        // Tránh negative-cache: nếu API trả rỗng (do lỗi mạng/timeout/đang migrate dữ liệu),
        // không đánh dấu fetchedToday để lần sau còn retry.
        if (resolved.isNotEmpty) {
          await _db.upsertEpisodes(
            category: sub,
            year: LocalDatabaseService.noYear,
            episodes: resolved,
          );
          await _db.replaceCollectionItems(
            collectionKey: cacheCategory,
            episodeIds: resolved.map((e) => e.resolvedStorageId).toList(),
          );
          await _db.upsertCollectionFetch(cacheCategory, DateTime.now());
          final refreshedNow = await _db.getEpisodesByCollectionKey(cacheCategory);
          return refreshedNow.isNotEmpty ? refreshedNow : resolved;
        }
      } catch (e) {
        debugPrint('Error fetching Another Series $cacheCategory: $e');
      }
    }

    final refreshed = await _db.getEpisodesByCollectionKey(cacheCategory);
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
