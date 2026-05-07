import 'package:flutter/foundation.dart';
import '../models/vocabulary_item.dart';
import '../models/enhanced_vocabulary.dart';
import 'ai/ai_provider_factory.dart';
import 'ai/ai_error_handler.dart';
import 'ai/exceptions.dart';
import 'ai_cache_lookup.dart';
import 'ai_cache_service.dart';
import 'heart_service.dart';
import 'language_manager.dart';

/// Service for AI-powered vocabulary enhancement
class AIVocabularyService {
  static final AIVocabularyService _instance = AIVocabularyService._internal();
  factory AIVocabularyService() => _instance;
  AIVocabularyService._internal();

  final AICacheService _cache = AICacheService();
  final LanguageManager _languageManager = LanguageManager();

  /// Enhance vocabulary with additional information
  Future<EnhancedVocabulary> enhanceVocabulary(
    VocabularyItem item, {
    String? context,
  }) async {
    final languageCode = _languageManager.currentLocale.languageCode;
    
    // Check cache with priority: Local → Firebase → null
    final cachedData = await _cache.getVocabularyFromCache(
      item.vocab,
      languageCode,
      episodeId: item.bbcEpisodeId,
    );

    if (cachedData != null) {
      debugPrint('Using cached enhanced vocabulary for ${item.vocab}');
      final payload = cachedData.value;
      // Tool RTDB upload may include locale gloss in `meaning` (see playMP3 UploadVocabularyAiCachesAsync).
      final cachedMean = payload['meaning']?.toString().trim();
      final effectiveItem = (cachedMean != null && cachedMean.isNotEmpty)
          ? VocabularyItem(
              id: item.id,
              bbcEpisodeId: item.bbcEpisodeId,
              vocab: item.vocab,
              mean: cachedMean,
            )
          : item;
      if (cachedData.source == AiCacheSource.firebase) {
        await HeartService().consumeHeartOrThrow();
      }
      return EnhancedVocabulary.fromAIResponse(effectiveItem, payload);
    }

    await HeartService().consumeHeartOrThrow();

    // Get providers (primary and backup)
    final primaryProvider = AIProviderFactory.getPrimaryProvider();
    final backupProvider = AIProviderFactory.getBackupProvider();

    try {
      // Try primary provider first with retry
      Map<String, dynamic>? response;
      try {
        response = await AIErrorHandler.withRetry(
          () => primaryProvider.enhanceVocabulary(
            item.vocab,
            item.mean,
            context: context,
          ),
          maxRetries: 1, // Only 1 retry, then fallback
        );
        debugPrint('✅ Primary provider (Gemini) vocabulary enhancement successful');
      } catch (e) {
        debugPrint('⚠️ Primary provider failed: $e');
        
        // If rate limit with long retry time (>30s), try backup provider immediately
        if (e is RateLimitException && e.retryAfter != null && e.retryAfter!.inSeconds > 30) {
          debugPrint('⚠️ Rate limit retry time too long (${e.retryAfter!.inSeconds}s), falling back to OpenAI...');
          try {
            if (await backupProvider.isAvailable()) {
              response = await backupProvider.enhanceVocabulary(
                item.vocab,
                item.mean,
                context: context,
              );
              debugPrint('✅ Backup provider (OpenAI) vocabulary enhancement successful');
            } else {
              rethrow;
            }
          } catch (backupError) {
            debugPrint('❌ Backup provider also failed: $backupError');
            rethrow;
          }
        } else if (e is APIException || e is RateLimitException) {
          // For other API errors or short retry times, try backup
          debugPrint('⚠️ Trying backup provider due to API error...');
          try {
            if (await backupProvider.isAvailable()) {
              response = await backupProvider.enhanceVocabulary(
                item.vocab,
                item.mean,
                context: context,
              );
              debugPrint('✅ Backup provider (OpenAI) vocabulary enhancement successful');
            } else {
              rethrow;
            }
          } catch (backupError) {
            debugPrint('❌ Backup provider also failed: $backupError');
            rethrow;
          }
        } else {
          rethrow;
        }
      }

      if (response == null) {
        throw Exception('Vocabulary enhancement failed: no result');
      }

      // Parse response
      final enhanced = EnhancedVocabulary.fromAIResponse(item, response);

      // Save to both local and Firebase cache
      await _cache.saveVocabularyToCache(
        item.vocab,
        languageCode,
        response,
        episodeId: item.bbcEpisodeId,
      );

      return enhanced;
    } catch (e) {
      debugPrint('Error enhancing vocabulary: $e');
      // Return basic enhanced vocabulary on error
      return EnhancedVocabulary(
        original: item,
        synonyms: [],
        antonyms: [],
        exampleSentences: [],
        collocations: [],
        pronunciation: null,
        wordForm: null,
      );
    }
  }
}

