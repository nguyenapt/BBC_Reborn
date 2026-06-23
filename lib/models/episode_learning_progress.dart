class EpisodeLearningProgress {
  final String episodeId;
  final String episodeTitle;
  final String category;
  final String? thumbImage;
  final int lastPositionMs;
  final int totalDurationMs;
  final int lastTabIndex;
  final bool listenedComplete;
  final bool transcriptViewed;
  final bool vocabViewed;
  final bool questionsViewed;
  final bool speakingDone;
  final DateTime lastOpenedAt;

  const EpisodeLearningProgress({
    required this.episodeId,
    required this.episodeTitle,
    required this.category,
    this.thumbImage,
    this.lastPositionMs = 0,
    this.totalDurationMs = 0,
    this.lastTabIndex = 0,
    this.listenedComplete = false,
    this.transcriptViewed = false,
    this.vocabViewed = false,
    this.questionsViewed = false,
    this.speakingDone = false,
    required this.lastOpenedAt,
  });

  int get checklistCompletedCount {
    var count = 0;
    if (listenedComplete || _listenProgressRatio >= 0.85) count++;
    if (transcriptViewed) count++;
    if (vocabViewed) count++;
    if (questionsViewed || speakingDone) count++;
    return count;
  }

  static const int checklistTotal = 4;

  double get checklistRatio =>
      checklistTotal == 0 ? 0 : checklistCompletedCount / checklistTotal;

  double get _listenProgressRatio {
    if (totalDurationMs <= 0) return 0;
    return (lastPositionMs / totalDurationMs).clamp(0.0, 1.0);
  }

  double get listenProgressRatio =>
      listenedComplete ? 1.0 : _listenProgressRatio;

  bool get isInProgress =>
      lastPositionMs > 5000 ||
      (checklistCompletedCount > 0 && checklistCompletedCount < checklistTotal);

  bool get shouldShowProgressRing => isInProgress;

  double get ringProgressValue => checklistCompletedCount > 0
      ? checklistRatio
      : listenProgressRatio;

  Map<String, dynamic> toJson() => {
        'episodeId': episodeId,
        'episodeTitle': episodeTitle,
        'category': category,
        'thumbImage': thumbImage,
        'lastPositionMs': lastPositionMs,
        'totalDurationMs': totalDurationMs,
        'lastTabIndex': lastTabIndex,
        'listenedComplete': listenedComplete,
        'transcriptViewed': transcriptViewed,
        'vocabViewed': vocabViewed,
        'questionsViewed': questionsViewed,
        'speakingDone': speakingDone,
        'lastOpenedAt': lastOpenedAt.toIso8601String(),
      };

  factory EpisodeLearningProgress.fromJson(Map<String, dynamic> json) {
    return EpisodeLearningProgress(
      episodeId: json['episodeId']?.toString() ?? '',
      episodeTitle: json['episodeTitle']?.toString() ?? '',
      category: json['category']?.toString() ?? '',
      thumbImage: json['thumbImage']?.toString(),
      lastPositionMs: (json['lastPositionMs'] as num?)?.toInt() ?? 0,
      totalDurationMs: (json['totalDurationMs'] as num?)?.toInt() ?? 0,
      lastTabIndex: (json['lastTabIndex'] as num?)?.toInt() ?? 0,
      listenedComplete: json['listenedComplete'] == true,
      transcriptViewed: json['transcriptViewed'] == true,
      vocabViewed: json['vocabViewed'] == true,
      questionsViewed: json['questionsViewed'] == true,
      speakingDone: json['speakingDone'] == true,
      lastOpenedAt: DateTime.tryParse(json['lastOpenedAt']?.toString() ?? '') ??
          DateTime.now(),
    );
  }

  EpisodeLearningProgress copyWith({
    String? episodeId,
    String? episodeTitle,
    String? category,
    String? thumbImage,
    int? lastPositionMs,
    int? totalDurationMs,
    int? lastTabIndex,
    bool? listenedComplete,
    bool? transcriptViewed,
    bool? vocabViewed,
    bool? questionsViewed,
    bool? speakingDone,
    DateTime? lastOpenedAt,
  }) {
    return EpisodeLearningProgress(
      episodeId: episodeId ?? this.episodeId,
      episodeTitle: episodeTitle ?? this.episodeTitle,
      category: category ?? this.category,
      thumbImage: thumbImage ?? this.thumbImage,
      lastPositionMs: lastPositionMs ?? this.lastPositionMs,
      totalDurationMs: totalDurationMs ?? this.totalDurationMs,
      lastTabIndex: lastTabIndex ?? this.lastTabIndex,
      listenedComplete: listenedComplete ?? this.listenedComplete,
      transcriptViewed: transcriptViewed ?? this.transcriptViewed,
      vocabViewed: vocabViewed ?? this.vocabViewed,
      questionsViewed: questionsViewed ?? this.questionsViewed,
      speakingDone: speakingDone ?? this.speakingDone,
      lastOpenedAt: lastOpenedAt ?? this.lastOpenedAt,
    );
  }
}

enum LearningActivityType {
  listening,
  vocabReview,
  grammarReview,
  speaking,
}
