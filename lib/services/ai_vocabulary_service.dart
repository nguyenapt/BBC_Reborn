import 'package:flutter/foundation.dart';
import '../models/vocabulary_item.dart';
import '../models/enhanced_vocabulary.dart';
import 'ai/ai_provider_factory.dart';
import 'ai/ai_error_handler.dart';
import 'ai/exceptions.dart';
import 'ai_cache_service.dart';
import 'heart_service.dart';

/// Service for AI-powered vocabulary enhancement
class AIVocabularyService {
  static final AIVocabularyService _instance = AIVocabularyService._internal();
  factory AIVocabularyService() => _instance;
  AIVocabularyService._internal();

  final AICacheService _cache = AICacheService();

  /// Enhance vocabulary with additional information
  Future<EnhancedVocabulary> enhanceVocabulary(
    VocabularyItem item, {
    String? context,
  }) async {
    // Check cache with priority: Local → Firebase → null
    final cachedData = await _cache.getVocabularyFromCache(item.vocab);

    if (cachedData != null) {
      debugPrint('Using cached enhanced vocabulary for ${item.vocab}');
      // Convert cached data to EnhancedVocabulary
      return EnhancedVocabulary.fromAIResponse(item, cachedData);
    }

    // Check hearts before calling AI (only if not cached)
    final heartService = HeartService();
    if (!heartService.hasHearts) {
      throw NoHeartsException();
    }

    // Use a heart
    final heartUsed = await heartService.useHeart();
    if (!heartUsed) {
      throw NoHeartsException();
    }

    // Get provider with fallback
    final provider = await AIProviderFactory.createProviderWithFallback();

    try {
      final response = await AIErrorHandler.withRetry(
        () => provider.enhanceVocabulary(
          item.vocab,
          item.mean,
          context: context,
        ),
      );

      // Parse response
      final enhanced = EnhancedVocabulary.fromAIResponse(item, response);

      // Save to both local and Firebase cache
      await _cache.saveVocabularyToCache(item.vocab, response);

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

