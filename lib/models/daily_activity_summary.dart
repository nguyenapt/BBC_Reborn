class DailyActivitySummary {
  final int listeningMs;
  final int vocabReviews;
  final int grammarReviews;
  final int speakingAttempts;
  final double speakingScoreSum;

  const DailyActivitySummary({
    this.listeningMs = 0,
    this.vocabReviews = 0,
    this.grammarReviews = 0,
    this.speakingAttempts = 0,
    this.speakingScoreSum = 0,
  });

  double get speakingAverage =>
      speakingAttempts > 0 ? speakingScoreSum / speakingAttempts : 0;

  DailyActivitySummary copyWith({
    int? listeningMs,
    int? vocabReviews,
    int? grammarReviews,
    int? speakingAttempts,
    double? speakingScoreSum,
  }) {
    return DailyActivitySummary(
      listeningMs: listeningMs ?? this.listeningMs,
      vocabReviews: vocabReviews ?? this.vocabReviews,
      grammarReviews: grammarReviews ?? this.grammarReviews,
      speakingAttempts: speakingAttempts ?? this.speakingAttempts,
      speakingScoreSum: speakingScoreSum ?? this.speakingScoreSum,
    );
  }

  Map<String, dynamic> toJson() => {
        'listeningMs': listeningMs,
        'vocabReviews': vocabReviews,
        'grammarReviews': grammarReviews,
        'speakingAttempts': speakingAttempts,
        'speakingScoreSum': speakingScoreSum,
      };

  factory DailyActivitySummary.fromJson(Map<String, dynamic> json) {
    return DailyActivitySummary(
      listeningMs: json['listeningMs'] as int? ?? 0,
      vocabReviews: json['vocabReviews'] as int? ?? 0,
      grammarReviews: json['grammarReviews'] as int? ?? 0,
      speakingAttempts: json['speakingAttempts'] as int? ?? 0,
      speakingScoreSum: (json['speakingScoreSum'] as num?)?.toDouble() ?? 0,
    );
  }
}
