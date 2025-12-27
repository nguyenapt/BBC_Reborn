import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'storage_service.dart';
import 'ai_firebase_cache_service.dart';
import '../utils/cache_key_helper.dart';

/// Service for caching AI responses
/// Priority order: Local Cache → Firebase Cache → AI API
class AICacheService {
  static final AICacheService _instance = AICacheService._internal();
  factory AICacheService() => _instance;
  AICacheService._internal();

  final StorageService _storage = StorageService();
  final AIFirebaseCacheService _firebaseCache = AIFirebaseCacheService();

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

  /// Get translation with priority: Local → Firebase → null
  Future<Map<String, String>?> getTranslationFromCache(
    String episodeId,
    String languageCode,
  ) async {
    // 1. Check local cache first (fastest)
    final localKey = CacheKeyHelper.translationKey(episodeId, languageCode);
    final localCache = await getCachedMap(localKey);
    if (localCache != null) {
      debugPrint('Local cache HIT for translation: $localKey');
      return localCache;
    }

    // 2. Check Firebase cache
    final firebaseCache = await _firebaseCache.getTranslation(episodeId, languageCode);
    if (firebaseCache != null) {
      // Save to local cache for faster access next time
      await cacheMap(localKey, firebaseCache);
      return firebaseCache;
    }

    return null;
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

  /// Get translation for a specific line from cache
  /// Checks Firebase cache first (with lineNumber matching), then local cache
  Future<String?> getLineTranslationFromCache(
    String episodeId,
    String languageCode,
    String originalText,
    int? lineNumber,
  ) async {
    // 1. Check Firebase cache first (has lineNumber support)
    final firebaseTranslation = await _firebaseCache.getLineTranslation(
      episodeId,
      languageCode,
      originalText,
      lineNumber,
    );
    if (firebaseTranslation != null) {
      debugPrint('Firebase cache HIT for line translation: $episodeId/$languageCode');
      return firebaseTranslation;
    }

    // 2. Check local cache (fallback to text matching)
    final localKey = CacheKeyHelper.translationKey(episodeId, languageCode);
    final localCache = await getCachedMap(localKey);
    if (localCache != null && localCache.containsKey(originalText)) {
      debugPrint('Local cache HIT for line translation: $episodeId/$languageCode');
      return localCache[originalText];
    }

    return null;
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

  /// Get grammar explanation with priority: Local → Firebase → null
  Future<Map<String, dynamic>?> getGrammarFromCache(String sentence, String languageCode) async {
    final localKey = CacheKeyHelper.grammarKey(sentence, languageCode);
    
    // 1. Check local cache first
    final localCache = await getCached<Map<String, dynamic>>(
      localKey,
      (json) => json,
    );
    if (localCache != null) {
      debugPrint('Local cache HIT for grammar: $localKey');
      return localCache;
    }

    // 2. Check Firebase cache
    final firebaseCache = await _firebaseCache.getGrammar(sentence, languageCode);
    if (firebaseCache != null) {
      // Save to local cache
      await cacheData<Map<String, dynamic>>(
        localKey,
        firebaseCache,
        (data) => data,
      );
      return firebaseCache;
    }

    return null;
  }

  /// Save grammar explanation to both local and Firebase cache
  Future<void> saveGrammarToCache(
    String sentence,
    String languageCode,
    Map<String, dynamic> grammarData,
  ) async {
    final localKey = CacheKeyHelper.grammarKey(sentence, languageCode);
    
    // Save to local cache
    await cacheData<Map<String, dynamic>>(
      localKey,
      grammarData,
      (data) => data,
    );
    
    // Save to Firebase cache (async)
    _firebaseCache.saveGrammar(sentence, languageCode, grammarData)
        .catchError((e) => debugPrint('Error saving grammar to Firebase: $e'));
  }

  /// Get questions with priority: Local → Firebase → null
  Future<List<Map<String, dynamic>>?> getQuestionsFromCache(
    String episodeId,
    int count,
  ) async {
    final localKey = CacheKeyHelper.questionsKey(episodeId, count);
    
    // 1. Check local cache first
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

    // 2. Check Firebase cache
    final firebaseCache = await _firebaseCache.getQuestions(episodeId, count);
    if (firebaseCache != null && firebaseCache.isNotEmpty) {
      // Save to local cache
      await cacheData<List<Map<String, dynamic>>>(
        localKey,
        firebaseCache,
        (data) => {'questions': data},
      );
      return firebaseCache;
    }

    return null;
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

  /// Get vocabulary enhancement with priority: Local → Firebase → null
  Future<Map<String, dynamic>?> getVocabularyFromCache(String word, String languageCode) async {
    final localKey = CacheKeyHelper.vocabularyKey(word, languageCode);
    
    // 1. Check local cache first
    final localCache = await getCached<Map<String, dynamic>>(
      localKey,
      (json) => json,
    );
    if (localCache != null) {
      debugPrint('Local cache HIT for vocabulary: $localKey');
      return localCache;
    }

    // 2. Check Firebase cache
    final firebaseCache = await _firebaseCache.getVocabulary(word, languageCode);
    if (firebaseCache != null) {
      // Save to local cache
      await cacheData<Map<String, dynamic>>(
        localKey,
        firebaseCache,
        (data) => data,
      );
      return firebaseCache;
    }

    return null;
  }

  /// Save vocabulary enhancement to both local and Firebase cache
  Future<void> saveVocabularyToCache(
    String word,
    String languageCode,
    Map<String, dynamic> vocabularyData,
  ) async {
    final localKey = CacheKeyHelper.vocabularyKey(word, languageCode);
    
    // Save to local cache
    await cacheData<Map<String, dynamic>>(
      localKey,
      vocabularyData,
      (data) => data,
    );
    
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

