import 'dart:convert';
import 'package:flutter/foundation.dart' show kIsWeb;
import '../models/episode.dart';
import '../models/grammar.dart';
import '../utils/debug_source_log.dart';
import 'api_daily_cache_keys.dart';
import 'firebase_service.dart';
import 'local_database_service.dart';
import 'web_api_daily_cache.dart';

class GrammarService {
  final LocalDatabaseService _apiCacheDb = LocalDatabaseService();
  final FirebaseService _firebase = FirebaseService();

  bool _isFetchedToday(DateTime? lastFetched) {
    if (lastFetched == null) return false;
    final now = DateTime.now();
    return now.year == lastFetched.year &&
        now.month == lastFetched.month &&
        now.day == lastFetched.day;
  }

  /// Legacy Basic Grammar list — `HomePage/Grammar` removed on hard cutover.
  Future<List<Grammar>> getAllGrammars() async {
    try {
      final key = ApiDailyCacheKeys.grammarList;

      if (kIsWeb) {
        final webCached = await WebApiDailyCache.getPayload(key);
        if (webCached != null && webCached.isNotEmpty) {
          debugLogDataSource(
            'GrammarList',
            'Web SharedPreferences daily cache HIT',
          );
          return parseGrammarsFromJsonString(webCached);
        }
      } else {
        final lastFetched = await _apiCacheDb.getApiDailyLastFetched(key);
        final cached = await _apiCacheDb.getApiDailyCachePayload(key);
        if (_isFetchedToday(lastFetched) &&
            cached != null &&
            cached.isNotEmpty) {
          debugLogDataSource(
            'GrammarList',
            'SQLite api_daily_cache (key=$key, fetched today) — skip RTDB',
          );
          return parseGrammarsFromJsonString(cached);
        }
      }

      debugLogDataSource(
        'GrammarList',
        'CEFR cutover: no HomePage/Grammar — returning empty',
      );
      return const [];
    } catch (e) {
      throw Exception('Error fetching grammars: $e');
    }
  }

  /// Episodes under CEFR sub-categories whose text contains "Grammar".
  Future<List<Episode>> getGrammarEpisodesFromCefr() {
    return _firebase.getGrammarSubCategoryEpisodes();
  }

  static List<Grammar> parseGrammarsFromJsonString(String responseBody) {
    if (responseBody.isEmpty || responseBody == 'null') return const [];
    final dynamic data = json.decode(responseBody);
    return parseGrammarsFromDecoded(data);
  }

  static List<Grammar> parseGrammarsFromDecoded(dynamic data) {
    final List<Grammar> grammars = [];

    if (data is List) {
      for (var item in data) {
        if (item is Map<String, dynamic>) {
          try {
            grammars.add(Grammar.fromJson(item));
          } catch (e) {
            print('Error parsing grammar item: $e');
          }
        }
      }
    } else if (data is Map<String, dynamic>) {
      data.forEach((key, value) {
        if (value is Map<String, dynamic>) {
          try {
            grammars.add(Grammar.fromJson(value));
          } catch (e) {
            print('Error parsing grammar item: $e');
          }
        }
      });
    }

    return grammars;
  }
}
