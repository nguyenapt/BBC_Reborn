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
  final String? feedbackJson;
  final String? userRecordingPath;
  final int? lineStartMs;
  final int? lineEndMs;
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
    this.feedbackJson,
    this.userRecordingPath,
    this.lineStartMs,
    this.lineEndMs,
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
      'feedback_json': feedbackJson,
      'user_recording_path': userRecordingPath,
      'line_start_ms': lineStartMs,
      'line_end_ms': lineEndMs,
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
      feedbackJson: map['feedback_json']?.toString(),
      userRecordingPath: map['user_recording_path']?.toString(),
      lineStartMs: map['line_start_ms'] as int?,
      lineEndMs: map['line_end_ms'] as int?,
      durationMs: map['duration_ms'] as int? ?? 0,
      createdAt: DateTime.tryParse(map['created_at']?.toString() ?? '') ??
          DateTime.now(),
    );
  }
}
