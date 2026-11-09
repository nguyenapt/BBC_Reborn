import 'dart:convert';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:http/http.dart' as http;
import '../models/grammar.dart';
import '../utils/debug_source_log.dart';
import 'api_daily_cache_keys.dart';
import 'local_database_service.dart';
import 'web_api_daily_cache.dart';

class GrammarService {
  static const String _baseUrl = 'https://bbc-listening-english.firebaseio.com';
  static const String _grammarPath = 'HomePage/Grammar';

  final LocalDatabaseService _apiCacheDb = LocalDatabaseService();

  bool _isFetchedToday(DateTime? lastFetched) {
    if (lastFetched == null) return false;
    final now = DateTime.now();
    return now.year == lastFetched.year &&
        now.month == lastFetched.month &&
        now.day == lastFetched.day;
  }

  /// Lấy danh sách tất cả grammars (tối đa một lần tải [HomePage/Grammar.json] mỗi ngày).
  Future<List<Grammar>> getAllGrammars() async {
    try {
      final key = ApiDailyCacheKeys.grammarList;

      if (kIsWeb) {
        final webCached = await WebApiDailyCache.getPayload(key);
        if (webCached != null && webCached.isNotEmpty) {
          debugLogDataSource('GrammarList', 'Web SharedPreferences daily cache HIT');
          return parseGrammarsFromJsonString(webCached);
        }
        debugLogDataSource('GrammarList', 'Web: RTDB REST (cold day)');
        final response = await http.get(
          Uri.parse('$_baseUrl/$_grammarPath.json'),
          headers: {'Accept': 'application/json'},
        );
        if (response.statusCode == 200) {
          await WebApiDailyCache.putPayload(key, response.body);
          return parseGrammarsFromJsonString(response.body);
        }
        throw Exception('Failed to load grammars: ${response.statusCode}');
      }

      final lastFetched = await _apiCacheDb.getApiDailyLastFetched(key);
      final cached = await _apiCacheDb.getApiDailyCachePayload(key);
      if (_isFetchedToday(lastFetched) && cached != null && cached.isNotEmpty) {
        debugLogDataSource(
          'GrammarList',
          'SQLite api_daily_cache (key=$key, fetched today) — skip RTDB',
        );
        return parseGrammarsFromJsonString(cached);
      }

      debugLogDataSource('GrammarList', 'RTDB REST GET .../HomePage/Grammar.json');
      final response = await http.get(
        Uri.parse('$_baseUrl/$_grammarPath.json'),
        headers: {'Accept': 'application/json'},
      );

      if (response.statusCode == 200) {
        await _apiCacheDb.upsertApiDailyCache(key, response.body, DateTime.now());
        return parseGrammarsFromJsonString(response.body);
      }
      throw Exception('Failed to load grammars: ${response.statusCode}');
    } catch (e) {
      throw Exception('Error fetching grammars: $e');
    }
  }

  static List<Grammar> parseGrammarsFromJsonString(String responseBody) {
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
    } else {
      return [];
    }

    grammars.sort((a, b) => a.sortOrder.compareTo(b.sortOrder));
    return grammars;
  }

  /// Mock data for UI tests (unused; English fallback).
  List<Grammar> _getMockGrammars() {
    return [
      Grammar(
        id: 'mock-1',
        name: 'Present Simple',
        sortOrder: 0,
        parts: [
          GrammarPart(
            id: 'mock-part-1',
            name: 'Usage',
            theory:
                '<h3>Present Simple is used for:</h3><ul><li>Daily habits</li><li>General truths</li><li>Fixed schedules</li></ul>',
            description:
                '<p>Present Simple is the most basic English tense; it is often used with frequency adverbs such as <strong>always, usually, often, sometimes, never</strong>.</p>',
            sortOrder: 0,
          ),
          GrammarPart(
            id: 'mock-part-2',
            name: 'Structure',
            theory:
                '<h3>Patterns:</h3><ul><li><strong>Affirmative:</strong> S + V(s/es) + O</li><li><strong>Negative:</strong> S + do/does + not + V + O</li><li><strong>Question:</strong> Do/Does + S + V + O?</li></ul>',
            description:
                '<p>With third-person singular subjects (he, she, it), add <strong>-s</strong> or <strong>-es</strong> to the verb; with plural subjects, use the base verb.</p>',
            sortOrder: 1,
          ),
        ],
      ),
    ];
  }

  /// Lấy grammar theo ID
  Future<Grammar?> getGrammarById(String grammarId) async {
    try {
      final response = await http.get(
        Uri.parse('$_baseUrl/$_grammarPath/$grammarId.json'),
        headers: {'Accept': 'application/json'},
      );

      if (response.statusCode == 200) {
        final Map<String, dynamic> data = json.decode(response.body);
        return Grammar.fromJson(data);
      } else {
        return null;
      }
    } catch (e) {
      print('Error fetching grammar by ID: $e');
      return null;
    }
  }

  /// Test API để xem cấu trúc dữ liệu
  Future<void> testApi() async {
    try {
      final response = await http.get(
        Uri.parse('$_baseUrl/$_grammarPath.json'),
        headers: {'Accept': 'application/json'},
      );

      print('Status Code: ${response.statusCode}');
      print('Response Body: ${response.body}');
      
      if (response.statusCode == 200) {
        final dynamic data = json.decode(response.body);
        print('Parsed Data Type: ${data.runtimeType}');
        print('Parsed Data: $data');
      }
    } catch (e) {
      print('Test API Error: $e');
    }
  }
}
