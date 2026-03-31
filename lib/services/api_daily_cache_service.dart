import '../models/episode.dart';
import '../utils/debug_source_log.dart';
import 'firebase_service.dart';

/// Tái dùng [FirebaseService.getHomePageData] (cache tối đa một lần/ngày) cho favourites.
///
/// Theo dõi chi phí: Firebase Console → Realtime Database → Usage (downloaded GB);
/// Google Cloud Billing → filter SKU Storage egress sau khi triển khai.
class ApiDailyCacheService {
  static final ApiDailyCacheService _instance = ApiDailyCacheService._internal();
  factory ApiDailyCacheService() => _instance;
  ApiDailyCacheService._internal();

  final FirebaseService _firebase = FirebaseService();

  /// Resolve favourite từ cùng snapshot HomePage (không GET [HomePage.json] thêm).
  Future<List<Episode>> episodesMatchingFavouriteIds(List<String> favouriteIds) async {
    if (favouriteIds.isEmpty) return [];
    debugLogDataSource(
      'Favourites',
      'Lọc favourite qua getHomePageData() (cùng cache HomePage — không GET HomePage.json riêng)',
    );
    final categories = await _firebase.getHomePageData();
    final out = <Episode>[];
    final set = favouriteIds.toSet();
    for (final cat in categories) {
      for (final ep in cat.episodes) {
        final id = ep.id ?? '';
        if (id.isNotEmpty && set.contains(id)) {
          out.add(ep);
        }
      }
    }
    return out;
  }
}
