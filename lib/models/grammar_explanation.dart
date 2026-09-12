/// Model for grammar explanation
class GrammarExplanation {
  final String sentence;
  final String? passageText;
  final String grammarPoint; // e.g., "Present Perfect"
  final String explanation;
  final List<String> highlightedWords; // Words to highlight
  final GrammarPassageOverall? overall;
  final List<GrammarSentenceAnalysis> sentenceAnalyses;
  final String? rulePattern;
  final String? whyThisForm;
  final List<String> commonMistakes;
  final GrammarMiniQuiz? miniQuiz;
  final int? startIndex; // Position in transcript (optional)
  final int? endIndex; // Position in transcript (optional)

  GrammarExplanation({
    required this.sentence,
    this.passageText,
    required this.grammarPoint,
    required this.explanation,
    required this.highlightedWords,
    this.overall,
    this.sentenceAnalyses = const [],
    this.rulePattern,
    this.whyThisForm,
    this.commonMistakes = const [],
    this.miniQuiz,
    this.startIndex,
    this.endIndex,
  });

  Map<String, dynamic> toJson() {
    return {
      'sentence': sentence,
      'passageText': passageText,
      'grammarPoint': grammarPoint,
      'explanation': explanation,
      'highlightedWords': highlightedWords,
      'overall': overall?.toJson(),
      'sentenceAnalyses': sentenceAnalyses.map((e) => e.toJson()).toList(),
      'rulePattern': rulePattern,
      'whyThisForm': whyThisForm,
      'commonMistakes': commonMistakes,
      'miniQuiz': miniQuiz?.toJson(),
      'startIndex': startIndex,
      'endIndex': endIndex,
    };
  }

  factory GrammarExplanation.fromJson(Map<String, dynamic> json) {
    return GrammarExplanation(
      sentence: json['sentence'] ?? '',
      passageText: json['passageText']?.toString(),
      grammarPoint: json['grammarPoint'] ?? '',
      explanation: json['explanation'] ?? '',
      highlightedWords: (json['highlightedWords'] as List<dynamic>?)
          ?.map((e) => e.toString())
          .toList() ?? [],
      overall: json['overall'] is Map<String, dynamic>
          ? GrammarPassageOverall.fromJson(json['overall'])
          : null,
      sentenceAnalyses: (json['sentenceAnalyses'] as List<dynamic>?)
              ?.whereType<Map<String, dynamic>>()
              .map(GrammarSentenceAnalysis.fromJson)
              .toList() ??
          [],
      rulePattern: json['rulePattern']?.toString(),
      whyThisForm: json['whyThisForm']?.toString(),
      commonMistakes: (json['commonMistakes'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          [],
      miniQuiz: json['miniQuiz'] is Map<String, dynamic>
          ? GrammarMiniQuiz.fromJson(json['miniQuiz'])
          : null,
      startIndex: json['startIndex'],
      endIndex: json['endIndex'],
    );
  }

  bool get isPassageMode => overall != null || sentenceAnalyses.isNotEmpty;
}

/// Result of opening a transcript-line grammar explanation.
class GrammarSentenceResolveResult {
  final GrammarExplanation explanation;
  final String displayLanguageCode;
  final bool englishAvailable;
  final bool targetAvailable;

  const GrammarSentenceResolveResult({
    required this.explanation,
    required this.displayLanguageCode,
    required this.englishAvailable,
    required this.targetAvailable,
  });
}

/// Chooses which grammar locale to show when opening the popup.
class GrammarOpenPolicy {
  static const englishCode = 'en';

  static String displayLanguageCode({
    required String targetLanguageCode,
    required bool englishAvailable,
    required bool targetAvailable,
  }) {
    if (targetLanguageCode == englishCode) {
      return englishCode;
    }
    if (targetAvailable) return targetLanguageCode;
    if (englishAvailable) return englishCode;
    return targetLanguageCode;
  }

  /// Segmented switcher: English (if cached) + target. Hidden when only one option.
  static bool showLanguageSwitcher({
    required String targetLanguageCode,
    required bool englishAvailable,
  }) {
    return targetLanguageCode != englishCode && englishAvailable;
  }
}

class GrammarPassageOverall {
  final String grammarTheme;
  final String usageSummary;
  final List<String> keyStructures;

  GrammarPassageOverall({
    required this.grammarTheme,
    required this.usageSummary,
    this.keyStructures = const [],
  });

  Map<String, dynamic> toJson() {
    return {
      'grammarTheme': grammarTheme,
      'usageSummary': usageSummary,
      'keyStructures': keyStructures,
    };
  }

  factory GrammarPassageOverall.fromJson(Map<String, dynamic> json) {
    return GrammarPassageOverall(
      grammarTheme: json['grammarTheme']?.toString() ?? '',
      usageSummary: json['usageSummary']?.toString() ?? '',
      keyStructures: (json['keyStructures'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          [],
    );
  }
}

class GrammarSentenceAnalysis {
  final String sentenceText;
  final String mainStructure;
  final String usageInContext;
  final List<GrammarPhraseAnalysis> phraseBreakdown;
  final List<String> examples;
  final List<String> commonMistakes;
  final String? rewriteExercise;
  final GrammarMiniQuiz? miniQuiz;

  GrammarSentenceAnalysis({
    required this.sentenceText,
    required this.mainStructure,
    required this.usageInContext,
    this.phraseBreakdown = const [],
    this.examples = const [],
    this.commonMistakes = const [],
    this.rewriteExercise,
    this.miniQuiz,
  });

  Map<String, dynamic> toJson() {
    return {
      'sentenceText': sentenceText,
      'mainStructure': mainStructure,
      'usageInContext': usageInContext,
      'phraseBreakdown': phraseBreakdown.map((e) => e.toJson()).toList(),
      'examples': examples,
      'commonMistakes': commonMistakes,
      'rewriteExercise': rewriteExercise,
      'miniQuiz': miniQuiz?.toJson(),
    };
  }

  factory GrammarSentenceAnalysis.fromJson(Map<String, dynamic> json) {
    return GrammarSentenceAnalysis(
      sentenceText: json['sentenceText']?.toString() ?? '',
      mainStructure: json['mainStructure']?.toString() ?? '',
      usageInContext: json['usageInContext']?.toString() ?? '',
      phraseBreakdown: (json['phraseBreakdown'] as List<dynamic>?)
              ?.whereType<Map<String, dynamic>>()
              .map(GrammarPhraseAnalysis.fromJson)
              .toList() ??
          [],
      examples: (json['examples'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          [],
      commonMistakes: (json['commonMistakes'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          [],
      rewriteExercise: json['rewriteExercise']?.toString(),
      miniQuiz: json['miniQuiz'] is Map<String, dynamic>
          ? GrammarMiniQuiz.fromJson(json['miniQuiz'])
          : null,
    );
  }
}

class GrammarPhraseAnalysis {
  final String phrase;
  final String structure;
  final String usage;

  GrammarPhraseAnalysis({
    required this.phrase,
    required this.structure,
    required this.usage,
  });

  Map<String, dynamic> toJson() {
    return {
      'phrase': phrase,
      'structure': structure,
      'usage': usage,
    };
  }

  factory GrammarPhraseAnalysis.fromJson(Map<String, dynamic> json) {
    return GrammarPhraseAnalysis(
      phrase: json['phrase']?.toString() ?? '',
      structure: json['structure']?.toString() ?? '',
      usage: json['usage']?.toString() ?? '',
    );
  }
}

class GrammarMiniQuiz {
  final String question;
  final List<String> options;
  final String correctAnswer;
  final String explanation;

  GrammarMiniQuiz({
    required this.question,
    required this.options,
    required this.correctAnswer,
    required this.explanation,
  });

  Map<String, dynamic> toJson() {
    return {
      'question': question,
      'options': options,
      'correctAnswer': correctAnswer,
      'explanation': explanation,
    };
  }

  factory GrammarMiniQuiz.fromJson(Map<String, dynamic> json) {
    return GrammarMiniQuiz(
      question: json['question']?.toString() ?? '',
      options: (json['options'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          [],
      correctAnswer: json['correctAnswer']?.toString() ?? '',
      explanation: json['explanation']?.toString() ?? '',
    );
  }
}

