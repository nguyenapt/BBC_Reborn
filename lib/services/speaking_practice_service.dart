import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:record/record.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:uuid/uuid.dart';
import '../models/episode.dart';
import '../models/speaking_attempt.dart';
import '../models/speaking_feedback.dart';
import '../models/speaking_session.dart';
import 'speech_transcription_service.dart';
import 'local_database_service.dart';
import 'speaking_feedback_service.dart';

class SpeakingAttemptResult {
  final SpeakingAttempt attempt;
  final SpeakingFeedback feedback;
  final SpeakingSession updatedSession;

  const SpeakingAttemptResult({
    required this.attempt,
    required this.feedback,
    required this.updatedSession,
  });
}

class SpeakingPracticeService {
  static final SpeakingPracticeService _instance =
      SpeakingPracticeService._internal();
  factory SpeakingPracticeService() => _instance;
  SpeakingPracticeService._internal();

  final AudioRecorder _recorder = AudioRecorder();
  final SpeechTranscriptionService _sttService = SpeechTranscriptionService();
  final SpeakingFeedbackService _feedbackService = SpeakingFeedbackService();
  final LocalDatabaseService _db = LocalDatabaseService();
  final Uuid _uuid = const Uuid();

  DateTime? _recordingStartedAt;
  String? _currentRecordingPath;

  Future<bool> requestMicrophonePermission() async {
    final status = await Permission.microphone.request();
    return status.isGranted;
  }

  Future<void> startRecording() async {
    final hasPermission = await requestMicrophonePermission();
    if (!hasPermission) {
      throw Exception('Microphone permission denied');
    }

    final tempDir = await getTemporaryDirectory();
    final fileName = 'speaking_${DateTime.now().millisecondsSinceEpoch}.wav';
    final path = '${tempDir.path}/$fileName';

    _recordingStartedAt = DateTime.now();
    _currentRecordingPath = path;

    await _recorder.start(
      const RecordConfig(
        encoder: AudioEncoder.wav,
        sampleRate: 16000,
        numChannels: 1,
        bitRate: 16000,
      ),
      path: path,
    );
  }

  Future<SpeakingAttemptResult> stopRecordingAndEvaluate({
    required SpeakingSession session,
    required Episode episode,
    required String mode,
    required String lineText,
    int? lineIndex,
    String? speaker,
    String language = 'en-US',
  }) async {
    final path = await _recorder.stop();
    final recordingPath = path ?? _currentRecordingPath;

    if (recordingPath == null) {
      throw Exception('Recording not found');
    }

    final durationMs = _calculateDurationMs();
    final recognizedText =
        await _sttService.transcribeWavFile(recordingPath, language: language);
    final feedback = await _feedbackService.evaluateSpeech(
      referenceText: lineText,
      spokenText: recognizedText,
      language: language,
    );

    final attempt = SpeakingAttempt(
      id: _uuid.v4(),
      sessionId: session.id,
      episodeId: episode.id ?? '',
      mode: mode,
      lineIndex: lineIndex,
      speaker: speaker,
      lineText: lineText,
      recognizedText: recognizedText,
      score: feedback.overallScore,
      feedback: feedback.feedback,
      durationMs: durationMs,
      createdAt: DateTime.now(),
    );

    await _db.insertSpeakingAttempt(attempt);

    final updatedSession = _updateSessionStats(session, feedback.overallScore);
    await _db.updateSpeakingSession(updatedSession);

    _cleanupRecording(recordingPath);

    return SpeakingAttemptResult(
      attempt: attempt,
      feedback: feedback,
      updatedSession: updatedSession,
    );
  }

  Future<SpeakingSession> startSession({
    required Episode episode,
    required String mode,
  }) async {
    final session = SpeakingSession(
      id: _uuid.v4(),
      episodeId: episode.id ?? '',
      mode: mode,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
      totalAttempts: 0,
      averageScore: 0,
    );

    await _db.insertSpeakingSession(session);
    return session;
  }

  int _calculateDurationMs() {
    final started = _recordingStartedAt;
    if (started == null) {
      return 0;
    }
    return DateTime.now().difference(started).inMilliseconds;
  }

  SpeakingSession _updateSessionStats(SpeakingSession session, double newScore) {
    final totalAttempts = session.totalAttempts + 1;
    final double totalScore =
        (session.averageScore * session.totalAttempts) + newScore;
    final double averageScore =
        totalAttempts > 0 ? totalScore / totalAttempts : 0.0;

    return session.copyWith(
      updatedAt: DateTime.now(),
      totalAttempts: totalAttempts,
      averageScore: averageScore,
    );
  }

  void _cleanupRecording(String path) {
    try {
      final file = File(path);
      if (file.existsSync()) {
        file.deleteSync();
      }
    } catch (e) {
      debugPrint('Error cleaning up recording file: $e');
    }
  }
}
