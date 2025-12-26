import 'package:flutter/foundation.dart';
import '../models/transcript_line.dart';
import 'ai/ai_provider_factory.dart';
import 'ai/ai_error_handler.dart';
import 'ai/exceptions.dart';
import 'ai_cache_service.dart';
import 'language_manager.dart';
import 'heart_service.dart';

/// Service for AI-powered translation
class AITranslationService {
  static final AITranslationService _instance = AITranslationService._internal();
  factory AITranslationService() => _instance;
  AITranslationService._internal();

  final AICacheService _cache = AICacheService();
  final LanguageManager _languageManager = LanguageManager();

  /// Get target language code from LanguageManager
  String _getTargetLanguage() {
    final locale = _languageManager.currentLocale;
    // Map locale to language name for AI
    switch (locale.languageCode) {
      case 'vi':
        return 'Vietnamese';
      case 'zh':
        return 'Chinese';
      case 'ja':
        return 'Japanese';
      case 'ko':
        return 'Korean';
      case 'es':
        return 'Spanish';
      case 'pt':
        return 'Portuguese';
      case 'ar':
        return 'Arabic';
      case 'ru':
        return 'Russian';
      case 'fr':
        return 'French';
      case 'de':
        return 'German';
      default:
        return 'English';
    }
  }

  /// Get target language code (for cache keys)
  String _getTargetLanguageCode() {
    return _languageManager.currentLocale.languageCode;
  }

  /// Translate transcript lines
  Future<Map<String, String>> translateTranscript(
    List<TranscriptLine> lines,
    String episodeId,
  ) async {
    final targetLanguage = _getTargetLanguage();
    final languageCode = _getTargetLanguageCode();

    // Check cache with priority: Local → Firebase → null
    final cached = await _cache.getTranslationFromCache(episodeId, languageCode);
    if (cached != null && cached.isNotEmpty) {
      debugPrint('Using cached translations for episode $episodeId');
      return cached;
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

    // Translate all lines
    final translations = <String, String>{};
    
    try {
      // Batch translate (translate multiple lines at once to save API calls)
      final textsToTranslate = lines.map((line) => line.text).toList();
      
      // Translate in batches of 5 to avoid token limits
      const batchSize = 5;
      for (int i = 0; i < textsToTranslate.length; i += batchSize) {
        final batch = textsToTranslate.sublist(
          i,
          i + batchSize > textsToTranslate.length 
            ? textsToTranslate.length 
            : i + batchSize,
        );
        
        // Create context from previous and next lines
        final context = _buildContext(lines, i, batch.length);
        
        // Translate batch
        for (int j = 0; j < batch.length; j++) {
          final text = batch[j];
          final lineIndex = i + j;
          
          try {
            final translated = await AIErrorHandler.withRetry(
              () => provider.translate(
                text,
                targetLanguage,
                context: context,
              ),
            );
            
            translations[text] = translated;
          } catch (e) {
            debugPrint('Error translating line $lineIndex: $e');
            // Continue with other lines
            translations[text] = text; // Fallback to original
          }
        }
      }

      // Save to both local and Firebase cache
      if (translations.isNotEmpty) {
        await _cache.saveTranslationToCache(episodeId, languageCode, translations);
      }
      
      return translations;
    } catch (e) {
      debugPrint('Error in translateTranscript: $e');
      // Return partial translations if available
      return translations;
    }
  }

  /// Build context from surrounding lines
  String _buildContext(List<TranscriptLine> lines, int startIndex, int batchSize) {
    final contextLines = <String>[];
    
    // Add previous line
    if (startIndex > 0) {
      contextLines.add(lines[startIndex - 1].text);
    }
    
    // Add next line
    if (startIndex + batchSize < lines.length) {
      contextLines.add(lines[startIndex + batchSize].text);
    }
    
    return contextLines.join(' ');
  }

  /// Translate vocabulary word
  Future<String> translateVocabulary(
    String word,
    String meaning, {
    String? context,
  }) async {
    final targetLanguage = _getTargetLanguage();
    final cacheKey = 'vocab_translation_${word}_$targetLanguage';

    // Check cache first
    final cached = await _cache.getCachedString(cacheKey);
    if (cached != null) {
      return cached;
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
      // Build context for better translation
      final fullContext = context != null 
        ? 'Context: $context. Meaning: $meaning'
        : 'Meaning: $meaning';

      final translated = await AIErrorHandler.withRetry(
        () => provider.translate(
          word,
          targetLanguage,
          context: fullContext,
        ),
      );

      // Cache translation
      await _cache.cacheString(cacheKey, translated);

      return translated;
    } catch (e) {
      debugPrint('Error translating vocabulary: $e');
      // Return original word as fallback
      return word;
    }
  }

  /// Translate single text
  Future<String> translateText(
    String text, {
    String? context,
  }) async {
    final targetLanguage = _getTargetLanguage();
    final cacheKey = 'text_translation_${text.hashCode}_$targetLanguage';

    // Check cache first
    final cached = await _cache.getCachedString(cacheKey);
    if (cached != null) {
      return cached;
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
      final translated = await AIErrorHandler.withRetry(
        () => provider.translate(
          text,
          targetLanguage,
          context: context,
        ),
      );

      // Cache translation
      await _cache.cacheString(cacheKey, translated);

      return translated;
    } catch (e) {
      debugPrint('Error translating text: $e');
      return text; // Fallback to original
    }
  }
}

