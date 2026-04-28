import 'grammar_explanation.dart';

class SavedGrammarItem {
  final String id;
  final String sentence;
  final String grammarPoint;
  final String explanation;
  final List<String> highlightedWords;
  final String? passageText;
  final GrammarPassageOverall? overall;
  final List<GrammarSentenceAnalysis> sentenceAnalyses;
  final String? rulePattern;
  final String? whyThisForm;
  final List<String> commonMistakes;
  final GrammarMiniQuiz? miniQuiz;
  final String episodeId;
  final String episodeName;
  final String category;
  final bool isPinned;
  final int reviewStage;
  final int reviewCount;
  final DateTime? nextReviewAt;
  final DateTime? lastReviewedAt;
  final DateTime createdAt;
  final DateTime lastViewedAt;

  SavedGrammarItem({
    required this.id,
    required this.sentence,
    required this.grammarPoint,
    required this.explanation,
    required this.highlightedWords,
    this.passageText,
    this.overall,
    this.sentenceAnalyses = const [],
    this.rulePattern,
    this.whyThisForm,
    this.commonMistakes = const [],
    this.miniQuiz,
    required this.episodeId,
    required this.episodeName,
    required this.category,
    required this.isPinned,
    this.reviewStage = 0,
    this.reviewCount = 0,
    this.nextReviewAt,
    this.lastReviewedAt,
    required this.createdAt,
    required this.lastViewedAt,
  });

  GrammarExplanation toGrammarExplanation() {
    return GrammarExplanation(
      sentence: sentence,
      grammarPoint: grammarPoint,
      explanation: explanation,
      highlightedWords: highlightedWords,
      passageText: passageText,
      overall: overall,
      sentenceAnalyses: sentenceAnalyses,
      rulePattern: rulePattern,
      whyThisForm: whyThisForm,
      commonMistakes: commonMistakes,
      miniQuiz: miniQuiz,
    );
  }

  SavedGrammarItem copyWith({
    String? id,
    String? sentence,
    String? grammarPoint,
    String? explanation,
    List<String>? highlightedWords,
    String? passageText,
    GrammarPassageOverall? overall,
    List<GrammarSentenceAnalysis>? sentenceAnalyses,
    String? rulePattern,
    String? whyThisForm,
    List<String>? commonMistakes,
    GrammarMiniQuiz? miniQuiz,
    String? episodeId,
    String? episodeName,
    String? category,
    bool? isPinned,
    int? reviewStage,
    int? reviewCount,
    DateTime? nextReviewAt,
    DateTime? lastReviewedAt,
    DateTime? createdAt,
    DateTime? lastViewedAt,
  }) {
    return SavedGrammarItem(
      id: id ?? this.id,
      sentence: sentence ?? this.sentence,
      grammarPoint: grammarPoint ?? this.grammarPoint,
      explanation: explanation ?? this.explanation,
      highlightedWords: highlightedWords ?? this.highlightedWords,
      passageText: passageText ?? this.passageText,
      overall: overall ?? this.overall,
      sentenceAnalyses: sentenceAnalyses ?? this.sentenceAnalyses,
      rulePattern: rulePattern ?? this.rulePattern,
      whyThisForm: whyThisForm ?? this.whyThisForm,
      commonMistakes: commonMistakes ?? this.commonMistakes,
      miniQuiz: miniQuiz ?? this.miniQuiz,
      episodeId: episodeId ?? this.episodeId,
      episodeName: episodeName ?? this.episodeName,
      category: category ?? this.category,
      isPinned: isPinned ?? this.isPinned,
      reviewStage: reviewStage ?? this.reviewStage,
      reviewCount: reviewCount ?? this.reviewCount,
      nextReviewAt: nextReviewAt ?? this.nextReviewAt,
      lastReviewedAt: lastReviewedAt ?? this.lastReviewedAt,
      createdAt: createdAt ?? this.createdAt,
      lastViewedAt: lastViewedAt ?? this.lastViewedAt,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'sentence': sentence,
      'grammarPoint': grammarPoint,
      'explanation': explanation,
      'highlightedWords': highlightedWords,
      'passageText': passageText,
      'overall': overall?.toJson(),
      'sentenceAnalyses': sentenceAnalyses.map((e) => e.toJson()).toList(),
      'rulePattern': rulePattern,
      'whyThisForm': whyThisForm,
      'commonMistakes': commonMistakes,
      'miniQuiz': miniQuiz?.toJson(),
      'episodeId': episodeId,
      'episodeName': episodeName,
      'category': category,
      'isPinned': isPinned,
      'reviewStage': reviewStage,
      'reviewCount': reviewCount,
      'nextReviewAt': nextReviewAt?.toIso8601String(),
      'lastReviewedAt': lastReviewedAt?.toIso8601String(),
      'createdAt': createdAt.toIso8601String(),
      'lastViewedAt': lastViewedAt.toIso8601String(),
    };
  }

  factory SavedGrammarItem.fromJson(Map<String, dynamic> json) {
    return SavedGrammarItem(
      id: json['id']?.toString() ?? '',
      sentence: json['sentence']?.toString() ?? '',
      grammarPoint: json['grammarPoint']?.toString() ?? '',
      explanation: json['explanation']?.toString() ?? '',
      highlightedWords: (json['highlightedWords'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          [],
      passageText: json['passageText']?.toString(),
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
      episodeId: json['episodeId']?.toString() ?? '',
      episodeName: json['episodeName']?.toString() ?? '',
      category: json['category']?.toString() ?? '',
      isPinned: json['isPinned'] == true,
      reviewStage: int.tryParse(json['reviewStage']?.toString() ?? '0') ?? 0,
      reviewCount: int.tryParse(json['reviewCount']?.toString() ?? '0') ?? 0,
      nextReviewAt: DateTime.tryParse(json['nextReviewAt']?.toString() ?? ''),
      lastReviewedAt: DateTime.tryParse(json['lastReviewedAt']?.toString() ?? ''),
      createdAt: DateTime.tryParse(json['createdAt']?.toString() ?? '') ??
          DateTime.now(),
      lastViewedAt: DateTime.tryParse(json['lastViewedAt']?.toString() ?? '') ??
          DateTime.now(),
    );
  }
}
