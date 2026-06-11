import 'dart:convert';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:http/http.dart' as http;
import '../config/firebase_rtdb_config.dart';
import '../config/rtdb_list_config.dart';
import '../models/category.dart';
import '../models/episode.dart';
import '../utils/category_names.dart';
import '../utils/debug_source_log.dart';
import 'api_daily_cache_keys.dart';
import 'local_database_service.dart';

class FirebaseService {
  static const String _baseUrl = kFirebaseRtdbBaseUrl;

  final LocalDatabaseService _apiCacheDb = LocalDatabaseService();

  bool _isFetchedToday(DateTime? lastFetched) {
    if (lastFetched == null) return false;
    final now = DateTime.now();
    return now.year == lastFetched.year &&
        now.month == lastFetched.month &&
        now.day == lastFetched.day;
  }

  /// Tối đa một lần tải [HomePage.json] mỗi ngày (SQLite); dùng chung cho Home, player, favourites.
  Future<List<Category>> getHomePageData() async {
    // Web: SQLite (sqflite_common_ffi_web) cần sqlite3.wasm trong web/; nếu thiếu, open DB trả null
    // → lỗi "unsupported result null (null)". Tránh SQLite cho luồng Home trên web.
    if (kIsWeb) {
      debugLogDataSource(
        'HomePage',
        'Web: skip SQLite cache — RTDB REST direct',
      );
      final body = await fetchHomePageJsonBody();
      return parseHomePageFromJsonBody(body);
    }

    final key = ApiDailyCacheKeys.homePage;
    final lastFetched = await _apiCacheDb.getApiDailyLastFetched(key);
    final cached = await _apiCacheDb.getApiDailyCachePayload(key);

    if (_isFetchedToday(lastFetched) && cached != null && cached.isNotEmpty) {
      debugLogDataSource(
        'HomePage',
        'SQLite api_daily_cache (key=$key, fetched today) — skip RTDB',
      );
      return parseHomePageFromJsonBody(cached);
    }

    debugLogDataSource('HomePage', 'RTDB REST GET .../List/HomePage.json or HomePage.json');
    final body = await fetchHomePageJsonBody();
    await _apiCacheDb.upsertApiDailyCache(key, body, DateTime.now());
    return parseHomePageFromJsonBody(body);
  }

  static Future<String> fetchHomePageJsonBody() async {
    if (RtdbListConfig.useSlimListPaths) {
      final slim = await http.get(
        Uri.parse('$_baseUrl/List/HomePage.json'),
        headers: {'Accept': 'application/json'},
      );
      if (slim.statusCode == 200 &&
          slim.body.isNotEmpty &&
          slim.body != 'null') {
        return slim.body;
      }
    }
    final response = await http.get(
      Uri.parse('$_baseUrl/HomePage.json'),
      headers: {'Accept': 'application/json'},
    );
    if (response.statusCode == 200) {
      return response.body;
    }
    throw Exception('Failed to load data: ${response.statusCode}');
  }

  static List<Category> parseHomePageFromJsonBody(String responseBody) {
    final Map<String, dynamic> data = json.decode(responseBody);
    final List<Category> categories = [];

    data.forEach((categoryName, categoryData) {
      if (categoryName == 'Grammar') {
        return;
      }
      if (categoryData is List) {
        final List<Episode> episodes = [];

        for (final episodeData in categoryData) {
          if (episodeData is Map<String, dynamic>) {
            try {
              final episodeId = episodeData['Id']?.toString() ?? '';
              if (episodeId.isNotEmpty) {
                episodes.add(Episode.fromJson(
                  episodeData,
                  episodeId,
                  listCategory: categoryName,
                ));
              }
            } catch (e) {
              print('Error parsing episode: $e');
            }
          }
        }

        if (episodes.isNotEmpty) {
          categories.add(Category(
            name: categoryName,
            episodes: episodes,
          ));
        }
      }
    });

    categories.sort((a, b) => a.name.compareTo(b.name));
    return categories;
  }

  // Lấy tất cả episodes từ một category cụ thể
  Future<List<Episode>> getEpisodesByCategory(String categoryName) async {
    try {
      if (RtdbListConfig.useSlimListPaths) {
        final slim = await http.get(
          Uri.parse('$_baseUrl/List/HomePage/$categoryName.json'),
          headers: {'Accept': 'application/json'},
        );
        if (slim.statusCode == 200 && slim.body.isNotEmpty && slim.body != 'null') {
          final dynamic data = json.decode(slim.body);
          return _parseCategoryYearPayload(data, listCategory: categoryName);
        }
      }

      final response = await http.get(
        Uri.parse('$_baseUrl/HomePage/$categoryName.json'),
        headers: {'Accept': 'application/json'},
      );

      if (response.statusCode == 200) {
        final Map<String, dynamic> data = json.decode(response.body);
        final List<Episode> episodes = [];

        data.forEach((episodeId, episodeData) {
          if (episodeData is Map<String, dynamic>) {
            episodes.add(Episode.fromJson(episodeData, episodeId));
          }
        });

        return episodes;
      } else {
        throw Exception('Failed to load episodes: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Error fetching episodes: $e');
    }
  }

  static List<Episode> _parseCategoryYearPayload(
    dynamic data, {
    String? listCategory,
  }) {
    final List<Episode> episodes = [];

    if (data is Map<String, dynamic>) {
      data.forEach((episodeId, episodeData) {
        if (episodeData is Map<String, dynamic>) {
          episodes.add(Episode.fromJson(
            episodeData,
            episodeId,
            listCategory: listCategory,
          ));
        }
      });
    } else if (data is List) {
      for (int i = 0; i < data.length; i++) {
        final episodeData = data[i];
        if (episodeData is Map<String, dynamic>) {
          final episodeId = episodeData['Id']?.toString() ?? i.toString();
          episodes.add(Episode.fromJson(
            episodeData,
            episodeId,
            listCategory: listCategory,
          ));
        }
      }
    } else if (data is Map<String, dynamic> && data.containsKey('Id')) {
      final episodeId = data['Id']?.toString() ?? '0';
      episodes.add(Episode.fromJson(
        data,
        episodeId,
        listCategory: listCategory,
      ));
    }

    episodes.sort((a, b) => b.publishedDate.compareTo(a.publishedDate));
    return episodes;
  }

  /// Parse payload của `AS/{sub}` nơi key thường là số (0,1,2...) nhưng GUID nằm ở field `Id`.
  /// Cần ưu tiên field `Id` để EpisodeDetail hydrate theo guid.
  static List<Episode> _parseAnotherSeriesPayload(dynamic data) {
    final List<Episode> episodes = [];
    if (data is Map<String, dynamic>) {
      data.forEach((key, value) {
        if (value is Map<String, dynamic>) {
          final guid = value['Id']?.toString();
          final resolvedId = (guid != null && guid.isNotEmpty) ? guid : key;
          episodes.add(Episode.fromJson(value, resolvedId));
        }
      });
    } else if (data is List) {
      for (int i = 0; i < data.length; i++) {
        final episodeData = data[i];
        if (episodeData is Map<String, dynamic>) {
          final guid = episodeData['Id']?.toString();
          final resolvedId =
              (guid != null && guid.isNotEmpty) ? guid : i.toString();
          episodes.add(Episode.fromJson(episodeData, resolvedId));
        }
      }
    }
    episodes.sort((a, b) => b.publishedDate.compareTo(a.publishedDate));
    return episodes;
  }

  /// Lấy episode đầy đủ (transcript/vocab) từ tree gốc — dùng sau khi list chỉ có bản mỏng.
  ///
  /// Thử `GET /{category}/{year}/{id}.json` hoặc `/{category}/{id}.json`; nếu không có (array layout),
  /// fallback tải cả năm / cả category **không** qua `List/`.
  static Future<Episode?> fetchEpisodeFull(Episode partial) async {
    final id = partial.id;
    if (id == null || id.isEmpty) return null;

    var category = partial.category;
    if (category.isEmpty) {
      category = await _resolveCategoryForEpisode(partial);
    }
    var yearParsed = int.tryParse(partial.year ?? '');
    if (yearParsed == null && partial.publishedDate.year > 1800) {
      yearParsed = partial.publishedDate.year;
    }

    if (yearParsed != null && yearParsed > 1800) {
      try {
        final direct = await http.get(
          Uri.parse('$_baseUrl/$category/$yearParsed/$id.json'),
          headers: {'Accept': 'application/json'},
        );
        if (direct.statusCode == 200 &&
            direct.body.isNotEmpty &&
            direct.body != 'null') {
          final decoded = json.decode(direct.body);
          if (decoded is Map<String, dynamic>) {
            return Episode.fromJson(decoded, id);
          }
        }
      } catch (_) {}

      // Another Series full tree: `/AS/{sub}/{year}/{id}.json`
      try {
        final asYear = await http.get(
          Uri.parse('$_baseUrl/AS/$category/$yearParsed/$id.json'),
          headers: {'Accept': 'application/json'},
        );
        if (asYear.statusCode == 200 &&
            asYear.body.isNotEmpty &&
            asYear.body != 'null') {
          final decoded = json.decode(asYear.body);
          if (decoded is Map<String, dynamic>) {
            return Episode.fromJson(decoded, id);
          }
        }
      } catch (_) {}

      try {
        final bulk = await getCategoryDataLegacyFull(category, yearParsed);
        for (final e in bulk) {
          if (e.id == id) return e;
        }
      } catch (_) {}
    }

    try {
      final direct = await http.get(
        Uri.parse('$_baseUrl/$category/$id.json'),
        headers: {'Accept': 'application/json'},
      );
      if (direct.statusCode == 200 &&
          direct.body.isNotEmpty &&
          direct.body != 'null') {
        final decoded = json.decode(direct.body);
        if (decoded is Map<String, dynamic>) {
          return Episode.fromJson(decoded, id);
        }
      }
    } catch (_) {}

    // Another Series full tree: `/AS/{sub}/{id}.json`
    try {
      final asDirect = await http.get(
        Uri.parse('$_baseUrl/AS/$category/$id.json'),
        headers: {'Accept': 'application/json'},
      );
      if (asDirect.statusCode == 200 &&
          asDirect.body.isNotEmpty &&
          asDirect.body != 'null') {
        final decoded = json.decode(asDirect.body);
        if (decoded is Map<String, dynamic>) {
          return Episode.fromJson(decoded, id);
        }
      }
    } catch (_) {}

    try {
      final bulk = await getCategoryDataWithoutYearLegacyFull(category);
      for (final e in bulk) {
        if (e.id == id) return e;
      }
    } catch (_) {}

    // Another Series: fallback bulk `/AS/{sub}.json` rồi match theo guid.
    try {
      final asBulk = await getAnotherSeriesFullBulk(category);
      for (final e in asBulk) {
        if (e.id == id) return e;
      }
    } catch (_) {}

    return null;
  }

  /// Khi JSON episode thiếu `Category` (dữ liệu migrate), thử khớp id trong tree gốc.
  static Future<String> _resolveCategoryForEpisode(Episode partial) async {
    final id = partial.id;
    if (id == null || id.isEmpty) return '';

    for (final code in CategoryNames.primaryTabCodes) {
      try {
        final bulk = await getCategoryDataWithoutYearLegacyFull(code);
        if (bulk.any((e) => e.id == id)) return code;
      } catch (_) {}
    }
    return '';
  }

  /// Luôn đọc `/{category}/{year}.json` (đầy đủ), không qua `List/`.
  static Future<List<Episode>> getCategoryDataLegacyFull(
    String category,
    int year,
  ) async {
    final response = await http.get(
      Uri.parse('$_baseUrl/$category/$year.json'),
      headers: {'Accept': 'application/json'},
    );
    if (response.statusCode != 200) {
      throw Exception('Failed to load category data: ${response.statusCode}');
    }
    final dynamic data = json.decode(response.body);
    return _parseCategoryYearPayload(data, listCategory: category);
  }

  /// Luôn đọc `/{category}.json` (đầy đủ).
  static Future<List<Episode>> getCategoryDataWithoutYearLegacyFull(
    String category,
  ) async {
    final response = await http.get(
      Uri.parse('$_baseUrl/$category.json'),
      headers: {'Accept': 'application/json'},
    );
    if (response.statusCode != 200) {
      throw Exception('Failed to load category data: ${response.statusCode}');
    }
    final dynamic data = json.decode(response.body);
    return _parseCategoryYearPayload(data, listCategory: category);
  }

  // Lấy dữ liệu category theo năm (cho CategoriesScreen)
  static Future<List<Episode>> getCategoryData(String category, int year) async {
    try {
      if (RtdbListConfig.useSlimListPaths) {
        final slim = await http.get(
          Uri.parse('$_baseUrl/List/$category/$year.json'),
          headers: {'Accept': 'application/json'},
        );
        if (slim.statusCode == 200 &&
            slim.body.isNotEmpty &&
            slim.body != 'null') {
          final dynamic data = json.decode(slim.body);
          return _parseCategoryYearPayload(data, listCategory: category);
        }
      }

      final response = await http.get(
        Uri.parse('$_baseUrl/$category/$year.json'),
        headers: {'Accept': 'application/json'},
      );

      if (response.statusCode == 200) {
        final dynamic data = json.decode(response.body);
        return _parseCategoryYearPayload(data, listCategory: category);
      } else {
        throw Exception('Failed to load category data: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Error fetching category data: $e');
    }
  }

  // Lấy dữ liệu category trực tiếp (không có year) - cho Other Programs
  static Future<List<Episode>> getCategoryDataWithoutYear(String category) async {
    try {
      if (RtdbListConfig.useSlimListPaths) {
        final slim = await http.get(
          Uri.parse('$_baseUrl/List/$category.json'),
          headers: {'Accept': 'application/json'},
        );
        if (slim.statusCode == 200 &&
            slim.body.isNotEmpty &&
            slim.body != 'null') {
          final dynamic data = json.decode(slim.body);
          return _parseCategoryYearPayload(data, listCategory: category);
        }
      }

      final response = await http.get(
        Uri.parse('$_baseUrl/$category.json'),
        headers: {'Accept': 'application/json'},
      );

      if (response.statusCode == 200) {
        final dynamic data = json.decode(response.body);
        return _parseCategoryYearPayload(data, listCategory: category);
      } else {
        throw Exception('Failed to load category data: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Error fetching category data: $e');
    }
  }

  // =========================
  // Another Series (AS) helpers
  // =========================

  /// `List` (slim) parent path cho AS.
  /// - Home: `List/HomePage/AS` (hoặc legacy `HomePage/AS`)
  /// - Other: `List/AS` (hoặc legacy `AS`)
  static String anotherSeriesListParentPath({required bool forHomePage}) {
    if (RtdbListConfig.useSlimListPaths) {
      return forHomePage ? 'List/HomePage/AS' : 'List/AS';
    }
    return forHomePage ? 'HomePage/AS' : 'AS';
  }

  static bool _holdsAnotherSeriesEpisodePayload(dynamic v) {
    if (v == null) return false;
    if (v is List) return v.isNotEmpty;
    if (v is Map) return v.isNotEmpty;
    return false;
  }

  /// Parse các key sub (OF, EIM, …) từ JSON node cha AS.
  static List<String> parseAnotherSeriesSubKeys(String responseBody) {
    try {
      final decoded = json.decode(responseBody);
      if (decoded is! Map<String, dynamic>) return [];
      final keys = <String>[];
      decoded.forEach((k, v) {
        if (_holdsAnotherSeriesEpisodePayload(v)) keys.add(k);
      });
      keys.sort();
      return keys;
    } catch (_) {
      return [];
    }
  }

  /// Dùng RTDB `?shallow=true` để chỉ lấy key (nhẹ), tránh tải cả payload lớn.
  static Future<List<String>> _fetchShallowKeys(String path) async {
    try {
      final res = await http.get(
        Uri.parse('$_baseUrl/$path.json?shallow=true'),
        headers: {'Accept': 'application/json'},
      );
      if (res.statusCode != 200 || res.body.isEmpty || res.body == 'null') {
        return [];
      }
      final decoded = json.decode(res.body);
      if (decoded is! Map<String, dynamic>) return [];
      final keys = decoded.keys.map((e) => e.toString()).toList()..sort();
      return keys;
    } catch (_) {
      return [];
    }
  }

  /// Lấy danh sách sub key của AS cho Home/Other.
  /// Lưu ý: phiên bản "cũ" chỉ đọc đúng 1 nhánh theo [forHomePage].
  static Future<List<String>> fetchAnotherSeriesSubKeys({
    required bool forHomePage,
  }) async {
    // Luôn ưu tiên `List/...` vì payload mỏng, đúng chuẩn sub keys (OF/EIM/...)
    // Kể cả khi build tắt RTDB_SLIM_LIST, Android vẫn nên thử `List/AS` trước.
    final preferredListParent = forHomePage ? 'List/HomePage/AS' : 'List/AS';
    final legacyParent = anotherSeriesListParentPath(forHomePage: forHomePage);
    try {
      // Ưu tiên shallow để giảm payload (List/* trước)
      final shallowPreferred = await _fetchShallowKeys(preferredListParent);
      if (shallowPreferred.isNotEmpty) return shallowPreferred;

      // Nếu List/* không có, thử theo config hiện tại
      final shallowLegacy = await _fetchShallowKeys(legacyParent);
      if (shallowLegacy.isNotEmpty) return shallowLegacy;

      // Fallback: GET JSON thường (List/* trước)
      final resPreferred = await http.get(
        Uri.parse('$_baseUrl/$preferredListParent.json'),
        headers: {'Accept': 'application/json'},
      );
      if (resPreferred.statusCode == 200 &&
          resPreferred.body.isNotEmpty &&
          resPreferred.body != 'null') {
        final keys = parseAnotherSeriesSubKeys(resPreferred.body);
        if (keys.isNotEmpty) return keys;
      }

      final resLegacy = await http.get(
        Uri.parse('$_baseUrl/$legacyParent.json'),
        headers: {'Accept': 'application/json'},
      );
      if (resLegacy.statusCode == 200 &&
          resLegacy.body.isNotEmpty &&
          resLegacy.body != 'null') {
        final keys = parseAnotherSeriesSubKeys(resLegacy.body);
        if (keys.isNotEmpty) return keys;
      }

      // Fallback: nếu node `List/AS` chưa có/đã đổi, thử đọc key trực tiếp từ tree đầy đủ `/AS.json`.
      return _fetchAnotherSeriesSubKeysFromFullTree();
    } catch (_) {
      return _fetchAnotherSeriesSubKeysFromFullTree();
    }
  }

  static Future<List<String>> _fetchAnotherSeriesSubKeysFromFullTree() async {
    // Thử lấy key theo shallow ở tree đầy đủ trước (nhanh và nhẹ)
    final shallow = await _fetchShallowKeys('AS');
    if (shallow.isNotEmpty) return shallow;

    // Fallback cuối: tải payload đầy đủ (có thể lớn)
    try {
      final res = await http.get(
        Uri.parse('$_baseUrl/AS.json'),
        headers: {'Accept': 'application/json'},
      );
      if (res.statusCode != 200 || res.body.isEmpty || res.body == 'null') {
        return [];
      }
      final decoded = json.decode(res.body);
      if (decoded is! Map<String, dynamic>) return [];
      final keys = <String>[];
      decoded.forEach((k, v) {
        if (_holdsAnotherSeriesEpisodePayload(v)) keys.add(k);
      });
      keys.sort();
      return keys;
    } catch (_) {
      return [];
    }
  }

  static List<Episode> _forceEpisodesCategory(
    List<Episode> episodes,
    String category,
  ) {
    if (episodes.isEmpty) return episodes;
    return episodes
        .map(
          (e) => Episode(
            actor: e.actor,
            category: category,
            duration: e.duration,
            publishedDate: e.publishedDate,
            episodeName: e.episodeName,
            transcript: e.transcript,
            thumbImage: e.thumbImage,
            id: e.id,
            fileUrl: e.fileUrl,
            secondFileUrl: e.secondFileUrl,
            summary: e.summary,
            year: e.year,
            transcriptHtml: e.transcriptHtml,
            vocabulary: e.vocabulary,
            vocabularies: e.vocabularies,
          ),
        )
        .toList();
  }

  /// Parse body JSON của một nhánh AS (List/AS/{sub} hoặc legacy) thành danh sách episode.
  static List<Episode> _parseAnotherSeriesListBody(String body, String sub) {
    if (body.isEmpty || body == 'null') return [];
    try {
      final dynamic data = json.decode(body);
      final parsed = _parseAnotherSeriesPayload(data);
      return _forceEpisodesCategory(
        parsed.isNotEmpty
            ? parsed
            : _parseCategoryYearPayload(data, listCategory: sub),
        sub,
      );
    } catch (_) {
      return [];
    }
  }

  /// GET một path RTDB và parse thành episodes (Another Series).
  static Future<List<Episode>> _fetchAnotherSeriesListAtPath(
    String pathWithoutJson,
    String sub,
  ) async {
    try {
      final res = await http.get(
        Uri.parse('$_baseUrl/$pathWithoutJson.json'),
        headers: {'Accept': 'application/json'},
      );
      if (res.statusCode != 200 || res.body.isEmpty || res.body == 'null') {
        return [];
      }
      return _parseAnotherSeriesListBody(res.body, sub);
    } catch (_) {
      return [];
    }
  }

  /// Lấy list episode (payload mỏng) của 1 sub trong AS.
  ///
  /// Luôn ưu tiên `List/AS/{sub}` hoặc `List/HomePage/AS/{sub}` trước (bất kể [RtdbListConfig]),
  /// sau đó fallback theo [anotherSeriesListParentPath], cuối cùng bulk `AS/{sub}`.
  static Future<List<Episode>> getAnotherSeriesListEpisodes(
    String sub, {
    required bool forHomePage,
  }) async {
    final preferredListParent =
        forHomePage ? 'List/HomePage/AS' : 'List/AS';
    final legacyParent = anotherSeriesListParentPath(forHomePage: forHomePage);

    final fromList = await _fetchAnotherSeriesListAtPath(
      '$preferredListParent/$sub',
      sub,
    );
    if (fromList.isNotEmpty) return fromList;

    if (legacyParent != preferredListParent) {
      final fromLegacy = await _fetchAnotherSeriesListAtPath(
        '$legacyParent/$sub',
        sub,
      );
      if (fromLegacy.isNotEmpty) return fromLegacy;
    }

    return getAnotherSeriesFullBulk(sub);
  }

  /// Lấy bulk đầy đủ cho Another Series từ tree `AS/{sub}`.
  static Future<List<Episode>> getAnotherSeriesFullBulk(String sub) async {
    try {
      final res = await http.get(
        Uri.parse('$_baseUrl/AS/$sub.json'),
        headers: {'Accept': 'application/json'},
      );
      if (res.statusCode != 200 || res.body.isEmpty || res.body == 'null') {
        return [];
      }
      final dynamic data = json.decode(res.body);
      // AS/{sub} dùng key số, GUID nằm trong field `Id`.
      return _forceEpisodesCategory(_parseAnotherSeriesPayload(data), sub);
    } catch (_) {
      return [];
    }
  }
}
