import 'package:flutter/foundation.dart';
import '../config/ai_config.dart';
import '../models/ai_cache_tier.dart';
import '../models/grammar_explanation.dart';
import '../models/grammar_progressive_result.dart';
import 'ai/ai_provider_factory.dart';
import 'ai/ai_error_handler.dart';
import 'ai/exceptions.dart';
import 'ai/grammar_passage_dual_map.dart';
import 'ai_cache_service.dart';
import 'language_manager.dart';

/// Service for AI-powered grammar explanation
class AIGrammarService {
  static final AIGrammarService _instance = AIGrammarService._internal();
  factory AIGrammarService() => _instance;
  AIGrammarService._internal();

  final AICacheService _cache = AICacheService();
  final LanguageManager _languageManager = LanguageManager();

  /// Map locale code to English language name for the AI prompt.
  String _getTargetLanguage([String? languageCode]) {
    final code = languageCode ?? _languageManager.currentLocale.languageCode;
    switch (code) {
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

  /// Explain grammar in a sentence.
  ///
  /// Non-English locales translate from a canonical English JSON when possible.
  Future<GrammarExplanation> explainSentence(
    String sentence,
    String episodeId, {
    int? lineNumber,
    String? languageCode,
  }) async {
    if (!AIConfig.enableGrammar) {
      throw APIException('Grammar feature is temporarily disabled.');
    }

    final resolvedLanguageCode =
        languageCode ?? _languageManager.currentLocale.languageCode;
    final modelVersion =
        '${AIConfig.primaryProvider.name}:${AIConfig.geminiModel}:${AIConfig.openaiModel}';
    const promptVersion = AIConfig.grammarPromptVersion;

    if (resolvedLanguageCode == GrammarOpenPolicy.englishCode) {
      return _explainOrGenerateEnglish(
        sentence,
        episodeId,
        lineNumber: lineNumber,
        modelVersion: modelVersion,
        promptVersion: promptVersion,
      );
    }

    final targetHit = await _cache.lookupGrammar(
      sentence,
      resolvedLanguageCode,
      episodeId: episodeId,
      lineNumber: lineNumber,
      modelVersion: modelVersion,
      promptVersion: promptVersion,
    );
    if (targetHit != null) {
      debugPrint('Using cached grammar explanation for sentence');
      return _finalizeGrammarCacheHit(
        sentence: sentence,
        languageCode: resolvedLanguageCode,
        episodeId: episodeId,
        cacheHit: targetHit,
        modelVersion: modelVersion,
        promptVersion: promptVersion,
      );
    }

    final english = await _loadEnglishCanonical(
      sentence,
      episodeId,
      lineNumber: lineNumber,
      modelVersion: modelVersion,
      promptVersion: promptVersion,
    );
    return _translateEnglishAndSave(
      sentence: sentence,
      episodeId: episodeId,
      lineNumber: lineNumber,
      english: english,
      targetLanguageCode: resolvedLanguageCode,
      modelVersion: modelVersion,
      promptVersion: promptVersion,
    );
  }

  /// Open-path: show target if cached, else EN if cached; do not translate until toggle.
  Future<GrammarSentenceResolveResult> resolveSentenceExplanation(
    String sentence,
    String episodeId, {
    int? lineNumber,
  }) async {
    if (!AIConfig.enableGrammar) {
      throw APIException('Grammar feature is temporarily disabled.');
    }

    final targetLang = _languageManager.currentLocale.languageCode;
    final modelVersion =
        '${AIConfig.primaryProvider.name}:${AIConfig.geminiModel}:${AIConfig.openaiModel}';
    const promptVersion = AIConfig.grammarPromptVersion;

    Future<({Map<String, dynamic> data, AICacheTier tier})?> peek(String lang) {
      return _cache.lookupGrammar(
        sentence,
        lang,
        episodeId: episodeId,
        lineNumber: lineNumber,
        modelVersion: modelVersion,
        promptVersion: promptVersion,
      );
    }

    if (targetLang == GrammarOpenPolicy.englishCode) {
      final explanation = await _explainOrGenerateEnglish(
        sentence,
        episodeId,
        lineNumber: lineNumber,
        modelVersion: modelVersion,
        promptVersion: promptVersion,
      );
      return GrammarSentenceResolveResult(
        explanation: explanation,
        displayLanguageCode: GrammarOpenPolicy.englishCode,
        englishAvailable: true,
        targetAvailable: true,
      );
    }

    final peeked = await Future.wait([
      peek(GrammarOpenPolicy.englishCode),
      peek(targetLang),
    ]);
    final enHit = peeked[0];
    final targetHit = peeked[1];

    if (targetHit != null) {
      final explanation = await _finalizeGrammarCacheHit(
        sentence: sentence,
        languageCode: targetLang,
        episodeId: episodeId,
        cacheHit: targetHit,
        modelVersion: modelVersion,
        promptVersion: promptVersion,
      );
      return GrammarSentenceResolveResult(
        explanation: explanation,
        displayLanguageCode: targetLang,
        englishAvailable: enHit != null,
        targetAvailable: true,
      );
    }

    if (enHit != null) {
      final explanation = await _finalizeGrammarCacheHit(
        sentence: sentence,
        languageCode: GrammarOpenPolicy.englishCode,
        episodeId: episodeId,
        cacheHit: enHit,
        modelVersion: modelVersion,
        promptVersion: promptVersion,
      );
      return GrammarSentenceResolveResult(
        explanation: explanation,
        displayLanguageCode: GrammarOpenPolicy.englishCode,
        englishAvailable: true,
        targetAvailable: false,
      );
    }

    final explanation = await _explainOrGenerateEnglish(
      sentence,
      episodeId,
      lineNumber: lineNumber,
      modelVersion: modelVersion,
      promptVersion: promptVersion,
    );
    return GrammarSentenceResolveResult(
      explanation: explanation,
      displayLanguageCode: GrammarOpenPolicy.englishCode,
      englishAvailable: true,
      targetAvailable: false,
    );
  }

  Future<GrammarExplanation> _explainOrGenerateEnglish(
    String sentence,
    String episodeId, {
    int? lineNumber,
    required String modelVersion,
    required String promptVersion,
  }) async {
    final cacheHit = await _cache.lookupGrammar(
      sentence,
      GrammarOpenPolicy.englishCode,
      episodeId: episodeId,
      lineNumber: lineNumber,
      modelVersion: modelVersion,
      promptVersion: promptVersion,
    );
    if (cacheHit != null) {
      debugPrint('Using cached grammar explanation for sentence');
      return _finalizeGrammarCacheHit(
        sentence: sentence,
        languageCode: GrammarOpenPolicy.englishCode,
        episodeId: episodeId,
        cacheHit: cacheHit,
        modelVersion: modelVersion,
        promptVersion: promptVersion,
      );
    }

    await AICacheService.consumeForLiveAi(episodeId: episodeId);
    final response = await _explainPassageSingleWithFallback(sentence, 'English');
    final explanationObj = _mapCachedGrammarToModel(sentence, response);
    await _cache.saveGrammarToCache(
      sentence,
      GrammarOpenPolicy.englishCode,
      explanationObj.toJson(),
      episodeId: episodeId,
      lineNumber: lineNumber,
      modelVersion: modelVersion,
      promptVersion: promptVersion,
    );
    return explanationObj;
  }

  /// Load English JSON without billing when it is only used as a translate source.
  Future<GrammarExplanation> _loadEnglishCanonical(
    String sentence,
    String episodeId, {
    int? lineNumber,
    required String modelVersion,
    required String promptVersion,
  }) async {
    final enHit = await _cache.lookupGrammar(
      sentence,
      GrammarOpenPolicy.englishCode,
      episodeId: episodeId,
      lineNumber: lineNumber,
      modelVersion: modelVersion,
      promptVersion: promptVersion,
    );
    if (enHit != null) {
      return _mapCachedGrammarToModel(sentence, enHit.data);
    }
    return _explainOrGenerateEnglish(
      sentence,
      episodeId,
      lineNumber: lineNumber,
      modelVersion: modelVersion,
      promptVersion: promptVersion,
    );
  }

  Future<GrammarExplanation> _translateEnglishAndSave({
    required String sentence,
    required String episodeId,
    int? lineNumber,
    required GrammarExplanation english,
    required String targetLanguageCode,
    required String modelVersion,
    required String promptVersion,
  }) async {
    await AICacheService.consumeForLiveAi(episodeId: episodeId);
    final targetLanguage = _getTargetLanguage(targetLanguageCode);
    final englishJson = english.toJson();
    final response = await _translateGrammarJsonWithFallback(
      englishJson,
      targetLanguage,
    );
    final merged = preserveGrammarQuotesFromEnglish(englishJson, response);
    final explanationObj = _mapCachedGrammarToModel(sentence, merged);
    await _cache.saveGrammarToCache(
      sentence,
      targetLanguageCode,
      explanationObj.toJson(),
      episodeId: episodeId,
      lineNumber: lineNumber,
      modelVersion: modelVersion,
      promptVersion: promptVersion,
    );
    return explanationObj;
  }

  Future<Map<String, dynamic>> _explainPassageSingleWithFallback(
    String sentence,
    String targetLanguage,
  ) async {
    final primaryProvider = AIProviderFactory.getPrimaryProvider();
    final backupProvider = AIProviderFactory.getBackupProvider();
    try {
      return await AIErrorHandler.withRetry(
        () => primaryProvider.explainGrammarPassageSingle(
          sentence,
          targetLanguage,
        ),
        maxRetries: 1,
      );
    } catch (e) {
      debugPrint('⚠️ Primary provider failed: $e');
      if (e is RateLimitException &&
          e.retryAfter != null &&
          e.retryAfter!.inSeconds > 30) {
        if (await backupProvider.isAvailable()) {
          return backupProvider.explainGrammarPassageSingle(
            sentence,
            targetLanguage,
          );
        }
        rethrow;
      }
      if (e is APIException || e is RateLimitException) {
        if (await backupProvider.isAvailable()) {
          return backupProvider.explainGrammarPassageSingle(
            sentence,
            targetLanguage,
          );
        }
      }
      rethrow;
    }
  }

  Future<Map<String, dynamic>> _translateGrammarJsonWithFallback(
    Map<String, dynamic> englishJson,
    String targetLanguage,
  ) async {
    final primaryProvider = AIProviderFactory.getPrimaryProvider();
    final backupProvider = AIProviderFactory.getBackupProvider();
    try {
      return await AIErrorHandler.withRetry(
        () => primaryProvider.translateGrammarPassageJson(
          englishJson,
          targetLanguage,
        ),
        maxRetries: 1,
      );
    } catch (e) {
      debugPrint('⚠️ Primary provider grammar translate failed: $e');
      if (e is APIException || e is RateLimitException) {
        if (await backupProvider.isAvailable()) {
          return backupProvider.translateGrammarPassageJson(
            englishJson,
            targetLanguage,
          );
        }
      }
      rethrow;
    }
  }

  Future<GrammarExplanation> _finalizeGrammarCacheHit({
    required String sentence,
    required String languageCode,
    required String episodeId,
    required ({Map<String, dynamic> data, AICacheTier tier}) cacheHit,
    required String modelVersion,
    required String promptVersion,
  }) async {
    await AICacheService.consumeHeartIfFirebase(
      cacheHit.tier,
      episodeId: episodeId,
    );
    if (cacheHit.tier == AICacheTier.firebase) {
      await _cache.materializeGrammarLocal(
        sentence,
        languageCode,
        cacheHit.data,
        episodeId: episodeId,
        modelVersion: modelVersion,
        promptVersion: promptVersion,
      );
    }
    return _mapCachedGrammarToModel(sentence, cacheHit.data);
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

    final cacheHit = await _cache.lookupGrammarPassage(
      normalizedPassage,
      languageCode,
      episodeId: episodeId,
      modelVersion: modelVersion,
      promptVersion: promptVersion,
      schemaVersion: schemaVersion,
    );
    if (cacheHit != null) {
      try {
        final cached =
            _mapPassageResponseToModel(normalizedPassage, cacheHit.data);
        await AICacheService.consumeHeartIfFirebase(
          cacheHit.tier,
          episodeId: episodeId,
        );
        if (cacheHit.tier == AICacheTier.firebase) {
          await _cache.materializeGrammarPassageLocal(
            normalizedPassage,
            languageCode,
            cacheHit.data,
            episodeId: episodeId,
            modelVersion: modelVersion,
            promptVersion: promptVersion,
            schemaVersion: schemaVersion,
          );
        }
        return GrammarPassageProgressiveResult(
          initial: cached,
          full: Future.value(cached),
        );
      } catch (e) {
        // Cache might contain older/partial schema. Ignore and continue to API/fallback.
        debugPrint('⚠️ Failed to map cached passage grammar, ignoring cache: $e');
      }
    }

    await AICacheService.consumeForLiveAi(episodeId: episodeId);

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

  /// Cache from playMP3 may be sentence-only or passage dual-map in grammar_by_episode.
  GrammarExplanation _mapCachedGrammarToModel(
    String sentence,
    Map<String, dynamic> response,
  ) {
    if (_hasPassageFields(response)) {
      return _mapPassageResponseToModel(sentence, response);
    }
    return _mapResponseToModel(sentence, response);
  }

  bool _hasPassageFields(Map<String, dynamic> response) {
    final overall = response['overall'];
    if (overall is Map) return true;
    final analyses = response['sentenceAnalyses'];
    return analyses is List && analyses.isNotEmpty;
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
    // Prefer real passage fields (playMP3 dual-map includes both sentence + passage keys).
    if (_hasPassageFields(response)) {
      final overallRaw = response['overall'];
      final overallMap = overallRaw is Map
          ? Map<String, dynamic>.from(overallRaw)
          : <String, dynamic>{};
      final theme = overallMap['grammarTheme']?.toString().trim().isNotEmpty == true
          ? overallMap['grammarTheme'].toString().trim()
          : (response['grammarPoint']?.toString().trim().isNotEmpty == true
              ? response['grammarPoint'].toString().trim()
              : 'Grammar Overview');
      final usage = overallMap['usageSummary']?.toString().trim().isNotEmpty == true
          ? overallMap['usageSummary'].toString().trim()
          : (response['explanation']?.toString().trim() ?? '');
      final overall = GrammarPassageOverall(
        grammarTheme: theme,
        usageSummary: usage,
        keyStructures: (overallMap['keyStructures'] as List<dynamic>?)
                ?.map((e) => e.toString())
                .where((e) => e.trim().isNotEmpty)
                .toList() ??
            [],
      );
      final analyses = (response['sentenceAnalyses'] as List<dynamic>? ?? [])
          .whereType<Map>()
          .map((e) => GrammarSentenceAnalysis.fromJson(Map<String, dynamic>.from(e)))
          .toList();

      final firstAnalysis = analyses.isNotEmpty ? analyses.first : null;
      final explanation = overall.usageSummary.trim().isNotEmpty
          ? overall.usageSummary
          : (response['explanation']?.toString().trim() ?? '');
      if (explanation.isEmpty) {
        throw InvalidResponseException('Missing grammar explanation content');
      }

      return GrammarExplanation(
        sentence: passage,
        passageText: response['passageText']?.toString() ?? passage,
        grammarPoint: overall.grammarTheme,
        explanation: explanation,
        highlightedWords: firstAnalysis?.phraseBreakdown.map((e) => e.phrase).toList() ??
            (response['highlightedWords'] as List<dynamic>?)
                ?.map((e) => e.toString())
                .toList() ??
            const [],
        overall: overall,
        sentenceAnalyses: analyses,
        rulePattern: firstAnalysis?.mainStructure ?? response['rulePattern']?.toString(),
        whyThisForm: firstAnalysis?.usageInContext ?? response['whyThisForm']?.toString(),
        commonMistakes: firstAnalysis?.commonMistakes.isNotEmpty == true
            ? firstAnalysis!.commonMistakes
            : (response['commonMistakes'] as List<dynamic>?)
                    ?.map((e) => e.toString())
                    .toList() ??
                const [],
      );
    }

    // Backward-compatible: sentence schema only → synthesize minimal passage shape.
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

    throw InvalidResponseException('Unrecognized grammar passage response schema');
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

