import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:wakelock_plus/wakelock_plus.dart';
import '../config/rtdb_list_config.dart';
import '../models/episode.dart';
import '../models/transcript_line.dart';
import '../utils/category_colors.dart';
import '../utils/category_names.dart';
import '../services/audio_player_service.dart';
import '../services/firebase_service.dart';
import '../services/local_database_service.dart';
import '../services/language_manager.dart';
import '../services/admob_service.dart';
import '../widgets/audio_player_widget.dart';
import '../widgets/episode_info_slide.dart';
import '../widgets/transcript_slide.dart';
import '../widgets/vocabulary_slide.dart';
import '../widgets/heart_widget.dart';
import '../widgets/question_slide.dart';
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
  static const double _playerBottomOffset = 10;
  static const double _contentPlayerGap = 16;
  static const double _fallbackPlayerHeight = 88;

  late final AudioPlayerService _audioService;
  late final PageController _pageController;
  late final LanguageManager _languageManager;
  final GlobalKey _playerKey = GlobalKey();
  late Episode _episode;
  bool _hydratingFullEpisode = false;
  int _currentPageIndex = 0; // Transcript
  int _scrollToActiveTranscriptRequestId = 0;
  bool _isHandlingBackNavigation = false;
  double _playerHeight = _fallbackPlayerHeight;
  List<TranscriptLine> _parsedTranscriptLines = [];

  bool _mustFetchFullEpisode(Episode e) {
    if (!RtdbListConfig.useSlimListPaths) return false;
    if (e.transcript.trim().isNotEmpty) return false;
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
    _languageManager = LanguageManager();
    _pageController = PageController(initialPage: 0);

    // Load episode vào audio service với category episodes
    _audioService.loadEpisodeWithCategory(_episode, widget.categoryEpisodes);
    Future.microtask(_hydrateFullEpisodeIfNeeded);
    _scheduleDebugSqliteSourceNotice(widget.episode);

    // Bật Always Display (Wakelock) để màn hình không tự tắt
    _enableAlwaysDisplay();
    
    // Tạo interstitial ad để sẵn sàng hiển thị
    AdMobService().createInterstitialAd();
    
    _scheduleMeasurePlayerHeight();
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
    final safeBottom = MediaQuery.of(context).padding.bottom;
    return _playerHeight +
        _playerBottomOffset +
        _contentPlayerGap +
        safeBottom;
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
    if (!_mustFetchFullEpisode(_episode)) {
      if (mounted) setState(() => _hydratingFullEpisode = false);
      return;
    }

    try {
      final full = await FirebaseService.fetchEpisodeFull(_episode);
      if (!mounted || full == null) {
        if (mounted) setState(() => _hydratingFullEpisode = false);
        return;
      }
      // Cập nhật UI trước — SQLite (đặc biệt web) có thể lỗi; không được chặn hiển thị transcript.
      setState(() {
        _episode = full;
        _hydratingFullEpisode = false;
        _rebuildParsedTranscriptLines();
      });
      await _audioService.loadEpisodeWithCategory(_episode, widget.categoryEpisodes);
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

  // Bật Always Display
  Future<void> _enableAlwaysDisplay() async {
    try {
      await WakelockPlus.enable();
      print('Always Display enabled - Screen will stay on');
    } catch (e) {
      print('Failed to enable Always Display: $e');
    }
  }

  // Tắt Always Display
  Future<void> _disableAlwaysDisplay() async {
    try {
      await WakelockPlus.disable();
      print('Always Display disabled - Screen can turn off');
    } catch (e) {
      print('Failed to disable Always Display: $e');
    }
  }

  @override
  void dispose() {
    _pageController.dispose();
    // Release audio player khi rời khỏi màn hình
    _audioService.stop();
    
    // Tắt Always Display khi rời khỏi màn hình
    _disableAlwaysDisplay();
    
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
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => SpeakingPracticeScreen(
                    episode: _episode,
                    audioService: _audioService,
                  ),
                ),
              );
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
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surface,
              border: Border(
                bottom: BorderSide(
                  color: categoryColor.withOpacity(0.2),
                  width: 1,
                ),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                // Category Badge and Episode Name - Cùng một dòng
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    // Category Badge
                    Container(
                      margin: const EdgeInsets.only(right: 1),
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: categoryColor,
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Text(
                        _episode.category,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    // Episode Name
                    Expanded(
                      child: SelectableText(
                        _episode.episodeName,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          height: 1.3,
                          color: Theme.of(context).colorScheme.onSurface,
                        ),
                        contextMenuBuilder: (context, editableTextState) {
                          return AdaptiveTextSelectionToolbar.buttonItems(
                            anchors: editableTextState.contextMenuAnchors,
                            buttonItems: <ContextMenuButtonItem>[
                              ContextMenuButtonItem(
                                label: 'Copy',
                                onPressed: () {
                                  final selectedText = editableTextState.textEditingValue.selection.textInside(
                                    editableTextState.textEditingValue.text,
                                  );
                                  if (selectedText.isNotEmpty) {
                                    Clipboard.setData(ClipboardData(text: selectedText));
                                    editableTextState.hideToolbar();
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                        content: Text(
                                          _languageManager.getText('copiedToClipboard'),
                                        ),
                                      ),
                                    );
                                  }
                                },
                              ),
                              ContextMenuButtonItem(
                                label: 'Translate',
                                onPressed: () {
                                  final selectedText = editableTextState.textEditingValue.selection.textInside(
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
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                // Duration and Date - Cùng một dòng
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    // Duration and Date (bỏ date nếu là Other Programs category)
                    Row(
                      children: [
                        Icon(
                          Icons.access_time,
                          size: 16,
                          color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
                        ),
                        const SizedBox(width: 4),
                        Text(
                          _episode.duration,
                          style: TextStyle(
                            fontSize: 14,
                            color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
                          ),
                        ),
                        // Chỉ hiển thị date nếu không phải Other Programs category
                        if (!_isOtherProgramsCategory(_episode.category)) ...[
                          const SizedBox(width: 16),
                          Icon(
                            Icons.calendar_today,
                            size: 16,
                            color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
                          ),
                          const SizedBox(width: 4),
                          Text(
                            _formatDate(_episode.publishedDate),
                            style: TextStyle(
                              fontSize: 14,
                              color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ],
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
                  },
                  children: [
                    ListenableBuilder(
                      listenable: _audioService,
                      builder: (context, child) {
                        return TranscriptSlide(
                          episode: _episode,
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
            left: 10,
            right: 10,
            bottom: 10,
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
      padding: const EdgeInsets.fromLTRB(4, 6, 10, 2),
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
