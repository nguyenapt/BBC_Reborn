import 'package:flutter/foundation.dart';
import '../models/cefr_category.dart';
import '../models/cefr_level.dart';
import '../models/episode.dart';
import '../utils/debug_source_log.dart';
import 'firebase_service.dart';
import 'local_database_service.dart';

class EpisodeCacheService {
  static final EpisodeCacheService _instance = EpisodeCacheService._internal();
  factory EpisodeCacheService() => _instance;
  EpisodeCacheService._internal();

  final LocalDatabaseService _db = LocalDatabaseService();
  final FirebaseService _firebase = FirebaseService();

  /// Load full CEFR level (sub-categories + episodes) with daily SQLite cache.
  Future<CefrCategory> getLevel(String levelCode) async {
    final level = CefrLevel.parse(levelCode);
    if (kIsWeb) {
      debugLogDataSource(level.code, 'Web — RTDB (no SQLite)');
      return _firebase.getLevel(level.code);
    }

    final cacheCategory = 'CEFR|${level.code}';
    final lastFetched = await _db.getCollectionLastFetched(cacheCategory);
    final fetchedToday = _isFetchedToday(lastFetched);
    final cached = await _db.getEpisodesByCollectionKey(cacheCategory);

    // Prefer full daily JSON cache via FirebaseService (structure + texts).
    // Episode rows still help offline membership.
    try {
      final remote = await _firebase.getLevel(level.code);
      if (remote.subCategories.isNotEmpty ||
          remote.allEpisodesInSubOrder.isNotEmpty) {
        final all = remote.allEpisodesInSubOrder;
        if (all.isNotEmpty) {
          await _db.upsertEpisodes(
            category: level.code,
            year: LocalDatabaseService.noYear,
            episodes: all,
          );
          await _db.replaceCollectionItems(
            collectionKey: cacheCategory,
            episodeIds: all.map((e) => e.resolvedStorageId).toList(),
          );
          await _db.upsertCollectionFetch(cacheCategory, DateTime.now());
        }
        return remote;
      }
      if (fetchedToday && cached.isNotEmpty) {
        debugLogDataSource(
          level.code,
          'SQLite collection fallback (empty remote)',
        );
        return CefrCategory(
          level: level,
          subCategories: [],
        );
      }
      return remote;
    } catch (e) {
      debugPrint('getLevel ${level.code}: $e');
      if (cached.isNotEmpty) {
        return CefrCategory(
          level: level,
          subCategories: [],
        );
      }
      rethrow;
    }
  }

  Future<List<Episode>> getSubCategoryEpisodes(
    String levelCode,
    int subIndex,
  ) async {
    final level = await getLevel(levelCode);
    final sub = level.subAt(subIndex);
    return sub?.episodes ?? [];
  }

  /// All episodes for a level in subcategory node order (0→1→2…).
  Future<List<Episode>> getLevelEpisodesViewAll(String levelCode) async {
    final level = await getLevel(levelCode);
    return level.allEpisodesInSubOrder;
  }

  bool _isFetchedToday(DateTime? lastFetched) {
    if (lastFetched == null) return false;
    final now = DateTime.now();
    return now.year == lastFetched.year &&
        now.month == lastFetched.month &&
        now.day == lastFetched.day;
  }
}
