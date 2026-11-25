import 'dart:convert';
import 'package:flutter/foundation.dart' show debugPrint, kIsWeb;
import 'package:http/http.dart' as http;
import '../config/firebase_rtdb_config.dart';
import '../models/cefr_category.dart';
import '../models/cefr_level.dart';
import '../models/episode.dart';
import '../models/sub_category.dart';
import '../utils/debug_source_log.dart';
import 'api_daily_cache_keys.dart';
import 'local_database_service.dart';
import 'web_api_daily_cache.dart';

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

  /// Load one CEFR level (`/{level}.json`) with daily cache.
  Future<CefrCategory> getLevel(String levelCode) async {
    final level = CefrLevel.parse(levelCode);
    final key = ApiDailyCacheKeys.cefrLevel(level.code);

    if (kIsWeb) {
      final webCached = await WebApiDailyCache.getPayload(key);
      if (webCached != null && webCached.isNotEmpty) {
        debugLogDataSource(level.code, 'Web SharedPreferences daily cache HIT');
        return parseCefrCategoryFromJsonBody(level, webCached);
      }
      debugLogDataSource(level.code, 'Web: RTDB REST (cold day)');
      final body = await fetchLevelJsonBody(level.code);
      await WebApiDailyCache.putPayload(key, body);
      return parseCefrCategoryFromJsonBody(level, body);
    }

    final lastFetched = await _apiCacheDb.getApiDailyLastFetched(key);
    final cached = await _apiCacheDb.getApiDailyCachePayload(key);
    if (_isFetchedToday(lastFetched) && cached != null && cached.isNotEmpty) {
      debugLogDataSource(
        level.code,
        'SQLite api_daily_cache (key=$key, fetched today) — skip RTDB',
      );
      return parseCefrCategoryFromJsonBody(level, cached);
    }

    debugLogDataSource(level.code, 'RTDB REST GET .../${level.code}.json');
    final body = await fetchLevelJsonBody(level.code);
    await _apiCacheDb.upsertApiDailyCache(key, body, DateTime.now());
    return parseCefrCategoryFromJsonBody(level, body);
  }

  /// Load all CEFR levels A1–C2.
  Future<List<CefrCategory>> getAllLevels() async {
    final out = <CefrCategory>[];
    for (final level in CefrLevel.all) {
      try {
        out.add(await getLevel(level.code));
      } catch (e) {
        debugPrint('getAllLevels ${level.code}: $e');
        out.add(CefrCategory(level: level));
      }
    }
    return out;
  }

  static Future<String> fetchLevelJsonBody(String levelCode) async {
    final response = await http.get(
      Uri.parse('$_baseUrl/$levelCode.json'),
      headers: {'Accept': 'application/json'},
    );
    if (response.statusCode == 200 &&
        response.body.isNotEmpty &&
        response.body != 'null') {
      return response.body;
    }
    // Empty level still valid scaffold.
    if (response.statusCode == 200) {
      return '{}';
    }
    throw Exception('Failed to load level $levelCode: ${response.statusCode}');
  }

  static CefrCategory parseCefrCategoryFromJsonBody(
    CefrLevel level,
    String responseBody,
  ) {
    if (responseBody.isEmpty || responseBody == 'null') {
      return CefrCategory(level: level);
    }
    final decoded = json.decode(responseBody);
    if (decoded is! Map<String, dynamic>) {
      return CefrCategory(level: level);
    }
    return parseCefrCategoryFromMap(level, decoded);
  }

  static CefrCategory parseCefrCategoryFromMap(
    CefrLevel level,
    Map<String, dynamic> data,
  ) {
    final metadataRaw = data['metadata'];
    String? metadata;
    if (metadataRaw is String && metadataRaw.trim().isNotEmpty) {
      metadata = metadataRaw;
    } else if (metadataRaw is Map && metadataRaw.isNotEmpty) {
      metadata = metadataRaw.toString();
    }

    final subsRaw = data['sub-categories'];
    final subs = <SubCategory>[];
    if (subsRaw is List) {
      for (var i = 0; i < subsRaw.length; i++) {
        final item = subsRaw[i];
        if (item is Map<String, dynamic>) {
          subs.add(_parseSubCategory(level, i, item));
        } else if (item is Map) {
          subs.add(
            _parseSubCategory(level, i, Map<String, dynamic>.from(item)),
          );
        }
      }
    } else if (subsRaw is Map) {
      final entries = subsRaw.entries.toList()
        ..sort((a, b) {
          final ai = int.tryParse(a.key.toString()) ?? 0;
          final bi = int.tryParse(b.key.toString()) ?? 0;
          return ai.compareTo(bi);
        });
      for (final entry in entries) {
        final index = int.tryParse(entry.key.toString()) ?? subs.length;
        final value = entry.value;
        if (value is Map<String, dynamic>) {
          subs.add(_parseSubCategory(level, index, value));
        } else if (value is Map) {
          subs.add(
            _parseSubCategory(
              level,
              index,
              Map<String, dynamic>.from(value),
            ),
          );
        }
      }
      subs.sort((a, b) => a.index.compareTo(b.index));
    }

    return CefrCategory(
      level: level,
      metadata: metadata,
      subCategories: subs,
    );
  }

  static SubCategory _parseSubCategory(
    CefrLevel level,
    int index,
    Map<String, dynamic> data,
  ) {
    final text = data['text']?.toString().trim() ?? '';
    final episodes = _parseEpisodesPayload(
      data['episodes'],
      levelCode: level.code,
      subIndex: index,
    );
    return SubCategory(index: index, text: text, episodes: episodes);
  }

  static List<Episode> _parseEpisodesPayload(
    dynamic data, {
    required String levelCode,
    required int subIndex,
  }) {
    final episodes = <Episode>[];
    if (data == null || data == '' || data is String) {
      return episodes;
    }

    if (data is List) {
      for (var i = 0; i < data.length; i++) {
        final item = data[i];
        if (item is Map<String, dynamic>) {
          episodes.add(
            _episodeFromMap(item, i.toString(), levelCode, subIndex),
          );
        } else if (item is Map) {
          episodes.add(
            _episodeFromMap(
              Map<String, dynamic>.from(item),
              i.toString(),
              levelCode,
              subIndex,
            ),
          );
        }
      }
    } else if (data is Map<String, dynamic>) {
      data.forEach((key, value) {
        if (value is Map<String, dynamic>) {
          episodes.add(_episodeFromMap(value, key, levelCode, subIndex));
        } else if (value is Map) {
          episodes.add(
            _episodeFromMap(
              Map<String, dynamic>.from(value),
              key,
              levelCode,
              subIndex,
            ),
          );
        }
      });
    } else if (data is Map) {
      data.forEach((key, value) {
        if (value is Map) {
          episodes.add(
            _episodeFromMap(
              Map<String, dynamic>.from(value),
              key.toString(),
              levelCode,
              subIndex,
            ),
          );
        }
      });
    }

    return episodes;
  }

  static Episode _episodeFromMap(
    Map<String, dynamic> json,
    String fallbackKey,
    String levelCode,
    int subIndex,
  ) {
    final guid = json['Id']?.toString();
    final id = (guid != null && guid.isNotEmpty) ? guid : fallbackKey;
    final episode = Episode.fromJson(json, id);
    final existingPath = episode.rtdbPath?.trim();
    if (existingPath != null && existingPath.isNotEmpty) {
      return episode;
    }
    return Episode(
      id: episode.id,
      actor: episode.actor,
      category: episode.category.isNotEmpty ? episode.category : levelCode,
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
      rtdbPath: '$levelCode/sub-categories/$subIndex/episodes/$fallbackKey',
    );
  }

  /// Episodes for one subcategory (network, no year).
  static Future<List<Episode>> getSubCategoryEpisodes(
    String levelCode,
    int subIndex,
  ) async {
    final response = await http.get(
      Uri.parse(
        '$_baseUrl/$levelCode/sub-categories/$subIndex/episodes.json',
      ),
      headers: {'Accept': 'application/json'},
    );
    if (response.statusCode != 200 ||
        response.body.isEmpty ||
        response.body == 'null') {
      return [];
    }
    final decoded = json.decode(response.body);
    return _parseEpisodesPayload(
      decoded,
      levelCode: levelCode,
      subIndex: subIndex,
    );
  }

  /// All episodes for a level in subcategory index order (0→1→2…).
  Future<List<Episode>> getLevelEpisodesInSubOrder(String levelCode) async {
    final level = await getLevel(levelCode);
    return level.allEpisodesInSubOrder;
  }

  /// Flat list of every episode across A1–C2 (for favourites / player lookup).
  Future<List<Episode>> getAllEpisodesFlat() async {
    final levels = await getAllLevels();
    final out = <Episode>[];
    for (final level in levels) {
      out.addAll(level.allEpisodesInSubOrder);
    }
    return out;
  }

  /// Grammar-labelled subcategories across all levels (episodes as content source).
  Future<List<Episode>> getGrammarSubCategoryEpisodes() async {
    final levels = await getAllLevels();
    final out = <Episode>[];
    for (final level in levels) {
      for (final sub in level.subCategories) {
        if (sub.isGrammar) {
          out.addAll(sub.episodes);
        }
      }
    }
    return out;
  }

  /// Tải episode từ RTDB theo payload FCM (`rtdbPath` / episodeId).
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

    // CEFR: try category as level + episodeKey under each sub-category.
    final level = CefrLevel.tryParse(category);
    if (level != null && episodeKey != null && episodeKey.isNotEmpty) {
      for (var i = 0; i < 20; i++) {
        final path =
            '${level.code}/sub-categories/$i/episodes/$episodeKey';
        final found = await _fetchEpisodeAtRtdbPath(path, episodeId);
        if (found != null) return found;
      }
    }

    return fetchEpisodeFull(
      Episode(
        actor: '',
        category: category ?? '',
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

  static bool _episodeIdsMatch(String a, String b) {
    if (a.isEmpty || b.isEmpty) return false;
    return a.toLowerCase() == b.toLowerCase();
  }

  static bool _episodeHasTranscript(Episode e) {
    if (e.transcript.trim().isNotEmpty) return true;
    final html = e.transcriptHtml?.trim();
    return html != null && html.isNotEmpty;
  }

  /// Chỉ cho phép path an toàn: `A1/sub-categories/0/episodes/3`, …
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

  /// Mô tả ngắn đường dẫn sẽ thử khi mở detail (debug).
  static String describeEpisodeDetailRequest(Episode partial) {
    final id = partial.id ?? '?';
    final rtdb = _sanitizeRtdbPath(partial.rtdbPath);
    if (rtdb != null && rtdb.isNotEmpty) {
      return 'Request detail → GET /$rtdb.json (RtdbPath, id=$id)';
    }
    final level = CefrLevel.tryParse(partial.category);
    if (level != null) {
      return 'Request detail → search ${level.code}/sub-categories/*/episodes (id=$id)';
    }
    return 'Request detail → RtdbPath missing (id=$id)';
  }

  /// Kết quả [fetchEpisodeFullWithSource] — dùng snackbar debug.
  static Future<EpisodeFullFetchOutcome> fetchEpisodeFullWithSource(
    Episode partial,
  ) async {
    final id = partial.id;
    if (id == null || id.isEmpty) {
      return const EpisodeFullFetchOutcome(null, 'MISS — thiếu episode id');
    }

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

    // Fallback: scan CEFR levels for matching id.
    try {
      final service = FirebaseService();
      final levels = await service.getAllLevels();
      for (final level in levels) {
        for (final sub in level.subCategories) {
          for (final e in sub.episodes) {
            if (_episodeIdsMatch(e.id ?? '', id)) {
              if (_episodeHasTranscript(e)) {
                final label =
                    'CEFR ${level.code}/sub-categories/${sub.index} (match id)';
                _debugEpisodeDetailFetch(label);
                return EpisodeFullFetchOutcome(e, label);
              }
              final rtdb = _sanitizeRtdbPath(e.rtdbPath);
              if (rtdb != null) {
                final full = await _fetchEpisodeAtRtdbPath(rtdb, id);
                if (full != null) {
                  final label = 'GET /$rtdb.json (CEFR scan)';
                  _debugEpisodeDetailFetch(label);
                  return EpisodeFullFetchOutcome(full, label);
                }
              }
            }
          }
        }
      }
    } catch (e) {
      debugPrint('CEFR scan fallback failed: $e');
    }

    const label = 'MISS — không tìm thấy full episode sau mọi fallback';
    _debugEpisodeDetailFetch(label);
    return const EpisodeFullFetchOutcome(null, label);
  }

  static void _debugEpisodeDetailFetch(String message) {
    debugPrint('[EpisodeDetail] $message');
    debugLogDataSource('EpisodeDetail', message);
  }

  /// Lấy episode đầy đủ (transcript/vocab) — SQLite → RtdbPath → CEFR scan.
  static Future<Episode?> fetchEpisodeFull(Episode partial) async {
    return (await fetchEpisodeFullWithSource(partial)).episode;
  }
}

/// Kết quả hydrate episode detail — dùng snackbar debug.
class EpisodeFullFetchOutcome {
  final Episode? episode;
  final String sourceLabel;

  const EpisodeFullFetchOutcome(this.episode, this.sourceLabel);
}
