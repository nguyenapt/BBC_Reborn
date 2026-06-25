class SpeakingReviewItem {
  final String id;
  final String episodeId;
  final String episodeTitle;
  final String lineText;
  final int? lineIndex;
  final String mode;
  final double lastScore;
  final int reviewStage;
  final int reviewCount;
  final DateTime? nextReviewAt;
  final DateTime lastAttemptAt;

  const SpeakingReviewItem({
    required this.id,
    required this.episodeId,
    required this.episodeTitle,
    required this.lineText,
    required this.lastScore,
    required this.reviewStage,
    required this.reviewCount,
    required this.lastAttemptAt,
    this.lineIndex,
    this.mode = 'repeat',
    this.nextReviewAt,
  });

  bool get isDue {
    final next = nextReviewAt;
    if (next == null) return false;
    return !next.isAfter(DateTime.now());
  }

  SpeakingReviewItem copyWith({
    String? episodeTitle,
    double? lastScore,
    int? reviewStage,
    int? reviewCount,
    DateTime? nextReviewAt,
    DateTime? lastAttemptAt,
  }) {
    return SpeakingReviewItem(
      id: id,
      episodeId: episodeId,
      episodeTitle: episodeTitle ?? this.episodeTitle,
      lineText: lineText,
      lineIndex: lineIndex,
      mode: mode,
      lastScore: lastScore ?? this.lastScore,
      reviewStage: reviewStage ?? this.reviewStage,
      reviewCount: reviewCount ?? this.reviewCount,
      nextReviewAt: nextReviewAt ?? this.nextReviewAt,
      lastAttemptAt: lastAttemptAt ?? this.lastAttemptAt,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'episodeId': episodeId,
        'episodeTitle': episodeTitle,
        'lineText': lineText,
        'lineIndex': lineIndex,
        'mode': mode,
        'lastScore': lastScore,
        'reviewStage': reviewStage,
        'reviewCount': reviewCount,
        'nextReviewAt': nextReviewAt?.toIso8601String(),
        'lastAttemptAt': lastAttemptAt.toIso8601String(),
      };

  factory SpeakingReviewItem.fromJson(Map<String, dynamic> json) {
    return SpeakingReviewItem(
      id: json['id']?.toString() ?? '',
      episodeId: json['episodeId']?.toString() ?? '',
      episodeTitle: json['episodeTitle']?.toString() ?? '',
      lineText: json['lineText']?.toString() ?? '',
      lineIndex: json['lineIndex'] as int?,
      mode: json['mode']?.toString() ?? 'repeat',
      lastScore: (json['lastScore'] as num?)?.toDouble() ?? 0,
      reviewStage: json['reviewStage'] as int? ?? 0,
      reviewCount: json['reviewCount'] as int? ?? 0,
      nextReviewAt: DateTime.tryParse(json['nextReviewAt']?.toString() ?? ''),
      lastAttemptAt: DateTime.tryParse(json['lastAttemptAt']?.toString() ?? '') ??
          DateTime.now(),
    );
  }
}
