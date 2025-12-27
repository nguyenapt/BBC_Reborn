import 'package:flutter/foundation.dart';
import '../models/grammar_explanation.dart';
import 'ai/ai_provider_factory.dart';
import 'ai/ai_error_handler.dart';
import 'ai/exceptions.dart';
import 'ai_cache_service.dart';
import 'language_manager.dart';
import 'heart_service.dart';

/// Service for AI-powered grammar explanation
class AIGrammarService {
  static final AIGrammarService _instance = AIGrammarService._internal();
  factory AIGrammarService() => _instance;
  AIGrammarService._internal();

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
      default:
        return 'English';
    }
  }

  /// Explain grammar in a sentence
  Future<GrammarExplanation> explainSentence(
    String sentence,
    String episodeId,
  ) async {
    final targetLanguage = _getTargetLanguage();
    final languageCode = _languageManager.currentLocale.languageCode;

    // Check cache with priority: Local → Firebase → null
    final cachedData = await _cache.getGrammarFromCache(sentence, languageCode);
    
    if (cachedData != null) {
      debugPrint('Using cached grammar explanation for sentence');
      // Convert cached data to GrammarExplanation
      final grammarPoint = cachedData['grammarPoint']?.toString() ?? 'Unknown';
      final explanation = cachedData['explanation']?.toString() ?? '';
      final highlightedWords = (cachedData['highlightedWords'] as List<dynamic>?)
          ?.map((e) => e.toString())
          .toList() ?? [];
      
      return GrammarExplanation(
        sentence: sentence,
        grammarPoint: grammarPoint,
        explanation: explanation,
        highlightedWords: highlightedWords,
      );
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

    // Get providers (primary and backup)
    final primaryProvider = AIProviderFactory.getPrimaryProvider();
    final backupProvider = AIProviderFactory.getBackupProvider();

    try {
      // Try primary provider first with retry
      Map<String, dynamic>? response;
      try {
        response = await AIErrorHandler.withRetry(
          () => primaryProvider.explainGrammar(sentence, targetLanguage),
          maxRetries: 1, // Only 1 retry, then fallback
        );
        debugPrint('✅ Primary provider (Gemini) grammar explanation successful');
      } catch (e) {
        debugPrint('⚠️ Primary provider failed: $e');
        
        // If rate limit with long retry time (>30s), try backup provider immediately
        if (e is RateLimitException && e.retryAfter != null && e.retryAfter!.inSeconds > 30) {
          debugPrint('⚠️ Rate limit retry time too long (${e.retryAfter!.inSeconds}s), falling back to OpenAI...');
          try {
            if (await backupProvider.isAvailable()) {
              response = await backupProvider.explainGrammar(sentence, targetLanguage);
              debugPrint('✅ Backup provider (OpenAI) grammar explanation successful');
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
              response = await backupProvider.explainGrammar(sentence, targetLanguage);
              debugPrint('✅ Backup provider (OpenAI) grammar explanation successful');
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
        throw Exception('Grammar explanation failed: no result');
      }

      // Parse response
      final grammarPoint = response['grammarPoint']?.toString() ?? 'Unknown';
      final explanation = response['explanation']?.toString() ?? '';
      final highlightedWords = (response['highlightedWords'] as List<dynamic>?)
          ?.map((e) => e.toString())
          .toList() ?? [];

      final explanationObj = GrammarExplanation(
        sentence: sentence,
        grammarPoint: grammarPoint,
        explanation: explanation,
        highlightedWords: highlightedWords,
      );

      // Save to both local and Firebase cache
      final grammarData = {
        'grammarPoint': grammarPoint,
        'explanation': explanation,
        'highlightedWords': highlightedWords,
      };
      await _cache.saveGrammarToCache(sentence, languageCode, grammarData);

      return explanationObj;
    } catch (e) {
      debugPrint('Error explaining grammar: $e');
      // Return default explanation on error
      return GrammarExplanation(
        sentence: sentence,
        grammarPoint: 'Error',
        explanation: AIErrorHandler.getErrorMessage(e),
        highlightedWords: [],
      );
    }
  }

  /// Analyze entire transcript for grammar points
  Future<List<GrammarExplanation>> analyzeTranscript(
    List<String> sentences,
    String episodeId,
  ) async {
    final explanations = <GrammarExplanation>[];

    for (final sentence in sentences) {
      if (sentence.trim().isEmpty) continue;

      try {
        final explanation = await explainSentence(sentence, episodeId);
        explanations.add(explanation);
      } catch (e) {
        debugPrint('Error analyzing sentence: $e');
        // Continue with other sentences
      }
    }

    return explanations;
  }
}

