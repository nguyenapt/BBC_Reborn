class SpeakingSession {
  final String id;
  final String episodeId;
  final String mode; // repeat | roleplay
  final DateTime createdAt;
  final DateTime updatedAt;
  final int totalAttempts;
  final double averageScore;

  SpeakingSession({
    required this.id,
    required this.episodeId,
    required this.mode,
    required this.createdAt,
    required this.updatedAt,
    required this.totalAttempts,
    required this.averageScore,
  });

  SpeakingSession copyWith({
    DateTime? updatedAt,
    int? totalAttempts,
    double? averageScore,
  }) {
    return SpeakingSession(
      id: id,
      episodeId: episodeId,
      mode: mode,
      createdAt: createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      totalAttempts: totalAttempts ?? this.totalAttempts,
      averageScore: averageScore ?? this.averageScore,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'episode_id': episodeId,
      'mode': mode,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
      'total_attempts': totalAttempts,
      'average_score': averageScore,
    };
  }

  factory SpeakingSession.fromMap(Map<String, dynamic> map) {
    return SpeakingSession(
      id: map['id']?.toString() ?? '',
      episodeId: map['episode_id']?.toString() ?? '',
      mode: map['mode']?.toString() ?? 'repeat',
      createdAt: DateTime.tryParse(map['created_at']?.toString() ?? '') ??
          DateTime.now(),
      updatedAt: DateTime.tryParse(map['updated_at']?.toString() ?? '') ??
          DateTime.now(),
      totalAttempts: map['total_attempts'] as int? ?? 0,
      averageScore: (map['average_score'] as num?)?.toDouble() ?? 0,
    );
  }
}
