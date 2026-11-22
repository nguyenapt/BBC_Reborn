import 'dart:async';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../config/ai_config.dart';
import '../models/episode.dart';
import '../models/grammar_explanation.dart';
import '../models/transcript_line.dart';
import '../services/ai/ai_error_handler.dart';
import '../services/ai_grammar_service.dart';
import '../services/ai_translation_service.dart';
import '../services/language_manager.dart';
import '../services/learning_analytics_service.dart';
import '../services/review_reminder_service.dart';
import '../services/saved_grammar_service.dart';
import '../utils/category_colors.dart';
import 'banner_ad_widget.dart';
import 'episode_detail_tab_panel.dart';
import 'grammar_explanation_widget.dart';
import 'heart_economy_ui.dart';

/// Cinema-style subtitle view: EN cue + actions on top, banner ad below.
class SubtitleCinemaPanel extends StatefulWidget {
  final Episode episode;
  final List<TranscriptLine> lines;
  final int currentPositionMs;
  final double scrollBottomInset;
  final Future<void> Function(int startMs, int endMs)? onToggleLoopLine;
  final bool Function(int startMs, int endMs)? isLineLooping;

  const SubtitleCinemaPanel({
    super.key,
    required this.episode,
    required this.lines,
    required this.currentPositionMs,
    this.scrollBottomInset = 0,
    this.onToggleLoopLine,
    this.isLineLooping,
  });

  @override
  State<SubtitleCinemaPanel> createState() => _SubtitleCinemaPanelState();
}

class _SubtitleCinemaPanelState extends State<SubtitleCinemaPanel> {
  final AITranslationService _translationService = AITranslationService();
  final AIGrammarService _grammarService = AIGrammarService();
  final SavedGrammarService _savedGrammarService = SavedGrammarService();
  final ReviewReminderService _reviewReminderService = ReviewReminderService();
  final LearningAnalyticsService _analyticsService = LearningAnalyticsService();
  final LanguageManager _languageManager = LanguageManager();

  final Map<String, String> _lineTranslations = {};
  final Map<String, bool> _lineTranslating = {};
  final Map<String, GrammarExplanation> _grammarCache = {};
  final Map<int, bool> _grammarEnglishAvailableByLine = {};

  int? _activeIndex;
  TranscriptLine? _activeLine;

  @override
  void initState() {
    super.initState();
    _resolveActive();
  }

  @override
  void didUpdateWidget(covariant SubtitleCinemaPanel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.currentPositionMs != widget.currentPositionMs ||
        !identical(oldWidget.lines, widget.lines)) {
      _resolveActive();
    }
  }

  void _resolveActive() {
    final ms = widget.currentPositionMs;
    int? index;
    TranscriptLine? line;
    if (ms > 0) {
      for (var i = 0; i < widget.lines.length; i++) {
        final l = widget.lines[i];
        if (l.startTime == 0 && l.endTime == 0) continue;
        if (l.isActiveAt(ms)) {
          index = i;
          line = l;
          break;
        }
      }
    }
    if (index != _activeIndex) {
      setState(() {
        _activeIndex = index;
        _activeLine = line;
      });
    } else if (line?.text != _activeLine?.text) {
      setState(() => _activeLine = line);
    }
  }

  int _effectiveLoopEndMs(TranscriptLine line, int index) {
    if (line.endTime > line.startTime) return line.endTime;
    for (var i = index + 1; i < widget.lines.length; i++) {
      final next = widget.lines[i];
      if (next.startTime > line.startTime) return next.startTime;
    }
    return line.startTime + 2500;
  }

  String _cueBodyText(TranscriptLine line) => line.text.trim();

  Color _speakerAccentColor(String speaker) {
    const palette = <Color>[
      Color(0xFF047857),
      Color(0xFF1D4ED8),
      Color(0xFF7C3AED),
      Color(0xFFB45309),
      Color(0xFF0F766E),
      Color(0xFFBE185D),
      Color(0xFF4D7C0F),
      Color(0xFF4338CA),
    ];
    if (speaker.isEmpty) return palette[0];
    return palette[speaker.hashCode.abs() % palette.length];
  }

  String _speakerInitial(String speaker) {
    final t = speaker.trim();
    if (t.isEmpty) return '?';
    return t[0].toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    final categoryColor =
        CategoryColors.getCategoryColor(widget.episode.category);
    final scheme = Theme.of(context).colorScheme;
    final line = _activeLine;
    final index = _activeIndex;
    final hasCue = line != null && index != null;
    final enText = hasCue ? _cueBodyText(line) : '';
    final speakerRaw = hasCue ? line.speaker.trim() : '';
    final speakerLabel = speakerRaw.isNotEmpty
        ? speakerRaw.toUpperCase()
        : _languageManager.getText('speakerDefault').toUpperCase();
    final speakerColor = _speakerAccentColor(speakerRaw);
    final translated =
        hasCue ? _lineTranslations[line.text] : null;
    final translating =
        hasCue && (_lineTranslating[line.text] == true);
    final fontScale = _languageManager.textScaleFactor;

    // Player inset 18 — banner cùng bề ngang; gap với player = 8px.
    const playerGapInInset = 16.0; // khớp EpisodeDetailScreen._contentPlayerGap
    final bottomPad =
        (widget.scrollBottomInset - playerGapInInset + 8).clamp(0.0, 400.0);
    final playerHInset = EpisodeDetailTabPanel.contentHorizontalInset;

    Widget actionPad({required Widget child}) {
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
        child: child,
      );
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final paneWidth = constraints.maxWidth.isFinite
            ? constraints.maxWidth
            : MediaQuery.sizeOf(context).width;
        final bannerWidth =
            (paneWidth - playerHInset * 2).clamp(0.0, 1200.0);

        return SizedBox.expand(
      child: Padding(
        padding: EdgeInsets.only(bottom: bottomPad),
        child: Column(
          children: [
            // Speaker + EN + dịch — phía trên.
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(14, 8, 14, 4),
                child: Align(
                  alignment: Alignment.topLeft,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          CircleAvatar(
                            radius: 17,
                            backgroundColor: speakerColor.withOpacity(0.22),
                            child: Text(
                              _speakerInitial(speakerRaw),
                              style: GoogleFonts.nunitoSans(
                                fontSize: 15 * fontScale,
                                fontWeight: FontWeight.bold,
                                color: speakerColor,
                              ),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              hasCue ? speakerLabel : '…',
                              style: GoogleFonts.nunitoSans(
                                fontSize: 13 * fontScale,
                                fontWeight: FontWeight.bold,
                                letterSpacing: 0.65,
                                color: hasCue
                                    ? speakerColor
                                    : scheme.onSurface.withOpacity(0.35),
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      AnimatedSwitcher(
                        duration: const Duration(milliseconds: 180),
                        child: Text(
                          hasCue ? (enText.isNotEmpty ? enText : '…') : '…',
                          key: ValueKey<String>(
                            hasCue
                                ? '${index}_${line.speaker}_$enText'
                                : 'empty',
                          ),
                          textAlign: TextAlign.left,
                          style: GoogleFonts.nunitoSans(
                            fontSize: 16 * fontScale,
                            height: 1.35,
                            fontWeight: FontWeight.w600,
                            color: scheme.onSurface
                                .withOpacity(hasCue ? 0.92 : 0.35),
                          ),
                        ),
                      ),
                      if (translated != null && translated.trim().isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.only(top: 8),
                          child: Text(
                            translated,
                            textAlign: TextAlign.left,
                            style: GoogleFonts.nunitoSans(
                              fontSize: 13 * fontScale,
                              height: 1.35,
                              fontStyle: FontStyle.italic,
                              color: scheme.onSurface.withOpacity(0.62),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ),
            // Cụm action — cách banner 4px.
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 0, 12, 4),
              child: Wrap(
                spacing: 2,
                runSpacing: 0,
                alignment: WrapAlignment.center,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  Builder(
                    builder: (context) {
                      if (!hasCue || widget.onToggleLoopLine == null) {
                        return const SizedBox.shrink();
                      }
                      final loopEnd = _effectiveLoopEndMs(line, index);
                      if (loopEnd <= line.startTime) {
                        return const SizedBox.shrink();
                      }
                      final isLooping = widget.isLineLooping?.call(
                            line.startTime,
                            loopEnd,
                          ) ??
                          false;
                      final loopColor = isLooping
                          ? const Color(0xFF10B981)
                          : categoryColor;
                      return InkWell(
                        onTap: () {
                          widget.onToggleLoopLine!(
                            line.startTime,
                            loopEnd,
                          );
                        },
                        borderRadius: BorderRadius.circular(999),
                        child: actionPad(
                          child: Icon(
                            Icons.repeat_rounded,
                            color: loopColor,
                            size: 16,
                          ),
                        ),
                      );
                    },
                  ),
                  InkWell(
                    onTap: !hasCue || translating
                        ? null
                        : () => _translateLine(context, line.text, index),
                    borderRadius: BorderRadius.circular(999),
                    child: actionPad(
                      child: translating
                          ? SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                valueColor: AlwaysStoppedAnimation<Color>(
                                  scheme.primary,
                                ),
                              ),
                            )
                          : Icon(
                              translated != null
                                  ? Icons.translate
                                  : Icons.translate_outlined,
                              color: hasCue
                                  ? scheme.primary
                                  : scheme.onSurface.withOpacity(0.28),
                              size: 16,
                            ),
                    ),
                  ),
                  InkWell(
                    onTap: !hasCue
                        ? null
                        : () => _showGrammarExplanation(
                              context,
                              line.text,
                              index,
                            ),
                    borderRadius: BorderRadius.circular(999),
                    child: actionPad(
                      child: Icon(
                        Icons.lightbulb_outline,
                        color: hasCue
                            ? scheme.tertiary
                            : scheme.onSurface.withOpacity(0.28),
                        size: 16,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            // Banner adaptive = đúng bề ngang pane (inset 18).
            Padding(
              padding: EdgeInsets.fromLTRB(playerHInset, 0, playerHInset, 0),
              child: BannerAdWidget(
                adaptive: true,
                adaptiveWidth: bannerWidth,
                margin: EdgeInsets.zero,
              ),
            ),
          ],
        ),
      ),
        );
      },
    );
  }

  Future<void> _translateLine(
    BuildContext context,
    String lineText,
    int lineIndex,
  ) async {
    // Same flow as TranscriptSlide._translateLine.
    if (_lineTranslations.containsKey(lineText)) return;
    if (_lineTranslating[lineText] == true) return;

    setState(() {
      _lineTranslating[lineText] = true;
    });

    try {
      final episodeId = widget.episode.id ?? '';
      final translated = await _translationService.translateTranscriptLine(
        lineText,
        episodeId,
        lineIndex,
      );

      if (mounted) {
        setState(() {
          _lineTranslations[lineText] = translated;
          _lineTranslating[lineText] = false;
        });
        unawaited(HeartEconomyUi.maybeShowCreditsSnack(context, episodeId));
      }
    } catch (e) {
      debugPrint('Error translating line: $e');
      if (mounted) {
        setState(() {
          _lineTranslating[lineText] = false;
        });
        _showErrorSnackBar(
          context,
          e,
          onRetry: () => _translateLine(context, lineText, lineIndex),
        );
      }
    }
  }

  String _grammarMemoryKey(int lineNumber, String languageCode) =>
      '$lineNumber|$languageCode';

  Future<void> _showGrammarExplanation(
    BuildContext context,
    String sentence,
    int lineNumber,
  ) async {
    final normalizedSentence = sentence.trim();
    if (normalizedSentence.isEmpty) return;
    if (!AIConfig.enableGrammar) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(_languageManager.getText('grammarFeatureDisabled')),
        ),
      );
      return;
    }

    final targetLanguageCode = _languageManager.currentLocale.languageCode;
    final enCached = _grammarCache[
        _grammarMemoryKey(lineNumber, GrammarOpenPolicy.englishCode)];
    final targetCached =
        _grammarCache[_grammarMemoryKey(lineNumber, targetLanguageCode)];

    if (targetLanguageCode == GrammarOpenPolicy.englishCode &&
        enCached != null) {
      await _savedGrammarService.recordViewed(
        explanation: enCached,
        episode: widget.episode,
      );
      await _analyticsService.trackEvent('grammar_opened');
      if (!context.mounted) return;
      _showGrammarDialog(
        context,
        enCached,
        lineNumber: lineNumber,
        sentence: normalizedSentence,
        selectedLanguageCode: GrammarOpenPolicy.englishCode,
        targetLanguageCode: targetLanguageCode,
        englishAvailable: true,
      );
      return;
    }

    if (targetCached != null) {
      final englishAvailable =
          _grammarEnglishAvailableByLine[lineNumber] == true || enCached != null;
      await _savedGrammarService.recordViewed(
        explanation: targetCached,
        episode: widget.episode,
      );
      await _analyticsService.trackEvent('grammar_opened');
      if (!context.mounted) return;
      _showGrammarDialog(
        context,
        targetCached,
        lineNumber: lineNumber,
        sentence: normalizedSentence,
        selectedLanguageCode: targetLanguageCode,
        targetLanguageCode: targetLanguageCode,
        englishAvailable: englishAvailable,
      );
      return;
    }

    if (enCached != null) {
      _grammarEnglishAvailableByLine[lineNumber] = true;
      await _savedGrammarService.recordViewed(
        explanation: enCached,
        episode: widget.episode,
      );
      await _analyticsService.trackEvent('grammar_opened');
      if (!context.mounted) return;
      _showGrammarDialog(
        context,
        enCached,
        lineNumber: lineNumber,
        sentence: normalizedSentence,
        selectedLanguageCode: GrammarOpenPolicy.englishCode,
        targetLanguageCode: targetLanguageCode,
        englishAvailable: true,
      );
      return;
    }

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => Center(
        child: Card(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                CircularProgressIndicator(
                  valueColor: AlwaysStoppedAnimation<Color>(
                    Theme.of(context).colorScheme.primary,
                  ),
                ),
                const SizedBox(height: 16),
                Text(_languageManager.getText('analyzingGrammar')),
              ],
            ),
          ),
        ),
      ),
    );

    try {
      final result = await _grammarService.resolveSentenceExplanation(
        normalizedSentence,
        widget.episode.id ?? '',
        lineNumber: lineNumber,
      );
      _grammarCache[_grammarMemoryKey(
        lineNumber,
        result.displayLanguageCode,
      )] = result.explanation;
      _grammarEnglishAvailableByLine[lineNumber] = result.englishAvailable;
      await _savedGrammarService.recordViewed(
        explanation: result.explanation,
        episode: widget.episode,
      );
      await _analyticsService.trackEvent('grammar_opened');
      if (!context.mounted) return;
      Navigator.of(context).pop();
      _showGrammarDialog(
        context,
        result.explanation,
        lineNumber: lineNumber,
        sentence: normalizedSentence,
        selectedLanguageCode: result.displayLanguageCode,
        targetLanguageCode: targetLanguageCode,
        englishAvailable: result.englishAvailable,
      );
    } catch (e) {
      if (!context.mounted) return;
      Navigator.of(context).pop();
      _showErrorSnackBar(
        context,
        e,
        onRetry: () => _showGrammarExplanation(
          context,
          normalizedSentence,
          lineNumber,
        ),
      );
    }
  }

  Future<GrammarExplanation?> _loadGrammarForLanguage({
    required BuildContext context,
    required String sentence,
    required int lineNumber,
    required String languageCode,
  }) async {
    final cacheKey = _grammarMemoryKey(lineNumber, languageCode);
    final cached = _grammarCache[cacheKey];
    if (cached != null) return cached;
    try {
      final explanation = await _grammarService.explainSentence(
        sentence,
        widget.episode.id ?? '',
        lineNumber: lineNumber,
        languageCode: languageCode,
      );
      _grammarCache[cacheKey] = explanation;
      if (languageCode == GrammarOpenPolicy.englishCode) {
        _grammarEnglishAvailableByLine[lineNumber] = true;
      }
      return explanation;
    } catch (e) {
      if (context.mounted) {
        _showErrorSnackBar(
          context,
          e,
          onRetry: () => _loadGrammarForLanguage(
            context: context,
            sentence: sentence,
            lineNumber: lineNumber,
            languageCode: languageCode,
          ),
        );
      }
      return null;
    }
  }

  void _showGrammarDialog(
    BuildContext context,
    GrammarExplanation explanation, {
    required int lineNumber,
    required String sentence,
    required String selectedLanguageCode,
    required String targetLanguageCode,
    required bool englishAvailable,
  }) {
    var currentExplanation = explanation;
    final savedItem = _savedGrammarService.getBySentence(
      explanation.sentence,
      widget.episode.id ?? '',
    );
    final wasSaved = savedItem?.isPinned == true;
    showDialog(
      context: context,
      builder: (context) => GrammarExplanationDialog(
        explanation: explanation,
        category: widget.episode.category,
        isSaved: wasSaved,
        selectedLanguageCode: selectedLanguageCode,
        targetLanguageCode: targetLanguageCode,
        englishAvailable: englishAvailable,
        onLanguageChanged: (lang) async {
          final next = await _loadGrammarForLanguage(
            context: context,
            sentence: sentence,
            lineNumber: lineNumber,
            languageCode: lang,
          );
          if (next != null) currentExplanation = next;
          return next;
        },
        onToggleSaved: () async {
          if (!wasSaved) {
            await _maybeAskReviewReminderPermission(context);
          }
          final isSaved = await _savedGrammarService.togglePinnedForExplanation(
            explanation: currentExplanation,
            episode: widget.episode,
          );
          await _analyticsService.trackEvent('rule_saved');
          if (!context.mounted) return;
          Navigator.of(context).pop();
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                isSaved
                    ? _languageManager.getText('savedToMyLearning')
                    : _languageManager.getText('removedFromSavedGrammar'),
              ),
            ),
          );
        },
      ),
    );
  }

  Future<void> _maybeAskReviewReminderPermission(BuildContext context) async {
    if (await _reviewReminderService.hasAskedPermission()) return;
    if (!context.mounted) return;
    final allow = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(_languageManager.getText('enableReviewRemindersTitle')),
        content: Text(_languageManager.getText('enableReviewRemindersDesc')),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: Text(_languageManager.getText('later')),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: Text(_languageManager.getText('allow')),
          ),
        ],
      ),
    );
    await _reviewReminderService.markAskedPermission();
    if (allow == true) {
      await _reviewReminderService.requestNotificationPermission();
    }
  }

  /// Same as TranscriptSlide: Episode Pass / credits / hearts via HeartEconomyUi.
  Future<void> _showErrorSnackBar(
    BuildContext context,
    dynamic error, {
    required VoidCallback onRetry,
  }) async {
    final episodeId = widget.episode.id ?? '';
    final handled = await HeartEconomyUi.handleError(
      context,
      error,
      onRetry: onRetry,
      episodeId: episodeId,
    );
    if (handled || !context.mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(AIErrorHandler.getErrorMessage(error)),
        action: SnackBarAction(
          label: 'Retry',
          onPressed: onRetry,
        ),
      ),
    );
  }
}
