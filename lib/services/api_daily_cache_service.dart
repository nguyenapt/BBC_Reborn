import '../models/episode.dart';
import '../utils/debug_source_log.dart';
import 'firebase_service.dart';

/// Resolve favourites from CEFR level snapshots (daily-cached).
class ApiDailyCacheService {
  static final ApiDailyCacheService _instance = ApiDailyCacheService._internal();
  factory ApiDailyCacheService() => _instance;
  ApiDailyCacheService._internal();

  final FirebaseService _firebase = FirebaseService();

  Future<List<Episode>> episodesMatchingFavouriteIds(
    List<String> favouriteIds,
  ) async {
    if (favouriteIds.isEmpty) return [];
    debugLogDataSource(
      'Favourites',
      'Resolve favourites via getAllEpisodesFlat() (CEFR daily cache)',
    );
    final all = await _firebase.getAllEpisodesFlat();
    final set = favouriteIds.toSet();
    final out = <Episode>[];
    for (final ep in all) {
      final id = ep.id ?? '';
      if (id.isNotEmpty && set.contains(id)) {
        out.add(ep);
      }
    }
    return out;
  }
}
