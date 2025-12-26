/// Model for grammar explanation
class GrammarExplanation {
  final String sentence;
  final String grammarPoint; // e.g., "Present Perfect"
  final String explanation;
  final List<String> highlightedWords; // Words to highlight
  final int? startIndex; // Position in transcript (optional)
  final int? endIndex; // Position in transcript (optional)

  GrammarExplanation({
    required this.sentence,
    required this.grammarPoint,
    required this.explanation,
    required this.highlightedWords,
    this.startIndex,
    this.endIndex,
  });

  Map<String, dynamic> toJson() {
    return {
      'sentence': sentence,
      'grammarPoint': grammarPoint,
      'explanation': explanation,
      'highlightedWords': highlightedWords,
      'startIndex': startIndex,
      'endIndex': endIndex,
    };
  }

  factory GrammarExplanation.fromJson(Map<String, dynamic> json) {
    return GrammarExplanation(
      sentence: json['sentence'] ?? '',
      grammarPoint: json['grammarPoint'] ?? '',
      explanation: json['explanation'] ?? '',
      highlightedWords: (json['highlightedWords'] as List<dynamic>?)
          ?.map((e) => e.toString())
          .toList() ?? [],
      startIndex: json['startIndex'],
      endIndex: json['endIndex'],
    );
  }
}

