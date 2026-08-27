import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'dart:async';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../config/rtdb_list_config.dart';
import '../models/episode.dart';
import '../models/transcript_line.dart';
import '../utils/category_colors.dart';
import '../utils/category_names.dart';
import '../services/audio_player_service.dart';
import '../services/firebase_service.dart';
import '../services/local_database_service.dart';
import '../services/language_manager.dart';
import '../services/learning_progress_service.dart';
import '../services/episode_detail_wake_lock.dart';
import '../services/episode_detail_session.dart';
import '../utils/debug_source_log.dart';
import '../services/admob_service.dart';
import '../widgets/audio_player_widget.dart';
import '../widgets/episode_info_slide.dart';
import '../widgets/transcript_slide.dart';
import '../widgets/vocabulary_slide.dart';
import '../widgets/heart_widget.dart';
import '../widgets/question_slide.dart';
import '../widgets/learning_checklist_bar.dart';
import '../widgets/episode_detail_tab_panel.dart';
import 'speaking_practice_screen.dart';
import 'speaking_history_screen.dart';

class EpisodeDetailScreen extends StatefulWidget {
  final Episode episode;
  final List<Episode> categoryEpisodes;

  const EpisodeDetailScreen({
    super.key,
    required this.episode,
    required this.categoryEpisodes,
  });

  @override
  State<EpisodeDetailScreen> createState() => _EpisodeDetailScreenState();
}

class _EpisodeDetailScreenState extends State<EpisodeDetailScreen> {
  static const String _prefAutoPlayNoticeShown = 'auto_play_enabled_notice_shown';

  static const double _playerBottomOffset = 10;
  static const double _contentPlayerGap = 16;
  static const double _fallbackPlayerHeight = 88;

  late final AudioPlayerService _audioService;
  late final PageController _pageController;
  late final LanguageManager _languageManager;
  final LearningProgressService _learningProgress = LearningProgressService();
  final GlobalKey _playerKey = GlobalKey();
  late Episode _episode;
  bool _hydratingFullEpisode = false;
  int _currentPageIndex = 0; // Transcript
  int _scrollToActiveTranscriptRequestId = 0;
  bool _isHandlingBackNavigation = false;
  double _playerHeight = _fallbackPlayerHeight;
  List<TranscriptLine> _parsedTranscriptLines = [];
  late final VoidCallback _audioServiceListener;
  bool _exitFinalized = false;

  bool _mustFetchFullEpisode(Episode e) {
    if (!RtdbListConfig.useSlimListPaths) return false;
    if (e.transcript.trim().isNotEmpty) return false;
    final html = e.transcriptHtml?.trim();
    if (html != null && html.isNotEmpty) return false;
    final id = e.id;
    if (id == null || id.isEmpty) return false;
    return true;
  }

  @override
  void initState() {
    super.initState();
    _episode = widget.episode;
    _rebuildParsedTranscriptLines();
    _hydratingFullEpisode = _mustFetchFullEpisode(_episode);
    _audioService = AudioPlayerService();
    EpisodeDetailSession.acquire();
    _languageManager = LanguageManager();
    final saved = _learningProgress.getProgress(
      LearningProgressService.episodeKey(_episode),
    );
    final initialTab = (saved?.lastTabIndex ?? 0).clamp(0, 3);
    _currentPageIndex = initialTab;
    _pageController = PageController(initialPage: initialTab);

    if (saved != null &&
        saved.lastPositionMs > 0 &&
        !saved.listenedComplete) {
      final total = saved.totalDurationMs;
      final nearEnd = total > 0 &&
          saved.lastPositionMs >= (total * 0.92).round();
      if (!nearEnd) {
        _audioService.setPendingSeekPosition(
          Duration(milliseconds: saved.lastPositionMs),
        );
      }
    }

    // Load episode vào audio service với category episodes
    _audioService.loadEpisodeWithCategory(_episode, widget.categoryEpisodes);
    unawaited(_learningProgress.touchEpisode(_episode));
    _scheduleDebugDetailFetchNotice();
    Future.microtask(_hydrateFullEpisodeIfNeeded);
    _scheduleDebugSqliteSourceNotice(widget.episode);

    // Bật Always Display (Wakelock) để màn hình không tự tắt
    unawaited(EpisodeDetailWakeLock.acquire());
    
    // Tạo interstitial ad để sẵn sàng hiển thị
    AdMobService().createInterstitialAd();
    
    _audioServiceListener = _onAudioServiceEpisodeChanged;
    _audioService.addListener(_audioServiceListener);

    _scheduleMeasurePlayerHeight();
  }

  void _onAudioServiceEpisodeChanged() {
    final current = _audioService.currentEpisode;
    if (current == null) return;
    if (current.id == _episode.id) {
      // Hydrate lần đầu có thể xong trước khi currentEpisode được gán.
      if (_mustFetchFullEpisode(_episode) && !_hydratingFullEpisode && mounted) {
        setState(() => _hydratingFullEpisode = true);
        Future.microtask(_hydrateFullEpisodeIfNeeded);
      }
      return;
    }

    final inCategory = widget.categoryEpisodes.any((e) => e.id == current.id);
    if (!inCategory) return;

    final idx =
        widget.categoryEpisodes.indexWhere((e) => e.id == current.id);
    final nextEpisode =
        idx >= 0 ? widget.categoryEpisodes[idx] : current;

    if (!mounted) return;
    setState(() {
      _episode = nextEpisode;
      _hydratingFullEpisode = _mustFetchFullEpisode(_episode);
      _rebuildParsedTranscriptLines();
      _currentPageIndex = 0;
    });
    _pageController.jumpToPage(0);
    unawaited(_learningProgress.touchEpisode(_episode));
    Future.microtask(_hydrateFullEpisodeIfNeeded);
    _scheduleDebugSqliteSourceNotice(_episode);
  }

  Future<void> _onAutoPlayEnabledFirstTime() async {
    if (!mounted) return;
    final prefs = await SharedPreferences.getInstance();
    if (prefs.getBool(_prefAutoPlayNoticeShown) ?? false) return;
    await prefs.setBool(_prefAutoPlayNoticeShown, true);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 3),
        content: Text(_languageManager.getText('autoPlayEnabledHint')),
      ),
    );
  }

  Future<bool> _onWillPopShowInterstitial() async {
    if (_isHandlingBackNavigation) return false;
    _isHandlingBackNavigation = true;
    AdMobService().showInterstitialAd(
      context: context,
      onDismissedOrUnavailable: () {
        if (!mounted) return;
        _isHandlingBackNavigation = false;
        Navigator.of(context).pop();
      },
    );
    return false;
  }

  @override
  void didUpdateWidget(EpisodeDetailScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.episode.id != widget.episode.id ||
        oldWidget.episode.episodeName != widget.episode.episodeName) {
      _episode = widget.episode;
      setState(() {
        _hydratingFullEpisode = _mustFetchFullEpisode(_episode);
        _rebuildParsedTranscriptLines();
      });
      _audioService.loadEpisodeWithCategory(_episode, widget.categoryEpisodes);
      Future.microtask(_hydrateFullEpisodeIfNeeded);
      _scheduleDebugSqliteSourceNotice(widget.episode);
    }
    _scheduleMeasurePlayerHeight();
  }

  void _scheduleMeasurePlayerHeight() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final ctx = _playerKey.currentContext;
      if (ctx == null) return;
      final size = ctx.size;
      if (size == null) return;
      final measured = size.height;
      if ((_playerHeight - measured).abs() > 0.5) {
        setState(() {
          _playerHeight = measured;
        });
      }
    });
  }

  double _contentBottomInset(BuildContext context) {
    final safeBottom = MediaQuery.viewPaddingOf(context).bottom;
    return _playerHeight +
        _playerBottomOffset +
        _contentPlayerGap +
        safeBottom;
  }

  /// Cố định — không đổi khi player mở rộng panel transcript.
  double _checklistBottomInset(BuildContext context) {
    final safeBottom = MediaQuery.viewPaddingOf(context).bottom;
    return _fallbackPlayerHeight + _playerBottomOffset + safeBottom;
  }

  void _rebuildParsedTranscriptLines() {
    if (_episode.transcriptHtml != null && _episode.transcriptHtml!.isNotEmpty) {
      _parsedTranscriptLines =
          TranscriptLine.parseTranscriptHtml(_episode.transcriptHtml);
      return;
    }
    if (_episode.transcript.isNotEmpty) {
      _parsedTranscriptLines = _episode.transcript
          .split('\n')
          .where((line) => line.trim().isNotEmpty)
          .map(
            (line) => TranscriptLine(
              startTime: 0,
              endTime: 0,
              speaker: '',
              text: line.trim(),
            ),
          )
          .toList();
      return;
    }
    _parsedTranscriptLines = [];
  }

  TranscriptLine? _currentActiveTranscriptLine() {
    if (_parsedTranscriptLines.isEmpty) return null;
    final currentMs = _audioService.currentPositionMs;
    if (currentMs <= 0) return null;
    for (final line in _parsedTranscriptLines) {
      if (line.startTime == 0 && line.endTime == 0) {
        continue;
      }
      if (line.isActiveAt(currentMs)) {
        return line;
      }
    }
    return null;
  }

  void _focusCurrentTranscriptLine() {
    final activeLine = _currentActiveTranscriptLine();
    if (activeLine == null) return;
    setState(() {
      _currentPageIndex = 0;
      _scrollToActiveTranscriptRequestId++;
    });
    _pageController.animateToPage(
      0,
      duration: const Duration(milliseconds: 280),
      curve: Curves.easeOutCubic,
    );
  }

  /// Debug: báo đường dẫn sẽ dùng khi mở detail từ Home/List.
  void _scheduleDebugDetailFetchNotice() {
    if (!kDebugMode) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (_mustFetchFullEpisode(_episode)) {
        debugLogDataSource(
          'EpisodeDetail',
          FirebaseService.describeEpisodeDetailRequest(_episode),
        );
        return;
      }
      final rtdb = _episode.rtdbPath?.trim();
      if (rtdb != null && rtdb.isNotEmpty) {
        debugLogDataSource(
          'EpisodeDetail',
          'Không fetch RTDB — transcript có sẵn (RtdbPath=$rtdb)',
        );
      } else {
        debugLogDataSource(
          'EpisodeDetail',
          'Không fetch RTDB — transcript có sẵn trên list/home',
        );
      }
    });
  }

  /// Chỉ [kDebugMode], không web: báo khi detail hiển thị transcript có sẵn trùng với bản đầy đủ trong SQLite.
  void _scheduleDebugSqliteSourceNotice(Episode episodeAtOpen) {
    if (!kDebugMode || kIsWeb) return;
    final id = episodeAtOpen.id;
    if (id == null || id.isEmpty) return;
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) return;
      if (_mustFetchFullEpisode(episodeAtOpen)) return;
      if (episodeAtOpen.transcript.trim().isEmpty) return;
      final fromDb = await LocalDatabaseService().getEpisodeById(id);
      if (fromDb == null || fromDb.transcript.trim().isEmpty) return;
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          behavior: SnackBarBehavior.floating,
          content: Text('[Debug] Detail: đọc từ SQLite ($id)'),
          duration: const Duration(seconds: 4),
        ),
      );
    });
  }

  /// List `List/...` không có transcript — tải bản đầy đủ từ tree gốc và ghi SQLite.
  Future<void> _hydrateFullEpisodeIfNeeded() async {
    final targetId = _episode.id;
    if (targetId == null || targetId.isEmpty) return;

    if (!_mustFetchFullEpisode(_episode)) {
      if (mounted) setState(() => _hydratingFullEpisode = false);
      return;
    }

    try {
      final outcome = await FirebaseService.fetchEpisodeFullWithSource(_episode);
      final full = outcome.episode;
      if (!mounted || full == null) {
        if (mounted) setState(() => _hydratingFullEpisode = false);
        return;
      }
      // Không đòi currentEpisode khớp: cold start nó còn null khi đang stop().
      if (_episode.id != targetId) {
        if (mounted) setState(() => _hydratingFullEpisode = false);
        return;
      }
      setState(() {
        _episode = full;
        _hydratingFullEpisode = false;
        _rebuildParsedTranscriptLines();
      });
      if (_audioService.currentEpisode?.id == targetId) {
        await _audioService.refreshEpisodeData(_episode);
      }
      try {
        await LocalDatabaseService().upsertEpisode(full);
      } catch (e, st) {
        debugPrint('upsert after hydrate (non-fatal): $e\n$st');
      }
    } catch (e, st) {
      debugPrint('hydrate episode: $e\n$st');
      if (mounted) setState(() => _hydratingFullEpisode = false);
    }
  }

  Future<void> _finalizeEpisodeDetailExit() async {
    if (_exitFinalized) return;
    _exitFinalized = true;

    final positionMs = _audioService.currentPosition.inMilliseconds;
    final totalDurationMs = _audioService.totalDuration.inMilliseconds;
    final tabIndex = _currentPageIndex;
    final episode = _episode;

    await _learningProgress.flushEpisodeState(
      episode: episode,
      positionMs: positionMs,
      totalDurationMs: totalDurationMs,
      tabIndex: tabIndex,
    );
    await _audioService.stop();
    await EpisodeDetailWakeLock.release();
    EpisodeDetailSession.release();
  }

  @override
  void dispose() {
    _audioService.removeListener(_audioServiceListener);
    _pageController.dispose();
    unawaited(_finalizeEpisodeDetailExit());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    _scheduleMeasurePlayerHeight();
    return ListenableBuilder(
      listenable: _languageManager,
      builder: (context, child) {
        final categoryColor = CategoryColors.getCategoryColor(_episode.category);
        
        return WillPopScope(
          onWillPop: _onWillPopShowInterstitial,
          child: Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surface,
      appBar: AppBar(
        backgroundColor: categoryColor,
        foregroundColor: Theme.of(context).colorScheme.onPrimary,
        elevation: 0,
        actions: [
          IconButton(
            onPressed: () async {
              final completed = await Navigator.push<bool>(
                context,
                MaterialPageRoute(
                  builder: (context) => SpeakingPracticeScreen(
                    episode: _episode,
                    audioService: _audioService,
                  ),
                ),
              );
              if (mounted && completed == true) {
                await _learningProgress.markSpeakingDone(_episode);
                setState(() {});
              }
            },
            icon: const Icon(Icons.mic),
          ),
          IconButton(
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const SpeakingHistoryScreen(),
                ),
              );
            },
            icon: const Icon(Icons.history),
          ),
          // Favourite button
          ListenableBuilder(
            listenable: _audioService,
            builder: (context, child) {
              return IconButton(
                onPressed: () => _audioService.toggleFavourite(),
                icon: Icon(
                  _audioService.isFavourite ? Icons.favorite : Icons.favorite_border,
                  color: Theme.of(context).colorScheme.onPrimary,
                ),
              );
            },
          ),
          // Download button
          ListenableBuilder(
            listenable: _audioService,
            builder: (context, child) {
              return IconButton(
                onPressed: _audioService.isDownloaded 
                    ? null 
                    : () => _audioService.downloadEpisode(),
                icon: Icon(
                  _audioService.isDownloaded ? Icons.download_done : Icons.download,
                  color: Theme.of(context).colorScheme.onPrimary,
                ),
              );
            },
          ),
          Builder(
            builder: (context) {
              final safe = MediaQuery.of(context).padding.top;
              final panelTop = safe + kToolbarHeight;
              return Padding(
                padding: const EdgeInsets.only(left: 4, right: 10),
                child: Center(
                  child: HeartWidget(panelTop: panelTop, compact: true),
                ),
              );
            },
          ),
        ],
      ),
      body: Stack(
        clipBehavior: Clip.none,
        children: [
          Column(
            children: [
              // Episode Name Header
              Container(
            width: double.infinity,
            padding: const EdgeInsets.fromLTRB(12, 10, 12, 8),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surface,
              border: Border(
                bottom: BorderSide(
                  color: categoryColor.withOpacity(0.2),
                  width: 1,
                ),
              ),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      SelectableText(
                        _episode.episodeName,
                        textAlign: TextAlign.left,
                        style: TextStyle(
                          fontSize: 17.5,
                          fontWeight: FontWeight.w700,
                          height: 1.25,
                          letterSpacing: -0.2,
                          color: Theme.of(context)
                              .colorScheme
                              .onSurface
                              .withOpacity(0.95),
                        ),
                        contextMenuBuilder: (context, editableTextState) {
                          return AdaptiveTextSelectionToolbar.buttonItems(
                            anchors: editableTextState.contextMenuAnchors,
                            buttonItems: <ContextMenuButtonItem>[
                              ContextMenuButtonItem(
                                label: 'Copy',
                                onPressed: () {
                                  final selectedText = editableTextState
                                      .textEditingValue.selection
                                      .textInside(
                                    editableTextState.textEditingValue.text,
                                  );
                                  if (selectedText.isNotEmpty) {
                                    Clipboard.setData(
                                      ClipboardData(text: selectedText),
                                    );
                                    editableTextState.hideToolbar();
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                        content: Text(
                                          _languageManager
                                              .getText('copiedToClipboard'),
                                        ),
                                      ),
                                    );
                                  }
                                },
                              ),
                              ContextMenuButtonItem(
                                label: 'Translate',
                                onPressed: () {
                                  final selectedText = editableTextState
                                      .textEditingValue.selection
                                      .textInside(
                                    editableTextState.textEditingValue.text,
                                  );
                                  if (selectedText.isNotEmpty) {
                                    _openGoogleTranslate(selectedText);
                                    editableTextState.hideToolbar();
                                  }
                                },
                              ),
                            ],
                          );
                        },
                      ),
                      const SizedBox(height: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 7,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: categoryColor,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          _episode.category,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 10),
                // Right: fixed top — duration / published date (không theo chiều cao title)
                Padding(
                  padding: const EdgeInsets.only(top: 2),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(
                            Icons.access_time_filled_rounded,
                            size: 15,
                            color: Color(0xFFE65100), // cam đậm
                          ),
                          const SizedBox(width: 3),
                          Text(
                            _episode.duration,
                            style: TextStyle(
                              fontSize: 12,
                              color: Theme.of(context)
                                  .colorScheme
                                  .onSurface
                                  .withOpacity(0.55),
                            ),
                          ),
                        ],
                      ),
                      if (!_isOtherProgramsCategory(_episode.category)) ...[
                        const SizedBox(height: 6),
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(
                              Icons.calendar_month_rounded,
                              size: 14,
                              color: Color(0xFF1565C0), // xanh dương đậm
                            ),
                            const SizedBox(width: 3),
                            Text(
                              _formatDate(_episode.publishedDate),
                              style: TextStyle(
                                fontSize: 12,
                                color: Theme.of(context)
                                    .colorScheme
                                    .onSurface
                                    .withOpacity(0.55),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
          _buildDetailTabs(context, categoryColor),
          Expanded(
            child: Builder(
              builder: (context) {
                final scrollBottomInset = _contentBottomInset(context);
                return PageView(
                  controller: _pageController,
                  onPageChanged: (index) {
                    setState(() {
                      _currentPageIndex = index;
                    });
                    unawaited(
                      _learningProgress.updateTabIndex(
                        episode: _episode,
                        tabIndex: index,
                      ),
                    );
                  },
                  children: [
                    ListenableBuilder(
                      listenable: _audioService,
                      builder: (context, child) {
                        return TranscriptSlide(
                          episode: _episode,
                          learningProgress: _learningProgress,
                          isAwaitingFullEpisode: _hydratingFullEpisode,
                          scrollBottomInset: scrollBottomInset,
                          currentPositionMs: _audioService.currentPositionMs,
                          scrollToActiveRequestId:
                              _scrollToActiveTranscriptRequestId,
                          onPlayAtTime: (startTimeMs) {
                            _audioService.seekTo(
                              Duration(milliseconds: startTimeMs),
                            );
                            _audioService.play();
                          },
                        );
                      },
                    ),
                    EpisodeInfoSlide(
                      languageManager: _languageManager,
                      episode: _episode,
                      scrollBottomInset: scrollBottomInset,
                      topEpisodes: widget.categoryEpisodes,
                      onEpisodeTap: (episode) {
                        Navigator.pushReplacement(
                          context,
                          MaterialPageRoute(
                            builder: (context) => EpisodeDetailScreen(
                              episode: episode,
                              categoryEpisodes: widget.categoryEpisodes,
                            ),
                          ),
                        );
                      },
                    ),
                    VocabularySlide(
                      episode: _episode,
                      isAwaitingFullEpisode: _hydratingFullEpisode,
                      scrollBottomInset: scrollBottomInset,
                    ),
                    QuestionSlide(
                      episode: _episode,
                      isAwaitingFullEpisode: _hydratingFullEpisode,
                      scrollBottomInset: scrollBottomInset,
                    ),
                  ],
                );
              },
            ),
          ),
            ],
          ),
          Positioned(
            right: LearningChecklistBar.laneOuterPadding,
            top: 0,
            bottom: _checklistBottomInset(context),
            child: SafeArea(
              child: Align(
                alignment: Alignment.centerRight,
                child: ListenableBuilder(
                  listenable: _learningProgress,
                  builder: (context, child) {
                    return LearningChecklistBar(
                      accentColor: categoryColor,
                      progress: _learningProgress.getProgress(
                        LearningProgressService.episodeKey(_episode),
                      ),
                      onStepTap: (tabIndex) {
                        setState(() => _currentPageIndex = tabIndex);
                        _pageController.animateToPage(
                          tabIndex,
                          duration: const Duration(milliseconds: 280),
                          curve: Curves.easeOutCubic,
                        );
                      },
                    );
                  },
                ),
              ),
            ),
          ),
          Positioned(
            left: EpisodeDetailTabPanel.contentHorizontalInset,
            right: EpisodeDetailTabPanel.contentHorizontalInset,
            bottom: _playerBottomOffset +
                MediaQuery.viewPaddingOf(context).bottom,
            child: ListenableBuilder(
              listenable: _audioService,
              builder: (context, child) {
                _scheduleMeasurePlayerHeight();
                final activeLine = _currentActiveTranscriptLine();
                final shouldShowCurrentPanel = activeLine != null &&
                    (_audioService.isPlaying ||
                        _audioService.isPaused ||
                        _audioService.currentPositionMs > 0);
                final speaker = activeLine != null && activeLine.speaker.trim().isNotEmpty
                    ? activeLine.speaker.toUpperCase()
                    : _languageManager.getText('speakerDefault');
                final lineText = activeLine?.text.trim().isNotEmpty == true
                    ? activeLine!.text
                    : '...';
                return KeyedSubtree(
                  key: _playerKey,
                  child: AudioPlayerWidget(
                    audioService: _audioService,
                    currentSpeaker: speaker,
                    currentLineText: lineText,
                    showCurrentPanel: shouldShowCurrentPanel,
                    onCurrentPanelTap: _focusCurrentTranscriptLine,
                    onPlayPressed: null,
                    onAutoPlayEnabled: _onAutoPlayEnabledFirstTime,
                  ),
                );
              },
            ),
          ),
        ],
      ),
        ),
        );
      },
    );
  }

  Widget _buildDetailTabs(BuildContext context, Color categoryColor) {
    final muted = Theme.of(context).colorScheme.onSurface.withOpacity(0.55);
    final tabs = <({IconData icon, String label})>[
      (icon: Icons.description_rounded, label: _languageManager.getText('transcript')),
      (icon: Icons.menu_book_rounded, label: _languageManager.getText('reference')),
      (icon: Icons.translate_rounded, label: _languageManager.getText('vocabulary')),
      (icon: Icons.quiz_outlined, label: _languageManager.getText('questionsTab')),
    ];

    const tabRadius = 10.0;

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.fromLTRB(12, 6, 12, 2),
      child: Row(
        children: [
          ...List.generate(tabs.length, (i) {
          final selected = _currentPageIndex == i;
          final t = tabs[i];
          return Padding(
            padding: EdgeInsets.only(left: i == 0 ? 0 : 2, right: 2),
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                borderRadius: BorderRadius.circular(tabRadius),
                onTap: () {
                  _pageController.animateToPage(
                    i,
                    duration: const Duration(milliseconds: 320),
                    curve: Curves.easeOutCubic,
                  );
                },
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 7),
                  decoration: BoxDecoration(
                    color: selected ? categoryColor.withOpacity(0.22) : Colors.transparent,
                    borderRadius: BorderRadius.circular(tabRadius),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        t.icon,
                        size: 18,
                        color: selected ? categoryColor : muted,
                      ),
                      const SizedBox(width: 5),
                      Text(
                        t.label,
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                          color: selected ? categoryColor : muted,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          );
        }),
        const SizedBox(width: 4),
      ],
      ),
    );
  }

  bool _isOtherProgramsCategory(String category) {
    return CategoryNames.anotherSeriesFixedProgramCodes.contains(category) ||
        CategoryNames.isAnotherSeriesSubcategory(category);
  }

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final difference = now.difference(date).inDays;
    
    if (difference == 0) {
      return _languageManager.getText('today');
    } else if (difference == 1) {
      return _languageManager.getText('yesterday');
    } else if (difference < 7) {
      return _languageManager.getTextWithParams('daysAgo', {'count': difference});
    } else {
      return '${date.day}/${date.month}/${date.year}';
    }
  }

  Future<void> _openGoogleTranslate(String text) async {
    // URL encode text để truyền vào Google Translate
    final encodedText = Uri.encodeComponent(text);
    // URL Google Translate với text đã chọn
    final translateUrl = 'https://translate.google.com/?sl=auto&tl=vi&text=$encodedText';
    
    try {
      final Uri url = Uri.parse(translateUrl);
      if (await canLaunchUrl(url)) {
        await launchUrl(url, mode: LaunchMode.externalApplication);
      } else {
        throw Exception('Could not launch Google Translate');
      }
    } catch (e) {
      debugPrint('Error opening Google Translate: $e');
      // Hiển thị thông báo lỗi
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              _languageManager.getText('googleTranslateOpenFailed'),
            ),
          ),
        );
      }
    }
  }
}
