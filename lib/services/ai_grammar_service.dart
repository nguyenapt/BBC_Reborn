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

    // Check cache with priority: Local → Firebase → null
    final cachedData = await _cache.getGrammarFromCache(sentence);
    
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

    // Get provider with fallback
    final provider = await AIProviderFactory.createProviderWithFallback();

    try {
      final response = await AIErrorHandler.withRetry(
        () => provider.explainGrammar(sentence, targetLanguage),
      );

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
      await _cache.saveGrammarToCache(sentence, grammarData);

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

