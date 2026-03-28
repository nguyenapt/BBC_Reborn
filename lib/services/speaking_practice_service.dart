import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:record/record.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:uuid/uuid.dart';

import 'speaking_blob_revoke_stub.dart'
    if (dart.library.html) 'speaking_blob_revoke_web.dart'
    if (dart.library.js_interop) 'speaking_blob_revoke_web.dart';
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

  /// Luồng biên độ âm thanh khi đang ghi (dùng cho tự ngắt khi im lặng).
  Stream<Amplitude> onRecordingAmplitudeChanged([
    Duration interval = const Duration(milliseconds: 120),
  ]) =>
      _recorder.onAmplitudeChanged(interval);

  /// Hủy ghi âm và xóa file (khi user đổi câu / thoát).
  Future<void> cancelRecording() async {
    await _recorder.cancel();
    _recordingStartedAt = null;
    _currentRecordingPath = null;
  }

  /// Xóa file WAV đã giữ lại (không qua evaluate).
  void discardRecordingFile(String path) {
    _cleanupRecording(path);
  }

  Future<Uint8List> _readRecordingBytes(String path) async {
    if (kIsWeb && path.startsWith('blob:')) {
      return SpeechTranscriptionService.readWebBlobBytes(path);
    }
    final file = File(path);
    if (!file.existsSync()) {
      throw Exception('Recording not found');
    }
    return file.readAsBytes();
  }

  Future<void> startRecording() async {
    if (kIsWeb) {
      final ok = await _recorder.hasPermission(request: true);
      if (!ok) {
        throw Exception(
          'Microphone permission denied. In Chrome, allow the microphone '
          'for this site (lock icon in the address bar). Use https or localhost.',
        );
      }
      _recordingStartedAt = DateTime.now();
      _currentRecordingPath = null;
      await _recorder.start(
        const RecordConfig(
          encoder: AudioEncoder.wav,
          sampleRate: 48000,
          numChannels: 1,
          bitRate: 128000,
        ),
        path: 'speaking_web.wav',
      );
      return;
    }

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

  /// Dừng mic, giữ file WAV để phân tích sau (tab Repeat — tự ngắt im lặng).
  Future<({String path, int durationMs})> stopRecordingKeepFile() async {
    final durationMs = _calculateDurationMs();
    final path = await _recorder.stop();
    final recordingPath = path ?? _currentRecordingPath;

    if (recordingPath == null) {
      throw Exception('Recording not found');
    }

    _recordingStartedAt = null;
    return (path: recordingPath, durationMs: durationMs);
  }

  Future<SpeakingAttemptResult> evaluateRecordingFile({
    required String recordingPath,
    required int durationMs,
    required SpeakingSession session,
    required Episode episode,
    required String mode,
    required String lineText,
    int? lineIndex,
    String? speaker,
    int? lineStartMs,
    int? lineEndMs,
    String language = 'en-US',
  }) async {
    final attemptId = _uuid.v4();
    final eid = episode.resolvedStorageId;

    final audioBytes = await _readRecordingBytes(recordingPath);

    String? userRecordingPath;
    if (!kIsWeb && !recordingPath.startsWith('blob:')) {
      try {
        final root = await getApplicationDocumentsDirectory();
        final dir = Directory(p.join(root.path, 'speaking_recordings'));
        if (!dir.existsSync()) {
          dir.createSync(recursive: true);
        }
        final dest = p.join(dir.path, '$attemptId.wav');
        await File(recordingPath).copy(dest);
        userRecordingPath = dest;
      } catch (e) {
        debugPrint('Speaking: persist recording failed: $e');
      }
    }

    _cleanupRecording(recordingPath);

    final recognizedText =
        await _sttService.transcribeWavBytes(audioBytes, language: language);
    final feedback = await _feedbackService.evaluateSpeech(
      referenceText: lineText,
      spokenText: recognizedText,
      language: language,
    );

    final feedbackJson = jsonEncode(feedback.toMap());

    final attempt = SpeakingAttempt(
      id: attemptId,
      sessionId: session.id,
      episodeId: eid,
      mode: mode,
      lineIndex: lineIndex,
      speaker: speaker,
      lineText: lineText,
      recognizedText: recognizedText,
      score: feedback.overallScore,
      feedback: feedback.feedback,
      feedbackJson: feedbackJson,
      userRecordingPath: userRecordingPath,
      lineStartMs: lineStartMs,
      lineEndMs: lineEndMs,
      durationMs: durationMs,
      createdAt: DateTime.now(),
    );

    await _db.insertSpeakingAttempt(attempt);

    final updatedSession = _updateSessionStats(session, feedback.overallScore);
    await _db.updateSpeakingSession(updatedSession);

    return SpeakingAttemptResult(
      attempt: attempt,
      feedback: feedback,
      updatedSession: updatedSession,
    );
  }

  Future<SpeakingAttemptResult> stopRecordingAndEvaluate({
    required SpeakingSession session,
    required Episode episode,
    required String mode,
    required String lineText,
    int? lineIndex,
    String? speaker,
    int? lineStartMs,
    int? lineEndMs,
    String language = 'en-US',
  }) async {
    final durationMs = _calculateDurationMs();
    final path = await _recorder.stop();
    final recordingPath = path ?? _currentRecordingPath;

    if (recordingPath == null) {
      throw Exception('Recording not found');
    }

    _recordingStartedAt = null;

    return evaluateRecordingFile(
      recordingPath: recordingPath,
      durationMs: durationMs,
      session: session,
      episode: episode,
      mode: mode,
      lineText: lineText,
      lineIndex: lineIndex,
      speaker: speaker,
      lineStartMs: lineStartMs,
      lineEndMs: lineEndMs,
      language: language,
    );
  }

  Future<SpeakingSession> startSession({
    required Episode episode,
    required String mode,
  }) async {
    await _db.upsertEpisode(episode);
    final eid = episode.resolvedStorageId;
    final session = SpeakingSession(
      id: _uuid.v4(),
      episodeId: eid,
      episodeTitle: episode.episodeName,
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
      if (kIsWeb && path.startsWith('blob:')) {
        revokeSpeakingBlobUrl(path);
        return;
      }
      final file = File(path);
      if (file.existsSync()) {
        file.deleteSync();
      }
    } catch (e) {
      debugPrint('Error cleaning up recording file: $e');
    }
  }
}
