enum VocabularyPracticeOutcome {
  gotIt,
  stillLearning,
}

class VocabularyPracticeState {
  final String key;
  final int repetitions;
  final int intervalDays;
  final double easeFactor;
  final DateTime? nextReviewAt;
  final DateTime? lastReviewedAt;
  final VocabularyPracticeOutcome? lastOutcome;

  const VocabularyPracticeState({
    required this.key,
    this.repetitions = 0,
    this.intervalDays = 0,
    this.easeFactor = 2.5,
    this.nextReviewAt,
    this.lastReviewedAt,
    this.lastOutcome,
  });

  VocabularyPracticeState copyWith({
    int? repetitions,
    int? intervalDays,
    double? easeFactor,
    DateTime? nextReviewAt,
    bool clearNextReviewAt = false,
    DateTime? lastReviewedAt,
    bool clearLastReviewedAt = false,
    VocabularyPracticeOutcome? lastOutcome,
    bool clearLastOutcome = false,
  }) {
    return VocabularyPracticeState(
      key: key,
      repetitions: repetitions ?? this.repetitions,
      intervalDays: intervalDays ?? this.intervalDays,
      easeFactor: easeFactor ?? this.easeFactor,
      nextReviewAt: clearNextReviewAt ? null : (nextReviewAt ?? this.nextReviewAt),
      lastReviewedAt:
          clearLastReviewedAt ? null : (lastReviewedAt ?? this.lastReviewedAt),
      lastOutcome: clearLastOutcome ? null : (lastOutcome ?? this.lastOutcome),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'key': key,
      'repetitions': repetitions,
      'intervalDays': intervalDays,
      'easeFactor': easeFactor,
      'nextReviewAt': nextReviewAt?.toUtc().toIso8601String(),
      'lastReviewedAt': lastReviewedAt?.toUtc().toIso8601String(),
      'lastOutcome': lastOutcome?.name,
    };
  }

  static VocabularyPracticeState fromJson(Map<String, dynamic> json) {
    VocabularyPracticeOutcome? parseOutcome(dynamic value) {
      if (value == null) return null;
      final raw = value.toString();
      for (final outcome in VocabularyPracticeOutcome.values) {
        if (outcome.name == raw) return outcome;
      }
      return null;
    }

    DateTime? parseTime(dynamic value) {
      if (value == null) return null;
      return DateTime.tryParse(value.toString())?.toUtc();
    }

    return VocabularyPracticeState(
      key: json['key']?.toString() ?? '',
      repetitions: (json['repetitions'] as num?)?.toInt() ?? 0,
      intervalDays: (json['intervalDays'] as num?)?.toInt() ?? 0,
      easeFactor: (json['easeFactor'] as num?)?.toDouble() ?? 2.5,
      nextReviewAt: parseTime(json['nextReviewAt']),
      lastReviewedAt: parseTime(json['lastReviewedAt']),
      lastOutcome: parseOutcome(json['lastOutcome']),
    );
  }
}
