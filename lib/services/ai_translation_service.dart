import 'package:flutter/foundation.dart';
import '../models/transcript_line.dart';
import 'ai/ai_provider_factory.dart';
import 'ai/ai_error_handler.dart';
import 'ai/exceptions.dart';
import 'ai_cache_service.dart';
import 'language_manager.dart';
import 'heart_service.dart';
import '../utils/cache_key_helper.dart';

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
      // Include original lines to add lineNumber to each translation item
      if (translations.isNotEmpty) {
        final originalLines = lines.map((line) => line.text).toList();
        await _cache.saveTranslationToCache(episodeId, languageCode, translations, originalLines: originalLines);
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

  /// Translate multiple vocabulary words in one batch request
  /// Returns a map of word -> translation
  Future<Map<String, String>> translateVocabularyBatch(
    List<Map<String, String>> vocabularyList, // List of {word, meaning, context?}
  ) async {
    if (vocabularyList.isEmpty) return {};
    
    final targetLanguage = _getTargetLanguage();
    final languageCode = _getTargetLanguageCode();
    
    // Check cache for all words first
    final cachedTranslations = <String, String>{};
    final wordsToTranslate = <Map<String, String>>[];
    
    for (final vocab in vocabularyList) {
      final word = vocab['word'] ?? '';
      final cacheKey = 'vocab_translation_${word}_$languageCode';
      final cached = await _cache.getCachedString(cacheKey);
      if (cached != null) {
        cachedTranslations[word] = cached;
      } else {
        wordsToTranslate.add(vocab);
      }
    }
    
    // If all words are cached, return immediately
    if (wordsToTranslate.isEmpty) {
      debugPrint('✅ All vocabulary translations found in cache');
      return cachedTranslations;
    }
    
    // Check hearts before calling AI (only if not all cached)
    final heartService = HeartService();
    if (!heartService.hasHearts) {
      throw NoHeartsException();
    }

    // Use a heart (only 1 heart for batch translation)
    final heartUsed = await heartService.useHeart();
    if (!heartUsed) {
      throw NoHeartsException();
    }

    // Get both providers for fallback
    final primaryProvider = AIProviderFactory.getPrimaryProvider();
    final backupProvider = AIProviderFactory.getBackupProvider();

    try {
      // Prepare vocabulary list with extracted context
      final preparedVocabList = <Map<String, String>>[];
      
      for (final vocab in wordsToTranslate) {
        final word = vocab['word'] ?? '';
        final meaning = vocab['meaning'] ?? '';
        final fullContext = vocab['context'];
        
        // Extract relevant context from transcript (max 200 chars)
        String? relevantContext;
        if (fullContext != null && fullContext.isNotEmpty) {
          final wordLower = word.toLowerCase();
          final sentences = fullContext.split(RegExp(r'[.!?]\s+'));
          final relevantSentences = sentences
              .where((sentence) => sentence.toLowerCase().contains(wordLower))
              .take(2)
              .join('. ');
          
          if (relevantSentences.isNotEmpty) {
            relevantContext = relevantSentences.length > 200 
                ? '${relevantSentences.substring(0, 200)}...'
                : relevantSentences;
          }
        }
        
        preparedVocabList.add({
          'word': word,
          'meaning': meaning,
          if (relevantContext != null) 'context': relevantContext,
        });
      }
      
      // Batch translate with provider fallback
      Map<String, String> translations;
      
      try {
        // Try primary provider first
        debugPrint('🔄 Attempting batch translation with primary provider (Gemini)...');
        translations = await AIErrorHandler.withRetry(
          () => primaryProvider.translateVocabularyBatch(
            preparedVocabList,
            targetLanguage,
          ),
          maxRetries: 1, // Only 1 retry, then fallback
        );
        debugPrint('✅ Primary provider batch translation successful');
      } catch (primaryError) {
        // Check if it's a rate limit or quota error
        final shouldFallback = primaryError is RateLimitException || 
                              primaryError is APIException ||
                              (primaryError.toString().contains('quota') || 
                               primaryError.toString().contains('rate limit'));
        
        if (shouldFallback) {
          debugPrint('⚠️ Primary provider failed: $primaryError');
          debugPrint('🔄 Falling back to backup provider (OpenAI)...');
          
          try {
            // Check if backup provider is available
            final backupAvailable = await backupProvider.isAvailable();
            if (!backupAvailable) {
              debugPrint('❌ Backup provider not available');
              // If backup not available, throw original error with improved message
              final primaryMessage = primaryError is APIException 
                  ? primaryError.message 
                  : (primaryError is RateLimitException 
                      ? primaryError.message 
                      : primaryError.toString());
              
              throw APIException(
                'Translation failed: $primaryMessage. Backup provider (OpenAI) is not configured.',
                null,
                primaryError,
              );
            }
            
            // Try backup provider
            translations = await backupProvider.translateVocabularyBatch(
              preparedVocabList,
              targetLanguage,
            );
            debugPrint('✅ Backup provider batch translation successful');
          } catch (backupError) {
            debugPrint('❌ Backup provider also failed: $backupError');
            
            // Extract messages from both errors
            final primaryMessage = primaryError is APIException 
                ? primaryError.message 
                : (primaryError is RateLimitException 
                    ? primaryError.message 
                    : primaryError.toString());
            
            // If backup error is about backup not available (from our check above),
            // the error message already includes both, so just rethrow it
            if (backupError is APIException && 
                backupError.message.contains('Backup provider (OpenAI) is not configured')) {
              rethrow; // Already has the right message
            }
            
            // If backup has a different meaningful error, combine both
            if (backupError is APIException || backupError is RateLimitException) {
              final backupMessage = backupError is APIException 
                  ? (backupError as APIException).message 
                  : (backupError as RateLimitException).message;
              
              throw APIException(
                'Translation failed. Primary (Gemini): $primaryMessage. Backup (OpenAI): $backupMessage',
                null,
                backupError,
              );
            } else {
              // For other backup errors, throw original primary error
              throw primaryError;
            }
          }
        } else {
          // For other errors, rethrow
          rethrow;
        }
      }
      
      // Cache all translations
      for (final entry in translations.entries) {
        final word = entry.key;
        final translation = entry.value;
        final cacheKey = 'vocab_translation_${word}_$languageCode';
        await _cache.cacheString(cacheKey, translation);
      }
      
      // Merge cached and new translations
      cachedTranslations.addAll(translations);
      
      debugPrint('✅ Batch translated ${translations.length} vocabulary words');
      return cachedTranslations;
    } catch (e) {
      debugPrint('❌ Error in batch vocabulary translation: $e');
      
      // If we have some cached translations, return them (partial success)
      // This allows UI to show what was already translated
      if (cachedTranslations.isNotEmpty) {
        debugPrint('⚠️ Returning ${cachedTranslations.length} cached translations (partial success)');
        return cachedTranslations;
      }
      
      // If no cached translations and batch failed, re-throw to let UI handle the error
      rethrow;
    }
  }

  /// Translate vocabulary word
  Future<String> translateVocabulary(
    String word,
    String meaning, {
    String? context,
  }) async {
    final targetLanguage = _getTargetLanguage();
    final languageCode = _getTargetLanguageCode();
    // Use languageCode for cache key to ensure consistency
    final cacheKey = 'vocab_translation_${word}_$languageCode';

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
      // Extract relevant context from transcript (max 200 chars around the word)
      String? relevantContext;
      if (context != null && context.isNotEmpty) {
        // Find sentences containing the word (case-insensitive)
        final wordLower = word.toLowerCase();
        final sentences = context.split(RegExp(r'[.!?]\s+'));
        final relevantSentences = sentences
            .where((sentence) => sentence.toLowerCase().contains(wordLower))
            .take(2) // Take max 2 sentences
            .join('. ');
        
        if (relevantSentences.isNotEmpty) {
          // Limit context length to avoid confusion
          relevantContext = relevantSentences.length > 200 
              ? '${relevantSentences.substring(0, 200)}...'
              : relevantSentences;
        }
      }

      // Build context for better translation - only include meaning and short context
      final fullContext = relevantContext != null
        ? 'Meaning: $meaning. Example context: $relevantContext'
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

  /// Translate a single transcript line with caching
  /// Checks Firebase cache first (with lineNumber matching), then local cache, then AI API
  Future<String> translateTranscriptLine(
    String lineText,
    String episodeId,
    int? lineNumber,
  ) async {
    final targetLanguage = _getTargetLanguage();
    final languageCode = _getTargetLanguageCode();
    
    debugPrint('🔄 translateTranscriptLine called:');
    debugPrint('   Line text: $lineText');
    debugPrint('   EpisodeId: $episodeId');
    debugPrint('   LineNumber: $lineNumber');
    debugPrint('   Target language: $targetLanguage');
    debugPrint('   Language code: $languageCode');
    debugPrint('   Current locale: ${_languageManager.currentLocale.languageCode}');
    
    // Skip translation if target language is English (source is already English)
    if (languageCode == 'en') {
      debugPrint('⚠️ Target language is English, skipping translation');
      return lineText;
    }
    
    // 1. Check cache first (Firebase with lineNumber, then local)
    final cached = await _cache.getLineTranslationFromCache(
      episodeId,
      languageCode,
      lineText,
      lineNumber,
    );
    if (cached != null) {
      debugPrint('✅ Using cached translation for line: $lineText (lineNumber: $lineNumber)');
      return cached;
    }

    // 2. Check hearts before calling AI (only if not cached)
    final heartService = HeartService();
    if (!heartService.hasHearts) {
      throw NoHeartsException();
    }

    // 3. Use a heart
    final heartUsed = await heartService.useHeart();
    if (!heartUsed) {
      throw NoHeartsException();
    }

    // 4. Get providers (primary and backup)
    final primaryProvider = AIProviderFactory.getPrimaryProvider();
    final backupProvider = AIProviderFactory.getBackupProvider();

    try {
      debugPrint('🌐 Calling AI to translate: "$lineText" -> $targetLanguage');
      
      // Try primary provider first with retry
      String? translated;
      try {
        translated = await AIErrorHandler.withRetry(
          () => primaryProvider.translate(
            lineText,
            targetLanguage,
          ),
          maxRetries: 1, // Only 1 retry, then fallback
        );
        debugPrint('✅ Primary provider (Gemini) translation successful');
      } catch (e) {
        debugPrint('⚠️ Primary provider failed: $e');
        
        // Check if it's a rate limit or API error that should trigger fallback
        final shouldFallback = e is RateLimitException || 
                              e is APIException ||
                              (e.toString().contains('quota') || 
                               e.toString().contains('rate limit') ||
                               e.toString().contains('API key not configured'));
        
        if (shouldFallback) {
          debugPrint('🔄 Falling back to backup provider (OpenAI)...');
          try {
            // Check if backup provider is available
            final backupAvailable = await backupProvider.isAvailable();
            if (!backupAvailable) {
              debugPrint('❌ Backup provider not available');
              // If backup not available, throw original error with improved message
              final primaryMessage = e is APIException 
                  ? e.message 
                  : (e is RateLimitException 
                      ? e.message 
                      : e.toString());
              
              throw APIException(
                'Translation failed: $primaryMessage. Backup provider (OpenAI) is not configured.',
                null,
                e,
              );
            }
            
            // Try backup provider
            translated = await backupProvider.translate(
              lineText,
              targetLanguage,
            );
            debugPrint('✅ Backup provider (OpenAI) translation successful');
          } catch (backupError) {
            debugPrint('❌ Backup provider also failed: $backupError');
            
            // Extract messages from both errors
            final primaryMessage = e is APIException 
                ? e.message 
                : (e is RateLimitException 
                    ? e.message 
                    : e.toString());
            
            // If backup error is about backup not available (from our check above),
            // the error message already includes both, so just rethrow it
            if (backupError is APIException && 
                backupError.message.contains('Backup provider (OpenAI) is not configured')) {
              rethrow; // Already has the right message
            }
            
            // If backup has a different meaningful error, combine both
            if (backupError is APIException || backupError is RateLimitException) {
              final backupMessage = backupError is APIException 
                  ? (backupError as APIException).message 
                  : (backupError as RateLimitException).message;
              
              throw APIException(
                'Translation failed. Primary (Gemini): $primaryMessage. Backup (OpenAI): $backupMessage',
                null,
                backupError,
              );
            } else {
              // For other backup errors, throw original primary error
              rethrow;
            }
          }
        } else {
          // For other errors, rethrow
          rethrow;
        }
      }
      
      if (translated == null) {
        throw Exception('Translation failed: no result');
      }
      
      // Check if translation is same as original (AI might have failed to translate)
      if (translated.trim().toLowerCase() == lineText.trim().toLowerCase()) {
        debugPrint('⚠️ WARNING: Translation result is same as original text!');
        debugPrint('   Original: "$lineText"');
        debugPrint('   Translated: "$translated"');
        debugPrint('   This might indicate the AI did not translate properly.');
        
        // If target language is not English, this is an error
        if (targetLanguage.toLowerCase() != 'english') {
          throw InvalidResponseException('AI returned original text instead of translation to $targetLanguage');
        }
      }
      
      debugPrint('✅ AI translation result: "$translated"');

      // 5. Save to cache (with lineNumber for Firebase)
      // Always save to Firebase, even if lineNumber is null (will use -1 as fallback)
      final effectiveLineNumber = lineNumber ?? -1;
      debugPrint('💾 Saving translation to cache: episodeId=$episodeId, languageCode=$languageCode, lineNumber=$effectiveLineNumber');
      await _cache.saveLineTranslationToCache(
        episodeId,
        languageCode,
        lineText,
        translated,
        effectiveLineNumber,
      );
      debugPrint('✅ Translation saved to cache successfully');

      return translated;
    } catch (e, stackTrace) {
      debugPrint('❌ Error translating transcript line: $e');
      debugPrint('   Stack trace: $stackTrace');
      return lineText; // Fallback to original
    }
  }
}

