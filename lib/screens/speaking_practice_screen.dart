import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:record/record.dart';
import '../models/episode.dart';
import '../models/speaking_attempt.dart';
import '../models/speaking_feedback.dart';
import '../models/speaking_session.dart';
import '../models/transcript_line.dart';
import '../services/admob_service.dart';
import '../services/ai/ai_error_handler.dart';
import '../services/ai/exceptions.dart';
import '../services/audio_player_service.dart';
import '../services/heart_service.dart';
import '../services/language_manager.dart';
import '../services/local_database_service.dart';
import '../services/speaking_practice_service.dart';
import '../widgets/heart_widget.dart';
import '../widgets/transcript_native_ad_widget.dart';
import 'speaking_ai_analysis_screen.dart';

class SpeakingPracticeScreen extends StatefulWidget {
  final Episode episode;
  final AudioPlayerService audioService;

  const SpeakingPracticeScreen({
    super.key,
    required this.episode,
    required this.audioService,
  });

  @override
  State<SpeakingPracticeScreen> createState() => _SpeakingPracticeScreenState();
}

class _SpeakingPracticeScreenState extends State<SpeakingPracticeScreen>
    with TickerProviderStateMixin {
  static const double _headerTitleScale = 0.86;
  static const double _headerSubtitleScale = 0.9;
  static const double _transcriptTextScale = 0.88;

  /// dBFS: giá trị [current] lớn hơn ngưỡng = có tiếng nói (theo package record).
  static const double _repeatSoundThresholdDb = -38;
  static const int _repeatMinRecordingMs = 700;
  static const int _repeatSilenceAfterSpeechMs = 1400;
  static const int _repeatMaxRecordingMs = 60000;

  late final TabController _tabController;
  late final AnimationController _repeatPulseController;
  final SpeakingPracticeService _practiceService = SpeakingPracticeService();
  final LocalDatabaseService _db = LocalDatabaseService();

  /// Đổi khi có attempt mới — refresh FutureBuilder lịch sử dòng.
  int _lineHistoryGeneration = 0;

  List<TranscriptLine> _lines = [];
  List<String> _speakers = [];
  /// Vị trí chèn native ad trong transcript (cùng logic [TranscriptSlide]).
  List<int> _transcriptAdPositions = [];

  TranscriptLine? _repeatSelectedLine;

  String? _roleplaySpeaker;
  int _roleplayIndex = 0;

  SpeakingSession? _repeatSession;
  SpeakingSession? _roleplaySession;

  bool _isRecording = false;
  bool _isProcessing = false;

  StreamSubscription<Amplitude>? _repeatAmpSub;
  DateTime? _repeatRecordingStartedAt;
  DateTime _repeatLastSoundAt = DateTime.now();
  bool _repeatHasDetectedSpeech = false;
  bool _repeatAutoStopScheduled = false;

  String? _repeatPendingPath;
  int? _repeatPendingDurationMs;
  bool _repeatAwaitingSend = false;
  bool _repeatAnalysisInProgress = false;

  StreamSubscription<Amplitude>? _roleplayAmpSub;
  DateTime? _roleplayRecordingStartedAt;
  DateTime _roleplayLastSoundAt = DateTime.now();
  bool _roleplayHasDetectedSpeech = false;
  bool _roleplayAutoStopScheduled = false;
  String? _roleplayPendingPath;
  int? _roleplayPendingDurationMs;
  bool _roleplayAwaitingSend = false;
  bool _roleplayAnalysisInProgress = false;

  /// Tránh song song stop/ghi giữa Repeat và Roleplay hoặc auto vs thủ công.
  bool _micStopInProgress = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _repeatPulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 550),
    );
    _prepareTranscriptLines();
  }

  void _disposeRecordingSync() {
    _repeatAmpSub?.cancel();
    _repeatAmpSub = null;
    _roleplayAmpSub?.cancel();
    _roleplayAmpSub = null;
    if (_isRecording) {
      unawaited(_practiceService.cancelRecording());
    }
    _isRecording = false;
    _repeatAutoStopScheduled = false;
    _repeatRecordingStartedAt = null;
    _repeatHasDetectedSpeech = false;
    _roleplayAutoStopScheduled = false;
    _roleplayRecordingStartedAt = null;
    _roleplayHasDetectedSpeech = false;
    _repeatPulseController.stop();
    _repeatPulseController.reset();
    final pr = _repeatPendingPath;
    if (pr != null) {
      _practiceService.discardRecordingFile(pr);
    }
    _repeatPendingPath = null;
    _repeatPendingDurationMs = null;
    _repeatAwaitingSend = false;
    _repeatAnalysisInProgress = false;
    final pp = _roleplayPendingPath;
    if (pp != null) {
      _practiceService.discardRecordingFile(pp);
    }
    _roleplayPendingPath = null;
    _roleplayPendingDurationMs = null;
    _roleplayAwaitingSend = false;
    _roleplayAnalysisInProgress = false;
  }

  @override
  void dispose() {
    _disposeRecordingSync();
    _repeatPulseController.dispose();
    _tabController.dispose();
    super.dispose();
  }

  void _prepareTranscriptLines() {
    final parsed = TranscriptLine.parseTranscriptHtml(widget.episode.transcriptHtml);
    if (parsed.isNotEmpty) {
      _lines = parsed;
    } else {
      _lines = _fallbackParseTranscript(widget.episode.transcript);
    }

    final speakers = _lines
        .map((e) => e.speaker)
        .where((e) => e.isNotEmpty)
        .where(TranscriptLine.isLikelyPersonSpeakerLabel)
        .toSet()
        .toList();
    speakers.sort();
    _speakers = speakers;

    if (_lines.isNotEmpty) {
      _repeatSelectedLine = _lines.first;
    }
    _calculateTranscriptAdPositions();
  }

  void _calculateTranscriptAdPositions() {
    if (kIsWeb) {
      _transcriptAdPositions = [];
      return;
    }
    final totalItems = _lines.length;
    if (totalItems < 20) {
      if (totalItems > 0) {
        _transcriptAdPositions = [totalItems ~/ 2];
      } else {
        _transcriptAdPositions = [];
      }
    } else {
      _transcriptAdPositions = [
        totalItems ~/ 3,
        totalItems * 2 ~/ 3,
      ];
    }
  }

  Widget _speakingTranscriptNativeAdSlot() {
    if (kIsWeb) return const SizedBox.shrink();
    return TranscriptNativeAdWidget(
      category: widget.episode.category,
      slot: TranscriptNativeAdSlot.speakingListTile,
    );
  }

  List<TranscriptLine> _fallbackParseTranscript(String transcript) {
    final cleaned = transcript.replaceAll(RegExp(r'\s+'), ' ').trim();
    if (cleaned.isEmpty) return [];
    final sentences = cleaned.split(RegExp(r'(?<=[.!?])\s+'));
    return sentences
        .where((s) => s.trim().isNotEmpty)
        .map((s) => TranscriptLine(
              startTime: 0,
              endTime: 0,
              speaker: '',
              text: s.trim(),
            ))
        .toList();
  }

  Future<void> _ensureSession(String mode) async {
    if (mode == 'repeat' && _repeatSession == null) {
      _repeatSession = await _practiceService.startSession(
        episode: widget.episode,
        mode: mode,
      );
    } else if (mode == 'roleplay' && _roleplaySession == null) {
      _roleplaySession = await _practiceService.startSession(
        episode: widget.episode,
        mode: mode,
      );
    }
  }

  Future<void> _stopRepeatMicAndResetUi() async {
    await _repeatAmpSub?.cancel();
    _repeatAmpSub = null;
    final wasRepeat = _repeatRecordingStartedAt != null;
    if (wasRepeat && _isRecording) {
      await _practiceService.cancelRecording();
    }
    _repeatPulseController.stop();
    _repeatPulseController.reset();
    if (mounted) {
      setState(() {
        if (wasRepeat) _isRecording = false;
        _repeatAutoStopScheduled = false;
        _repeatRecordingStartedAt = null;
        _repeatHasDetectedSpeech = false;
      });
    }
  }

  Future<void> _stopRoleplayMicAndResetUi() async {
    await _roleplayAmpSub?.cancel();
    _roleplayAmpSub = null;
    final wasRoleplay = _roleplayRecordingStartedAt != null;
    if (wasRoleplay && _isRecording) {
      await _practiceService.cancelRecording();
    }
    _repeatPulseController.stop();
    _repeatPulseController.reset();
    if (mounted) {
      setState(() {
        if (wasRoleplay) _isRecording = false;
        _roleplayAutoStopScheduled = false;
        _roleplayRecordingStartedAt = null;
        _roleplayHasDetectedSpeech = false;
      });
    }
  }

  void _discardRoleplaySavedClip() {
    final p = _roleplayPendingPath;
    if (p != null) {
      _practiceService.discardRecordingFile(p);
    }
    _roleplayPendingPath = null;
    _roleplayPendingDurationMs = null;
    _roleplayAwaitingSend = false;
  }

  void _discardRepeatSavedClip() {
    final p = _repeatPendingPath;
    if (p != null) {
      _practiceService.discardRecordingFile(p);
    }
    _repeatPendingPath = null;
    _repeatPendingDurationMs = null;
    _repeatAwaitingSend = false;
  }

  Future<void> _startRepeatRecording() async {
    await _stopRepeatMicAndResetUi();
    await _stopRoleplayMicAndResetUi();
    _discardRepeatSavedClip();
    _discardRoleplaySavedClip();

    final started = DateTime.now();
    _repeatRecordingStartedAt = started;
    _repeatLastSoundAt = started;
    _repeatHasDetectedSpeech = false;
    setState(() {
      _isRecording = true;
      _isProcessing = false;
    });
    _repeatPulseController.repeat(reverse: true);

    try {
      await _practiceService.startRecording();
    } catch (e) {
      await _stopRepeatMicAndResetUi();
      if (mounted) _showError(e);
      return;
    }

    _repeatAmpSub = _practiceService.onRecordingAmplitudeChanged().listen(
      _onRepeatAmplitude,
      onError: (error) {
        debugPrint('Repeat recording amplitude error: $error');
      },
    );
  }

  void _onRepeatAmplitude(Amplitude amplitude) {
    if (!mounted || !_isRecording || _repeatRecordingStartedAt == null) return;

    final now = DateTime.now();
    if (amplitude.current > _repeatSoundThresholdDb) {
      _repeatHasDetectedSpeech = true;
      _repeatLastSoundAt = now;
    }

    final recMs = now.difference(_repeatRecordingStartedAt!).inMilliseconds;
    final silentMs = now.difference(_repeatLastSoundAt).inMilliseconds;

    final silenceEnded = _repeatHasDetectedSpeech &&
        recMs >= _repeatMinRecordingMs &&
        silentMs >= _repeatSilenceAfterSpeechMs;
    final maxLenEnded = recMs >= _repeatMaxRecordingMs;

    if ((silenceEnded || maxLenEnded) &&
        !_repeatAutoStopScheduled &&
        !_micStopInProgress) {
      _repeatAutoStopScheduled = true;
      unawaited(_autoStopRepeatRecording());
    }
  }

  void _onRoleplayAmplitude(Amplitude amplitude) {
    if (!mounted || !_isRecording || _roleplayRecordingStartedAt == null) return;

    final now = DateTime.now();
    if (amplitude.current > _repeatSoundThresholdDb) {
      _roleplayHasDetectedSpeech = true;
      _roleplayLastSoundAt = now;
    }

    final recMs = now.difference(_roleplayRecordingStartedAt!).inMilliseconds;
    final silentMs = now.difference(_roleplayLastSoundAt).inMilliseconds;

    final silenceEnded = _roleplayHasDetectedSpeech &&
        recMs >= _repeatMinRecordingMs &&
        silentMs >= _repeatSilenceAfterSpeechMs;
    final maxLenEnded = recMs >= _repeatMaxRecordingMs;

    if ((silenceEnded || maxLenEnded) &&
        !_roleplayAutoStopScheduled &&
        !_micStopInProgress) {
      _roleplayAutoStopScheduled = true;
      unawaited(_autoStopRoleplayRecording());
    }
  }

  Future<void> _autoStopRoleplayRecording() async {
    if (_micStopInProgress) return;
    _micStopInProgress = true;
    await _roleplayAmpSub?.cancel();
    _roleplayAmpSub = null;

    if (!mounted) {
      _micStopInProgress = false;
      return;
    }

    try {
      final kept = await _practiceService.stopRecordingKeepFile();
      if (!mounted) return;
      _repeatPulseController.stop();
      _repeatPulseController.reset();
      setState(() {
        _isRecording = false;
        _roleplayAwaitingSend = true;
        _roleplayPendingPath = kept.path;
        _roleplayPendingDurationMs = kept.durationMs;
        _roleplayAutoStopScheduled = false;
        _roleplayRecordingStartedAt = null;
      });
    } catch (e) {
      _repeatPulseController.stop();
      _repeatPulseController.reset();
      if (mounted) {
        setState(() {
          _isRecording = false;
          _roleplayAutoStopScheduled = false;
          _roleplayRecordingStartedAt = null;
        });
      }
      _showError(e);
    } finally {
      _micStopInProgress = false;
    }
  }

  Future<void> _autoStopRepeatRecording() async {
    if (_micStopInProgress) return;
    _micStopInProgress = true;
    await _repeatAmpSub?.cancel();
    _repeatAmpSub = null;

    if (!mounted) {
      _micStopInProgress = false;
      return;
    }

    try {
      final kept = await _practiceService.stopRecordingKeepFile();
      if (!mounted) return;
      _repeatPulseController.stop();
      _repeatPulseController.reset();
      setState(() {
        _isRecording = false;
        _repeatAwaitingSend = true;
        _repeatPendingPath = kept.path;
        _repeatPendingDurationMs = kept.durationMs;
        _repeatAutoStopScheduled = false;
        _repeatRecordingStartedAt = null;
      });
    } catch (e) {
      _repeatPulseController.stop();
      _repeatPulseController.reset();
      if (mounted) {
        setState(() {
          _isRecording = false;
          _repeatAutoStopScheduled = false;
          _repeatRecordingStartedAt = null;
        });
      }
      _showError(e);
    } finally {
      _micStopInProgress = false;
    }
  }

  /// Dừng ghi thủ công — lưu file, chờ user bấm Gửi phân tích (tránh lỗi STT ngay khi stop).
  Future<void> _forceStopRepeatAndSendAnalysis() async {
    if (!_isRecording || _isProcessing || _repeatSelectedLine == null) return;
    if (_micStopInProgress) return;

    _micStopInProgress = true;
    await _repeatAmpSub?.cancel();
    _repeatAmpSub = null;

    if (!mounted) {
      _micStopInProgress = false;
      return;
    }

    try {
      final kept = await _practiceService.stopRecordingKeepFile();
      if (!mounted) return;
      _repeatPulseController.stop();
      _repeatPulseController.reset();
      setState(() {
        _isRecording = false;
        _repeatAwaitingSend = true;
        _repeatPendingPath = kept.path;
        _repeatPendingDurationMs = kept.durationMs;
        _repeatAutoStopScheduled = false;
        _repeatRecordingStartedAt = null;
      });
    } catch (e) {
      _repeatPulseController.stop();
      _repeatPulseController.reset();
      if (mounted) {
        setState(() {
          _isRecording = false;
          _repeatAutoStopScheduled = false;
          _repeatRecordingStartedAt = null;
        });
      }
      _showError(e);
    } finally {
      _micStopInProgress = false;
    }
  }

  Future<void> _startRoleplayRecording() async {
    final line = _currentRoleplayLine();
    if (line == null) return;

    await _stopRoleplayMicAndResetUi();
    await _stopRepeatMicAndResetUi();
    _discardRoleplaySavedClip();
    _discardRepeatSavedClip();

    final started = DateTime.now();
    _roleplayRecordingStartedAt = started;
    _roleplayLastSoundAt = started;
    _roleplayHasDetectedSpeech = false;
    setState(() {
      _isRecording = true;
      _isProcessing = false;
    });
    _repeatPulseController.repeat(reverse: true);

    try {
      await _practiceService.startRecording();
    } catch (e) {
      await _stopRoleplayMicAndResetUi();
      if (mounted) _showError(e);
      return;
    }

    _roleplayAmpSub = _practiceService.onRecordingAmplitudeChanged().listen(
      _onRoleplayAmplitude,
      onError: (error) {
        debugPrint('Roleplay recording amplitude error: $error');
      },
    );
  }

  Future<void> _forceStopRoleplayAndSendAnalysis() async {
    final line = _currentRoleplayLine();
    if (!_isRecording || _isProcessing || line == null) return;
    if (_micStopInProgress) return;

    _micStopInProgress = true;
    await _roleplayAmpSub?.cancel();
    _roleplayAmpSub = null;

    if (!mounted) {
      _micStopInProgress = false;
      return;
    }

    try {
      final kept = await _practiceService.stopRecordingKeepFile();
      if (!mounted) return;
      _repeatPulseController.stop();
      _repeatPulseController.reset();
      setState(() {
        _isRecording = false;
        _roleplayAwaitingSend = true;
        _roleplayPendingPath = kept.path;
        _roleplayPendingDurationMs = kept.durationMs;
        _roleplayAutoStopScheduled = false;
        _roleplayRecordingStartedAt = null;
      });
    } catch (e) {
      _repeatPulseController.stop();
      _repeatPulseController.reset();
      if (mounted) {
        setState(() {
          _isRecording = false;
          _roleplayAutoStopScheduled = false;
          _roleplayRecordingStartedAt = null;
        });
      }
      _showError(e);
    } finally {
      _micStopInProgress = false;
    }
  }

  Future<void> _sendRepeatAnalysis() async {
    if (_repeatSelectedLine == null) return;
    final path = _repeatPendingPath;
    final dur = _repeatPendingDurationMs;
    if (path == null || dur == null) return;

    await _ensureSession('repeat');

    setState(() {
      _isProcessing = true;
      _repeatAnalysisInProgress = true;
    });

    try {
      final result = await _practiceService.evaluateRecordingFile(
        recordingPath: path,
        durationMs: dur,
        session: _repeatSession!,
        episode: widget.episode,
        mode: 'repeat',
        lineText: _repeatSelectedLine!.text,
        lineIndex: _lines.indexOf(_repeatSelectedLine!),
        speaker: _repeatSelectedLine!.speaker,
        lineStartMs: _repeatSelectedLine!.startTime,
        lineEndMs: _repeatSelectedLine!.endTime,
      );
      _repeatSession = result.updatedSession;
      if (!mounted) return;
      setState(() {
        _isProcessing = false;
        _repeatAnalysisInProgress = false;
        _repeatPendingPath = null;
        _repeatPendingDurationMs = null;
        _repeatAwaitingSend = false;
      });
      await _navigateToAnalysis(result, _repeatSelectedLine!);
    } catch (e) {
      if (mounted) {
        setState(() {
          _isProcessing = false;
          _repeatAnalysisInProgress = false;
          _repeatAwaitingSend = true;
        });
      }
      _showError(e, onRetry: () => _sendRepeatAnalysis());
    }
  }

  Future<void> _sendRoleplayAnalysis() async {
    final line = _currentRoleplayLine();
    if (line == null) return;
    final path = _roleplayPendingPath;
    final dur = _roleplayPendingDurationMs;
    if (path == null || dur == null) return;

    await _ensureSession('roleplay');

    setState(() {
      _isProcessing = true;
      _roleplayAnalysisInProgress = true;
    });

    try {
      final result = await _practiceService.evaluateRecordingFile(
        recordingPath: path,
        durationMs: dur,
        session: _roleplaySession!,
        episode: widget.episode,
        mode: 'roleplay',
        lineText: line.text,
        lineIndex: _lines.indexOf(line),
        speaker: line.speaker,
        lineStartMs: line.startTime,
        lineEndMs: line.endTime,
      );
      _roleplaySession = result.updatedSession;
      if (!mounted) return;
      setState(() {
        _isProcessing = false;
        _roleplayAnalysisInProgress = false;
        _roleplayPendingPath = null;
        _roleplayPendingDurationMs = null;
        _roleplayAwaitingSend = false;
        _roleplayIndex = _roleplayIndex + 1;
      });
      await _navigateToAnalysis(result, line);
    } catch (e) {
      if (mounted) {
        setState(() {
          _isProcessing = false;
          _roleplayAnalysisInProgress = false;
          _roleplayAwaitingSend = true;
        });
      }
      _showError(e, onRetry: () => _sendRoleplayAnalysis());
    }
  }

  TranscriptLine? _currentRoleplayLine() {
    final filtered = _roleplayLines();
    if (filtered.isEmpty) return null;
    if (_roleplayIndex >= filtered.length) {
      return null;
    }
    return filtered[_roleplayIndex];
  }

  /// Vị trí trong transcript của lượt user hiện tại (để làm mờ phần phía sau).
  int? _roleplayCurrentUserGlobalIndex() {
    if (_roleplaySpeaker == null) return null;
    final userIdx = <int>[];
    for (var i = 0; i < _lines.length; i++) {
      if (_lines[i].speaker == _roleplaySpeaker) {
        userIdx.add(i);
      }
    }
    if (userIdx.isEmpty) return null;
    if (_roleplayIndex >= userIdx.length) {
      return userIdx.last;
    }
    return userIdx[_roleplayIndex];
  }

  List<TranscriptLine> _roleplayLines() {
    if (_roleplaySpeaker == null) return [];
    return _lines.where((line) => line.speaker == _roleplaySpeaker).toList();
  }

  void _playSample(TranscriptLine line) {
    if (line.startTime <= 0 || line.endTime <= 0) {
      return;
    }
    final durationMs = line.endTime - line.startTime;
    widget.audioService.seekTo(Duration(milliseconds: line.startTime));
    widget.audioService.play();
    if (durationMs > 0) {
      Future.delayed(Duration(milliseconds: durationMs), () {
        widget.audioService.pause();
      });
    }
  }

  void _showError(dynamic error, {VoidCallback? onRetry}) {
    if (!mounted) return;
    final message = AIErrorHandler.getErrorMessage(error);
    final lm = LanguageManager();

    if (error is NoHeartsException) {
      final heartService = HeartService();
      final admobService = AdMobService();
      if (heartService.canEarnMoreHearts && !kIsWeb) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('No hearts available.'),
            action: SnackBarAction(
              label: 'Watch Ads',
              textColor: Theme.of(context).colorScheme.onInverseSurface,
              onPressed: () {
                if (admobService.isRewardedAdReady()) {
                  admobService.showRewardedAd(
                    onRewarded: () {
                      heartService.earnHeart();
                      if (!mounted) return;
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('❤️ You earned 1 heart!'),
                          backgroundColor: Color(0xFF7A5CFF),
                          duration: Duration(seconds: 2),
                        ),
                      );
                    },
                    onAdFailedToShow: (adError) {
                      if (!mounted) return;
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('Failed to show ad: $adError'),
                          backgroundColor: Theme.of(context).colorScheme.error,
                        ),
                      );
                    },
                  );
                } else {
                  admobService.createRewardedAd();
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Ad is loading, please try again in a moment'),
                      duration: Duration(seconds: 2),
                    ),
                  );
                }
              },
            ),
          ),
        );
        return;
      }
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        action: onRetry != null
            ? SnackBarAction(
                label: lm.getText('retry'),
                onPressed: onRetry,
              )
            : null,
      ),
    );
  }

  Future<void> _openAnalysisFromAttempt(SpeakingAttempt attempt) async {
    var ep = widget.episode;
    if (attempt.episodeId != widget.episode.resolvedStorageId) {
      final loaded = await LocalDatabaseService().getEpisodeById(attempt.episodeId);
      if (loaded != null) ep = loaded;
    }
    SpeakingFeedback feedback;
    if (attempt.feedbackJson != null && attempt.feedbackJson!.trim().isNotEmpty) {
      try {
        feedback = SpeakingFeedback.fromMap(
          jsonDecode(attempt.feedbackJson!) as Map<String, dynamic>,
        );
      } catch (_) {
        feedback = SpeakingFeedback(
          overallScore: attempt.score,
          pronunciationScore: attempt.score,
          fluencyScore: attempt.score,
          accuracyScore: attempt.score,
          feedback: attempt.feedback,
          mistakes: const [],
        );
      }
    } else {
      feedback = SpeakingFeedback(
        overallScore: attempt.score,
        pronunciationScore: attempt.score,
        fluencyScore: attempt.score,
        accuracyScore: attempt.score,
        feedback: attempt.feedback,
        mistakes: const [],
      );
    }
    if (!mounted) return;
    await Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        fullscreenDialog: true,
        builder: (ctx) => SpeakingAiAnalysisScreen(
          episode: ep,
          feedback: feedback,
          recognizedText: attempt.recognizedText,
          referenceLineText: attempt.lineText,
          lineStartMs: attempt.lineStartMs,
          lineEndMs: attempt.lineEndMs,
          userRecordingPath: attempt.userRecordingPath,
          enableExitInterstitial: false,
        ),
      ),
    );
  }

  Future<void> _showLineHistorySheet(String mode, TranscriptLine line) async {
    final idx = _lines.indexOf(line);
    if (idx < 0) return;
    final list = await _db.getSpeakingAttemptsForLine(
      episodeId: widget.episode.resolvedStorageId,
      mode: mode,
      lineIndex: idx,
      speaker: line.speaker,
    );
    if (!mounted) return;
    final lm = LanguageManager();
    final loc = lm.currentLocale.toString();
    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (ctx) {
        final maxH = MediaQuery.of(context).size.height * 0.5;
        if (list.isEmpty) {
          return SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Text(
                lm.getText('speakingLineHistoryEmpty'),
                textAlign: TextAlign.center,
              ),
            ),
          );
        }
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                child: Text(
                  lm.getText('speakingLineHistoryTitle'),
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ),
              SizedBox(
                height: maxH,
                child: ListView.builder(
                  itemCount: list.length,
                  itemBuilder: (context, i) {
                    final a = list[i];
                    String dateStr;
                    try {
                      dateStr = DateFormat.yMMMd(loc).add_Hm().format(a.createdAt.toLocal());
                    } catch (_) {
                      dateStr = DateFormat.yMMMd().add_Hm().format(a.createdAt.toLocal());
                    }
                    return ListTile(
                      leading: const Icon(Icons.analytics_outlined),
                      title: Text(
                        lm.getTextWithParams('speakingHistoryAttemptScore', {
                          'score': a.score.toStringAsFixed(0),
                        }),
                      ),
                      subtitle: Text(dateStr),
                      onTap: () {
                        Navigator.of(ctx).pop();
                        unawaited(_openAnalysisFromAttempt(a));
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _trailingHintOrLineHistory({
    required String mode,
    required TranscriptLine? line,
    required Widget expandedHint,
  }) {
    if (line == null) return expandedHint;
    final idx = _lines.indexOf(line);
    if (idx < 0) return expandedHint;
    return FutureBuilder<List<SpeakingAttempt>>(
      key: ValueKey(
        'lh-$mode-${widget.episode.resolvedStorageId}-$_lineHistoryGeneration-$idx',
      ),
      future: _db.getSpeakingAttemptsForLine(
        episodeId: widget.episode.resolvedStorageId,
        mode: mode,
        lineIndex: idx,
        speaker: line.speaker,
        limit: 1,
      ),
      builder: (context, snap) {
        final has = snap.data?.isNotEmpty ?? false;
        if (!has) return expandedHint;
        return Expanded(
          child: Align(
            alignment: Alignment.centerRight,
            child: IconButton(
              icon: const Icon(Icons.history_rounded),
              tooltip: LanguageManager().getText('speakingLineHistoryTooltip'),
              onPressed: () => unawaited(_showLineHistorySheet(mode, line)),
            ),
          ),
        );
      },
    );
  }

  Future<void> _navigateToAnalysis(
    SpeakingAttemptResult result,
    TranscriptLine line,
  ) async {
    await Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        fullscreenDialog: true,
        builder: (ctx) => SpeakingAiAnalysisScreen(
          episode: widget.episode,
          feedback: result.feedback,
          recognizedText: result.attempt.recognizedText,
          referenceLineText: line.text,
          lineStartMs: line.startTime,
          lineEndMs: line.endTime,
          userRecordingPath: result.attempt.userRecordingPath,
        ),
      ),
    );
    if (mounted) {
      setState(() => _lineHistoryGeneration++);
    }
  }

  bool _roleplayIsComplete() {
    final f = _roleplayLines();
    return _roleplaySpeaker != null && f.isNotEmpty && _roleplayIndex >= f.length;
  }

  bool _isSpeakingPracticeComplete() {
    if (_roleplayIsComplete()) return true;
    final session = _repeatSession;
    return session != null && session.totalAttempts > 0;
  }

  void _popWithCompletionResult() {
    Navigator.of(context).pop(_isSpeakingPracticeComplete());
  }

  Color _headingColor(Color categoryColor) {
    return Color.lerp(categoryColor, const Color(0xFF0B3D3D), 0.55)!;
  }

  Color _ctaGreen(Color categoryColor) {
    return Color.lerp(categoryColor, const Color(0xFF1E6B5A), 0.4)!;
  }

  TextStyle _scaledTextStyle(TextStyle? base, double factor, {double fallbackSize = 14}) {
    final s = base ?? TextStyle(fontSize: fallbackSize);
    final fs = s.fontSize ?? fallbackSize;
    return s.copyWith(fontSize: fs * factor);
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: LanguageManager(),
      builder: (context, _) {
        final lm = LanguageManager();
        final cs = Theme.of(context).colorScheme;
        final categoryColor = cs.primary;
        final softBg = Color.lerp(
          cs.surfaceContainerHighest,
          cs.surface,
          0.45,
        )!;
        return PopScope(
          canPop: false,
          onPopInvokedWithResult: (didPop, result) {
            if (!didPop) {
              _popWithCompletionResult();
            }
          },
          child: Scaffold(
          backgroundColor: softBg,
          appBar: AppBar(
            backgroundColor: categoryColor,
            foregroundColor: cs.onPrimary,
            elevation: 0,
            leading: BackButton(
              onPressed: _popWithCompletionResult,
            ),
            title: Text(lm.getText('speakingPracticeTitle')),
            actions: [
              Builder(
                builder: (context) {
                  final safe = MediaQuery.of(context).padding.top;
                  const tabBarHeight = 48.0;
                  final panelTop = safe + kToolbarHeight + tabBarHeight;
                  return Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: HeartWidget(panelTop: panelTop),
                  );
                },
              ),
            ],
            bottom: TabBar(
              controller: _tabController,
              labelColor: cs.onPrimary,
              unselectedLabelColor: cs.onPrimary.withOpacity(0.72),
              indicatorColor: cs.onPrimary,
              tabs: [
                Tab(text: lm.getText('speakingTabRepeat')),
                Tab(text: lm.getText('speakingTabRoleplay')),
              ],
            ),
          ),
          body: TabBarView(
            controller: _tabController,
            children: [
              _buildRepeatTab(context, softBg, categoryColor, lm),
              _buildRoleplayTab(context, softBg, categoryColor, lm),
            ],
          ),
          ),
        );
      },
    );
  }

  Widget _buildPracticeHeader({
    required BuildContext context,
    String? badge,
    Color? badgeBg,
    Color? badgeFg,
    required String title,
    required String subtitle,
    required Color titleColor,
  }) {
    final theme = Theme.of(context);
    final showBadge =
        badge != null && badge.isNotEmpty && badgeBg != null && badgeFg != null;
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (showBadge) ...[
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: badgeBg,
                borderRadius: BorderRadius.circular(999),
              ),
              child: Text(
                badge,
                style: theme.textTheme.labelSmall?.copyWith(
                  color: badgeFg,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.6,
                ),
              ),
            ),
            const SizedBox(height: 12),
          ],
          Text(
            title,
            style: _scaledTextStyle(
              theme.textTheme.headlineSmall,
              _headerTitleScale,
              fallbackSize: 24,
            ).copyWith(
              fontWeight: FontWeight.bold,
              color: titleColor,
              height: 1.2,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            subtitle,
            style: _scaledTextStyle(
              theme.textTheme.bodyMedium,
              _headerSubtitleScale,
              fallbackSize: 14,
            ).copyWith(
              color: titleColor.withValues(alpha: 0.75),
              height: 1.35,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _speakerAvatar(String name, Color categoryColor, {double radius = 22}) {
    final initial = name.isNotEmpty ? name[0].toUpperCase() : '?';
    return CircleAvatar(
      radius: radius,
      backgroundColor: categoryColor.withValues(alpha: 0.2),
      child: Text(
        initial,
        style: TextStyle(
          color: categoryColor,
          fontWeight: FontWeight.bold,
          fontSize: radius * 0.85,
        ),
      ),
    );
  }

  Widget _buildRepeatTab(
    BuildContext context,
    Color softBg,
    Color categoryColor,
    LanguageManager lm,
  ) {
    if (_lines.isEmpty) {
      return Center(child: Text(lm.getText('speakingNoTranscript')));
    }

    final heading = _headingColor(categoryColor);
    final summary = (widget.episode.summary?.trim().isNotEmpty ?? false)
        ? widget.episode.summary!.trim()
        : lm.getText('speakingRepeatSubtitleDefault');

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _buildPracticeHeader(
          context: context,
          title: widget.episode.episodeName,
          subtitle: summary,
          titleColor: heading,
        ),
        if (_repeatSelectedLine != null)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
            child: _repeatTurnCard(
              context,
              categoryColor,
              heading,
              lm,
            ),
          ),
        Expanded(
          child: ListView.builder(
            padding: EdgeInsets.fromLTRB(
              8,
              8,
              8,
              24 + MediaQuery.viewPaddingOf(context).bottom,
            ),
            itemCount: _lines.length + _transcriptAdPositions.length,
            itemBuilder: (context, index) {
              int adsBeforeIndex = 0;
              int? matchingAdPosition;
              for (final adPos in _transcriptAdPositions) {
                final actualAdIndex = adPos + adsBeforeIndex;
                if (actualAdIndex == index) {
                  matchingAdPosition = adPos;
                  break;
                }
                if (actualAdIndex < index) {
                  adsBeforeIndex++;
                }
              }
              if (matchingAdPosition != null) {
                return _speakingTranscriptNativeAdSlot();
              }
              final transcriptIndex = index - adsBeforeIndex;
              if (transcriptIndex < 0 || transcriptIndex >= _lines.length) {
                return const SizedBox.shrink();
              }
              final line = _lines[transcriptIndex];
              final selected = _repeatSelectedLine == line;
              return Material(
                color: selected
                    ? Theme.of(context).colorScheme.surface.withValues(alpha: 0.92)
                    : Colors.transparent,
                borderRadius: BorderRadius.circular(16),
                clipBehavior: Clip.antiAlias,
                child: ListTile(
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  selected: selected,
                  selectedTileColor: Theme.of(context).colorScheme.surface,
                  title: Text(
                    line.text,
                    style: TextStyle(
                      color: heading.withValues(alpha: selected ? 1 : 0.88),
                      fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
                      fontSize:
                          (Theme.of(context).textTheme.bodyLarge?.fontSize ?? 16) *
                              _transcriptTextScale,
                    ),
                  ),
                  subtitle: line.speaker.isNotEmpty
                      ? Text(
                          line.speaker,
                          style: TextStyle(
                            color: heading.withValues(alpha: 0.55),
                            fontSize:
                                (Theme.of(context).textTheme.labelSmall?.fontSize ?? 12) *
                                    _transcriptTextScale,
                          ),
                        )
                      : null,
                  onTap: () async {
                    if (_repeatSelectedLine != line) {
                      if (_repeatRecordingStartedAt != null) {
                        await _stopRepeatMicAndResetUi();
                      }
                      if (_roleplayRecordingStartedAt != null) {
                        await _stopRoleplayMicAndResetUi();
                      }
                      if (_repeatAwaitingSend) _discardRepeatSavedClip();
                      if (_roleplayAwaitingSend) _discardRoleplaySavedClip();
                    }
                    setState(() {
                      _repeatSelectedLine = line;
                    });
                  },
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _repeatTurnCard(
    BuildContext context,
    Color categoryColor,
    Color heading,
    LanguageManager lm,
  ) {
    final line = _repeatSelectedLine!;
    final theme = Theme.of(context);
    final canListen = line.startTime > 0 && line.endTime > 0;

    return Container(
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: theme.colorScheme.shadow.withValues(alpha: 0.07),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 18),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _speakerAvatar(lm.getText('speakingYou'), categoryColor),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        lm.getText('speakingYou'),
                        style: _scaledTextStyle(
                          theme.textTheme.titleSmall,
                          _transcriptTextScale,
                          fallbackSize: 14,
                        ).copyWith(
                          fontWeight: FontWeight.bold,
                          color: categoryColor,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: categoryColor.withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: Text(
                          lm.getText('speakingCurrentSentenceBadge'),
                          style: theme.textTheme.labelSmall?.copyWith(
                            color: heading,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 0.3,
                            fontSize: 10,
                          ),
                        ),
                      ),
                      const Spacer(),
                      IconButton(
                        visualDensity: VisualDensity.compact,
                        tooltip: lm.getText('speakingListenSampleTooltip'),
                        onPressed: canListen ? () => _playSample(line) : null,
                        icon: Icon(
                          Icons.volume_up_rounded,
                          color: canListen ? heading : heading.withValues(alpha: 0.25),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    line.text,
                    style: _scaledTextStyle(
                      theme.textTheme.titleMedium,
                      _transcriptTextScale,
                      fallbackSize: 16,
                    ).copyWith(
                      color: heading,
                      height: 1.35,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 18),
                  _buildRepeatRecordingControls(context, categoryColor, heading, lm),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRepeatRecordingControls(
    BuildContext context,
    Color categoryColor,
    Color heading,
    LanguageManager lm,
  ) {
    final theme = Theme.of(context);
    final cta = _ctaGreen(categoryColor);
    final hintStyle = _scaledTextStyle(
      theme.textTheme.bodySmall,
      _transcriptTextScale,
      fallbackSize: 12,
    ).copyWith(
      color: heading.withValues(alpha: 0.55),
    );

    if (_repeatAwaitingSend) {
      return Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: cta,
              foregroundColor: Theme.of(context).colorScheme.onPrimary,
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(999),
              ),
            ),
            onPressed: _isProcessing ? null : _sendRepeatAnalysis,
            child: _isProcessing
                ? SizedBox(
                    width: 22,
                    height: 22,
                    child: CircularProgressIndicator(
                      strokeWidth: 2.5,
                      color: Theme.of(context).colorScheme.onPrimary,
                    ),
                  )
                : Text(lm.getText('speakingSendAnalysis')),
          ),
          const SizedBox(width: 12),
          _trailingHintOrLineHistory(
            mode: 'repeat',
            line: _repeatSelectedLine,
            expandedHint: Expanded(
              child: Text(
                lm.getText('speakingHintSendAnalysis'),
                style: hintStyle,
              ),
            ),
          ),
        ],
      );
    }

    if (_repeatAnalysisInProgress && !_isRecording && !_repeatAwaitingSend) {
      return Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          SizedBox(
            width: 22,
            height: 22,
            child: CircularProgressIndicator(
              strokeWidth: 2.5,
              color: categoryColor,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              lm.getText('speakingRepeatAnalyzing'),
              style: hintStyle,
            ),
          ),
        ],
      );
    }

    if (_isRecording) {
      return Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          OutlinedButton(
            style: OutlinedButton.styleFrom(
              foregroundColor: heading,
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              side: BorderSide(
                color: categoryColor.withValues(alpha: 0.55),
                width: 1.5,
              ),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(999),
              ),
              backgroundColor: Theme.of(context).colorScheme.surface,
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
            onPressed: (_isProcessing || _micStopInProgress)
                ? null
                : () {
                    unawaited(_forceStopRepeatAndSendAnalysis());
                  },
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                AnimatedBuilder(
                  animation: _repeatPulseController,
                  builder: (context, child) {
                    final t = _repeatPulseController.value;
                    return Opacity(
                      opacity: 0.35 + 0.65 * t,
                      child: Transform.scale(
                        scale: 0.88 + 0.12 * t,
                        child: child,
                      ),
                    );
                  },
                  child: Container(
                    width: 16,
                    height: 16,
                    decoration: const BoxDecoration(
                      color: Color(0xFFEF4444),
                      shape: BoxShape.circle,
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Text(
                  lm.getText('speakingRecording'),
                  style: _scaledTextStyle(
                    theme.textTheme.titleSmall,
                    _transcriptTextScale,
                    fallbackSize: 14,
                  ).copyWith(
                    color: heading,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          _trailingHintOrLineHistory(
            mode: 'repeat',
            line: _repeatSelectedLine,
            expandedHint: Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    lm.getText('speakingRepeatAutoStopHint'),
                    style: hintStyle,
                  ),
                  Text(
                    lm.getText('speakingRepeatTapToStopHint'),
                    style: hintStyle,
                  ),
                ],
              ),
            ),
          ),
        ],
      );
    }

    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        FilledButton.icon(
          style: FilledButton.styleFrom(
            backgroundColor: cta,
            foregroundColor: Theme.of(context).colorScheme.onPrimary,
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(999),
            ),
          ),
          onPressed: _isProcessing ? null : _startRepeatRecording,
          icon: const Icon(Icons.mic_rounded, size: 22),
          label: Text(lm.getText('speakingStartRecording')),
        ),
        const SizedBox(width: 12),
        _trailingHintOrLineHistory(
          mode: 'repeat',
          line: _repeatSelectedLine,
          expandedHint: Expanded(
            child: Text(
              lm.getText('speakingHintPracticeSentence'),
              style: hintStyle,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildRoleplayRecordingControls(
    BuildContext context,
    Color categoryColor,
    Color heading,
    LanguageManager lm,
  ) {
    final theme = Theme.of(context);
    final cta = _ctaGreen(categoryColor);
    final hintStyle = _scaledTextStyle(
      theme.textTheme.bodySmall,
      _transcriptTextScale,
      fallbackSize: 12,
    ).copyWith(
      color: heading.withValues(alpha: 0.55),
    );

    final roleplayLine = _currentRoleplayLine();

    if (_roleplayAwaitingSend) {
      return Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: cta,
              foregroundColor: Theme.of(context).colorScheme.onPrimary,
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(999),
              ),
            ),
            onPressed: _isProcessing ? null : _sendRoleplayAnalysis,
            child: _isProcessing
                ? SizedBox(
                    width: 22,
                    height: 22,
                    child: CircularProgressIndicator(
                      strokeWidth: 2.5,
                      color: Theme.of(context).colorScheme.onPrimary,
                    ),
                  )
                : Text(lm.getText('speakingSendAnalysis')),
          ),
          const SizedBox(width: 12),
          _trailingHintOrLineHistory(
            mode: 'roleplay',
            line: roleplayLine,
            expandedHint: Expanded(
              child: Text(
                lm.getText('speakingHintSendAnalysis'),
                style: hintStyle,
              ),
            ),
          ),
        ],
      );
    }

    if (_roleplayAnalysisInProgress && !_isRecording && !_roleplayAwaitingSend) {
      return Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          SizedBox(
            width: 22,
            height: 22,
            child: CircularProgressIndicator(
              strokeWidth: 2.5,
              color: categoryColor,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              lm.getText('speakingRepeatAnalyzing'),
              style: hintStyle,
            ),
          ),
        ],
      );
    }

    if (_isRecording) {
      return Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          OutlinedButton(
            style: OutlinedButton.styleFrom(
              foregroundColor: heading,
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              side: BorderSide(
                color: categoryColor.withValues(alpha: 0.55),
                width: 1.5,
              ),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(999),
              ),
              backgroundColor: Theme.of(context).colorScheme.surface,
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
            onPressed: (_isProcessing || _micStopInProgress)
                ? null
                : () {
                    unawaited(_forceStopRoleplayAndSendAnalysis());
                  },
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                AnimatedBuilder(
                  animation: _repeatPulseController,
                  builder: (context, child) {
                    final t = _repeatPulseController.value;
                    return Opacity(
                      opacity: 0.35 + 0.65 * t,
                      child: Transform.scale(
                        scale: 0.88 + 0.12 * t,
                        child: child,
                      ),
                    );
                  },
                  child: Container(
                    width: 16,
                    height: 16,
                    decoration: const BoxDecoration(
                      color: Color(0xFFEF4444),
                      shape: BoxShape.circle,
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Text(
                  lm.getText('speakingRecording'),
                  style: _scaledTextStyle(
                    theme.textTheme.titleSmall,
                    _transcriptTextScale,
                    fallbackSize: 14,
                  ).copyWith(
                    color: heading,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          _trailingHintOrLineHistory(
            mode: 'roleplay',
            line: roleplayLine,
            expandedHint: Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    lm.getText('speakingRepeatAutoStopHint'),
                    style: hintStyle,
                  ),
                  Text(
                    lm.getText('speakingRepeatTapToStopHint'),
                    style: hintStyle,
                  ),
                ],
              ),
            ),
          ),
        ],
      );
    }

    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        FilledButton.icon(
          style: FilledButton.styleFrom(
            backgroundColor: cta,
            foregroundColor: Theme.of(context).colorScheme.onPrimary,
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(999),
            ),
          ),
          onPressed: _isProcessing ? null : _startRoleplayRecording,
          icon: const Icon(Icons.mic_rounded, size: 22),
          label: Text(lm.getText('speakingStartRecording')),
        ),
        const SizedBox(width: 12),
        _trailingHintOrLineHistory(
          mode: 'roleplay',
          line: roleplayLine,
          expandedHint: Expanded(
            child: Text(
              lm.getText('speakingHintPracticeLineRoleplay'),
              style: hintStyle,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildRoleplayPersonaBar(
    BuildContext context,
    Color softBg,
    Color categoryColor,
    Color heading, {
    bool padForSystemNav = false,
  }) {
    final safeBottom =
        padForSystemNav ? MediaQuery.viewPaddingOf(context).bottom : 0.0;
    return Padding(
      padding: EdgeInsets.fromLTRB(16, 4, 16, 12 + safeBottom),
      child: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: Color.lerp(softBg, Theme.of(context).colorScheme.surface, 0.35),
          borderRadius: BorderRadius.circular(20),
        ),
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: _speakers.map((speaker) {
              final selected = _roleplaySpeaker == speaker;
              return Padding(
                padding: const EdgeInsets.only(right: 8),
                child: Material(
                  color: selected ? Theme.of(context).colorScheme.surface : Colors.transparent,
                  elevation: selected ? 1 : 0,
                  shadowColor: Theme.of(context).colorScheme.shadow.withOpacity(0.26),
                  borderRadius: BorderRadius.circular(999),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(999),
                    onTap: () async {
                      if (_roleplaySpeaker != speaker) {
                        if (_roleplayRecordingStartedAt != null) {
                          await _stopRoleplayMicAndResetUi();
                        }
                        if (_repeatRecordingStartedAt != null) {
                          await _stopRepeatMicAndResetUi();
                        }
                        if (_roleplayAwaitingSend) {
                          _discardRoleplaySavedClip();
                        }
                        if (_repeatAwaitingSend) {
                          _discardRepeatSavedClip();
                        }
                      }
                      setState(() {
                        _roleplaySpeaker = speaker;
                        _roleplayIndex = 0;
                      });
                    },
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            selected ? Icons.wb_sunny_outlined : Icons.person_outline_rounded,
                            size: 18,
                            color: selected ? categoryColor : heading.withValues(alpha: 0.55),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            speaker,
                            style: TextStyle(
                              fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                              color: heading.withValues(alpha: selected ? 1 : 0.65),
                              fontSize:
                                  (Theme.of(context).textTheme.bodyMedium?.fontSize ?? 14) *
                                      _transcriptTextScale,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
        ),
      ),
    );
  }

  Widget _buildRoleplayTab(
    BuildContext context,
    Color softBg,
    Color categoryColor,
    LanguageManager lm,
  ) {
    if (_lines.isEmpty || _speakers.isEmpty) {
      return Center(child: Text(lm.getText('speakingNoSpeakersRoleplay')));
    }

    final theme = Theme.of(context);
    final heading = _headingColor(categoryColor);
    final summary = (widget.episode.summary?.trim().isNotEmpty ?? false)
        ? widget.episode.summary!.trim()
        : lm.getText('speakingRoleplaySubtitleDefault');

    if (_roleplaySpeaker == null) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _buildPracticeHeader(
            context: context,
            title: widget.episode.episodeName,
            subtitle: summary,
            titleColor: heading,
          ),
          Expanded(
            child: Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text(
                  lm.getText('speakingRoleplayPickHint'),
                  textAlign: TextAlign.center,
                  style: _scaledTextStyle(
                    theme.textTheme.bodyLarge,
                    _transcriptTextScale,
                    fallbackSize: 16,
                  ).copyWith(
                    color: heading.withValues(alpha: 0.65),
                  ),
                ),
              ),
            ),
          ),
          _buildRoleplayPersonaBar(
            context,
            softBg,
            categoryColor,
            heading,
            padForSystemNav: true,
          ),
        ],
      );
    }

    return Column(
      children: [
        _buildPracticeHeader(
          context: context,
          title: widget.episode.episodeName,
          subtitle: summary,
          titleColor: heading,
        ),
        _buildRoleplayPersonaBar(context, softBg, categoryColor, heading),
        Expanded(
          child: ListView.builder(
            padding: EdgeInsets.fromLTRB(
              16,
              0,
              16,
              28 + MediaQuery.viewPaddingOf(context).bottom,
            ),
            itemCount: _lines.length +
                _transcriptAdPositions.length +
                (_roleplayIsComplete() ? 1 : 0),
            itemBuilder: (context, index) {
              final lineSlots = _lines.length + _transcriptAdPositions.length;
              if (_roleplayIsComplete() && index == lineSlots) {
                return _roleplayCompleteBanner(context, categoryColor, heading, lm);
              }
              int adsBeforeIndex = 0;
              int? matchingAdPosition;
              for (final adPos in _transcriptAdPositions) {
                final actualAdIndex = adPos + adsBeforeIndex;
                if (actualAdIndex == index) {
                  matchingAdPosition = adPos;
                  break;
                }
                if (actualAdIndex < index) {
                  adsBeforeIndex++;
                }
              }
              if (matchingAdPosition != null) {
                return Padding(
                  padding: const EdgeInsets.only(bottom: 14),
                  child: _speakingTranscriptNativeAdSlot(),
                );
              }
              final transcriptIndex = index - adsBeforeIndex;
              if (transcriptIndex < 0 || transcriptIndex >= _lines.length) {
                return const SizedBox.shrink();
              }
              return Padding(
                padding: const EdgeInsets.only(bottom: 14),
                child: _buildRoleplayScriptLine(
                  context,
                  transcriptIndex,
                  softBg,
                  categoryColor,
                  heading,
                  lm,
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _roleplayCompleteBanner(
    BuildContext context,
    Color categoryColor,
    Color heading,
    LanguageManager lm,
  ) {
    final theme = Theme.of(context);
    return Container(
      margin: const EdgeInsets.only(top: 8),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: categoryColor.withValues(alpha: 0.25)),
      ),
      child: Row(
        children: [
          Icon(Icons.celebration_outlined, color: categoryColor, size: 32),
          const SizedBox(width: 14),
          Expanded(
            child: Text(
              lm.getText('speakingRoleplayComplete'),
              style: _scaledTextStyle(
                theme.textTheme.titleSmall,
                _transcriptTextScale,
                fallbackSize: 14,
              ).copyWith(
                color: heading,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRoleplayScriptLine(
    BuildContext context,
    int i,
    Color softBg,
    Color categoryColor,
    Color heading,
    LanguageManager lm,
  ) {
    final line = _lines[i];
    final currGlobal = _roleplayCurrentUserGlobalIndex();
    final currentLine = _currentRoleplayLine();
    final roleplayDone = _roleplayIsComplete();
    final showAsUpcoming =
        !roleplayDone && currGlobal != null && i > currGlobal;
    final isUser = _roleplaySpeaker != null && line.speaker == _roleplaySpeaker;

    if (roleplayDone) {
      if (isUser) {
        return _roleplayPastUserLine(context, line, categoryColor, heading, lm);
      }
      return _roleplayNpcBubble(
        context,
        line,
        categoryColor,
        heading,
        lm,
        dimmed: false,
      );
    }

    if (isUser &&
        currGlobal != null &&
        i == currGlobal &&
        currentLine != null) {
      return _roleplayYourTurnCard(context, line, categoryColor, heading, lm);
    }
    if (isUser && currGlobal != null && i < currGlobal) {
      return _roleplayPastUserLine(context, line, categoryColor, heading, lm);
    }
    if (!isUser) {
      return _roleplayNpcBubble(
        context,
        line,
        categoryColor,
        heading,
        lm,
        dimmed: showAsUpcoming,
      );
    }
    if (isUser && showAsUpcoming) {
      return _roleplayNpcBubble(
        context,
        line,
        categoryColor,
        heading,
        lm,
        dimmed: true,
      );
    }
    return const SizedBox.shrink();
  }

  Widget _roleplayNpcBubble(
    BuildContext context,
    TranscriptLine line,
    Color categoryColor,
    Color heading,
    LanguageManager lm, {
    required bool dimmed,
  }) {
    final theme = Theme.of(context);
    final opacity = dimmed ? 0.38 : 1.0;
    final canListen = line.startTime > 0 && line.endTime > 0;
    return Opacity(
      opacity: opacity,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _speakerAvatar(line.speaker, categoryColor),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      line.speaker,
                      style: _scaledTextStyle(
                        theme.textTheme.titleSmall,
                        _transcriptTextScale,
                        fallbackSize: 14,
                      ).copyWith(
                        fontWeight: FontWeight.w700,
                        color: categoryColor,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        line.speaker.toUpperCase(),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: _scaledTextStyle(
                          theme.textTheme.labelSmall,
                          _transcriptTextScale,
                          fallbackSize: 11,
                        ).copyWith(
                          color: heading.withValues(alpha: 0.45),
                          letterSpacing: 0.8,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    IconButton(
                      visualDensity: VisualDensity.compact,
                      tooltip: lm.getText('speakingListenSampleTooltip'),
                      onPressed: canListen ? () => _playSample(line) : null,
                      icon: Icon(
                        Icons.volume_up_rounded,
                        color: canListen ? heading : heading.withValues(alpha: 0.25),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  line.text,
                  style: _scaledTextStyle(
                    theme.textTheme.bodyLarge,
                    _transcriptTextScale,
                    fallbackSize: 16,
                  ).copyWith(
                    color: heading,
                    height: 1.35,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _roleplayPastUserLine(
    BuildContext context,
    TranscriptLine line,
    Color categoryColor,
    Color heading,
    LanguageManager lm,
  ) {
    final theme = Theme.of(context);
    final canListen = line.startTime > 0 && line.endTime > 0;
    return Opacity(
      opacity: 0.52,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.check_circle_outline_rounded, color: categoryColor, size: 24),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        line.speaker,
                        style: _scaledTextStyle(
                          theme.textTheme.labelMedium,
                          _transcriptTextScale,
                          fallbackSize: 12,
                        ).copyWith(
                          color: categoryColor,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    IconButton(
                      visualDensity: VisualDensity.compact,
                      tooltip: lm.getText('speakingListenSampleTooltip'),
                      onPressed: canListen ? () => _playSample(line) : null,
                      icon: Icon(
                        Icons.volume_up_rounded,
                        color: canListen ? heading : heading.withValues(alpha: 0.25),
                      ),
                    ),
                  ],
                ),
                Text(
                  line.text,
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                  style: _scaledTextStyle(
                    theme.textTheme.bodyMedium,
                    _transcriptTextScale,
                    fallbackSize: 14,
                  ).copyWith(color: heading),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _roleplayYourTurnCard(
    BuildContext context,
    TranscriptLine line,
    Color categoryColor,
    Color heading,
    LanguageManager lm,
  ) {
    final theme = Theme.of(context);
    final canListen = line.startTime > 0 && line.endTime > 0;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _speakerAvatar(line.speaker, categoryColor),
        const SizedBox(width: 10),
        Expanded(
          child: Container(
            decoration: BoxDecoration(
              color: theme.colorScheme.surface,
              borderRadius: BorderRadius.circular(24),
              boxShadow: [
                BoxShadow(
                  color: theme.colorScheme.shadow.withValues(alpha: 0.08),
                  blurRadius: 22,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 14, 14, 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        line.speaker,
                        style: _scaledTextStyle(
                          theme.textTheme.titleSmall,
                          _transcriptTextScale,
                          fallbackSize: 14,
                        ).copyWith(
                          fontWeight: FontWeight.bold,
                          color: categoryColor,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: categoryColor.withValues(alpha: 0.85),
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: Text(
                          lm.getText('speakingYourTurn'),
                          style: theme.textTheme.labelSmall?.copyWith(
                            color: theme.colorScheme.onPrimary,
                            fontWeight: FontWeight.w800,
                            fontSize: 10,
                            letterSpacing: 0.4,
                          ),
                        ),
                      ),
                      const Spacer(),
                      IconButton(
                        tooltip: lm.getText('speakingListenSampleTooltip'),
                        visualDensity: VisualDensity.compact,
                        onPressed: canListen ? () => _playSample(line) : null,
                        icon: Icon(
                          Icons.volume_up_rounded,
                          color: canListen ? heading : heading.withValues(alpha: 0.25),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    line.text,
                    style: _scaledTextStyle(
                      theme.textTheme.titleMedium,
                      _transcriptTextScale,
                      fallbackSize: 16,
                    ).copyWith(
                      color: heading,
                      height: 1.35,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 16),
                  _buildRoleplayRecordingControls(context, categoryColor, heading, lm),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

}
