import 'dart:convert';
import 'package:flutter/foundation.dart' show debugPrint, kIsWeb;
import 'package:http/http.dart' as http;
import '../config/rtdb_list_config.dart';
import '../models/category.dart';
import '../models/episode.dart';
import '../utils/debug_source_log.dart';
import 'api_daily_cache_keys.dart';
import 'local_database_service.dart';
import 'web_api_daily_cache.dart';

class FirebaseService {
  static const String _baseUrl = 'https://bbc-listening-english.firebaseio.com';

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
    final key = ApiDailyCacheKeys.homePage;

    // Web: SharedPreferences daily cache (không dùng SQLite / wasm).
    if (kIsWeb) {
      final webCached = await WebApiDailyCache.getPayload(key);
      if (webCached != null && webCached.isNotEmpty) {
        debugLogDataSource('HomePage', 'Web SharedPreferences daily cache HIT');
        return parseHomePageFromJsonBody(webCached);
      }
      debugLogDataSource('HomePage', 'Web: RTDB REST (cold day)');
      final body = await fetchHomePageJsonBody();
      await WebApiDailyCache.putPayload(key, body);
      return parseHomePageFromJsonBody(body);
    }

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
                episodes.add(Episode.fromJson(episodeData, episodeId));
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
          return _parseCategoryYearPayload(data);
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

  static List<Episode> _parseCategoryYearPayload(dynamic data) {
    final List<Episode> episodes = [];

    if (data is Map<String, dynamic>) {
      data.forEach((episodeId, episodeData) {
        if (episodeData is Map<String, dynamic>) {
          episodes.add(Episode.fromJson(episodeData, episodeId));
        }
      });
    } else if (data is List) {
      for (int i = 0; i < data.length; i++) {
        final episodeData = data[i];
        if (episodeData is Map<String, dynamic>) {
          final episodeId = episodeData['Id']?.toString() ?? i.toString();
          episodes.add(Episode.fromJson(episodeData, episodeId));
        }
      }
    } else if (data is Map<String, dynamic> && data.containsKey('Id')) {
      final episodeId = data['Id']?.toString() ?? '0';
      episodes.add(Episode.fromJson(data, episodeId));
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

  /// Tải episode từ RTDB theo payload FCM playMP3 (`category`, `year`, `episodeKey`, `rtdbPath`, `episodeId`).
  ///
  /// playMP3 ghi `/{category}/{year}/{episodeKey}` — key là số tập, GUID nằm trong field `Id`.
  static Future<Episode?> fetchEpisodeFromPushNotification({
    required String episodeId,
    String? category,
    String? year,
    String? episodeKey,
    String? rtdbPath,
  }) async {
    if (episodeId.isEmpty) return null;

    final sanitizedPath = _sanitizeRtdbPath(rtdbPath);
    if (sanitizedPath != null) {
      final fromPath = await _fetchEpisodeAtRtdbPath(sanitizedPath, episodeId);
      if (fromPath != null) return fromPath;
    }

    if (category == null || category.isEmpty) {
      if (sanitizedPath == null) return null;
      return fetchEpisodeFull(
        Episode(
          actor: '',
          category: '',
          duration: '0',
          publishedDate: DateTime.now(),
          episodeName: '',
          transcript: '',
          thumbImage: '',
          id: episodeId,
          year: year,
          rtdbPath: sanitizedPath,
        ),
      );
    }

    final yearInt = int.tryParse(year ?? '');
    final pathsToTry = <String>[];

    if (episodeKey != null && episodeKey.isNotEmpty) {
      if (yearInt != null && yearInt > 1800) {
        pathsToTry.add('$_baseUrl/$category/$yearInt/$episodeKey.json');
        pathsToTry.add('$_baseUrl/AS/$category/$yearInt/$episodeKey.json');
      }
      pathsToTry.add('$_baseUrl/$category/$episodeKey.json');
      pathsToTry.add('$_baseUrl/AS/$category/$episodeKey.json');
    }

    for (final url in pathsToTry) {
      try {
        final response = await http.get(
          Uri.parse(url),
          headers: {'Accept': 'application/json'},
        );
        if (response.statusCode != 200 ||
            response.body.isEmpty ||
            response.body == 'null') {
          continue;
        }
        final decoded = json.decode(response.body);
        if (decoded is! Map<String, dynamic>) continue;

        final resolvedId = decoded['Id']?.toString() ?? episodeId;
        if (!_episodeIdsMatch(resolvedId, episodeId)) continue;

        return Episode.fromJson(decoded, resolvedId);
      } catch (_) {}
    }

    final partial = Episode(
      actor: '',
      category: category,
      duration: '0',
      publishedDate: yearInt != null && yearInt > 1800
          ? DateTime(yearInt)
          : DateTime.now(),
      episodeName: '',
      transcript: '',
      thumbImage: '',
      id: episodeId,
      year: year,
      rtdbPath: sanitizedPath,
    );
    return fetchEpisodeFull(partial);
  }

  static bool _episodeIdsMatch(String a, String b) {
    if (a.isEmpty || b.isEmpty) return false;
    return a.toLowerCase() == b.toLowerCase();
  }

  static bool _episodeHasTranscript(Episode e) {
    if (e.transcript.trim().isNotEmpty) return true;
    final html = e.transcriptHtml?.trim();
    return html != null && html.isNotEmpty;
  }

  /// Chỉ cho phép path an toàn: `6M/2026/11`, `AS/OF/11`, …
  static String? _sanitizeRtdbPath(String? raw) {
    if (raw == null) return null;
    var path = raw.trim().replaceAll('\\', '/');
    while (path.startsWith('/')) {
      path = path.substring(1);
    }
    if (path.toLowerCase().endsWith('.json')) {
      path = path.substring(0, path.length - 5);
    }
    if (path.isEmpty || path.contains('..')) return null;
    if (!RegExp(r'^[A-Za-z0-9_/\-]+$').hasMatch(path)) return null;
    return path;
  }

  static Future<Episode?> _fetchEpisodeAtRtdbPath(
    String rtdbPath,
    String preferredId,
  ) async {
    try {
      final response = await http.get(
        Uri.parse('$_baseUrl/$rtdbPath.json'),
        headers: {'Accept': 'application/json'},
      );
      if (response.statusCode != 200 ||
          response.body.isEmpty ||
          response.body == 'null') {
        return null;
      }
      final decoded = json.decode(response.body);
      if (decoded is! Map<String, dynamic>) return null;
      final resolvedId = decoded['Id']?.toString();
      final id = (resolvedId != null && resolvedId.isNotEmpty)
          ? resolvedId
          : preferredId;
      final episode = Episode.fromJson(decoded, id);
      if (episode.rtdbPath == null || episode.rtdbPath!.isEmpty) {
        return Episode(
          id: episode.id,
          actor: episode.actor,
          category: episode.category,
          duration: episode.duration,
          publishedDate: episode.publishedDate,
          episodeName: episode.episodeName,
          transcript: episode.transcript,
          thumbImage: episode.thumbImage,
          fileUrl: episode.fileUrl,
          secondFileUrl: episode.secondFileUrl,
          summary: episode.summary,
          year: episode.year,
          transcriptHtml: episode.transcriptHtml,
          vocabulary: episode.vocabulary,
          vocabularies: episode.vocabularies,
          rtdbPath: rtdbPath,
        );
      }
      return episode;
    } catch (_) {
      return null;
    }
  }

  /// Mô tả ngắn đường dẫn sẽ thử khi mở detail từ Home/List (debug).
  static String describeEpisodeDetailRequest(Episode partial) {
    final id = partial.id ?? '?';
    final rtdb = _sanitizeRtdbPath(partial.rtdbPath);
    if (rtdb != null && rtdb.isNotEmpty) {
      return 'Request detail → GET /$rtdb.json (RtdbPath, id=$id)';
    }

    final category = partial.category;
    var yearParsed = int.tryParse(partial.year ?? '');
    if (yearParsed == null && partial.publishedDate.year > 1800) {
      yearParsed = partial.publishedDate.year;
    }
    if (yearParsed != null && yearParsed > 1800) {
      return 'Request detail → GET /$category/$yearParsed/$id.json (fallback, chưa có RtdbPath)';
    }
    return 'Request detail → GET /$category/$id.json (fallback, không year)';
  }

  /// Kết quả [fetchEpisodeFullWithSource] — dùng snackbar debug.
  static Future<EpisodeFullFetchOutcome> fetchEpisodeFullWithSource(
    Episode partial,
  ) async {
    final id = partial.id;
    if (id == null || id.isEmpty) {
      return const EpisodeFullFetchOutcome(null, 'MISS — thiếu episode id');
    }

    // SQLite first — đã hydrate trước đó thì không gọi RTDB.
    if (!kIsWeb) {
      try {
        final fromDb = await LocalDatabaseService().getEpisodeById(id);
        if (fromDb != null && _episodeHasTranscript(fromDb)) {
          final label = 'SQLite cache ($id)';
          _debugEpisodeDetailFetch(label);
          return EpisodeFullFetchOutcome(fromDb, label);
        }
      } catch (e) {
        debugPrint('fetchEpisodeFull SQLite lookup failed: $e');
      }
    }

    final path = _sanitizeRtdbPath(partial.rtdbPath);
    if (path != null) {
      final fromPath = await _fetchEpisodeAtRtdbPath(path, id);
      if (fromPath != null) {
        final label = 'GET /$path.json (RtdbPath)';
        _debugEpisodeDetailFetch(label);
        return EpisodeFullFetchOutcome(fromPath, label);
      }
      debugPrint('[EpisodeDetail] RtdbPath MISS /$path.json — fallback');
    }

    final category = partial.category;
    var yearParsed = int.tryParse(partial.year ?? '');
    if (yearParsed == null && partial.publishedDate.year > 1800) {
      yearParsed = partial.publishedDate.year;
    }

    if (yearParsed != null && yearParsed > 1800) {
      final yearPath = '$category/$yearParsed/$id';
      try {
        final direct = await http.get(
          Uri.parse('$_baseUrl/$yearPath.json'),
          headers: {'Accept': 'application/json'},
        );
        if (direct.statusCode == 200 &&
            direct.body.isNotEmpty &&
            direct.body != 'null') {
          final decoded = json.decode(direct.body);
          if (decoded is Map<String, dynamic>) {
            final label = 'GET /$yearPath.json';
            _debugEpisodeDetailFetch(label);
            return EpisodeFullFetchOutcome(
              Episode.fromJson(decoded, id),
              label,
            );
          }
        }
      } catch (_) {}

      final asYearPath = 'AS/$category/$yearParsed/$id';
      try {
        final asYear = await http.get(
          Uri.parse('$_baseUrl/$asYearPath.json'),
          headers: {'Accept': 'application/json'},
        );
        if (asYear.statusCode == 200 &&
            asYear.body.isNotEmpty &&
            asYear.body != 'null') {
          final decoded = json.decode(asYear.body);
          if (decoded is Map<String, dynamic>) {
            final label = 'GET /$asYearPath.json';
            _debugEpisodeDetailFetch(label);
            return EpisodeFullFetchOutcome(
              Episode.fromJson(decoded, id),
              label,
            );
          }
        }
      } catch (_) {}

      try {
        final bulk = await getCategoryDataLegacyFull(category, yearParsed);
        for (final e in bulk) {
          if (_episodeIdsMatch(e.id ?? '', id)) {
            final label = 'bulk GET /$category/$yearParsed.json (match id)';
            _debugEpisodeDetailFetch(label);
            return EpisodeFullFetchOutcome(e, label);
          }
        }
      } catch (_) {}

      final asBulkPath = 'AS/$category/$yearParsed';
      try {
        final asYearBulk = await http.get(
          Uri.parse('$_baseUrl/$asBulkPath.json'),
          headers: {'Accept': 'application/json'},
        );
        if (asYearBulk.statusCode == 200 &&
            asYearBulk.body.isNotEmpty &&
            asYearBulk.body != 'null') {
          final decoded = json.decode(asYearBulk.body);
          final episodes = _parseAnotherSeriesPayload(decoded);
          for (final e in episodes) {
            if (_episodeIdsMatch(e.id ?? '', id)) {
              final label = 'bulk GET /$asBulkPath.json (match id)';
              _debugEpisodeDetailFetch(label);
              return EpisodeFullFetchOutcome(e, label);
            }
          }
        }
      } catch (_) {}
    }

    final flatPath = '$category/$id';
    try {
      final direct = await http.get(
        Uri.parse('$_baseUrl/$flatPath.json'),
        headers: {'Accept': 'application/json'},
      );
      if (direct.statusCode == 200 &&
          direct.body.isNotEmpty &&
          direct.body != 'null') {
        final decoded = json.decode(direct.body);
        if (decoded is Map<String, dynamic>) {
          final label = 'GET /$flatPath.json';
          _debugEpisodeDetailFetch(label);
          return EpisodeFullFetchOutcome(
            Episode.fromJson(decoded, id),
            label,
          );
        }
      }
    } catch (_) {}

    final asFlatPath = 'AS/$category/$id';
    try {
      final asDirect = await http.get(
        Uri.parse('$_baseUrl/$asFlatPath.json'),
        headers: {'Accept': 'application/json'},
      );
      if (asDirect.statusCode == 200 &&
          asDirect.body.isNotEmpty &&
          asDirect.body != 'null') {
        final decoded = json.decode(asDirect.body);
        if (decoded is Map<String, dynamic>) {
          final label = 'GET /$asFlatPath.json';
          _debugEpisodeDetailFetch(label);
          return EpisodeFullFetchOutcome(
            Episode.fromJson(decoded, id),
            label,
          );
        }
      }
    } catch (_) {}

    try {
      final bulk = await getCategoryDataWithoutYearLegacyFull(category);
      for (final e in bulk) {
        if (_episodeIdsMatch(e.id ?? '', id)) {
          final label = 'bulk GET /$category.json (match id)';
          _debugEpisodeDetailFetch(label);
          return EpisodeFullFetchOutcome(e, label);
        }
      }
    } catch (_) {}

    try {
      final asBulk = await getAnotherSeriesFullBulk(category);
      for (final e in asBulk) {
        if (_episodeIdsMatch(e.id ?? '', id)) {
          final label = 'bulk GET /AS/$category.json (match id)';
          _debugEpisodeDetailFetch(label);
          return EpisodeFullFetchOutcome(e, label);
        }
      }
    } catch (_) {}

    const label = 'MISS — không tìm thấy full episode sau mọi fallback';
    _debugEpisodeDetailFetch(label);
    return const EpisodeFullFetchOutcome(null, label);
  }

  static void _debugEpisodeDetailFetch(String message) {
    debugPrint('[EpisodeDetail] $message');
    debugLogDataSource('EpisodeDetail', message);
  }

  /// Lấy episode đầy đủ (transcript/vocab) từ tree gốc — dùng sau khi list chỉ có bản mỏng.
  ///
  /// Thứ tự: SQLite → RtdbPath GET → direct GET theo path → bulk theo năm/category.
  static Future<Episode?> fetchEpisodeFull(Episode partial) async {
    return (await fetchEpisodeFullWithSource(partial)).episode;
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
    return _parseCategoryYearPayload(data);
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
    return _parseCategoryYearPayload(data);
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
          return _parseCategoryYearPayload(data);
        }
      }

      final response = await http.get(
        Uri.parse('$_baseUrl/$category/$year.json'),
        headers: {'Accept': 'application/json'},
      );

      if (response.statusCode == 200) {
        final dynamic data = json.decode(response.body);
        return _parseCategoryYearPayload(data);
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
          return _parseCategoryYearPayload(data);
        }
      }

      final response = await http.get(
        Uri.parse('$_baseUrl/$category.json'),
        headers: {'Accept': 'application/json'},
      );

      if (response.statusCode == 200) {
        final dynamic data = json.decode(response.body);
        return _parseCategoryYearPayload(data);
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
  /// Cache SQLite tối đa 1 lần/ngày (mobile); web luôn fetch (xem [web_api_daily_cache]).
  static Future<List<String>> fetchAnotherSeriesSubKeys({
    required bool forHomePage,
  }) async {
    final cacheKey = forHomePage
        ? ApiDailyCacheKeys.anotherSeriesSubKeysHome
        : ApiDailyCacheKeys.anotherSeriesSubKeysList;

    if (!kIsWeb) {
      try {
        final db = LocalDatabaseService();
        final lastFetched = await db.getApiDailyLastFetched(cacheKey);
        final cached = await db.getApiDailyCachePayload(cacheKey);
        if (_isFetchedTodayStatic(lastFetched) &&
            cached != null &&
            cached.isNotEmpty) {
          final decoded = json.decode(cached);
          if (decoded is List) {
            final keys = decoded.map((e) => e.toString()).toList();
            if (keys.isNotEmpty) {
              debugLogDataSource(
                'AS',
                'SQLite api_daily_cache ($cacheKey) — skip RTDB sub-keys',
              );
              return keys;
            }
          }
        }
      } catch (e) {
        debugPrint('AS sub-keys cache read failed: $e');
      }
    } else {
      final webCached = await WebApiDailyCache.getStringList(cacheKey);
      if (webCached != null && webCached.isNotEmpty) {
        return webCached;
      }
    }

    final keys = await _fetchAnotherSeriesSubKeysNetwork(forHomePage: forHomePage);
    if (keys.isEmpty) return keys;

    try {
      final payload = json.encode(keys);
      if (!kIsWeb) {
        await LocalDatabaseService().upsertApiDailyCache(
          cacheKey,
          payload,
          DateTime.now(),
        );
      } else {
        await WebApiDailyCache.putStringList(cacheKey, keys);
      }
    } catch (e) {
      debugPrint('AS sub-keys cache write failed: $e');
    }
    return keys;
  }

  static bool _isFetchedTodayStatic(DateTime? lastFetched) {
    if (lastFetched == null) return false;
    final now = DateTime.now();
    return now.year == lastFetched.year &&
        now.month == lastFetched.month &&
        now.day == lastFetched.day;
  }

  static Future<List<String>> _fetchAnotherSeriesSubKeysNetwork({
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
      return await _fetchAnotherSeriesSubKeysFromFullTree();
    } catch (_) {
      return await _fetchAnotherSeriesSubKeysFromFullTree();
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
            rtdbPath: e.rtdbPath,
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
        parsed.isNotEmpty ? parsed : _parseCategoryYearPayload(data),
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

/// Kết quả hydrate episode detail — dùng snackbar debug.
class EpisodeFullFetchOutcome {
  final Episode? episode;
  final String sourceLabel;

  const EpisodeFullFetchOutcome(this.episode, this.sourceLabel);
}
