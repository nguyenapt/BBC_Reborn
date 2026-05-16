import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../models/ai_cache_entry.dart';
import '../utils/cache_key_helper.dart';

/// Service for caching AI responses in Firebase
/// Allows sharing AI responses between users to save API costs
class AIFirebaseCacheService {
  static final AIFirebaseCacheService _instance = AIFirebaseCacheService._internal();
  factory AIFirebaseCacheService() => _instance;
  AIFirebaseCacheService._internal();

  static const String _baseUrl = 'https://bbc-listening-english.firebaseio.com';
  static const String _cachePath = 'ai_cache';
  static const int _cacheVersion = 1;
  static const int _defaultTtlDays = 90;
  static const int _vocabularyTtlDays = 180; // Vocabulary changes less frequently
  static const int _grammarSchemaVersion = 2;

  String _normalizeSentenceForCacheLookup(String text) {
    var s = text.trim().toLowerCase();
    s = s.replaceAll(RegExp(r'\s+'), ' ');
    // Remove wrapping quotes that may appear in UI text selections/logs.
    const quoteChars = ['"', "'", '‘', '’', '“', '”'];
    while (s.isNotEmpty && quoteChars.contains(s[0])) {
      s = s.substring(1).trimLeft();
    }
    while (s.isNotEmpty && quoteChars.contains(s[s.length - 1])) {
      s = s.substring(0, s.length - 1).trimRight();
    }
    return s.trim();
  }

  /// Get translation from Firebase cache
  Future<Map<String, String>?> getTranslation(
    String episodeId,
    String languageCode,
  ) async {
    try {
      final key = CacheKeyHelper.translationKey(episodeId, languageCode);
      // Sanitize episodeId and languageCode for Firebase
      final safeEpisodeId = CacheKeyHelper.sanitizeFirebaseKey(episodeId);
      final safeLanguageCode = CacheKeyHelper.sanitizeFirebaseKey(languageCode);
      final url = '$_baseUrl/$_cachePath/translations/$safeEpisodeId/$safeLanguageCode.json';
      
      final response = await http.get(
        Uri.parse(url),
        headers: {'Accept': 'application/json'},
      ).timeout(const Duration(seconds: 5));

      if (response.statusCode == 200 && response.body != 'null') {
        final cacheEntry = AICacheEntry.fromJson(json.decode(response.body));
        
        // Check if cache is still valid
        if (cacheEntry.isValid(defaultTtlDays: _defaultTtlDays)) {
          // Handle both old format (map) and new format (array)
          final translationsData = cacheEntry.data['translations'];
          Map<String, String>? translations;
          
          if (translationsData is List) {
            // New format: array of {original, translated, lineNumber?}
            translations = CacheKeyHelper.translationsFromFirebaseFormat(translationsData);
          } else if (translationsData is Map) {
            // Old format: map (for backward compatibility)
            translations = (translationsData as Map<String, dynamic>)
                .map((k, v) => MapEntry(k.toString(), v.toString()));
          }
          
          if (translations != null && translations.isNotEmpty) {
            debugPrint('Firebase cache HIT for translation: $key');
            return translations;
          }
        } else {
          debugPrint('Firebase cache EXPIRED for translation: $key');
        }
      }
      
      return null;
    } catch (e) {
      debugPrint('Error getting translation from Firebase: $e');
      return null; // Fail silently, fallback to API
    }
  }

  /// Get translation for a specific line from Firebase cache.
  /// Language is encoded in [languageCode] (URL segment). List entries match [lineNumber] first.
  Future<String?> getLineTranslation(
    String episodeId,
    String languageCode,
    String originalText,
    int? lineNumber,
  ) async {
    try {
      final safeEpisodeId = CacheKeyHelper.sanitizeFirebaseKey(episodeId);
      final safeLanguageCode = CacheKeyHelper.sanitizeFirebaseKey(languageCode);
      final url = '$_baseUrl/$_cachePath/translations/$safeEpisodeId/$safeLanguageCode.json';
      
      final response = await http.get(
        Uri.parse(url),
        headers: {'Accept': 'application/json'},
      ).timeout(const Duration(seconds: 5));

      if (response.statusCode == 200 && response.body != 'null') {
        final cacheEntry = AICacheEntry.fromJson(json.decode(response.body));
        
        // Check if cache is still valid
        if (cacheEntry.isValid(defaultTtlDays: _defaultTtlDays)) {
          final translationsData = cacheEntry.data['translations'];

          if (translationsData is List) {
            final translation = CacheKeyHelper.findLineTranslation(
              translationsData,
              originalText,
              lineNumber,
            );
            if (translation != null) {
              debugPrint(
                  'Firebase cache HIT for line translation: $episodeId/$languageCode (lineNumber: $lineNumber)');
              return translation;
            }
          } else if (translationsData is Map) {
            final translation = CacheKeyHelper.lookupTranslationFlexible(
              translationsData,
              originalText,
            );
            if (translation != null) {
              debugPrint(
                  'Firebase cache HIT for line translation (map schema): $episodeId/$languageCode');
              return translation;
            }
          }
        } else {
          debugPrint('Firebase cache EXPIRED for line translation: $episodeId/$languageCode');
        }
      }
      
      return null;
    } catch (e) {
      debugPrint('Error getting line translation from Firebase: $e');
      return null; // Fail silently, fallback to API
    }
  }

  /// Get translations data with lineNumber info from Firebase
  /// Returns the raw translations array to preserve lineNumber
  Future<List<Map<String, dynamic>>?> getTranslationsWithLineNumbers(
    String episodeId,
    String languageCode,
  ) async {
    try {
      final safeEpisodeId = CacheKeyHelper.sanitizeFirebaseKey(episodeId);
      final safeLanguageCode = CacheKeyHelper.sanitizeFirebaseKey(languageCode);
      final url = '$_baseUrl/$_cachePath/translations/$safeEpisodeId/$safeLanguageCode.json';
      
      final response = await http.get(
        Uri.parse(url),
        headers: {'Accept': 'application/json'},
      ).timeout(const Duration(seconds: 5));

      if (response.statusCode == 200 && response.body != 'null') {
        final cacheEntry = AICacheEntry.fromJson(json.decode(response.body));
        
        if (cacheEntry.isValid(defaultTtlDays: _defaultTtlDays)) {
          final translationsData = cacheEntry.data['translations'];
          
          if (translationsData is List) {
            return translationsData.cast<Map<String, dynamic>>();
          }
        }
      }
      
      return null;
    } catch (e) {
      debugPrint('Error getting translations with lineNumbers from Firebase: $e');
      return null;
    }
  }

  /// Save translation to Firebase cache
  Future<void> saveTranslation(
    String episodeId,
    String languageCode,
    Map<String, String> translations, {
    List<String>? originalLines,
  }) async {
    try {
      // Sanitize episodeId and languageCode for Firebase (remove invalid characters)
      final safeEpisodeId = CacheKeyHelper.sanitizeFirebaseKey(episodeId);
      final safeLanguageCode = CacheKeyHelper.sanitizeFirebaseKey(languageCode);
      final url = '$_baseUrl/$_cachePath/translations/$safeEpisodeId/$safeLanguageCode.json';
      debugPrint('🔄 Attempting to save to Firebase: $url');
      debugPrint('   Original episodeId: $episodeId → Safe: $safeEpisodeId');
      debugPrint('   Original languageCode: $languageCode → Safe: $safeLanguageCode');
      debugPrint('   Translations count: ${translations.length}');
      
      // Convert translations to Firebase-safe format (array instead of map)
      // This avoids issues with special characters in keys
      // Include originalLines to add lineNumber to each item
      final translationsArray = CacheKeyHelper.translationsToFirebaseFormat(
        translations,
        originalLines: originalLines,
      );
      
      final cacheEntry = AICacheEntry(
        data: {
          'translations': translationsArray,
          'originalEpisodeId': episodeId, // Store original for reference
          'originalLanguageCode': languageCode,
        },
        createdAt: DateTime.now(),
        version: _cacheVersion,
        ttlDays: _defaultTtlDays,
      );

      final response = await http.put(
        Uri.parse(url),
        headers: {'Content-Type': 'application/json'},
        body: json.encode(cacheEntry.toJson()),
      ).timeout(const Duration(seconds: 10));
      
      if (response.statusCode == 200) {
        debugPrint('✅ Successfully saved translation to Firebase cache: $episodeId/$languageCode');
        debugPrint('   Response: ${response.statusCode}');
      } else {
        debugPrint('⚠️ Firebase save returned status ${response.statusCode}');
        debugPrint('   Response body: ${response.body}');
        throw Exception('Firebase save failed: ${response.statusCode} - ${response.body}');
      }
    } catch (e, stackTrace) {
      debugPrint('❌ Error saving translation to Firebase: $e');
      debugPrint('   EpisodeId: $episodeId, LanguageCode: $languageCode');
      debugPrint('   Stack trace: $stackTrace');
      rethrow; // Re-throw để caller có thể handle
    }
  }

  /// Save a single line translation to Firebase cache
  /// Merges with existing translations if available, preserving lineNumbers
  Future<void> saveLineTranslation(
    String episodeId,
    String languageCode,
    String originalText,
    String translatedText,
    int lineNumber,
  ) async {
    try {
      // First, try to get existing translations with lineNumber info
      final existingWithLineNumbers = await getTranslationsWithLineNumbers(episodeId, languageCode);
      
      if (existingWithLineNumbers != null && existingWithLineNumbers.isNotEmpty) {
        // Merge with existing translations, preserving lineNumbers
        bool found = false;
        for (final item in existingWithLineNumbers) {
          if (item['original']?.toString() == originalText) {
            // Update existing translation
            item['translated'] = translatedText;
            item['lineNumber'] = lineNumber; // Update lineNumber if changed
            found = true;
            break;
          }
        }
        
        if (!found) {
          // Add new translation with correct lineNumber
          existingWithLineNumbers.add({
            'original': originalText,
            'translated': translatedText,
            'lineNumber': lineNumber,
          });
        }
        
        // Save merged translations
        final cacheEntry = AICacheEntry(
          data: {
            'translations': existingWithLineNumbers,
            'originalEpisodeId': episodeId,
            'originalLanguageCode': languageCode,
          },
          createdAt: DateTime.now(),
          version: _cacheVersion,
          ttlDays: _defaultTtlDays,
        );
        
        final safeEpisodeId = CacheKeyHelper.sanitizeFirebaseKey(episodeId);
        final safeLanguageCode = CacheKeyHelper.sanitizeFirebaseKey(languageCode);
        final url = '$_baseUrl/$_cachePath/translations/$safeEpisodeId/$safeLanguageCode.json';
        
        final response = await http.put(
          Uri.parse(url),
          headers: {'Content-Type': 'application/json'},
          body: json.encode(cacheEntry.toJson()),
        ).timeout(const Duration(seconds: 10));
        
        if (response.statusCode == 200) {
          debugPrint('✅ Successfully merged line translation to existing Firebase cache: $episodeId/$languageCode (lineNumber: $lineNumber)');
        } else {
          debugPrint('⚠️ Firebase merge returned status ${response.statusCode}');
        }
      } else {
        // Create new translation entry with this single line and correct lineNumber
        // Create a list with proper lineNumber structure
        final translationsArray = [
          {
            'original': originalText,
            'translated': translatedText,
            'lineNumber': lineNumber,
          }
        ];
        
        final cacheEntry = AICacheEntry(
          data: {
            'translations': translationsArray,
            'originalEpisodeId': episodeId,
            'originalLanguageCode': languageCode,
          },
          createdAt: DateTime.now(),
          version: _cacheVersion,
          ttlDays: _defaultTtlDays,
        );
        
        final safeEpisodeId = CacheKeyHelper.sanitizeFirebaseKey(episodeId);
        final safeLanguageCode = CacheKeyHelper.sanitizeFirebaseKey(languageCode);
        final url = '$_baseUrl/$_cachePath/translations/$safeEpisodeId/$safeLanguageCode.json';
        
        final response = await http.put(
          Uri.parse(url),
          headers: {'Content-Type': 'application/json'},
          body: json.encode(cacheEntry.toJson()),
        ).timeout(const Duration(seconds: 10));
        
        if (response.statusCode == 200) {
          debugPrint('✅ Successfully saved new line translation to Firebase: $episodeId/$languageCode (lineNumber: $lineNumber)');
        } else {
          debugPrint('⚠️ Firebase save returned status ${response.statusCode}');
        }
      }
    } catch (e, stackTrace) {
      debugPrint('❌ Error saving line translation to Firebase: $e');
      debugPrint('   EpisodeId: $episodeId, LanguageCode: $languageCode, LineNumber: $lineNumber');
      debugPrint('   Stack trace: $stackTrace');
      // Don't rethrow - line translation is not critical, but log the error
    }
  }

  /// Get grammar explanation from Firebase cache
  Future<Map<String, dynamic>?> getGrammar(
    String sentence,
    String languageCode, {
    String? episodeId,
    String? modelVersion,
    String? promptVersion,
    int? lineNumber,
  }) async {
    try {
      final safeLanguageCode = CacheKeyHelper.sanitizeFirebaseKey(languageCode);
      if (episodeId != null && episodeId.trim().isNotEmpty) {
        final safeEpisodeId = CacheKeyHelper.sanitizeFirebaseKey(episodeId.trim());
        final lineKey =
            CacheKeyHelper.grammarEpisodeLineKey(sentence, lineNumber: lineNumber);
        final byEpisodeUrl =
            '$_baseUrl/$_cachePath/grammar_by_episode/$safeEpisodeId/$lineKey/$safeLanguageCode.json';
        debugPrint('[FirebaseGrammar] try grammar_by_episode url=$byEpisodeUrl');
        final byEpisodeResponse = await http.get(
          Uri.parse(byEpisodeUrl),
          headers: {'Accept': 'application/json'},
        ).timeout(const Duration(seconds: 5));

        if (byEpisodeResponse.statusCode == 200 && byEpisodeResponse.body != 'null') {
          final cacheEntry = AICacheEntry.fromJson(json.decode(byEpisodeResponse.body));
          if (cacheEntry.isValid(defaultTtlDays: _defaultTtlDays)) {
            debugPrint('Firebase cache HIT for grammar_by_episode: $episodeId/$lineKey');
            return cacheEntry.data;
          }
          debugPrint('[FirebaseGrammar] grammar_by_episode EXPIRED: $episodeId/$lineKey');
        }
        if (byEpisodeResponse.statusCode == 200 && byEpisodeResponse.body == 'null') {
          debugPrint('[FirebaseGrammar] grammar_by_episode MISS (null): $episodeId/$lineKey');
        } else if (byEpisodeResponse.statusCode != 200) {
          debugPrint('[FirebaseGrammar] grammar_by_episode status=${byEpisodeResponse.statusCode}');
        }

        // Fallback for prefilled caches where line key might differ by sentence normalization.
        final byEpisodeRootUrl =
            '$_baseUrl/$_cachePath/grammar_by_episode/$safeEpisodeId.json';
        debugPrint('[FirebaseGrammar] fallback scan by sourceSentence url=$byEpisodeRootUrl');
        final byEpisodeRootResponse = await http.get(
          Uri.parse(byEpisodeRootUrl),
          headers: {'Accept': 'application/json'},
        ).timeout(const Duration(seconds: 5));
        if (byEpisodeRootResponse.statusCode == 200 &&
            byEpisodeRootResponse.body != 'null') {
          final decoded = json.decode(byEpisodeRootResponse.body);
          if (decoded is Map<String, dynamic>) {
            final normalizedNeedle = _normalizeSentenceForCacheLookup(sentence);
            for (final lineEntry in decoded.entries) {
              final lineNode = lineEntry.value;
              if (lineNode is! Map<String, dynamic>) continue;
              final langNode = lineNode[safeLanguageCode];
              if (langNode is! Map<String, dynamic>) continue;
              try {
                final cacheEntry = AICacheEntry.fromJson(langNode);
                if (!cacheEntry.isValid(defaultTtlDays: _defaultTtlDays)) {
                  continue;
                }
                final sourceSentence =
                    cacheEntry.data['sourceSentence']?.toString() ?? '';
                final normalizedSource =
                    _normalizeSentenceForCacheLookup(sourceSentence);
                if (normalizedSource == normalizedNeedle) {
                  debugPrint(
                    '[FirebaseGrammar] grammar_by_episode HIT via sourceSentence scan: '
                    '$episodeId/${lineEntry.key}/$safeLanguageCode',
                  );
                  return cacheEntry.data;
                }
              } catch (_) {
                // Ignore malformed node and continue scanning.
              }
            }
            debugPrint('[FirebaseGrammar] sourceSentence scan MISS for episode=$episodeId');
          }
        }
      }

      final sentenceHash = CacheKeyHelper.grammarKey(
        sentence,
        languageCode,
        episodeId: episodeId,
        modelVersion: modelVersion,
        promptVersion: promptVersion,
      ).replaceFirst('grammar_', '');
      final url = '$_baseUrl/$_cachePath/grammar/$sentenceHash/$safeLanguageCode.json';
      debugPrint('[FirebaseGrammar] fallback legacy url=$url');
      
      final response = await http.get(
        Uri.parse(url),
        headers: {'Accept': 'application/json'},
      ).timeout(const Duration(seconds: 5));

      if (response.statusCode == 200 && response.body != 'null') {
        final cacheEntry = AICacheEntry.fromJson(json.decode(response.body));
        
        if (cacheEntry.isValid(defaultTtlDays: _defaultTtlDays)) {
          debugPrint('Firebase cache HIT for grammar: $sentenceHash');
          return cacheEntry.data;
        } else {
          debugPrint('Firebase cache EXPIRED for grammar: $sentenceHash');
        }
      }
      
      return null;
    } catch (e) {
      debugPrint('Error getting grammar from Firebase: $e');
      return null;
    }
  }

  /// Save grammar explanation to Firebase cache
  Future<void> saveGrammar(
    String sentence,
    String languageCode,
    Map<String, dynamic> grammarData,
    {
    String? episodeId,
    String? modelVersion,
    String? promptVersion,
    int? lineNumber,
  }) async {
    try {
      final safeLanguageCode = CacheKeyHelper.sanitizeFirebaseKey(languageCode);
      final normalizedEpisodeId = episodeId?.trim();
      final lineKey =
          CacheKeyHelper.grammarEpisodeLineKey(sentence, lineNumber: lineNumber);
      final normalizedGrammarData = Map<String, dynamic>.from(grammarData);
      if ((normalizedEpisodeId ?? '').isNotEmpty) {
        normalizedGrammarData['episodeId'] = normalizedEpisodeId;
      }
      normalizedGrammarData['lineKey'] = lineKey;
      normalizedGrammarData['sourceSentence'] = sentence.trim();
      if (lineNumber != null && lineNumber >= 0) {
        normalizedGrammarData['lineNumber'] = lineNumber;
      }
      normalizedGrammarData['schemaVersion'] = _grammarSchemaVersion;

      final sentenceHash = CacheKeyHelper.grammarKey(
        sentence,
        languageCode,
        episodeId: episodeId,
        modelVersion: modelVersion,
        promptVersion: promptVersion,
      ).replaceFirst('grammar_', '');
      final url = '$_baseUrl/$_cachePath/grammar/$sentenceHash/$safeLanguageCode.json';
      
      final cacheEntry = AICacheEntry(
        data: normalizedGrammarData,
        createdAt: DateTime.now(),
        version: _cacheVersion,
        ttlDays: _defaultTtlDays,
      );

      await http.put(
        Uri.parse(url),
        headers: {'Content-Type': 'application/json'},
        body: json.encode(cacheEntry.toJson()),
      ).timeout(const Duration(seconds: 5));

      if ((normalizedEpisodeId ?? '').isNotEmpty) {
        final safeEpisodeId = CacheKeyHelper.sanitizeFirebaseKey(normalizedEpisodeId!);
        final byEpisodeUrl =
            '$_baseUrl/$_cachePath/grammar_by_episode/$safeEpisodeId/$lineKey/$safeLanguageCode.json';
        await http.put(
          Uri.parse(byEpisodeUrl),
          headers: {'Content-Type': 'application/json'},
          body: json.encode(cacheEntry.toJson()),
        ).timeout(const Duration(seconds: 5));
      }
      
      debugPrint('Saved grammar to Firebase cache: $sentenceHash');
    } catch (e) {
      debugPrint('Error saving grammar to Firebase: $e');
    }
  }

  /// Get passage grammar explanation from Firebase cache (new namespace)
  Future<Map<String, dynamic>?> getGrammarPassage(
    String passage,
    String languageCode, {
    String? episodeId,
    String? modelVersion,
    String? promptVersion,
    String? schemaVersion,
  }) async {
    try {
      final passageHash = CacheKeyHelper.grammarPassageKey(
        passage,
        languageCode,
        episodeId: episodeId,
        modelVersion: modelVersion,
        promptVersion: promptVersion,
        schemaVersion: schemaVersion,
      ).replaceFirst('grammar_passage_', '');
      final safeLanguageCode = CacheKeyHelper.sanitizeFirebaseKey(languageCode);
      final url =
          '$_baseUrl/$_cachePath/grammar_passage/$passageHash/$safeLanguageCode.json';

      final response = await http.get(
        Uri.parse(url),
        headers: {'Accept': 'application/json'},
      ).timeout(const Duration(seconds: 5));

      if (response.statusCode == 200 && response.body != 'null') {
        final cacheEntry = AICacheEntry.fromJson(json.decode(response.body));
        if (cacheEntry.isValid(defaultTtlDays: _defaultTtlDays)) {
          return cacheEntry.data;
        }
      }
      return null;
    } catch (e) {
      debugPrint('Error getting grammar passage from Firebase: $e');
      return null;
    }
  }

  /// Save passage grammar explanation to Firebase cache (new namespace)
  Future<void> saveGrammarPassage(
    String passage,
    String languageCode,
    Map<String, dynamic> grammarData, {
    String? episodeId,
    String? modelVersion,
    String? promptVersion,
    String? schemaVersion,
  }) async {
    try {
      final passageHash = CacheKeyHelper.grammarPassageKey(
        passage,
        languageCode,
        episodeId: episodeId,
        modelVersion: modelVersion,
        promptVersion: promptVersion,
        schemaVersion: schemaVersion,
      ).replaceFirst('grammar_passage_', '');
      final safeLanguageCode = CacheKeyHelper.sanitizeFirebaseKey(languageCode);
      final url =
          '$_baseUrl/$_cachePath/grammar_passage/$passageHash/$safeLanguageCode.json';

      final cacheEntry = AICacheEntry(
        data: grammarData,
        createdAt: DateTime.now(),
        version: _cacheVersion,
        ttlDays: _defaultTtlDays,
      );
      await http.put(
        Uri.parse(url),
        headers: {'Content-Type': 'application/json'},
        body: json.encode(cacheEntry.toJson()),
      ).timeout(const Duration(seconds: 5));
    } catch (e) {
      debugPrint('Error saving grammar passage to Firebase: $e');
    }
  }

  /// Get questions from Firebase cache
  Future<List<Map<String, dynamic>>?> getQuestions(
    String episodeId,
    int count,
  ) async {
    try {
      final safeEpisodeId = CacheKeyHelper.sanitizeFirebaseKey(episodeId);
      final url = '$_baseUrl/$_cachePath/questions/$safeEpisodeId/$count.json';
      
      final response = await http.get(
        Uri.parse(url),
        headers: {'Accept': 'application/json'},
      ).timeout(const Duration(seconds: 5));

      if (response.statusCode == 200 && response.body != 'null') {
        final cacheEntry = AICacheEntry.fromJson(json.decode(response.body));
        
        if (cacheEntry.isValid(defaultTtlDays: _defaultTtlDays)) {
          final questions = cacheEntry.data['questions'] as List<dynamic>?;
          if (questions != null) {
            debugPrint('Firebase cache HIT for questions: $episodeId/$count');
            return questions.cast<Map<String, dynamic>>();
          }
        } else {
          debugPrint('Firebase cache EXPIRED for questions: $episodeId/$count');
        }
      }
      
      return null;
    } catch (e) {
      debugPrint('Error getting questions from Firebase: $e');
      return null;
    }
  }

  /// Save questions to Firebase cache
  Future<void> saveQuestions(
    String episodeId,
    int count,
    List<Map<String, dynamic>> questions,
  ) async {
    try {
      final safeEpisodeId = CacheKeyHelper.sanitizeFirebaseKey(episodeId);
      final url = '$_baseUrl/$_cachePath/questions/$safeEpisodeId/$count.json';
      
      final cacheEntry = AICacheEntry(
        data: {
          'questions': questions,
          'count': count,
        },
        createdAt: DateTime.now(),
        version: _cacheVersion,
        ttlDays: _defaultTtlDays,
      );

      await http.put(
        Uri.parse(url),
        headers: {'Content-Type': 'application/json'},
        body: json.encode(cacheEntry.toJson()),
      ).timeout(const Duration(seconds: 5));
      
      debugPrint('Saved questions to Firebase cache: $episodeId/$count');
    } catch (e) {
      debugPrint('Error saving questions to Firebase: $e');
    }
  }

  /// Get vocabulary enhancement from Firebase cache
  Future<Map<String, dynamic>?> getVocabulary(
    String word,
    String languageCode, {
    String? episodeId,
  }) async {
    try {
      final wordHash = CacheKeyHelper.hashString(word.toLowerCase().trim());
      final safeLanguageCode = CacheKeyHelper.sanitizeFirebaseKey(languageCode);
      if (episodeId != null && episodeId.trim().isNotEmpty) {
        final safeEpisodeId = CacheKeyHelper.sanitizeFirebaseKey(episodeId.trim());
        final byEpisodeUrl =
            '$_baseUrl/$_cachePath/vocabulary_by_episode/$safeEpisodeId/$wordHash.json';
        final byEpisodeResponse = await http.get(
          Uri.parse(byEpisodeUrl),
          headers: {'Accept': 'application/json'},
        ).timeout(const Duration(seconds: 5));
        if (byEpisodeResponse.statusCode == 200 && byEpisodeResponse.body != 'null') {
          final cacheEntry = AICacheEntry.fromJson(json.decode(byEpisodeResponse.body));
          if (cacheEntry.isValid(defaultTtlDays: _vocabularyTtlDays)) {
            debugPrint('Firebase cache HIT for vocabulary_by_episode: ${episodeId.trim()}/$wordHash');
            final byEpisodeData = cacheEntry.data;
            final vocabData = (byEpisodeData['data'] is Map<String, dynamic>)
                ? Map<String, dynamic>.from(byEpisodeData['data'] as Map<String, dynamic>)
                : <String, dynamic>{};
            final translation = byEpisodeData['translation'];
            if (translation is Map<String, dynamic>) {
              final localizedMeaning = translation[safeLanguageCode]?.toString() ?? '';
              if (localizedMeaning.isNotEmpty) {
                vocabData['meaning'] = localizedMeaning;
              }
            }

            if (vocabData.isNotEmpty) {
              return vocabData;
            }
          } else {
            debugPrint('Firebase cache EXPIRED for vocabulary_by_episode: ${episodeId.trim()}/$wordHash');
          }
        } else {
          debugPrint('Firebase cache MISS for vocabulary_by_episode: ${episodeId.trim()}/$wordHash');
        }
      }

      final url = '$_baseUrl/$_cachePath/vocabulary/$wordHash/$safeLanguageCode.json';
      
      final response = await http.get(
        Uri.parse(url),
        headers: {'Accept': 'application/json'},
      ).timeout(const Duration(seconds: 5));

      if (response.statusCode == 200 && response.body != 'null') {
        final cacheEntry = AICacheEntry.fromJson(json.decode(response.body));
        
        if (cacheEntry.isValid(defaultTtlDays: _vocabularyTtlDays)) {
          debugPrint('Firebase cache HIT for vocabulary: $wordHash');
          return cacheEntry.data;
        } else {
          debugPrint('Firebase cache EXPIRED for vocabulary: $wordHash');
        }
      }
      
      return null;
    } catch (e) {
      debugPrint('Error getting vocabulary from Firebase: $e');
      return null;
    }
  }

  /// Save vocabulary enhancement to Firebase cache
  Future<void> saveVocabulary(
    String word,
    String languageCode,
    Map<String, dynamic> vocabularyData,
    {String? episodeId}
  ) async {
    try {
      final wordHash = CacheKeyHelper.hashString(word.toLowerCase().trim());
      final safeLanguageCode = CacheKeyHelper.sanitizeFirebaseKey(languageCode);
      final url = '$_baseUrl/$_cachePath/vocabulary/$wordHash/$safeLanguageCode.json';
      
      final cacheEntry = AICacheEntry(
        data: vocabularyData,
        createdAt: DateTime.now(),
        version: _cacheVersion,
        ttlDays: _vocabularyTtlDays,
      );

      await http.put(
        Uri.parse(url),
        headers: {'Content-Type': 'application/json'},
        body: json.encode(cacheEntry.toJson()),
      ).timeout(const Duration(seconds: 5));

      if (episodeId != null && episodeId.trim().isNotEmpty) {
        final safeEpisodeId = CacheKeyHelper.sanitizeFirebaseKey(episodeId.trim());
        final byEpisodeUrl =
            '$_baseUrl/$_cachePath/vocabulary_by_episode/$safeEpisodeId/$wordHash.json';
        Map<String, dynamic> existingTranslation = <String, dynamic>{};
        try {
          final existingResponse = await http.get(
            Uri.parse(byEpisodeUrl),
            headers: {'Accept': 'application/json'},
          ).timeout(const Duration(seconds: 5));
          if (existingResponse.statusCode == 200 && existingResponse.body != 'null') {
            final existingEntry = AICacheEntry.fromJson(json.decode(existingResponse.body));
            final existing = existingEntry.data['translation'];
            if (existing is Map<String, dynamic>) {
              existingTranslation = Map<String, dynamic>.from(existing);
            }
          }
        } catch (_) {}

        final byEpisodeData = Map<String, dynamic>.from(vocabularyData);
        final meaning = byEpisodeData.remove('meaning')?.toString() ?? '';
        existingTranslation[safeLanguageCode] = meaning;

        final byEpisodeEntry = AICacheEntry(
          data: {
            'word': word.trim(),
            'wordHash': wordHash,
            'episodeId': episodeId.trim(),
            'data': byEpisodeData,
            'translation': existingTranslation,
            'schemaVersion': 2,
          },
          createdAt: DateTime.now(),
          version: _cacheVersion,
          ttlDays: _vocabularyTtlDays,
        );
        await http.put(
          Uri.parse(byEpisodeUrl),
          headers: {'Content-Type': 'application/json'},
          body: json.encode(byEpisodeEntry.toJson()),
        ).timeout(const Duration(seconds: 5));
      }
      
      debugPrint('Saved vocabulary to Firebase cache: $wordHash');
    } catch (e) {
      debugPrint('Error saving vocabulary to Firebase: $e');
    }
  }

  // ========== Cache Management Methods ==========

  /// Invalidate translation cache for an episode
  Future<void> invalidateTranslation(
    String episodeId,
    String? languageCode,
  ) async {
    try {
      if (languageCode != null) {
        // Invalidate specific language
        final url = '$_baseUrl/$_cachePath/translations/$episodeId/$languageCode.json';
        await http.delete(Uri.parse(url)).timeout(const Duration(seconds: 5));
        debugPrint('Invalidated translation cache: $episodeId/$languageCode');
      } else {
        // Invalidate all languages for this episode
        final url = '$_baseUrl/$_cachePath/translations/$episodeId.json';
        await http.delete(Uri.parse(url)).timeout(const Duration(seconds: 5));
        debugPrint('Invalidated all translation cache for episode: $episodeId');
      }
    } catch (e) {
      debugPrint('Error invalidating translation cache: $e');
    }
  }

  /// Invalidate questions cache for an episode
  Future<void> invalidateQuestions(String episodeId) async {
    try {
      final safeEpisodeId = CacheKeyHelper.sanitizeFirebaseKey(episodeId);
      final url = '$_baseUrl/$_cachePath/questions/$safeEpisodeId.json';
      await http.delete(Uri.parse(url)).timeout(const Duration(seconds: 5));
      debugPrint('Invalidated questions cache for episode: $episodeId');
    } catch (e) {
      debugPrint('Error invalidating questions cache: $e');
    }
  }

  /// Track episode access for popular episodes tracking
  Future<void> trackEpisodeAccess(String episodeId) async {
    try {
      final url = '$_baseUrl/$_cachePath/access_stats/$episodeId.json';
      final response = await http.get(
        Uri.parse(url),
        headers: {'Accept': 'application/json'},
      ).timeout(const Duration(seconds: 5));

      int accessCount = 1;
      if (response.statusCode == 200 && response.body != 'null') {
        final data = json.decode(response.body);
        accessCount = (data['count'] as int? ?? 0) + 1;
      }

      await http.put(
        Uri.parse(url),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({
          'episodeId': episodeId,
          'count': accessCount,
          'lastAccessed': DateTime.now().toIso8601String(),
        }),
      ).timeout(const Duration(seconds: 5));
    } catch (e) {
      debugPrint('Error tracking episode access: $e');
      // Fail silently
    }
  }

  /// Get popular episodes (for pre-caching strategy)
  Future<List<String>> getPopularEpisodes({int limit = 100}) async {
    try {
      final url = '$_baseUrl/$_cachePath/access_stats.json?orderBy="count"&limitToLast=$limit';
      final response = await http.get(
        Uri.parse(url),
        headers: {'Accept': 'application/json'},
      ).timeout(const Duration(seconds: 5));

      if (response.statusCode == 200 && response.body != 'null') {
        final data = json.decode(response.body) as Map<String, dynamic>;
        final episodes = data.entries
            .map((e) => e.value as Map<String, dynamic>)
            .where((e) => e['episodeId'] != null)
            .map((e) => e['episodeId'] as String)
            .toList();
        return episodes;
      }
      return [];
    } catch (e) {
      debugPrint('Error getting popular episodes: $e');
      return [];
    }
  }
}

