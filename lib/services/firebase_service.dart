import 'dart:convert';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:http/http.dart' as http;
import '../config/rtdb_list_config.dart';
import '../models/category.dart';
import '../models/episode.dart';
import '../utils/debug_source_log.dart';
import 'api_daily_cache_keys.dart';
import 'local_database_service.dart';

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

  /// Lấy episode đầy đủ (transcript/vocab) từ tree gốc — dùng sau khi list chỉ có bản mỏng.
  ///
  /// Thử `GET /{category}/{year}/{id}.json` hoặc `/{category}/{id}.json`; nếu không có (array layout),
  /// fallback tải cả năm / cả category **không** qua `List/`.
  static Future<Episode?> fetchEpisodeFull(Episode partial) async {
    final guidId = partial.id?.trim() ?? '';
    final nodeKey = partial.nodeKey?.trim() ?? guidId;
    if (nodeKey.isEmpty) return null;

    final category = partial.category;
    var yearParsed = int.tryParse(partial.year ?? '');
    if (yearParsed == null && partial.publishedDate.year > 1800) {
      yearParsed = partial.publishedDate.year;
    }

    if (yearParsed != null && yearParsed > 1800) {
      try {
        final direct = await http.get(
          Uri.parse('$_baseUrl/$category/$yearParsed/$nodeKey.json'),
          headers: {'Accept': 'application/json'},
        );
        if (direct.statusCode == 200 &&
            direct.body.isNotEmpty &&
            direct.body != 'null') {
          final decoded = json.decode(direct.body);
          if (decoded is Map<String, dynamic>) {
            return Episode.fromJson(decoded, nodeKey);
          }
        }
      } catch (_) {}

      try {
        final bulk = await getCategoryDataLegacyFull(category, yearParsed);
        for (final e in bulk) {
          if ((guidId.isNotEmpty && e.id == guidId) || e.nodeKey == nodeKey) return e;
        }
      } catch (_) {}
    }

    try {
      final direct = await http.get(
        Uri.parse('$_baseUrl/$category/$nodeKey.json'),
        headers: {'Accept': 'application/json'},
      );
      if (direct.statusCode == 200 &&
          direct.body.isNotEmpty &&
          direct.body != 'null') {
        final decoded = json.decode(direct.body);
        if (decoded is Map<String, dynamic>) {
          return Episode.fromJson(decoded, nodeKey);
        }
      }
    } catch (_) {}

    try {
      final bulk = await getCategoryDataWithoutYearLegacyFull(category);
      for (final e in bulk) {
        if ((guidId.isNotEmpty && e.id == guidId) || e.nodeKey == nodeKey) return e;
      }
    } catch (_) {}

    return null;
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
}
