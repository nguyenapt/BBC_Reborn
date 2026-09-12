import 'dart:convert';
import 'package:flutter/foundation.dart';
import '../models/ai_cache_tier.dart';
import 'storage_service.dart';
import 'ai_firebase_cache_service.dart';
import '../utils/cache_key_helper.dart';
import 'heart_service.dart';

/// Service for caching AI responses
/// Priority order: Local Cache → Firebase Cache → AI API
class AICacheService {
  static final AICacheService _instance = AICacheService._internal();
  factory AICacheService() => _instance;
  AICacheService._internal();

  final StorageService _storage = StorageService();
  final AIFirebaseCacheService _firebaseCache = AIFirebaseCacheService();

  String _translationLineIndexKey(String episodeId, String languageCode) =>
      'translation_line_idx_${episodeId}_$languageCode';

  Future<Map<String, String>> _getTranslationLineIndex(
    String episodeId,
    String languageCode,
  ) async {
    try {
      final cached =
          await _storage.getCachedData(_translationLineIndexKey(episodeId, languageCode));
      if (cached == null) return {};
      final decoded = json.decode(cached);
      if (decoded is! Map) return {};
      return decoded.map((k, v) => MapEntry(k.toString(), v.toString()));
    } catch (e) {
      debugPrint('Error reading translation line index: $e');
      return {};
    }
  }

  Future<void> _saveTranslationLineIndex(
    String episodeId,
    String languageCode,
    int lineNumber,
    String translatedText,
  ) async {
    try {
      final index = await _getTranslationLineIndex(episodeId, languageCode);
      index[lineNumber.toString()] = translatedText;
      await _storage.saveCachedData(
        _translationLineIndexKey(episodeId, languageCode),
        json.encode(index),
      );
    } catch (e) {
      debugPrint('Error saving translation line index: $e');
    }
  }

  /// Get cached data
  Future<T?> getCached<T>(
    String key,
    T Function(Map<String, dynamic>) fromJson,
  ) async {
    try {
      final cached = await _storage.getCachedData(key);
      if (cached != null) {
        final Map<String, dynamic> decoded = json.decode(cached);
        return fromJson(decoded);
      }
      return null;
    } catch (e) {
      debugPrint('Error getting cached data: $e');
      return null;
    }
  }

  /// Cache data
  Future<void> cacheData<T>(
    String key,
    T data,
    Map<String, dynamic> Function(T) toJson,
  ) async {
    try {
      final jsonData = toJson(data);
      final encoded = json.encode(jsonData);
      await _storage.saveCachedData(key, encoded);
    } catch (e) {
      debugPrint('Error caching data: $e');
    }
  }

  /// Get cached string (for simple translations)
  Future<String?> getCachedString(String key) async {
    try {
      return await _storage.getCachedData(key);
    } catch (e) {
      debugPrint('Error getting cached string: $e');
      return null;
    }
  }

  /// Cache string (for simple translations)
  Future<void> cacheString(String key, String value) async {
    try {
      await _storage.saveCachedData(key, value);
    } catch (e) {
      debugPrint('Error caching string: $e');
    }
  }

  /// Get cached map (for translations map)
  Future<Map<String, String>?> getCachedMap(String key) async {
    try {
      final cached = await _storage.getCachedData(key);
      if (cached != null) {
        final Map<String, dynamic> decoded = json.decode(cached);
        return decoded.map((k, v) => MapEntry(k.toString(), v.toString()));
      }
      return null;
    } catch (e) {
      debugPrint('Error getting cached map: $e');
      return null;
    }
  }

  /// Cache map (for translations map)
  Future<void> cacheMap(String key, Map<String, String> value) async {
    try {
      final encoded = json.encode(value);
      await _storage.saveCachedData(key, encoded);
    } catch (e) {
      debugPrint('Error caching map: $e');
    }
  }

  /// Remove cached data
  Future<void> removeCached(String key) async {
    try {
      await _storage.removeCachedData(key);
    } catch (e) {
      debugPrint('Error removing cached data: $e');
    }
  }

  /// Clear all AI cache
  Future<void> clearAllCache() async {
    try {
      await _storage.clearAICache();
    } catch (e) {
      debugPrint('Error clearing AI cache: $e');
    }
  }

  // ========== Firebase Integration Methods ==========

  /// Trừ heart/credit nếu không phải local cache.
  /// [episodeId] bắt buộc khi [HeartService.useEpisodeCredits] để trừ episode credit.
  static Future<void> consumeHeartIfFirebase(
    AICacheTier tier, {
    String? episodeId,
  }) async {
    if (tier == AICacheTier.local) return;
    final hearts = HeartService();
    if (hearts.useEpisodeCredits) {
      await hearts.consumeEpisodeCredit(
        episodeId ?? HeartService.miscScopeId,
        isLiveApi: false,
      );
      return;
    }
    if (tier == AICacheTier.firebase) {
      await hearts.consumeForAIFeature();
    }
  }

  /// Trừ 1 heart (legacy) hoặc 1 episode credit + đếm live soft-cap (credit mode).
  static Future<void> consumeForLiveAi({String? episodeId}) async {
    final hearts = HeartService();
    if (hearts.useEpisodeCredits) {
      await hearts.consumeEpisodeCredit(
        episodeId ?? HeartService.miscScopeId,
        isLiveApi: true,
      );
      return;
    }
    await hearts.consumeForAIFeature();
  }

  Future<Map<String, String>?> getTranslationFromLocalCache(
    String episodeId,
    String languageCode,
  ) async {
    final localKey = CacheKeyHelper.translationKey(episodeId, languageCode);
    final localCache = await getCachedMap(localKey);
    if (localCache != null) {
      debugPrint('Local cache HIT for translation: $localKey');
    }
    return localCache;
  }

  Future<Map<String, String>?> getTranslationFromFirebaseCache(
    String episodeId,
    String languageCode,
  ) async {
    final firebaseCache =
        await _firebaseCache.getTranslation(episodeId, languageCode);
    if (firebaseCache != null) {
      debugPrint('Firebase cache HIT for translation: $episodeId/$languageCode');
      // Do NOT write local here — only after heart/credit is consumed successfully.
    }
    return firebaseCache;
  }

  /// Persist Firebase translation to local after billing succeeds.
  Future<void> materializeTranslationLocal(
    String episodeId,
    String languageCode,
    Map<String, String> translations,
  ) async {
    final localKey = CacheKeyHelper.translationKey(episodeId, languageCode);
    await cacheMap(localKey, translations);
  }

  /// Tra translation: local (miễn) → Firebase (trừ credit/heart) → miss.
  Future<({Map<String, String> data, AICacheTier tier})?> lookupTranslation(
    String episodeId,
    String languageCode,
  ) async {
    final local = await getTranslationFromLocalCache(episodeId, languageCode);
    if (local != null && local.isNotEmpty) {
      return (data: local, tier: AICacheTier.local);
    }
    final firebase =
        await getTranslationFromFirebaseCache(episodeId, languageCode);
    // getTranslationFromFirebaseCache đã materialize local (cacheMap) khi HIT.
    if (firebase != null && firebase.isNotEmpty) {
      return (data: firebase, tier: AICacheTier.firebase);
    }
    return null;
  }

  /// Get translation with priority: Local → Firebase → null
  Future<Map<String, String>?> getTranslationFromCache(
    String episodeId,
    String languageCode,
  ) async {
    final hit = await lookupTranslation(episodeId, languageCode);
    return hit?.data;
  }

  /// Save translation to both local and Firebase cache
  Future<void> saveTranslationToCache(
    String episodeId,
    String languageCode,
    Map<String, String> translations, {
    List<String>? originalLines,
  }) async {
    final localKey = CacheKeyHelper.translationKey(episodeId, languageCode);
    
    // Save to local cache
    await cacheMap(localKey, translations);
    debugPrint('Saved translation to local cache: $episodeId/$languageCode (${translations.length} items)');
    
    // Save to Firebase cache (async, don't wait to avoid blocking)
    _firebaseCache.saveTranslation(episodeId, languageCode, translations, originalLines: originalLines)
        .then((_) {
          debugPrint('✅ Successfully saved translation to Firebase: $episodeId/$languageCode');
        })
        .catchError((e) {
          debugPrint('❌ Error saving translation to Firebase: $e');
          debugPrint('   EpisodeId: $episodeId, LanguageCode: $languageCode');
        });
  }

  Future<String?> getLineTranslationFromLocalCache(
    String episodeId,
    String languageCode,
    String originalText,
    int? lineNumber,
  ) async {
    final localKey = CacheKeyHelper.translationKey(episodeId, languageCode);
    final localMap = await getCachedMap(localKey);
    if (localMap != null) {
      final byText = localMap[originalText];
      if (byText != null && byText.isNotEmpty) {
        debugPrint('Local text-map cache HIT: $episodeId/$languageCode');
        return byText;
      }
    }
    if (lineNumber != null && lineNumber >= 0) {
      final lineIndex =
          await _getTranslationLineIndex(episodeId, languageCode);
      final byLine = lineIndex[lineNumber.toString()];
      if (byLine != null && byLine.isNotEmpty) {
        debugPrint(
          'Local line-index cache HIT: $episodeId/$languageCode line $lineNumber',
        );
        return byLine;
      }
    }
    return null;
  }

  Future<String?> getLineTranslationFromFirebaseCache(
    String episodeId,
    String languageCode,
    String originalText,
    int? lineNumber,
  ) async {
    final firebaseTranslation = await _firebaseCache.getLineTranslation(
      episodeId,
      languageCode,
      lineNumber,
    );
    if (firebaseTranslation == null) return null;

    debugPrint(
      'Firebase cache HIT for line translation: $episodeId/$languageCode',
    );
    // Do NOT write local here — only after heart/credit is consumed successfully.
    return firebaseTranslation;
  }

  /// Persist one Firebase line translation locally after billing succeeds.
  Future<void> materializeLineTranslationLocal(
    String episodeId,
    String languageCode,
    String originalText,
    String translatedText,
    int? lineNumber,
  ) async {
    final effectiveLineNumber = lineNumber ?? -1;
    if (effectiveLineNumber >= 0) {
      await _saveTranslationLineIndex(
        episodeId,
        languageCode,
        effectiveLineNumber,
        translatedText,
      );
    }
    final localKey = CacheKeyHelper.translationKey(episodeId, languageCode);
    final localCache = await getCachedMap(localKey) ?? <String, String>{};
    localCache[originalText] = translatedText;
    await cacheMap(localKey, localCache);
  }

  /// Tra dòng transcript: local (miễn) → Firebase (trừ credit/heart) → miss.
  Future<({String data, AICacheTier tier})?> lookupLineTranslation(
    String episodeId,
    String languageCode,
    String originalText,
    int? lineNumber,
  ) async {
    final local = await getLineTranslationFromLocalCache(
      episodeId,
      languageCode,
      originalText,
      lineNumber,
    );
    if (local != null) {
      return (data: local, tier: AICacheTier.local);
    }
    final firebase = await getLineTranslationFromFirebaseCache(
      episodeId,
      languageCode,
      originalText,
      lineNumber,
    );
    if (firebase != null) {
      return (data: firebase, tier: AICacheTier.firebase);
    }
    return null;
  }

  /// Get translation for a specific line from cache
  Future<String?> getLineTranslationFromCache(
    String episodeId,
    String languageCode,
    String originalText,
    int? lineNumber,
  ) async {
    final hit = await lookupLineTranslation(
      episodeId,
      languageCode,
      originalText,
      lineNumber,
    );
    return hit?.data;
  }

  /// Save a single line translation to cache
  Future<void> saveLineTranslationToCache(
    String episodeId,
    String languageCode,
    String originalText,
    String translatedText,
    int lineNumber,
  ) async {
    debugPrint('💾 saveLineTranslationToCache called:');
    debugPrint('   EpisodeId: $episodeId');
    debugPrint('   LanguageCode: $languageCode');
    debugPrint('   Original: "$originalText"');
    debugPrint('   Translated: "$translatedText"');
    debugPrint('   LineNumber: $lineNumber');
    
    // Save to local cache
    final localKey = CacheKeyHelper.translationKey(episodeId, languageCode);
    final localCache = await getCachedMap(localKey) ?? <String, String>{};
    localCache[originalText] = translatedText;
    await cacheMap(localKey, localCache);
    if (lineNumber >= 0) {
      await _saveTranslationLineIndex(
        episodeId,
        languageCode,
        lineNumber,
        translatedText,
      );
    }
    debugPrint('✅ Saved line translation to local cache: $episodeId/$languageCode (lineNumber: $lineNumber)');
    
    // Always save to Firebase cache (async, with lineNumber)
    // This ensures the translation is available for other users
    try {
      await _firebaseCache.saveLineTranslation(
        episodeId,
        languageCode,
        originalText,
        translatedText,
        lineNumber,
      );
      debugPrint('✅ Successfully saved line translation to Firebase: $episodeId/$languageCode (lineNumber: $lineNumber)');
    } catch (e, stackTrace) {
      debugPrint('❌ Error saving line translation to Firebase: $e');
      debugPrint('   EpisodeId: $episodeId, LanguageCode: $languageCode, LineNumber: $lineNumber');
      debugPrint('   Stack trace: $stackTrace');
      // Don't rethrow - continue even if Firebase save fails
    }
  }

  String _grammarLocalKey(
    String sentence,
    String languageCode, {
    String? episodeId,
    String? modelVersion,
    String? promptVersion,
  }) =>
      CacheKeyHelper.grammarKey(
        sentence,
        languageCode,
        episodeId: episodeId,
        modelVersion: modelVersion,
        promptVersion: promptVersion,
      );

  Future<Map<String, dynamic>?> getGrammarFromLocalCache(
    String sentence,
    String languageCode, {
    String? episodeId,
    String? modelVersion,
    String? promptVersion,
  }) async {
    final localKey = _grammarLocalKey(
      sentence,
      languageCode,
      episodeId: episodeId,
      modelVersion: modelVersion,
      promptVersion: promptVersion,
    );
    final localCache = await getCached<Map<String, dynamic>>(
      localKey,
      (json) => json,
    );
    if (localCache != null) {
      debugPrint('Local cache HIT for grammar: $localKey');
    }
    return localCache;
  }

  Future<Map<String, dynamic>?> getGrammarFromFirebaseCache(
    String sentence,
    String languageCode, {
    String? episodeId,
    int? lineNumber,
    String? modelVersion,
    String? promptVersion,
  }) async {
    if (episodeId != null &&
        episodeId.isNotEmpty &&
        lineNumber != null &&
        lineNumber >= 0) {
      final byEpisode = await _firebaseCache.getGrammarByEpisode(
        episodeId,
        lineNumber,
        languageCode,
      );
      if (byEpisode != null) {
        debugPrint(
          'grammar_by_episode cache HIT: $episodeId line_$lineNumber/$languageCode',
        );
        return byEpisode;
      }
    }

    final firebaseCache = await _firebaseCache.getGrammar(
      sentence,
      languageCode,
      episodeId: episodeId,
      modelVersion: modelVersion,
      promptVersion: promptVersion,
    );
    return firebaseCache;
  }

  Future<void> materializeGrammarLocal(
    String sentence,
    String languageCode,
    Map<String, dynamic> grammarData, {
    String? episodeId,
    String? modelVersion,
    String? promptVersion,
  }) async {
    final localKey = _grammarLocalKey(
      sentence,
      languageCode,
      episodeId: episodeId,
      modelVersion: modelVersion,
      promptVersion: promptVersion,
    );
    await cacheData<Map<String, dynamic>>(
      localKey,
      grammarData,
      (data) => data,
    );
  }

  Future<({Map<String, dynamic> data, AICacheTier tier})?> lookupGrammar(
    String sentence,
    String languageCode, {
    String? episodeId,
    int? lineNumber,
    String? modelVersion,
    String? promptVersion,
  }) async {
    final local = await getGrammarFromLocalCache(
      sentence,
      languageCode,
      episodeId: episodeId,
      modelVersion: modelVersion,
      promptVersion: promptVersion,
    );
    if (local != null) {
      return (data: local, tier: AICacheTier.local);
    }
    final firebase = await getGrammarFromFirebaseCache(
      sentence,
      languageCode,
      episodeId: episodeId,
      lineNumber: lineNumber,
      modelVersion: modelVersion,
      promptVersion: promptVersion,
    );
    if (firebase != null) {
      return (data: firebase, tier: AICacheTier.firebase);
    }
    return null;
  }

  /// Get grammar explanation with priority: Local → Firebase → null
  Future<Map<String, dynamic>?> getGrammarFromCache(
    String sentence,
    String languageCode, {
    String? episodeId,
    int? lineNumber,
    String? modelVersion,
    String? promptVersion,
  }) async {
    final hit = await lookupGrammar(
      sentence,
      languageCode,
      episodeId: episodeId,
      lineNumber: lineNumber,
      modelVersion: modelVersion,
      promptVersion: promptVersion,
    );
    return hit?.data;
  }

  /// Save grammar explanation to both local and Firebase cache
  Future<void> saveGrammarToCache(
    String sentence,
    String languageCode,
    Map<String, dynamic> grammarData,
    {
    String? episodeId,
    int? lineNumber,
    String? modelVersion,
    String? promptVersion,
  }) async {
    final localKey = CacheKeyHelper.grammarKey(
      sentence,
      languageCode,
      episodeId: episodeId,
      modelVersion: modelVersion,
      promptVersion: promptVersion,
    );
    
    // Save to local cache
    await cacheData<Map<String, dynamic>>(
      localKey,
      grammarData,
      (data) => data,
    );
    
    if (episodeId != null &&
        episodeId.isNotEmpty &&
        lineNumber != null &&
        lineNumber >= 0) {
      _firebaseCache
          .saveGrammarByEpisode(episodeId, lineNumber, languageCode, grammarData)
          .catchError(
            (e) => debugPrint('Error saving grammar_by_episode: $e'),
          );
    }

    // Save to Firebase cache (async)
    _firebaseCache
        .saveGrammar(
          sentence,
          languageCode,
          grammarData,
          episodeId: episodeId,
          modelVersion: modelVersion,
          promptVersion: promptVersion,
        )
        .catchError((e) => debugPrint('Error saving grammar to Firebase: $e'));
  }

  Map<String, dynamic> _mapLegacySentenceGrammarToPassage(
    String passage,
    Map<String, dynamic> legacy,
  ) =>
      {
        'overall': {
          'grammarTheme': legacy['grammarPoint']?.toString() ?? 'Grammar Pattern',
          'usageSummary': legacy['explanation']?.toString() ?? '',
          'keyStructures': [
            if ((legacy['rulePattern']?.toString() ?? '').trim().isNotEmpty)
              legacy['rulePattern'].toString(),
          ],
        },
        'sentenceAnalyses': [
          {
            'sentenceText': passage,
            'mainStructure': legacy['rulePattern']?.toString() ?? '',
            'usageInContext': legacy['explanation']?.toString() ?? '',
            'phraseBreakdown': (legacy['highlightedWords'] as List<dynamic>? ?? [])
                .map(
                  (word) => {
                    'phrase': word.toString(),
                    'structure': '',
                    'usage': '',
                  },
                )
                .toList(),
            'examples': <String>[],
            'commonMistakes': legacy['commonMistakes'] ?? <String>[],
            'rewriteExercise': '',
            'miniQuiz': legacy['miniQuiz'],
          },
        ],
      };

  Future<Map<String, dynamic>?> getGrammarPassageFromLocalCache(
    String passage,
    String languageCode, {
    String? episodeId,
    String? modelVersion,
    String? promptVersion,
    String? schemaVersion,
  }) async {
    final localKey = CacheKeyHelper.grammarPassageKey(
      passage,
      languageCode,
      episodeId: episodeId,
      modelVersion: modelVersion,
      promptVersion: promptVersion,
      schemaVersion: schemaVersion,
    );

    final localCache =
        await getCached<Map<String, dynamic>>(localKey, (json) => json);
    if (localCache != null) return localCache;

    final legacyLocal = await getGrammarFromLocalCache(
      passage,
      languageCode,
      episodeId: episodeId,
      modelVersion: modelVersion,
      promptVersion: promptVersion,
    );
    if (legacyLocal != null) {
      return _mapLegacySentenceGrammarToPassage(passage, legacyLocal);
    }
    return null;
  }

  Future<Map<String, dynamic>?> getGrammarPassageFromFirebaseCache(
    String passage,
    String languageCode, {
    String? episodeId,
    String? modelVersion,
    String? promptVersion,
    String? schemaVersion,
  }) async {
    final firebaseCache = await _firebaseCache.getGrammarPassage(
      passage,
      languageCode,
      episodeId: episodeId,
      modelVersion: modelVersion,
      promptVersion: promptVersion,
      schemaVersion: schemaVersion,
    );
    if (firebaseCache != null) {
      return firebaseCache;
    }

    final legacyFirebase = await getGrammarFromFirebaseCache(
      passage,
      languageCode,
      episodeId: episodeId,
      modelVersion: modelVersion,
      promptVersion: promptVersion,
    );
    if (legacyFirebase != null) {
      return _mapLegacySentenceGrammarToPassage(passage, legacyFirebase);
    }
    return null;
  }

  Future<void> materializeGrammarPassageLocal(
    String passage,
    String languageCode,
    Map<String, dynamic> grammarData, {
    String? episodeId,
    String? modelVersion,
    String? promptVersion,
    String? schemaVersion,
  }) async {
    final localKey = CacheKeyHelper.grammarPassageKey(
      passage,
      languageCode,
      episodeId: episodeId,
      modelVersion: modelVersion,
      promptVersion: promptVersion,
      schemaVersion: schemaVersion,
    );
    await cacheData<Map<String, dynamic>>(localKey, grammarData, (data) => data);
  }

  Future<({Map<String, dynamic> data, AICacheTier tier})?> lookupGrammarPassage(
    String passage,
    String languageCode, {
    String? episodeId,
    String? modelVersion,
    String? promptVersion,
    String? schemaVersion,
  }) async {
    final local = await getGrammarPassageFromLocalCache(
      passage,
      languageCode,
      episodeId: episodeId,
      modelVersion: modelVersion,
      promptVersion: promptVersion,
      schemaVersion: schemaVersion,
    );
    if (local != null) {
      return (data: local, tier: AICacheTier.local);
    }
    final firebase = await getGrammarPassageFromFirebaseCache(
      passage,
      languageCode,
      episodeId: episodeId,
      modelVersion: modelVersion,
      promptVersion: promptVersion,
      schemaVersion: schemaVersion,
    );
    if (firebase != null) {
      return (data: firebase, tier: AICacheTier.firebase);
    }
    return null;
  }

  /// Get passage grammar with priority: Local -> Firebase -> legacy sentence cache
  Future<Map<String, dynamic>?> getGrammarPassageFromCache(
    String passage,
    String languageCode, {
    String? episodeId,
    String? modelVersion,
    String? promptVersion,
    String? schemaVersion,
  }) async {
    final hit = await lookupGrammarPassage(
      passage,
      languageCode,
      episodeId: episodeId,
      modelVersion: modelVersion,
      promptVersion: promptVersion,
      schemaVersion: schemaVersion,
    );
    return hit?.data;
  }

  /// Save passage grammar to both local and Firebase cache (new namespace)
  Future<void> saveGrammarPassageToCache(
    String passage,
    String languageCode,
    Map<String, dynamic> grammarData, {
    String? episodeId,
    String? modelVersion,
    String? promptVersion,
    String? schemaVersion,
  }) async {
    final localKey = CacheKeyHelper.grammarPassageKey(
      passage,
      languageCode,
      episodeId: episodeId,
      modelVersion: modelVersion,
      promptVersion: promptVersion,
      schemaVersion: schemaVersion,
    );

    await cacheData<Map<String, dynamic>>(localKey, grammarData, (data) => data);
    _firebaseCache
        .saveGrammarPassage(
          passage,
          languageCode,
          grammarData,
          episodeId: episodeId,
          modelVersion: modelVersion,
          promptVersion: promptVersion,
          schemaVersion: schemaVersion,
        )
        .catchError((e) => debugPrint('Error saving grammar passage to Firebase: $e'));
  }

  Future<List<Map<String, dynamic>>?> getQuestionsFromLocalCache(
    String episodeId,
    int count,
  ) async {
    final localKey = CacheKeyHelper.questionsKey(episodeId, count);
    final localCache = await getCached<List<Map<String, dynamic>>>(
      localKey,
      (json) {
        final list = json['questions'] as List<dynamic>?;
        return list?.cast<Map<String, dynamic>>() ?? [];
      },
    );
    if (localCache != null && localCache.isNotEmpty) {
      debugPrint('Local cache HIT for questions: $localKey');
      return localCache;
    }
    return null;
  }

  Future<List<Map<String, dynamic>>?> getQuestionsFromFirebaseCache(
    String episodeId,
    int count,
  ) async {
    final firebaseCache = await _firebaseCache.getQuestions(episodeId, count);
    if (firebaseCache != null && firebaseCache.isNotEmpty) {
      debugPrint('Firebase cache HIT for questions: $episodeId/$count');
    }
    return firebaseCache;
  }

  Future<void> materializeQuestionsLocal(
    String episodeId,
    int count,
    List<Map<String, dynamic>> questions,
  ) async {
    final localKey = CacheKeyHelper.questionsKey(episodeId, count);
    await cacheData<List<Map<String, dynamic>>>(
      localKey,
      questions,
      (data) => {'questions': data},
    );
  }

  Future<({List<Map<String, dynamic>> data, AICacheTier tier})?> lookupQuestions(
    String episodeId,
    int count,
  ) async {
    final local = await getQuestionsFromLocalCache(episodeId, count);
    if (local != null) {
      return (data: local, tier: AICacheTier.local);
    }
    final firebase = await getQuestionsFromFirebaseCache(episodeId, count);
    if (firebase != null && firebase.isNotEmpty) {
      return (data: firebase, tier: AICacheTier.firebase);
    }
    return null;
  }

  /// Get questions with priority: Local → Firebase → null
  Future<List<Map<String, dynamic>>?> getQuestionsFromCache(
    String episodeId,
    int count,
  ) async {
    final hit = await lookupQuestions(episodeId, count);
    return hit?.data;
  }

  /// Save questions to both local and Firebase cache
  Future<void> saveQuestionsToCache(
    String episodeId,
    int count,
    List<Map<String, dynamic>> questions,
  ) async {
    final localKey = CacheKeyHelper.questionsKey(episodeId, count);
    
    // Save to local cache
    await cacheData<List<Map<String, dynamic>>>(
      localKey,
      questions,
      (data) => {'questions': data},
    );
    
    // Save to Firebase cache (async)
    _firebaseCache.saveQuestions(episodeId, count, questions)
        .catchError((e) => debugPrint('Error saving questions to Firebase: $e'));
  }

  Future<Map<String, dynamic>?> getVocabularyFromLocalCache(
    String word,
    String languageCode,
  ) async {
    final localKey = CacheKeyHelper.vocabularyKey(word, languageCode);
    final localCache = await getCached<Map<String, dynamic>>(
      localKey,
      (json) => json,
    );
    if (localCache != null) {
      debugPrint('Local cache HIT for vocabulary: $localKey');
    }
    return localCache;
  }

  Future<Map<String, dynamic>?> getVocabularyFromFirebaseCache(
    String word,
    String languageCode, {
    String? episodeId,
    String? vocabItemId,
  }) async {
    if (episodeId != null && episodeId.isNotEmpty) {
      for (final itemKey in CacheKeyHelper.vocabularyByEpisodeLookupKeys(
        word,
        itemId: vocabItemId,
      )) {
        final raw = await _firebaseCache.getVocabularyByEpisode(
          episodeId,
          itemKey,
        );
        if (raw == null) continue;

        final byEpisode =
            CacheKeyHelper.normalizeVocabularyByEpisodePayload(raw);
        debugPrint('vocabulary_by_episode cache HIT: $episodeId/$itemKey');
        return byEpisode;
      }
    }

    final firebaseCache =
        await _firebaseCache.getVocabulary(word, languageCode);
    return firebaseCache;
  }

  Future<void> materializeVocabularyLocal(
    String word,
    String languageCode,
    Map<String, dynamic> vocabularyData,
  ) async {
    final localKey = CacheKeyHelper.vocabularyKey(word, languageCode);
    await cacheData<Map<String, dynamic>>(
      localKey,
      vocabularyData,
      (data) => data,
    );
  }

  Future<({Map<String, dynamic> data, AICacheTier tier})?> lookupVocabulary(
    String word,
    String languageCode, {
    String? episodeId,
    String? vocabItemId,
  }) async {
    final local = await getVocabularyFromLocalCache(word, languageCode);
    if (local != null) {
      return (data: local, tier: AICacheTier.local);
    }
    final firebase = await getVocabularyFromFirebaseCache(
      word,
      languageCode,
      episodeId: episodeId,
      vocabItemId: vocabItemId,
    );
    if (firebase != null) {
      return (data: firebase, tier: AICacheTier.firebase);
    }
    return null;
  }

  /// Get vocabulary enhancement with priority: Local → Firebase → null
  Future<Map<String, dynamic>?> getVocabularyFromCache(
    String word,
    String languageCode, {
    String? episodeId,
    String? vocabItemId,
  }) async {
    final hit = await lookupVocabulary(
      word,
      languageCode,
      episodeId: episodeId,
      vocabItemId: vocabItemId,
    );
    return hit?.data;
  }

  /// Save vocabulary enhancement to both local and Firebase cache
  Future<void> saveVocabularyToCache(
    String word,
    String languageCode,
    Map<String, dynamic> vocabularyData, {
    String? episodeId,
    String? vocabItemId,
  }) async {
    final localKey = CacheKeyHelper.vocabularyKey(word, languageCode);
    
    // Save to local cache
    await cacheData<Map<String, dynamic>>(
      localKey,
      vocabularyData,
      (data) => data,
    );

    if (episodeId != null && episodeId.isNotEmpty) {
      final itemKey = CacheKeyHelper.vocabularyWordHashKey(word);
      _firebaseCache
          .saveVocabularyByEpisode(episodeId, itemKey, vocabularyData)
          .catchError(
            (e) => debugPrint('Error saving vocabulary_by_episode: $e'),
          );
    }
    
    // Save to Firebase cache (async)
    _firebaseCache.saveVocabulary(word, languageCode, vocabularyData)
        .catchError((e) => debugPrint('Error saving vocabulary to Firebase: $e'));
  }

  // ========== Cache Management Methods ==========

  /// Invalidate translation cache for an episode
  Future<void> invalidateTranslation(
    String episodeId,
    String? languageCode,
  ) async {
    // Remove from local cache
    if (languageCode != null) {
      final localKey = CacheKeyHelper.translationKey(episodeId, languageCode);
      await removeCached(localKey);
    } else {
      // Remove all languages for this episode (would need to know all languages)
      // For now, just log a warning
      debugPrint('Warning: Cannot remove all languages from local cache without knowing language list');
    }

    // Invalidate Firebase cache
    await _firebaseCache.invalidateTranslation(episodeId, languageCode);
  }

  /// Invalidate questions cache for an episode
  Future<void> invalidateQuestions(String episodeId) async {
    // Remove from local cache (would need to know count, but we can try common counts)
    for (int count = 3; count <= 10; count++) {
      final localKey = CacheKeyHelper.questionsKey(episodeId, count);
      await removeCached(localKey);
    }

    // Invalidate Firebase cache
    await _firebaseCache.invalidateQuestions(episodeId);
  }

  /// Track episode access for popular episodes tracking
  Future<void> trackEpisodeAccess(String episodeId) async {
    await _firebaseCache.trackEpisodeAccess(episodeId);
  }

  /// Get popular episodes (for pre-caching strategy)
  Future<List<String>> getPopularEpisodes({int limit = 100}) async {
    return await _firebaseCache.getPopularEpisodes(limit: limit);
  }
}

