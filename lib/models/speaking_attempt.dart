class SpeakingAttempt {
  final String id;
  final String sessionId;
  final String episodeId;
  final String mode; // repeat | roleplay
  final int? lineIndex;
  final String? speaker;
  final String lineText;
  final String recognizedText;
  final double score;
  final String feedback;
  final int durationMs;
  final DateTime createdAt;

  SpeakingAttempt({
    required this.id,
    required this.sessionId,
    required this.episodeId,
    required this.mode,
    required this.lineText,
    required this.recognizedText,
    required this.score,
    required this.feedback,
    required this.durationMs,
    required this.createdAt,
    this.lineIndex,
    this.speaker,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'session_id': sessionId,
      'episode_id': episodeId,
      'mode': mode,
      'line_index': lineIndex,
      'speaker': speaker,
      'line_text': lineText,
      'recognized_text': recognizedText,
      'score': score,
      'feedback': feedback,
      'duration_ms': durationMs,
      'created_at': createdAt.toIso8601String(),
    };
  }

  factory SpeakingAttempt.fromMap(Map<String, dynamic> map) {
    return SpeakingAttempt(
      id: map['id']?.toString() ?? '',
      sessionId: map['session_id']?.toString() ?? '',
      episodeId: map['episode_id']?.toString() ?? '',
      mode: map['mode']?.toString() ?? 'repeat',
      lineIndex: map['line_index'] as int?,
      speaker: map['speaker']?.toString(),
      lineText: map['line_text']?.toString() ?? '',
      recognizedText: map['recognized_text']?.toString() ?? '',
      score: (map['score'] as num?)?.toDouble() ?? 0,
      feedback: map['feedback']?.toString() ?? '',
      durationMs: map['duration_ms'] as int? ?? 0,
      createdAt: DateTime.tryParse(map['created_at']?.toString() ?? '') ??
          DateTime.now(),
    );
  }
}
