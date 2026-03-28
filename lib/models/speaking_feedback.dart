class SpeakingFeedback {
  final double overallScore;
  final double pronunciationScore;
  final double fluencyScore;
  final double accuracyScore;
  final String feedback;
  final List<SpeakingMistake> mistakes;

  const SpeakingFeedback({
    required this.overallScore,
    required this.pronunciationScore,
    required this.fluencyScore,
    required this.accuracyScore,
    required this.feedback,
    required this.mistakes,
  });

  factory SpeakingFeedback.fromMap(Map<String, dynamic> map) {
    return SpeakingFeedback(
      overallScore: (map['overallScore'] as num?)?.toDouble() ?? 0,
      pronunciationScore: (map['pronunciationScore'] as num?)?.toDouble() ?? 0,
      fluencyScore: (map['fluencyScore'] as num?)?.toDouble() ?? 0,
      accuracyScore: (map['accuracyScore'] as num?)?.toDouble() ?? 0,
      feedback: map['feedback']?.toString() ?? '',
      mistakes: (map['mistakes'] as List<dynamic>?)
              ?.map((e) => SpeakingMistake.fromMap(
                    (e as Map).cast<String, dynamic>(),
                  ))
              .toList() ??
          const [],
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'overallScore': overallScore,
      'pronunciationScore': pronunciationScore,
      'fluencyScore': fluencyScore,
      'accuracyScore': accuracyScore,
      'feedback': feedback,
      'mistakes': mistakes.map((m) => m.toMap()).toList(),
    };
  }
}

class SpeakingMistake {
  final String expected;
  final String spoken;
  final String note;

  const SpeakingMistake({
    required this.expected,
    required this.spoken,
    required this.note,
  });

  factory SpeakingMistake.fromMap(Map<String, dynamic> map) {
    return SpeakingMistake(
      expected: map['expected']?.toString() ?? '',
      spoken: map['spoken']?.toString() ?? '',
      note: map['note']?.toString() ?? '',
    );
  }

  Map<String, dynamic> toMap() => {
        'expected': expected,
        'spoken': spoken,
        'note': note,
      };
}
