import 'package:flutter/foundation.dart';
import '../models/vocabulary_item.dart';
import '../models/enhanced_vocabulary.dart';
import 'ai/ai_provider_factory.dart';
import 'ai/ai_error_handler.dart';
import 'ai_cache_service.dart';

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
    final cacheKey = 'enhanced_vocab_${item.vocab}';

    // Check cache first
    final cached = await _cache.getCached<EnhancedVocabulary>(
      cacheKey,
      (json) => EnhancedVocabulary.fromJson(json),
    );

    if (cached != null) {
      debugPrint('Using cached enhanced vocabulary for ${item.vocab}');
      return cached;
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

      // Cache enhanced vocabulary
      await _cache.cacheData(
        cacheKey,
        enhanced,
        (obj) => obj.toJson(),
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

