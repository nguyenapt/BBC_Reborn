import 'package:flutter/material.dart';
import '../models/episode.dart';
import '../models/speaking_session.dart';
import '../models/transcript_line.dart';
import '../services/ai/ai_error_handler.dart';
import '../services/audio_player_service.dart';
import '../services/language_manager.dart';
import '../services/speaking_practice_service.dart';
import '../utils/category_colors.dart';
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
    with SingleTickerProviderStateMixin {
  static const double _headerTitleScale = 0.86;
  static const double _headerSubtitleScale = 0.9;
  static const double _transcriptTextScale = 0.88;

  late final TabController _tabController;
  final SpeakingPracticeService _practiceService = SpeakingPracticeService();

  List<TranscriptLine> _lines = [];
  List<String> _speakers = [];

  TranscriptLine? _repeatSelectedLine;

  String? _roleplaySpeaker;
  int _roleplayIndex = 0;

  SpeakingSession? _repeatSession;
  SpeakingSession? _roleplaySession;

  bool _isRecording = false;
  bool _isProcessing = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _prepareTranscriptLines();
  }

  @override
  void dispose() {
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

    final speakers = _lines.map((e) => e.speaker).where((e) => e.isNotEmpty).toSet().toList();
    speakers.sort();
    _speakers = speakers;

    if (_lines.isNotEmpty) {
      _repeatSelectedLine = _lines.first;
    }
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

  Future<void> _startRecording() async {
    setState(() {
      _isRecording = true;
      _isProcessing = false;
    });
    await _practiceService.startRecording();
  }

  Future<void> _stopAndEvaluateRepeat() async {
    if (_repeatSelectedLine == null) return;
    await _ensureSession('repeat');

    setState(() {
      _isProcessing = true;
      _isRecording = false;
    });

    try {
      final result = await _practiceService.stopRecordingAndEvaluate(
        session: _repeatSession!,
        episode: widget.episode,
        mode: 'repeat',
        lineText: _repeatSelectedLine!.text,
        lineIndex: _lines.indexOf(_repeatSelectedLine!),
        speaker: _repeatSelectedLine!.speaker,
      );
      _repeatSession = result.updatedSession;
      if (!mounted) return;
      setState(() {
        _isProcessing = false;
      });
      await Navigator.of(context).push<void>(
        MaterialPageRoute<void>(
          fullscreenDialog: true,
          builder: (ctx) => SpeakingAiAnalysisScreen(
            episode: widget.episode,
            feedback: result.feedback,
            recognizedText: result.attempt.recognizedText,
          ),
        ),
      );
    } catch (e) {
      setState(() {
        _isProcessing = false;
      });
      _showError(e);
    }
  }

  Future<void> _stopAndEvaluateRoleplay() async {
    final line = _currentRoleplayLine();
    if (line == null) return;
    await _ensureSession('roleplay');

    setState(() {
      _isProcessing = true;
      _isRecording = false;
    });

    try {
      final result = await _practiceService.stopRecordingAndEvaluate(
        session: _roleplaySession!,
        episode: widget.episode,
        mode: 'roleplay',
        lineText: line.text,
        lineIndex: _lines.indexOf(line),
        speaker: line.speaker,
      );
      _roleplaySession = result.updatedSession;
      if (!mounted) return;
      setState(() {
        _roleplayIndex = _roleplayIndex + 1;
        _isProcessing = false;
      });
      await Navigator.of(context).push<void>(
        MaterialPageRoute<void>(
          fullscreenDialog: true,
          builder: (ctx) => SpeakingAiAnalysisScreen(
            episode: widget.episode,
            feedback: result.feedback,
            recognizedText: result.attempt.recognizedText,
          ),
        ),
      );
    } catch (e) {
      setState(() {
        _isProcessing = false;
      });
      _showError(e);
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

  void _showError(dynamic error) {
    final message = AIErrorHandler.getErrorMessage(error);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message)),
      );
    }
  }

  bool _roleplayIsComplete() {
    final f = _roleplayLines();
    return _roleplaySpeaker != null && f.isNotEmpty && _roleplayIndex >= f.length;
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
        final categoryColor = CategoryColors.getCategoryColor(widget.episode.category);
        final softBg = Color.lerp(
          CategoryColors.getCategoryBackgroundColor(widget.episode.category),
          Theme.of(context).colorScheme.surface,
          0.45,
        )!;
        return Scaffold(
          backgroundColor: softBg,
          appBar: AppBar(
            backgroundColor: categoryColor,
            foregroundColor: Colors.white,
            elevation: 0,
            title: Text(lm.getText('speakingPracticeTitle')),
            bottom: TabBar(
              controller: _tabController,
              labelColor: Colors.white,
              unselectedLabelColor: Colors.white70,
              indicatorColor: Colors.white,
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
          child: ListView.separated(
            padding: const EdgeInsets.fromLTRB(8, 8, 8, 24),
            itemCount: _lines.length,
            separatorBuilder: (_, __) => const SizedBox(height: 4),
            itemBuilder: (context, index) {
              final line = _lines[index];
              final selected = _repeatSelectedLine == line;
              return Material(
                color: selected
                    ? Colors.white.withValues(alpha: 0.85)
                    : Colors.transparent,
                borderRadius: BorderRadius.circular(16),
                clipBehavior: Clip.antiAlias,
                child: ListTile(
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  selected: selected,
                  selectedTileColor: Colors.white,
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
                  onTap: () {
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
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.07),
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
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      _pillRecordButton(
                        context: context,
                        onStop: _stopAndEvaluateRepeat,
                        categoryColor: categoryColor,
                        lm: lm,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          _isRecording
                              ? lm.getText('speakingHintFinishForAi')
                              : lm.getText('speakingHintPracticeSentence'),
                          style: _scaledTextStyle(
                            theme.textTheme.bodySmall,
                            _transcriptTextScale,
                            fallbackSize: 12,
                          ).copyWith(
                            color: heading.withValues(alpha: 0.55),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRoleplayPersonaBar(
    BuildContext context,
    Color softBg,
    Color categoryColor,
    Color heading,
  ) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
      child: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: Color.lerp(softBg, Colors.white, 0.35),
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
                  color: selected ? Colors.white : Colors.transparent,
                  elevation: selected ? 1 : 0,
                  shadowColor: Colors.black26,
                  borderRadius: BorderRadius.circular(999),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(999),
                    onTap: () {
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
          _buildRoleplayPersonaBar(context, softBg, categoryColor, heading),
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
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 28),
            itemCount: _lines.length + (_roleplayIsComplete() ? 1 : 0),
            itemBuilder: (context, index) {
              if (_roleplayIsComplete() && index == _lines.length) {
                return _roleplayCompleteBanner(context, categoryColor, heading, lm);
              }
              return Padding(
                padding: const EdgeInsets.only(bottom: 14),
                child: _buildRoleplayScriptLine(
                  context,
                  index,
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
        color: Colors.white,
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
        return _roleplayPastUserLine(context, line, categoryColor, heading);
      }
      return _roleplayNpcBubble(
        context,
        line,
        categoryColor,
        heading,
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
      return _roleplayPastUserLine(context, line, categoryColor, heading);
    }
    if (!isUser) {
      return _roleplayNpcBubble(
        context,
        line,
        categoryColor,
        heading,
        dimmed: showAsUpcoming,
      );
    }
    if (isUser && showAsUpcoming) {
      return _roleplayNpcBubble(
        context,
        line,
        categoryColor,
        heading,
        dimmed: true,
      );
    }
    return const SizedBox.shrink();
  }

  Widget _roleplayNpcBubble(
    BuildContext context,
    TranscriptLine line,
    Color categoryColor,
    Color heading, {
    required bool dimmed,
  }) {
    final theme = Theme.of(context);
    final opacity = dimmed ? 0.38 : 1.0;
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
  ) {
    final theme = Theme.of(context);
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
                Text(
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
              color: Colors.white,
              borderRadius: BorderRadius.circular(24),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.08),
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
                            color: Colors.white,
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
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      _pillRecordButton(
                        context: context,
                        onStop: _stopAndEvaluateRoleplay,
                        categoryColor: categoryColor,
                        lm: lm,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          _isRecording
                              ? lm.getText('speakingHintFinishForAi')
                              : lm.getText('speakingHintPracticeLineRoleplay'),
                          style: _scaledTextStyle(
                            theme.textTheme.bodySmall,
                            _transcriptTextScale,
                            fallbackSize: 12,
                          ).copyWith(
                            color: heading.withValues(alpha: 0.55),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _pillRecordButton({
    required BuildContext context,
    required Future<void> Function() onStop,
    required Color categoryColor,
    required LanguageManager lm,
  }) {
    final cta = _ctaGreen(categoryColor);
    final isDisabled = _isProcessing;

    if (_isRecording) {
      return FilledButton.icon(
        style: FilledButton.styleFrom(
          backgroundColor: cta,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(999),
          ),
        ),
        onPressed: isDisabled ? null : onStop,
        icon: const Icon(Icons.stop_rounded, size: 22),
        label: Text(lm.getText('speakingStopAndScore')),
      );
    }

    return FilledButton.icon(
      style: FilledButton.styleFrom(
        backgroundColor: cta,
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(999),
        ),
      ),
      onPressed: isDisabled ? null : _startRecording,
      icon: const Icon(Icons.mic_rounded, size: 22),
      label: Text(lm.getText('speakingStartRecording')),
    );
  }
}
