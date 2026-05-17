import 'package:flutter/foundation.dart';
import '../config/ai_config.dart';
import '../models/grammar_explanation.dart';
import '../models/grammar_progressive_result.dart';
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
    String episodeId, {
    int? lineNumber,
  }) async {
    if (!AIConfig.enableGrammar) {
      throw APIException('Grammar feature is temporarily disabled.');
    }

    final targetLanguage = _getTargetLanguage();
    final languageCode = _languageManager.currentLocale.languageCode;
    final modelVersion = '${AIConfig.primaryProvider.name}:${AIConfig.geminiModel}:${AIConfig.openaiModel}';
    const promptVersion = AIConfig.grammarPromptVersion;

    await HeartService().consumeForAIFeature();

    // Check cache with priority: Local → Firebase → null
    // [lineNumber] = transcript line index (0-based); RTDB path is line_{index}.
    final cachedData = await _cache.getGrammarFromCache(
      sentence,
      languageCode,
      episodeId: episodeId,
      lineNumber: lineNumber,
      modelVersion: modelVersion,
      promptVersion: promptVersion,
    );
    
    if (cachedData != null) {
      debugPrint('Using cached grammar explanation for sentence');
      return _mapResponseToModel(sentence, cachedData);
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

      final explanationObj = _mapResponseToModel(sentence, response);

      // Save to both local and Firebase cache
      await _cache.saveGrammarToCache(
        sentence,
        languageCode,
        explanationObj.toJson(),
        episodeId: episodeId,
        lineNumber: lineNumber,
        modelVersion: modelVersion,
        promptVersion: promptVersion,
      );

      return explanationObj;
    } catch (e) {
      debugPrint('Error explaining grammar: $e');
      rethrow;
    }
  }

  /// Explain grammar for a full passage with fallback to sentence-level flow
  Future<GrammarExplanation> explainPassage(
    String passage,
    String episodeId,
  ) async {
    final progressive = await explainPassageProgressive(passage, episodeId);
    return await progressive.full;
  }

  /// Progressive passage analysis:
  /// - Call 1: overall (fast) -> return immediately for UI
  /// - Call 2: sentence analyses (slower) -> completes later
  /// IMPORTANT: Only 1 heart is consumed for both calls.
  Future<GrammarPassageProgressiveResult> explainPassageProgressive(
    String passage,
    String episodeId,
  ) async {
    if (!AIConfig.enableGrammar) {
      throw APIException('Grammar feature is temporarily disabled.');
    }

    final normalizedPassage = _normalizePassage(passage);
    if (normalizedPassage.isEmpty) {
      throw InvalidResponseException('Passage is empty');
    }

    final targetLanguage = _getTargetLanguage();
    final languageCode = _languageManager.currentLocale.languageCode;
    final modelVersion =
        '${AIConfig.primaryProvider.name}:${AIConfig.geminiModel}:${AIConfig.openaiModel}';
    // Slim schema (no rewrite/quiz) + progressive mode.
    const promptVersion = '${AIConfig.grammarPromptVersion}_passage_v2_slim_progressive';
    const schemaVersion = '${AIConfig.grammarSchemaVersion}_passage_v2_slim_progressive';

    await HeartService().consumeForAIFeature();

    final cachedData = await _cache.getGrammarPassageFromCache(
      normalizedPassage,
      languageCode,
      episodeId: episodeId,
      modelVersion: modelVersion,
      promptVersion: promptVersion,
      schemaVersion: schemaVersion,
    );
    if (cachedData != null) {
      try {
        final cached = _mapPassageResponseToModel(normalizedPassage, cachedData);
        return GrammarPassageProgressiveResult(
          initial: cached,
          full: Future.value(cached),
        );
      } catch (e) {
        // Cache might contain older/partial schema. Ignore and continue to API/fallback.
        debugPrint('⚠️ Failed to map cached passage grammar, ignoring cache: $e');
      }
    }

    final primaryProvider = AIProviderFactory.getPrimaryProvider();
    final backupProvider = AIProviderFactory.getBackupProvider();

    // Call 1 (overall) - fast with short timeout, no retry.
    final overallMap = await _callPassageOverallFast(
      normalizedPassage,
      targetLanguage,
      primaryProvider: primaryProvider,
      backupProvider: backupProvider,
    );
    final overallOnly = _mapPassageOverallToModel(normalizedPassage, overallMap);

    // Call 2 (sentences) - async continuation, still no extra heart.
    final fullFuture = _callPassageSentencesAndMerge(
      normalizedPassage,
      episodeId,
      languageCode,
      targetLanguage,
      modelVersion: modelVersion,
      promptVersion: promptVersion,
      schemaVersion: schemaVersion,
      primaryProvider: primaryProvider,
      backupProvider: backupProvider,
      overallOnly: overallOnly,
    );

    return GrammarPassageProgressiveResult(initial: overallOnly, full: fullFuture);
  }

  Future<Map<String, dynamic>> _callPassageOverallFast(
    String passage,
    String targetLanguage, {
    required dynamic primaryProvider,
    required dynamic backupProvider,
  }) async {
    try {
      final res = await AIErrorHandler.withRetry(
        () => primaryProvider
            .explainGrammarPassageOverall(passage, targetLanguage)
            .timeout(const Duration(seconds: 7)),
        maxRetries: 0,
      );
      return res;
    } catch (e) {
      if (await backupProvider.isAvailable()) {
        return await backupProvider.explainGrammarPassageOverall(passage, targetLanguage);
      }
      rethrow;
    }
  }

  Future<GrammarExplanation> _callPassageSentencesAndMerge(
    String passage,
    String episodeId,
    String languageCode,
    String targetLanguage, {
    required String modelVersion,
    required String promptVersion,
    required String schemaVersion,
    required dynamic primaryProvider,
    required dynamic backupProvider,
    required GrammarExplanation overallOnly,
  }) async {
    Map<String, dynamic>? sentencesMap;
    try {
      sentencesMap = await AIErrorHandler.withRetry(
        () => primaryProvider
            .explainGrammarPassageSentences(passage, targetLanguage)
            .timeout(const Duration(seconds: 10)),
        maxRetries: 0,
      );
    } catch (e) {
      if (await backupProvider.isAvailable()) {
        sentencesMap = await backupProvider.explainGrammarPassageSentences(passage, targetLanguage);
      }
    }

    if (sentencesMap == null || !_isValidPassageSentencesSchema(sentencesMap)) {
      // Fallback to sentence-level explainSentence (still no extra heart; it will use hearts internally,
      // but we avoid calling it here to honor 1-heart rule for this progressive flow).
      // Return overall-only as "full" to avoid blocking UI.
      return overallOnly;
    }

    final merged = _mergeOverallAndSentences(overallOnly, sentencesMap);
    await _cache.saveGrammarPassageToCache(
      passage,
      languageCode,
      merged.toJson(),
      episodeId: episodeId,
      modelVersion: modelVersion,
      promptVersion: promptVersion,
      schemaVersion: schemaVersion,
    );
    return merged;
  }

  GrammarExplanation _mapPassageOverallToModel(String passage, Map<String, dynamic> response) {
    final overallMap = response['overall'] as Map<String, dynamic>? ?? {};
    final overall = GrammarPassageOverall(
      grammarTheme: overallMap['grammarTheme']?.toString().trim().isNotEmpty == true
          ? overallMap['grammarTheme'].toString().trim()
          : 'Grammar Overview',
      usageSummary: overallMap['usageSummary']?.toString() ?? '',
      keyStructures: (overallMap['keyStructures'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .where((e) => e.trim().isNotEmpty)
              .toList() ??
          [],
    );
    return GrammarExplanation(
      sentence: passage,
      passageText: passage,
      grammarPoint: overall.grammarTheme,
      explanation: overall.usageSummary,
      highlightedWords: const [],
      overall: overall,
      sentenceAnalyses: const [],
      commonMistakes: const [],
    );
  }

  GrammarExplanation _mergeOverallAndSentences(
    GrammarExplanation overallOnly,
    Map<String, dynamic> sentencesMap,
  ) {
    final analyses = (sentencesMap['sentenceAnalyses'] as List<dynamic>? ?? [])
        .whereType<Map<String, dynamic>>()
        .map(GrammarSentenceAnalysis.fromJson)
        .toList();
    final first = analyses.isNotEmpty ? analyses.first : null;
    return GrammarExplanation(
      sentence: overallOnly.sentence,
      passageText: overallOnly.passageText,
      grammarPoint: overallOnly.grammarPoint,
      explanation: overallOnly.explanation,
      highlightedWords: first?.phraseBreakdown.map((e) => e.phrase).toList() ?? const [],
      overall: overallOnly.overall,
      sentenceAnalyses: analyses,
      rulePattern: first?.mainStructure,
      whyThisForm: first?.usageInContext,
      commonMistakes: first?.commonMistakes ?? const [],
    );
  }

  GrammarExplanation _mapResponseToModel(
    String sentence,
    Map<String, dynamic> response,
  ) {
    final grammarPoint =
        response['grammarPoint']?.toString().trim().isNotEmpty == true
            ? response['grammarPoint'].toString().trim()
            : 'Grammar Pattern';
    final explanation = response['explanation']?.toString().trim() ?? '';
    if (explanation.isEmpty) {
      throw InvalidResponseException('Missing grammar explanation content');
    }
    final highlightedWords = (response['highlightedWords'] as List<dynamic>?)
            ?.map((e) => e.toString().trim())
            .where((e) => e.isNotEmpty)
            .toList() ??
        [];
    final commonMistakes = (response['commonMistakes'] as List<dynamic>?)
            ?.map((e) => e.toString().trim())
            .where((e) => e.isNotEmpty)
            .toList() ??
        [];

    return GrammarExplanation(
      sentence: sentence,
      grammarPoint: grammarPoint,
      explanation: explanation,
      highlightedWords: highlightedWords,
      rulePattern: response['rulePattern']?.toString(),
      whyThisForm: response['whyThisForm']?.toString(),
      commonMistakes: commonMistakes,
    );
  }

  GrammarExplanation _mapPassageResponseToModel(
    String passage,
    Map<String, dynamic> response,
  ) {
    // Backward-compatible support: if old sentence schema is returned, adapt.
    if (response.containsKey('grammarPoint') && response.containsKey('explanation')) {
      final single = _mapResponseToModel(passage, response);
      return GrammarExplanation(
        sentence: single.sentence,
        passageText: passage,
        grammarPoint: single.grammarPoint,
        explanation: single.explanation,
        highlightedWords: single.highlightedWords,
        overall: GrammarPassageOverall(
          grammarTheme: single.grammarPoint,
          usageSummary: single.explanation,
          keyStructures: [
            if ((single.rulePattern ?? '').trim().isNotEmpty) single.rulePattern!.trim(),
          ],
        ),
        sentenceAnalyses: [
          GrammarSentenceAnalysis(
            sentenceText: passage,
            mainStructure: single.rulePattern ?? '',
            usageInContext: single.whyThisForm ?? single.explanation,
            phraseBreakdown: single.highlightedWords
                .map(
                  (w) => GrammarPhraseAnalysis(phrase: w, structure: '', usage: ''),
                )
                .toList(),
            commonMistakes: single.commonMistakes,
            rewriteExercise: '',
          ),
        ],
        rulePattern: single.rulePattern,
        whyThisForm: single.whyThisForm,
        commonMistakes: single.commonMistakes,
      );
    }

    final overallMap = response['overall'] as Map<String, dynamic>? ?? {};
    final overall = GrammarPassageOverall(
      grammarTheme: overallMap['grammarTheme']?.toString() ?? 'Grammar Overview',
      usageSummary: overallMap['usageSummary']?.toString() ?? '',
      keyStructures: (overallMap['keyStructures'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          [],
    );
    final analyses = (response['sentenceAnalyses'] as List<dynamic>? ?? [])
        .whereType<Map<String, dynamic>>()
        .map(GrammarSentenceAnalysis.fromJson)
        .toList();

    final firstAnalysis = analyses.isNotEmpty ? analyses.first : null;
    return GrammarExplanation(
      sentence: passage,
      passageText: passage,
      grammarPoint: overall.grammarTheme,
      explanation: overall.usageSummary,
      highlightedWords: firstAnalysis?.phraseBreakdown.map((e) => e.phrase).toList() ?? const [],
      overall: overall,
      sentenceAnalyses: analyses,
      rulePattern: firstAnalysis?.mainStructure,
      whyThisForm: firstAnalysis?.usageInContext,
      commonMistakes: firstAnalysis?.commonMistakes ?? const [],
    );
  }

  bool _isValidPassageSentencesSchema(Map<String, dynamic> response) {
    final analyses = response['sentenceAnalyses'];
    return analyses is List && analyses.isNotEmpty;
  }

  // Legacy fallback kept for potential future use (not used in progressive flow).
  // ignore: unused_element
  Future<GrammarExplanation> _fallbackPassageFromSentences(
    String passage,
    String episodeId,
  ) async {
    final parts = _splitPassageIntoSentences(passage);
    final analyses = <GrammarSentenceAnalysis>[];
    for (final part in parts) {
      if (part.trim().isEmpty) continue;
      try {
        final explained = await explainSentence(part, episodeId);
        analyses.add(
          GrammarSentenceAnalysis(
            sentenceText: part,
            mainStructure: explained.rulePattern ?? explained.grammarPoint,
            usageInContext: explained.whyThisForm ?? explained.explanation,
            phraseBreakdown: explained.highlightedWords
                .map((w) => GrammarPhraseAnalysis(phrase: w, structure: '', usage: ''))
                .toList(),
            examples: const [],
            commonMistakes: explained.commonMistakes,
            rewriteExercise: '',
          ),
        );
      } catch (_) {
        // Skip failing sentence and continue fallback merge.
      }
    }

    final overviewText = analyses.isEmpty
        ? 'No detailed analysis available.'
        : 'This passage contains ${analyses.length} sentence-level grammar points.';
    return GrammarExplanation(
      sentence: passage,
      passageText: passage,
      grammarPoint: 'Passage Grammar',
      explanation: overviewText,
      highlightedWords: const [],
      overall: GrammarPassageOverall(
        grammarTheme: 'Passage Grammar',
        usageSummary: overviewText,
        keyStructures: analyses.map((a) => a.mainStructure).where((e) => e.trim().isNotEmpty).take(4).toList(),
      ),
      sentenceAnalyses: analyses,
      commonMistakes: analyses.expand((a) => a.commonMistakes).take(3).toList(),
    );
  }

  String _normalizePassage(String input) {
    final squashed = input.replaceAll(RegExp(r'\s+'), ' ').trim();
    if (squashed.length <= 1200) return squashed;
    return squashed.substring(0, 1200).trim();
  }

  List<String> _splitPassageIntoSentences(String passage) {
    return passage
        .split(RegExp(r'(?<=[.!?])\s+'))
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty)
        .toList();
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

