import 'dart:convert';

/// Dual-map passage grammar JSON for Flutter + legacy sentence fields.
/// Matches playMP3 [ToFlutterGrammarPassageData] / functions `toFlutterGrammarPassageData`.
Map<String, dynamic> toFlutterGrammarPassageData(
  Map<String, dynamic> apiResponse,
  String passage,
) {
  final overallRaw = apiResponse['overall'];
  final overall = overallRaw is Map
      ? Map<String, dynamic>.from(overallRaw)
      : <String, dynamic>{};

  var theme = overall['grammarTheme']?.toString().trim() ?? '';
  if (theme.isEmpty) theme = 'Grammar Overview';
  var usage = overall['usageSummary']?.toString().trim() ?? '';
  if (usage.isEmpty) usage = theme; // old apps require non-empty explanation
  overall['grammarTheme'] = theme;
  overall['usageSummary'] = usage;
  if (overall['keyStructures'] is! List) {
    overall['keyStructures'] = <dynamic>[];
  }

  final analysesRaw = apiResponse['sentenceAnalyses'];
  final analyses = analysesRaw is List ? List<dynamic>.from(analysesRaw) : <dynamic>[];

  Map<String, dynamic>? first;
  if (analyses.isNotEmpty && analyses.first is Map) {
    first = Map<String, dynamic>.from(analyses.first as Map);
  }

  final highlighted = <String>[];
  final commonMistakes = <String>[];
  if (first != null) {
    final phrases = first['phraseBreakdown'];
    if (phrases is List) {
      for (final p in phrases) {
        if (p is! Map) continue;
        final phrase = p['phrase']?.toString().trim() ?? '';
        if (phrase.isNotEmpty) highlighted.add(phrase);
      }
    }
    final mistakes = first['commonMistakes'];
    if (mistakes is List) {
      for (final m in mistakes) {
        final s = m?.toString().trim() ?? '';
        if (s.isNotEmpty) commonMistakes.add(s);
      }
    }
  }

  return {
    'sentence': passage,
    'passageText': passage,
    'grammarPoint': theme,
    'explanation': usage,
    'highlightedWords': highlighted,
    'overall': overall,
    'sentenceAnalyses': analyses,
    'rulePattern': first?['mainStructure']?.toString() ?? '',
    'whyThisForm': first?['usageInContext']?.toString() ?? '',
    'commonMistakes': commonMistakes,
  };
}

String buildTranslateGrammarPassageJsonPrompt(
  Map<String, dynamic> englishJson,
  String targetLanguage,
) {
  return '''
Translate the LEARNER-FACING fields of this English grammar JSON into $targetLanguage.
You MUST return ONLY a valid JSON object with the SAME schema and the SAME array lengths.

KEEP these fields EXACTLY as in the input (English quotes from the transcript):
- sentence, passageText, sentenceText
- highlightedWords (array of exact fragments)
- phrase (inside each phraseBreakdown item)
- examples (keep English example sentences)

TRANSLATE into $targetLanguage:
- grammarPoint, explanation, whyThisForm, rulePattern
- overall.grammarTheme, overall.usageSummary, overall.keyStructures
- mainStructure, usageInContext, structure, usage
- commonMistakes, rewriteExercise

Do not add or remove sentenceAnalyses or phraseBreakdown items.
Do not invent new quotes from the transcript.

English JSON:
${_jsonEncodeStable(englishJson)}

JSON object only:''';
}

/// Copy transcript quotes from canonical English JSON onto a translation.
Map<String, dynamic> preserveGrammarQuotesFromEnglish(
  Map<String, dynamic> english,
  Map<String, dynamic> translated,
) {
  final result = Map<String, dynamic>.from(translated);
  for (final key in ['sentence', 'passageText', 'highlightedWords']) {
    if (english.containsKey(key)) {
      result[key] = _deepCopyJson(english[key]);
    }
  }

  final enAnalyses = english['sentenceAnalyses'];
  if (enAnalyses is! List) return result;

  final trRaw = result['sentenceAnalyses'];
  final trAnalyses = trRaw is List ? List<dynamic>.from(trRaw) : <dynamic>[];
  while (trAnalyses.length < enAnalyses.length) {
    trAnalyses.add(_deepCopyJson(enAnalyses[trAnalyses.length]));
  }
  if (trAnalyses.length > enAnalyses.length) {
    trAnalyses.removeRange(enAnalyses.length, trAnalyses.length);
  }

  for (var i = 0; i < enAnalyses.length; i++) {
    final enA = enAnalyses[i];
    if (enA is! Map) continue;
    final enMap = Map<String, dynamic>.from(enA);
    final trItem = trAnalyses[i];
    final trMap = trItem is Map
        ? Map<String, dynamic>.from(trItem)
        : Map<String, dynamic>.from(enMap);
    if (enMap.containsKey('sentenceText')) {
      trMap['sentenceText'] = enMap['sentenceText'];
    }
    if (enMap.containsKey('examples')) {
      trMap['examples'] = _deepCopyJson(enMap['examples']);
    }
    final enPhrases = enMap['phraseBreakdown'];
    if (enPhrases is List) {
      final trPRaw = trMap['phraseBreakdown'];
      final trPhrases = trPRaw is List ? List<dynamic>.from(trPRaw) : <dynamic>[];
      while (trPhrases.length < enPhrases.length) {
        trPhrases.add(_deepCopyJson(enPhrases[trPhrases.length]));
      }
      if (trPhrases.length > enPhrases.length) {
        trPhrases.removeRange(enPhrases.length, trPhrases.length);
      }
      for (var j = 0; j < enPhrases.length; j++) {
        final enPh = enPhrases[j];
        if (enPh is! Map) continue;
        final trPhItem = trPhrases[j];
        final trPh = trPhItem is Map
            ? Map<String, dynamic>.from(trPhItem)
            : Map<String, dynamic>.from(enPh);
        trPh['phrase'] = enPh['phrase'];
        trPhrases[j] = trPh;
      }
      trMap['phraseBreakdown'] = trPhrases;
    }
    trAnalyses[i] = trMap;
  }
  result['sentenceAnalyses'] = trAnalyses;
  return result;
}

dynamic _deepCopyJson(dynamic value) {
  if (value is Map) {
    return value.map((k, v) => MapEntry(k.toString(), _deepCopyJson(v)));
  }
  if (value is List) {
    return value.map(_deepCopyJson).toList();
  }
  return value;
}

String _jsonEncodeStable(Map<String, dynamic> json) {
  return jsonEncode(json);
}
