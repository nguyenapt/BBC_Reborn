import 'dart:async';
import 'dart:io' show File;

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../models/episode.dart';
import '../models/speaking_feedback.dart';
import '../services/admob_service.dart';
import '../services/language_manager.dart';
import '../services/local_database_service.dart';
import '../utils/category_colors.dart';
import '../widgets/speaking_reference_highlight.dart';

/// Màn phân tích AI sau khi hoàn tất ghi âm — màu nền & accent theo category + Theme.
class SpeakingAiAnalysisScreen extends StatefulWidget {
  final Episode episode;
  final SpeakingFeedback feedback;
  final String? recognizedText;
  /// Câu tham chiếu (highlight lỗi + shadowing).
  final String? referenceLineText;
  final int? lineStartMs;
  final int? lineEndMs;
  final String? userRecordingPath;
  final bool enableExitInterstitial;

  const SpeakingAiAnalysisScreen({
    super.key,
    required this.episode,
    required this.feedback,
    this.recognizedText,
    this.referenceLineText,
    this.lineStartMs,
    this.lineEndMs,
    this.userRecordingPath,
    this.enableExitInterstitial = true,
  });

  @override
  State<SpeakingAiAnalysisScreen> createState() => _SpeakingAiAnalysisScreenState();
}

class _SpeakingAiAnalysisScreenState extends State<SpeakingAiAnalysisScreen> {
  bool _exitInProgress = false;
  String? _episodeAudioUrl;
  AudioPlayer? _refPlayer;
  AudioPlayer? _userPlayer;
  StreamSubscription<Duration>? _refPosSub;
  bool _refPlaying = false;
  bool _userPlaying = false;

  @override
  void initState() {
    super.initState();
    if (widget.enableExitInterstitial && !kIsWeb) {
      AdMobService().createInterstitialAd();
    }
    unawaited(_loadEpisodeAudioUrl());
  }

  Future<void> _loadEpisodeAudioUrl() async {
    final direct = widget.episode.fileUrl ?? widget.episode.secondFileUrl;
    if (direct != null && direct.isNotEmpty) {
      if (mounted) setState(() => _episodeAudioUrl = direct);
      return;
    }
    final fromDb =
        await LocalDatabaseService().getEpisodeFileUrl(widget.episode.resolvedStorageId);
    if (mounted) setState(() => _episodeAudioUrl = fromDb);
  }

  @override
  void dispose() {
    unawaited(_refPosSub?.cancel());
    unawaited(_refPlayer?.dispose());
    unawaited(_userPlayer?.dispose());
    super.dispose();
  }

  void _closeWithExitInterstitial() {
    if (_exitInProgress) return;
    _exitInProgress = true;
    if (!widget.enableExitInterstitial) {
      if (mounted) Navigator.of(context).pop();
      return;
    }
    AdMobService().showInterstitialAd(
      onDismissedOrUnavailable: () {
        if (!mounted) return;
        Navigator.of(context).pop();
      },
    );
  }

  static int _scorePercent(double raw) {
    final v = raw.clamp(0, 100);
    return v.round();
  }

  String _fluencyLabel(LanguageManager lm, double score) {
    final s = score.clamp(0, 100);
    if (s >= 85) return lm.getText('speakingAiFluencyExcellent');
    if (s >= 70) return lm.getText('speakingAiFluencyGood');
    if (s >= 55) return lm.getText('speakingAiFluencyFair');
    return lm.getText('speakingAiFluencyNeedsWork');
  }

  List<String> _focusTags(LanguageManager lm) {
    final tags = widget.feedback.mistakes
        .map((m) => m.expected.trim())
        .where((s) => s.isNotEmpty)
        .take(4)
        .toList();
    if (tags.isEmpty) {
      return [lm.getText('speakingAiFocusFallbackTag')];
    }
    return tags;
  }

  bool get _canPlayReference =>
      _episodeAudioUrl != null &&
      _episodeAudioUrl!.isNotEmpty &&
      widget.lineStartMs != null &&
      widget.lineEndMs != null &&
      widget.lineEndMs! > widget.lineStartMs!;

  bool get _canPlayUser {
    final p = widget.userRecordingPath;
    if (p == null || p.isEmpty) return false;
    if (kIsWeb) return false;
    return File(p).existsSync();
  }

  Future<void> _toggleReference() async {
    if (!_canPlayReference) return;
    final url = _episodeAudioUrl!;
    final start = widget.lineStartMs!;
    final end = widget.lineEndMs!;

    if (_refPlaying) {
      await _refPlayer?.pause();
      await _refPosSub?.cancel();
      _refPosSub = null;
      if (mounted) setState(() => _refPlaying = false);
      return;
    }

    _refPlayer ??= AudioPlayer();
    await _refPlayer!.stop();
    await _refPlayer!.setSourceUrl(url);
    await _refPlayer!.seek(Duration(milliseconds: start));
    await _refPlayer!.resume();
    if (mounted) setState(() => _refPlaying = true);

    await _refPosSub?.cancel();
    _refPosSub = _refPlayer!.onPositionChanged.listen((d) {
      if (d.inMilliseconds >= end) {
        unawaited(_refPlayer?.pause());
        unawaited(_refPosSub?.cancel());
        _refPosSub = null;
        if (mounted) setState(() => _refPlaying = false);
      }
    });
  }

  Future<void> _toggleUser() async {
    if (!_canPlayUser) return;
    final path = widget.userRecordingPath!;

    _userPlayer ??= AudioPlayer();
    if (_userPlaying) {
      await _userPlayer!.pause();
      if (mounted) setState(() => _userPlaying = false);
      return;
    }
    await _userPlayer!.stop();
    await _userPlayer!.setSource(DeviceFileSource(path));
    await _userPlayer!.resume();
    if (mounted) setState(() => _userPlaying = true);
    _userPlayer!.onPlayerComplete.listen((_) {
      if (mounted) setState(() => _userPlaying = false);
    });
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: LanguageManager(),
      builder: (context, _) {
        final lm = LanguageManager();
        final theme = Theme.of(context);
        final cs = theme.colorScheme;
        final categoryColor = CategoryColors.getCategoryColor(widget.episode.category);
        final categoryBg = CategoryColors.getCategoryBackgroundColor(widget.episode.category);

        final screenBg = Color.lerp(categoryBg, cs.surface, 0.42)!;
        final pronunciation = _scorePercent(widget.feedback.pronunciationScore);
        final fluencyPct = _scorePercent(widget.feedback.fluencyScore);
        final fluencyTitle = _fluencyLabel(lm, widget.feedback.fluencyScore);
        final fluencyHeading = lm.getTextWithParams(
          'speakingAiFluencyWithLevel',
          {'level': fluencyTitle},
        );
        final feedbackBody = widget.feedback.feedback.isNotEmpty
            ? widget.feedback.feedback
            : lm.getTextWithParams('speakingAiFluencyFallback', {'percent': '$fluencyPct'});
        final overallLine = lm.getTextWithParams('speakingAiOverallAccuracy', {
          'overall': widget.feedback.overallScore.toStringAsFixed(0),
          'accuracy': '${_scorePercent(widget.feedback.accuracyScore)}',
        });

        final refLine = widget.referenceLineText?.trim() ?? '';
        final highlightColor = categoryColor.withValues(alpha: 0.22);

        return PopScope(
          canPop: false,
          onPopInvokedWithResult: (didPop, result) {
            if (didPop) return;
            _closeWithExitInterstitial();
          },
          child: Scaffold(
            backgroundColor: screenBg,
            appBar: AppBar(
              backgroundColor: CategoryColors.getCategoryColor(widget.episode.category),
              foregroundColor: Colors.white,
              elevation: 0,
              title: Text(lm.getText('speakingAiAnalysisTitle')),
              leading: IconButton(
                icon: const Icon(Icons.close),
                onPressed: _exitInProgress ? null : _closeWithExitInterstitial,
              ),
            ),
            body: SafeArea(
              top: false,
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(20, 20, 20, 24),
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: Color.lerp(categoryBg, cs.surface, 0.55),
                    borderRadius: BorderRadius.circular(24),
                    boxShadow: [
                      BoxShadow(
                        color: cs.shadow.withValues(alpha: 0.08),
                        blurRadius: 20,
                        offset: const Offset(0, 8),
                      ),
                    ],
                  ),
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(20, 20, 20, 22),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                lm.getText('speakingAiAnalysisTitle'),
                                style: theme.textTheme.titleLarge?.copyWith(
                                  fontWeight: FontWeight.bold,
                                  color: cs.onSurface,
                                ),
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                              decoration: BoxDecoration(
                                color: Color.lerp(
                                      CategoryColors.getCategoryBackgroundColor(widget.episode.category),
                                      cs.tertiaryContainer,
                                      0.5,
                                    ) ??
                                    cs.tertiaryContainer,
                                borderRadius: BorderRadius.circular(999),
                              ),
                              child: Text(
                                lm.getText('speakingAiRealtimeBadge'),
                                style: theme.textTheme.labelSmall?.copyWith(
                                  fontWeight: FontWeight.w700,
                                  color: cs.onTertiaryContainer,
                                  letterSpacing: 0.6,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 22),
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.baseline,
                          textBaseline: TextBaseline.alphabetic,
                          children: [
                            Expanded(
                              child: Text(
                                lm.getText('speakingAiPronunciation'),
                                style: theme.textTheme.titleMedium?.copyWith(
                                  fontWeight: FontWeight.bold,
                                  color: cs.onSurface,
                                ),
                              ),
                            ),
                            Text(
                              '$pronunciation%',
                              style: theme.textTheme.headlineSmall?.copyWith(
                                fontWeight: FontWeight.bold,
                                color: categoryColor.withValues(alpha: 0.95),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(999),
                          child: LinearProgressIndicator(
                            value: pronunciation / 100.0,
                            minHeight: 10,
                            backgroundColor: cs.surfaceContainerHighest.withValues(alpha: 0.85),
                            valueColor: AlwaysStoppedAnimation<Color>(
                              categoryColor,
                            ),
                          ),
                        ),
                        if (refLine.isNotEmpty) ...[
                          const SizedBox(height: 18),
                          Text(
                            lm.getText('speakingAiReferenceLine'),
                            style: theme.textTheme.labelMedium?.copyWith(
                              fontWeight: FontWeight.w800,
                              color: categoryColor.withValues(alpha: 0.9),
                              letterSpacing: 0.6,
                            ),
                          ),
                          const SizedBox(height: 8),
                          SpeakingReferenceHighlight(
                            referenceText: refLine,
                            mistakes: widget.feedback.mistakes,
                            highlightColor: highlightColor,
                            textColor: cs.onSurface,
                            style: theme.textTheme.bodyLarge?.copyWith(height: 1.4),
                          ),
                        ],
                        if (widget.recognizedText != null &&
                            widget.recognizedText!.trim().isNotEmpty) ...[
                          const SizedBox(height: 14),
                          Text(
                            lm.getTextWithParams(
                              'speakingAiYouSaidLine',
                              {'line': widget.recognizedText!.trim()},
                            ),
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: cs.onSurfaceVariant,
                            ),
                          ),
                        ],
                        const SizedBox(height: 16),
                        _shadowingRow(theme, cs, lm, categoryColor),
                        const SizedBox(height: 16),
                        DecoratedBox(
                          decoration: BoxDecoration(
                            color: cs.surface,
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Padding(
                            padding: const EdgeInsets.all(16),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Container(
                                  width: 48,
                                  height: 48,
                                  decoration: BoxDecoration(
                                    color: Color.lerp(categoryBg, cs.primaryContainer, 0.4),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Icon(
                                    Icons.auto_awesome_rounded,
                                    color: categoryColor,
                                    size: 26,
                                  ),
                                ),
                                const SizedBox(width: 14),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        fluencyHeading,
                                        style: theme.textTheme.titleSmall?.copyWith(
                                          fontWeight: FontWeight.bold,
                                          color: cs.onSurface,
                                        ),
                                      ),
                                      const SizedBox(height: 6),
                                      Text(
                                        feedbackBody,
                                        style: theme.textTheme.bodyMedium?.copyWith(
                                          color: cs.onSurfaceVariant,
                                          height: 1.35,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        if (widget.feedback.mistakes.isNotEmpty) ...[
                          const SizedBox(height: 22),
                          Text(
                            lm.getText('speakingAiPronunciationMistakes'),
                            style: theme.textTheme.labelMedium?.copyWith(
                              fontWeight: FontWeight.w800,
                              color: categoryColor.withValues(alpha: 0.9),
                              letterSpacing: 0.8,
                            ),
                          ),
                          const SizedBox(height: 10),
                          ...widget.feedback.mistakes.map((m) {
                            return Padding(
                              padding: const EdgeInsets.only(bottom: 10),
                              child: DecoratedBox(
                                decoration: BoxDecoration(
                                  color: cs.surface,
                                  borderRadius: BorderRadius.circular(16),
                                  border: Border.all(
                                    color: cs.outlineVariant.withValues(alpha: 0.5),
                                  ),
                                ),
                                child: Padding(
                                  padding: const EdgeInsets.all(14),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      _mistRow(
                                        theme,
                                        cs,
                                        lm.getText('speakingAiExpected'),
                                        m.expected,
                                      ),
                                      if (m.spoken.trim().isNotEmpty) ...[
                                        const SizedBox(height: 6),
                                        _mistRow(
                                          theme,
                                          cs,
                                          lm.getText('speakingAiSpoken'),
                                          m.spoken,
                                        ),
                                      ],
                                      if (m.note.trim().isNotEmpty) ...[
                                        const SizedBox(height: 8),
                                        Text(
                                          lm.getText('speakingAiHowToFix'),
                                          style: theme.textTheme.labelSmall?.copyWith(
                                            fontWeight: FontWeight.w700,
                                            color: categoryColor,
                                          ),
                                        ),
                                        const SizedBox(height: 4),
                                        Text(
                                          m.note,
                                          style: theme.textTheme.bodySmall?.copyWith(
                                            color: cs.onSurfaceVariant,
                                            height: 1.35,
                                          ),
                                        ),
                                      ],
                                    ],
                                  ),
                                ),
                              ),
                            );
                          }),
                        ],
                        const SizedBox(height: 22),
                        Text(
                          lm.getText('speakingAiFocusArea'),
                          style: theme.textTheme.labelMedium?.copyWith(
                            fontWeight: FontWeight.w800,
                            color: categoryColor.withValues(alpha: 0.9),
                            letterSpacing: 0.8,
                          ),
                        ),
                        const SizedBox(height: 12),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: _focusTags(lm).map((tag) {
                            return Material(
                              color: cs.surface,
                              elevation: 0,
                              borderRadius: BorderRadius.circular(999),
                              child: Padding(
                                padding:
                                    const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                                child: Text(
                                  tag.length > 32 ? '${tag.substring(0, 29)}…' : tag,
                                  style: theme.textTheme.labelLarge?.copyWith(
                                    color: cs.onSurface,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                            );
                          }).toList(),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          overallLine,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: cs.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _mistRow(ThemeData theme, ColorScheme cs, String label, String value) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 88,
          child: Text(
            label,
            style: theme.textTheme.labelSmall?.copyWith(
              color: cs.onSurfaceVariant,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: theme.textTheme.bodySmall?.copyWith(
              color: cs.onSurface,
              height: 1.3,
            ),
          ),
        ),
      ],
    );
  }

  Widget _shadowingRow(
    ThemeData theme,
    ColorScheme cs,
    LanguageManager lm,
    Color categoryColor,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          lm.getText('speakingAiShadowingTitle'),
          style: theme.textTheme.labelMedium?.copyWith(
            fontWeight: FontWeight.w800,
            color: categoryColor.withValues(alpha: 0.9),
            letterSpacing: 0.6,
          ),
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(
              child: _audioChip(
                theme,
                cs,
                lm,
                lm.getText('speakingAiShadowingOriginal'),
                _canPlayReference,
                _refPlaying,
                _toggleReference,
                !_canPlayReference ? lm.getText('speakingAiShadowingNoReference') : null,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _audioChip(
                theme,
                cs,
                lm,
                lm.getText('speakingAiShadowingYours'),
                _canPlayUser,
                _userPlaying,
                _toggleUser,
                !_canPlayUser ? lm.getText('speakingAiShadowingNoUser') : null,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _audioChip(
    ThemeData theme,
    ColorScheme cs,
    LanguageManager lm,
    String title,
    bool canPlay,
    bool playing,
    VoidCallback onTap,
    String? disabledHint,
  ) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: cs.outlineVariant.withValues(alpha: 0.45)),
      ),
      child: InkWell(
        onTap: canPlay ? onTap : null,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: theme.textTheme.labelMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                  color: cs.onSurface,
                ),
              ),
              const SizedBox(height: 6),
              Row(
                children: [
                  Icon(
                    playing ? Icons.pause_circle_filled : Icons.play_circle_fill,
                    color: canPlay ? cs.primary : cs.outline,
                    size: 32,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      canPlay
                          ? (playing
                              ? lm.getText('speakingAiShadowingPause')
                              : lm.getText('speakingAiShadowingPlay'))
                          : (disabledHint ?? ''),
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: canPlay ? cs.onSurfaceVariant : cs.outline,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
