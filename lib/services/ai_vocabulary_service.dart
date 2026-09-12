import 'package:flutter/foundation.dart';
import '../models/ai_cache_tier.dart';
import '../models/vocabulary_item.dart';
import '../models/enhanced_vocabulary.dart';
import 'ai/ai_provider_factory.dart';
import 'ai/ai_error_handler.dart';
import 'ai/exceptions.dart';
import 'ai_cache_service.dart';
import 'language_manager.dart';

/// Service for AI-powered vocabulary enhancement
class AIVocabularyService {
  static final AIVocabularyService _instance = AIVocabularyService._internal();
  factory AIVocabularyService() => _instance;
  AIVocabularyService._internal();

  final AICacheService _cache = AICacheService();
  final LanguageManager _languageManager = LanguageManager();

  String? _relevantContext(String? context, String word) {
    if (context == null || context.trim().isEmpty) return null;
    final wordLower = word.toLowerCase();
    final sentences = context.split(RegExp(r'[.!?]\s+'));
    final relevant = sentences
        .where((sentence) => sentence.toLowerCase().contains(wordLower))
        .take(2)
        .join('. ');
    if (relevant.isEmpty) return null;
    return relevant.length > 200
        ? '${relevant.substring(0, 200)}...'
        : relevant;
  }

  /// Enhance vocabulary with additional information
  Future<EnhancedVocabulary> enhanceVocabulary(
    VocabularyItem item, {
    String? context,
    String? episodeId,
  }) async {
    final languageCode = _languageManager.currentLocale.languageCode;
    final resolvedEpisodeId =
        (episodeId?.trim().isNotEmpty == true ? episodeId! : item.bbcEpisodeId);

    final cacheHit = await _cache.lookupVocabulary(
      item.vocab,
      languageCode,
      episodeId: resolvedEpisodeId,
      vocabItemId: item.id,
    );

    if (cacheHit != null) {
      await AICacheService.consumeHeartIfFirebase(
        cacheHit.tier,
        episodeId: resolvedEpisodeId,
      );
      if (cacheHit.tier == AICacheTier.firebase) {
        await _cache.materializeVocabularyLocal(
          item.vocab,
          languageCode,
          cacheHit.data,
        );
      }
      debugPrint('Using cached enhanced vocabulary for ${item.vocab}');
      return EnhancedVocabulary.fromAIResponse(item, cacheHit.data);
    }

    await AICacheService.consumeForLiveAi(episodeId: resolvedEpisodeId);

    final trimmedContext = _relevantContext(context, item.vocab);

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
            context: trimmedContext,
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
                context: trimmedContext,
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
                context: trimmedContext,
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
        episodeId: resolvedEpisodeId,
        vocabItemId: item.id,
      );

      return enhanced;
    } catch (e) {
      debugPrint('Error enhancing vocabulary: $e');
      rethrow;
    }
  }
}

