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
import 'learning_progress_service.dart';
import 'speaking_review_service.dart';
import 'speaking_feedback_service.dart';
import 'audio_player_service.dart';
import 'ai/exceptions.dart';

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
    if (status.isGranted) return true;
    if (!kIsWeb && Platform.isIOS) {
      return _recorder.hasPermission(request: true);
    }
    return false;
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
    if (!kIsWeb && Platform.isIOS) {
      await AudioPlayerService().restoreAfterRecording();
    }
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

    if (!kIsWeb && Platform.isIOS) {
      await AudioPlayerService().prepareForRecording();
    }

    final tempDir = await getTemporaryDirectory();
    final fileName = 'speaking_${DateTime.now().millisecondsSinceEpoch}.wav';
    final path = '${tempDir.path}/$fileName';

    _recordingStartedAt = DateTime.now();
    _currentRecordingPath = path;

    try {
      await _recorder.start(
        const RecordConfig(
          encoder: AudioEncoder.wav,
          sampleRate: 16000,
          numChannels: 1,
          bitRate: 16000,
        ),
        path: path,
      );
    } catch (e) {
      if (!kIsWeb && Platform.isIOS) {
        await AudioPlayerService().restoreAfterRecording();
      }
      rethrow;
    }
  }

  /// Dừng mic, giữ file WAV để phân tích sau (tab Repeat — tự ngắt im lặng).
  Future<({String path, int durationMs})> stopRecordingKeepFile() async {
    final durationMs = _calculateDurationMs();
    String? recordingPath;
    try {
      try {
        if (await _recorder.isRecording()) {
          recordingPath = await _recorder.stop() ?? _currentRecordingPath;
        } else {
          recordingPath = _currentRecordingPath;
        }
      } catch (e) {
        debugPrint('Speaking: recorder.stop failed: $e');
        recordingPath = _currentRecordingPath;
        if (recordingPath == null) rethrow;
      }

      recordingPath = await _waitForRecordingFile(recordingPath!);
      _recordingStartedAt = null;
      return (path: recordingPath, durationMs: durationMs);
    } finally {
      if (!kIsWeb && Platform.isIOS) {
        try {
          await AudioPlayerService().restoreAfterRecording();
        } catch (e) {
          debugPrint('Speaking: restoreAfterRecording failed: $e');
        }
      }
    }
  }

  Future<String> _waitForRecordingFile(String path) async {
    if (path.isEmpty) {
      throw SpeakingRecordingException();
    }

    final file = File(path);
    for (var attempt = 0; attempt < 8; attempt++) {
      if (file.existsSync() && file.lengthSync() >= 44) {
        return path;
      }
      if (!kIsWeb && Platform.isIOS) {
        await Future<void>.delayed(Duration(milliseconds: 60 * (attempt + 1)));
      } else if (attempt == 0) {
        break;
      }
    }

    if (!file.existsSync() || file.lengthSync() < 44) {
      throw SpeakingRecordingException();
    }
    return path;
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

    debugPrint(
      'Speaking[evaluate] file path=$recordingPath bytes=${audioBytes.length}',
    );

    final recognizedText =
        await _sttService.transcribeWavBytes(audioBytes, language: language);
    final feedback = await _feedbackService.evaluateSpeech(
      referenceText: lineText,
      spokenText: recognizedText,
      language: language,
    );

    _cleanupRecording(recordingPath);

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

    await LearningProgressService().recordSpeakingScore(feedback.overallScore);
    await SpeakingReviewService().scheduleFromAttempt(
      attempt: attempt,
      episodeTitle: episode.episodeName,
    );

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
