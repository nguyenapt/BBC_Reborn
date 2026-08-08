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
