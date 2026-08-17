import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'dart:async';
import 'package:url_launcher/url_launcher.dart';
import '../models/episode.dart';
import '../models/transcript_line.dart';
import '../utils/category_colors.dart';
import '../services/ai_translation_service.dart';
import '../services/ai_grammar_service.dart';
import '../services/ai/ai_error_handler.dart';
import '../services/ai/exceptions.dart';
import '../models/grammar_explanation.dart';
import '../services/learning_progress_service.dart';
import '../services/language_manager.dart';
import '../services/admob_service.dart';
import '../services/heart_service.dart';
import '../services/saved_grammar_service.dart';
import '../services/learning_analytics_service.dart';
import '../services/review_reminder_service.dart';
import '../config/ai_config.dart';
import 'grammar_explanation_widget.dart';
import 'transcript_native_ad_widget.dart';
import 'episode_tab_skeleton.dart';
import 'episode_detail_tab_panel.dart';

class TranscriptSlide extends StatefulWidget {
  final Episode episode;
  final int? currentPositionMs; // Vị trí audio hiện tại (milliseconds)
  final Function(int startTimeMs)? onPlayAtTime; // Callback để play tại thời điểm cụ thể
  final int scrollToActiveRequestId;
  /// Đang tải transcript đầy đủ từ RTDB (list mỏng) — hiển thị skeleton thay vì "No transcript".
  final bool isAwaitingFullEpisode;

  /// Clearance above floating player (from [EpisodeDetailScreen]).
  final double scrollBottomInset;
  final LearningProgressService learningProgress;

  const TranscriptSlide({
    super.key,
    required this.episode,
    required this.learningProgress,
    this.currentPositionMs,
    this.onPlayAtTime,
    this.scrollToActiveRequestId = 0,
    this.isAwaitingFullEpisode = false,
    this.scrollBottomInset = 0,
  });

  @override
  State<TranscriptSlide> createState() => _TranscriptSlideState();
}

class _TranscriptSlideState extends State<TranscriptSlide>
    with SingleTickerProviderStateMixin {
  static const double _transcriptDoneLineRatio = 0.66;
  static const int _shortTranscriptLineThreshold = 5;
  static const Duration _shortTranscriptDwell = Duration(seconds: 18);
  static const double _lineVisibleFractionThreshold = 0.5;

  late List<TranscriptLine> transcriptLines;
  late ScrollController _scrollController;
  List<GlobalKey> _lineKeys = [];
  final Set<int> _seenLineIndices = {};
  int? _currentActiveIndex;
  List<int> _adPositions = [];
  bool _transcriptMarked = false;
  bool _hasScrolled = false;
  Timer? _shortTranscriptDwellTimer;
  
  // Translation state
  bool _showTranslation = false;
  Map<String, String>? _translations;
  bool _isTranslating = false;
  final AITranslationService _translationService = AITranslationService();
  final LanguageManager _languageManager = LanguageManager();
  
  // Grammar state
  final AIGrammarService _grammarService = AIGrammarService();
  final SavedGrammarService _savedGrammarService = SavedGrammarService();
  final ReviewReminderService _reviewReminderService = ReviewReminderService();
  final LearningAnalyticsService _analyticsService = LearningAnalyticsService();
  final Map<String, GrammarExplanation> _grammarCache = {};
  final Map<int, bool> _grammarEnglishAvailableByLine = {};
  late final AnimationController _breathController;
  
  // Line translation state (cache translations for each line)
  final Map<String, String> _lineTranslations = {};
  final Map<String, bool> _lineTranslating = {};

  @override
  void initState() {
    super.initState();
    _breathController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat(reverse: true);
    _scrollController = ScrollController();
    _scrollController.addListener(_onScroll);
    _buildTranscriptLinesFromEpisode();
    _calculateAdPositions();
    _updateActiveLine();
    _syncTranscriptMarkedFromProgress();
    _scheduleShortTranscriptDwellIfNeeded();
  }

  void _syncTranscriptMarkedFromProgress() {
    final progress = widget.learningProgress.getProgressForEpisode(widget.episode);
    _transcriptMarked = progress?.transcriptViewed == true;
  }

  void _scheduleShortTranscriptDwellIfNeeded() {
    if (_transcriptMarked) return;
    if (transcriptLines.length >= _shortTranscriptLineThreshold) return;
    if (transcriptLines.isEmpty) return;
    _shortTranscriptDwellTimer?.cancel();
    _shortTranscriptDwellTimer = Timer(_shortTranscriptDwell, () {
      if (!mounted || _transcriptMarked) return;
      if (_hasScrolled) {
        unawaited(_markTranscriptViewed());
      }
    });
  }

  /// Parse từ [widget.episode] — gọi lại khi parent hydrate transcript (vd. list RTDB mỏng → đầy đủ).
  void _buildTranscriptLinesFromEpisode() {
    final ep = widget.episode;
    // Ưu tiên sử dụng transcriptHtml (có time info)
    if (ep.transcriptHtml != null && ep.transcriptHtml!.isNotEmpty) {
      transcriptLines = TranscriptLine.parseTranscriptHtml(ep.transcriptHtml);

      if (transcriptLines.isNotEmpty &&
          transcriptLines.every((line) => line.startTime == 0 && line.endTime == 0)) {
        final lines = ep.transcriptHtml!.split('\n').where((line) => line.trim().isNotEmpty).toList();
        transcriptLines = lines
            .map((line) {
              return TranscriptLine(
                speaker: 'Speaker',
                text: line.trim(),
                startTime: 0,
                endTime: 0,
              );
            })
            .toList()
            .cast<TranscriptLine>();
      } else if (transcriptLines.isEmpty) {
        if (ep.transcript.isNotEmpty) {
          final lines = ep.transcript.split('\n').where((line) => line.trim().isNotEmpty).toList();
          transcriptLines = lines
              .map((line) {
                return TranscriptLine(
                  speaker: 'Speaker',
                  text: line.trim(),
                  startTime: 0,
                  endTime: 0,
                );
              })
              .toList()
              .cast<TranscriptLine>();
        }
      }
    } else if (ep.transcript.isNotEmpty) {
      final lines = ep.transcript.split('\n').where((line) => line.trim().isNotEmpty).toList();
      transcriptLines = lines
          .map((line) {
            return TranscriptLine(
              speaker: 'Speaker',
              text: line.trim(),
              startTime: 0,
              endTime: 0,
            );
          })
          .toList()
          .cast<TranscriptLine>();
    } else {
      transcriptLines = [];
    }
    _lineKeys = List.generate(transcriptLines.length, (_) => GlobalKey());
    _seenLineIndices.clear();
  }

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

  void _calculateAdPositions() {
    final totalItems = transcriptLines.length;
    if (totalItems < 20) {
      // Nếu ít hơn 20 items: chèn 1 native ad ở giữa
      if (totalItems > 0) {
        _adPositions = [totalItems ~/ 2];
      }
    } else {
      // Nếu từ 20 items trở lên: chèn 2 native ads
      _adPositions = [
        totalItems ~/ 3,
        totalItems * 2 ~/ 3,
      ];
    }
  }


  @override
  void didUpdateWidget(TranscriptSlide oldWidget) {
    super.didUpdateWidget(oldWidget);
    final transcriptChanged = oldWidget.episode.id != widget.episode.id ||
        oldWidget.episode.transcript != widget.episode.transcript ||
        oldWidget.episode.transcriptHtml != widget.episode.transcriptHtml;
    if (transcriptChanged) {
      setState(() {
        _buildTranscriptLinesFromEpisode();
        _calculateAdPositions();
      });
      _syncTranscriptMarkedFromProgress();
      _scheduleShortTranscriptDwellIfNeeded();
    }
    if (oldWidget.currentPositionMs != widget.currentPositionMs || transcriptChanged) {
      _updateActiveLine();
    }
    if (oldWidget.scrollToActiveRequestId != widget.scrollToActiveRequestId) {
      _scrollToActiveLine();
    }
  }

  void _updateActiveLine() {
    if (widget.currentPositionMs == null) return;
    
    // Chỉ update active line nếu transcript lines có time info (từ transcriptHtml)
    // Nếu transcript lines không có time (từ transcript field), không cần highlight
    if (transcriptLines.isEmpty) return;
    if (transcriptLines[0].startTime == 0 && transcriptLines[0].endTime == 0) {
      // Transcript từ field transcript (không có time info), không cần highlight
      return;
    }
    
    int newActiveIndex = -1;
    for (int i = 0; i < transcriptLines.length; i++) {
      if (transcriptLines[i].isActiveAt(widget.currentPositionMs!)) {
        newActiveIndex = i;
        break;
      }
    }
    
    if (newActiveIndex != _currentActiveIndex) {
      setState(() {
        _currentActiveIndex = newActiveIndex;
      });
    }
  }

  void _onScroll() {
    if (!_scrollController.hasClients) return;
    if (_scrollController.position.pixels > 8) {
      _hasScrolled = true;
    }
    _updateSeenLines();
  }

  double _visibleFraction(GlobalKey key) {
    final ctx = key.currentContext;
    if (ctx == null) return 0;
    final renderObject = ctx.findRenderObject();
    if (renderObject is! RenderBox ||
        !renderObject.hasSize ||
        !renderObject.attached) {
      return 0;
    }
    final viewport = RenderAbstractViewport.maybeOf(renderObject);
    if (viewport == null) return 0;

    final viewportBox = viewport as RenderBox;
    final itemRect = MatrixUtils.transformRect(
      renderObject.getTransformTo(viewportBox),
      renderObject.paintBounds,
    );
    final viewportRect = Offset.zero & viewportBox.size;
    final intersection = itemRect.intersect(viewportRect);
    if (intersection.isEmpty || itemRect.height <= 0) return 0;
    return intersection.height / itemRect.height;
  }

  void _updateSeenLines() {
    if (_transcriptMarked || transcriptLines.isEmpty) return;

    for (var i = 0; i < transcriptLines.length; i++) {
      if (_seenLineIndices.contains(i)) continue;
      if (i >= _lineKeys.length) continue;
      if (_visibleFraction(_lineKeys[i]) >= _lineVisibleFractionThreshold) {
        _seenLineIndices.add(i);
      }
    }

    final seenRatio = _seenLineIndices.length / transcriptLines.length;
    if (seenRatio >= _transcriptDoneLineRatio) {
      unawaited(_markTranscriptViewed());
    }
  }

  Future<void> _markTranscriptViewed() async {
    if (_transcriptMarked) return;
    _transcriptMarked = true;
    _shortTranscriptDwellTimer?.cancel();
    await widget.learningProgress.markTranscriptViewed(widget.episode);
  }

  int _displayIndexForTranscriptIndex(int transcriptIndex) {
    var adsBefore = 0;
    for (final adPos in _adPositions) {
      if (adPos <= transcriptIndex) {
        adsBefore += 1;
      }
    }
    return transcriptIndex + adsBefore;
  }

  void _scrollToActiveLine() {
    if (!_scrollController.hasClients) return;
    final activeIndex = _currentActiveIndex;
    if (activeIndex == null || activeIndex < 0 || activeIndex >= transcriptLines.length) {
      return;
    }
    final displayIndex = _displayIndexForTranscriptIndex(activeIndex);
    final target = (displayIndex * 112.0)
        .clamp(0.0, _scrollController.position.maxScrollExtent);
    _scrollController.animateTo(
      target,
      duration: const Duration(milliseconds: 360),
      curve: Curves.easeOutCubic,
    );
  }


  @override
  Widget build(BuildContext context) {
    // Listen to LanguageManager changes to rebuild when language changes
    return ListenableBuilder(
      listenable: _languageManager,
      builder: (context, child) {
        return _buildTranscriptContent();
      },
    );
  }

  Widget _buildTranscriptContent() {
    final categoryColor = CategoryColors.getCategoryColor(widget.episode.category);
    final primaryColor = Theme.of(context).colorScheme.primary;
    final tertiaryColor = Theme.of(context).colorScheme.tertiary;

    Widget emptyOrList() {
      if (widget.isAwaitingFullEpisode && transcriptLines.isEmpty) {
        return EpisodeTabSkeleton(accentColor: categoryColor, lineCount: 12);
      }
      if (transcriptLines.isEmpty) {
        return Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.description_outlined,
                size: 64,
                color: Theme.of(context).colorScheme.onSurface.withOpacity(0.4),
              ),
              const SizedBox(height: 16),
              Text(
                'No transcript available',
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
                ),
              ),
            ],
          ),
        );
      }

      return NotificationListener<ScrollNotification>(
        onNotification: (notification) {
          if (notification is ScrollUpdateNotification ||
              notification is ScrollEndNotification) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (mounted) _updateSeenLines();
            });
          }
          return false;
        },
        child: ListView.builder(
                    controller: _scrollController,
                    padding: EpisodeDetailTabPanel.scrollPadding(
                      widget.scrollBottomInset,
                    ),
                    itemCount: transcriptLines.length + _adPositions.length,
                    itemBuilder: (context, index) {
                      // Kiểm tra xem có cần chèn native ad ở vị trí này không
                      // Tính số ads đã chèn trước index này
                      int adsBeforeIndex = 0;
                      int? matchingAdPosition;
                      
                      for (int adPos in _adPositions) {
                        // Vị trí thực tế của ad trong list = adPos + số ads đã chèn trước nó
                        int actualAdIndex = adPos + adsBeforeIndex;
                        if (actualAdIndex == index) {
                          matchingAdPosition = adPos;
                          break;
                        }
                        if (actualAdIndex < index) {
                          adsBeforeIndex++;
                        }
                      }
                      
                      if (matchingAdPosition != null) {
                        return TranscriptNativeAdWidget(
                          category: widget.episode.category,
                          slot: TranscriptNativeAdSlot.episodeTranscript,
                        );
                      }
                      
                      // Tính toán index thực tế của transcript line (trừ đi số ads đã chèn trước đó)
                      int transcriptIndex = index - adsBeforeIndex;
                      
                      if (transcriptIndex < 0 || transcriptIndex >= transcriptLines.length) {
                        return const SizedBox.shrink();
                      }
                      
                      final line = transcriptLines[transcriptIndex];
                      // Kiểm tra xem line có time info không (nếu cả startTime và endTime đều = 0 thì không có time info)
                      final hasTimeInfo = !(line.startTime == 0 && line.endTime == 0);
                      final isActive = hasTimeInfo && _currentActiveIndex == transcriptIndex;
                      final isPassed = hasTimeInfo && widget.currentPositionMs != null && 
                          line.isPassedAt(widget.currentPositionMs!);
                      final speakerColor = _speakerAccentColor(line.speaker);
                      final quoted = '"${line.text}"';

                      return Padding(
                        key: _lineKeys[transcriptIndex],
                        padding: const EdgeInsets.only(bottom: 4),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 220),
                          curve: Curves.easeOutCubic,
                          decoration: BoxDecoration(
                            color: isActive
                                ? Color.alphaBlend(
                                    categoryColor.withOpacity(0.08),
                                    Theme.of(context).colorScheme.surface,
                                  )
                                : Colors.transparent,
                            borderRadius: BorderRadius.circular(10),
                            border: isActive
                                ? Border.all(
                                    color: categoryColor.withOpacity(0.14),
                                    width: 1,
                                  )
                                : isPassed
                                    ? Border.all(
                                        color: Theme.of(context)
                                            .colorScheme
                                            .outline
                                            .withOpacity(0.2),
                                      )
                                    : null,
                            boxShadow: isActive
                                ? [
                                    BoxShadow(
                                      color: categoryColor.withOpacity(0.06),
                                      blurRadius: 6,
                                      offset: const Offset(0, 1),
                                    ),
                                  ]
                                : null,
                          ),
                          padding: EdgeInsets.all(isActive ? 8 : 5),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                crossAxisAlignment: CrossAxisAlignment.center,
                                children: [
                                  AnimatedBuilder(
                                    animation: _breathController,
                                    builder: (context, child) {
                                      final scale =
                                          isActive ? (1.0 + (_breathController.value * 0.11)) : 1.0;
                                      return Transform.scale(
                                        alignment: Alignment.center,
                                        scale: scale,
                                        child: child,
                                      );
                                    },
                                    child: CircleAvatar(
                                      radius: 17,
                                      backgroundColor: speakerColor.withOpacity(0.22),
                                      child: Text(
                                        _speakerInitial(line.speaker),
                                        style: TextStyle(
                                          fontSize: 15,
                                          fontWeight: FontWeight.bold,
                                          color: speakerColor,
                                        ),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: Text(
                                      line.speaker.toUpperCase(),
                                      style: TextStyle(
                                        fontSize: 13,
                                        fontWeight: FontWeight.bold,
                                        letterSpacing: 0.65,
                                        color: isActive ? categoryColor : speakerColor,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 4),
                              SelectableText(
                                quoted,
                                style: TextStyle(
                                  fontSize: 14,
                                  height: 1.4,
                                  fontStyle: FontStyle.normal,
                                  fontWeight:
                                      isActive ? FontWeight.w600 : FontWeight.normal,
                                  color: isActive
                                      ? categoryColor
                                      : Theme.of(context).colorScheme.onSurface.withOpacity(
                                            isPassed ? 0.55 : 0.9,
                                          ),
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
                                                ClipboardData(text: selectedText));
                                            editableTextState.hideToolbar();
                                            ScaffoldMessenger.of(context).showSnackBar(
                                              SnackBar(
                                                content: Text(
                                                  _languageManager.getText(
                                                    'copiedToClipboard',
                                                  ),
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
                                            _openGoogleTranslate(context, selectedText);
                                            editableTextState.hideToolbar();
                                          }
                                        },
                                      ),
                                    ],
                                  );
                                },
                              ),
                              if (_lineTranslations.containsKey(line.text))
                                Padding(
                                  padding: const EdgeInsets.only(top: 4),
                                  child: SelectableText(
                                    _lineTranslations[line.text]!,
                                    style: TextStyle(
                                      fontSize: 13,
                                      height: 1.35,
                                      fontStyle: FontStyle.italic,
                                      color: Theme.of(context)
                                          .colorScheme
                                          .onSurface
                                          .withOpacity(0.6),
                                    ),
                                  ),
                                ),
                              if (_showTranslation &&
                                  _translations != null &&
                                  !_lineTranslations.containsKey(line.text))
                                Padding(
                                  padding: const EdgeInsets.only(top: 4),
                                  child: SelectableText(
                                    _translations![line.text] ?? '',
                                    style: TextStyle(
                                      fontSize: 13,
                                      height: 1.35,
                                      fontStyle: FontStyle.italic,
                                      color: Theme.of(context)
                                          .colorScheme
                                          .onSurface
                                          .withOpacity(0.6),
                                    ),
                                  ),
                                ),
                              const SizedBox(height: 4),
                              Wrap(
                                spacing: 12,
                                runSpacing: 4,
                                children: [
                                  if (hasTimeInfo)
                                    InkWell(
                                      onTap: () => widget.onPlayAtTime?.call(line.startTime),
                                      borderRadius: BorderRadius.circular(999),
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Icon(
                                            Icons.volume_up_rounded,
                                            color: categoryColor,
                                            size: 14,
                                          ),
                                          const SizedBox(width: 4),
                                          Text(
                                            'Listen',
                                            style: TextStyle(
                                              fontSize: 11,
                                              fontWeight: FontWeight.w600,
                                              color: categoryColor,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  InkWell(
                                    onTap: () =>
                                        _translateLine(context, line.text, transcriptIndex),
                                    borderRadius: BorderRadius.circular(999),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        _lineTranslating[line.text] == true
                                            ? SizedBox(
                                                width: 14,
                                                height: 14,
                                                child: CircularProgressIndicator(
                                                  strokeWidth: 2,
                                                  valueColor:
                                                      AlwaysStoppedAnimation<Color>(
                                                    primaryColor,
                                                  ),
                                                ),
                                              )
                                            : Icon(
                                                _lineTranslations.containsKey(line.text)
                                                    ? Icons.translate
                                                    : Icons.translate_outlined,
                                                color: primaryColor,
                                                size: 14,
                                              ),
                                        const SizedBox(width: 4),
                                        Text(
                                          'Translate',
                                          style: TextStyle(
                                            fontSize: 11,
                                            fontWeight: FontWeight.w600,
                                            color: primaryColor,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  InkWell(
                                    onTap: () => _showGrammarExplanation(
                                          context,
                                          line.text,
                                          transcriptIndex,
                                        ),
                                    borderRadius: BorderRadius.circular(999),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Icon(
                                          Icons.lightbulb_outline,
                                          color: tertiaryColor,
                                          size: 14,
                                        ),
                                        const SizedBox(width: 4),
                                        Text(
                                          'Grammar',
                                          style: TextStyle(
                                            fontSize: 11,
                                            fontWeight: FontWeight.w600,
                                            color: tertiaryColor,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
      );
    }

    return EpisodeDetailTabPanel(
      child: emptyOrList(),
    );
  }

  Future<void> _loadTranslations() async {
    if (transcriptLines.isEmpty) return;
    
    setState(() {
      _isTranslating = true;
    });

    try {
      final episodeId = widget.episode.id ?? '';
      final translations = await _translationService.translateTranscript(
        transcriptLines,
        episodeId,
      );

      if (mounted) {
        setState(() {
          _translations = translations;
          _showTranslation = true;
          _isTranslating = false;
        });
      }
    } catch (e) {
      debugPrint('Error loading translations: $e');
      if (mounted) {
        setState(() {
          _isTranslating = false;
        });
        
        _showErrorSnackBar(context, e, onRetry: () => _loadTranslations());
      }
    }
  }

  Future<void> _openGoogleTranslate(BuildContext context, String text) async {
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
      if (context.mounted) {
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

  String _grammarMemoryKey(int lineNumber, String languageCode) =>
      'line::$lineNumber::$languageCode';

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
    final enCached =
        _grammarCache[_grammarMemoryKey(lineNumber, GrammarOpenPolicy.englishCode)];
    final targetCached =
        _grammarCache[_grammarMemoryKey(lineNumber, targetLanguageCode)];

    if (targetLanguageCode == GrammarOpenPolicy.englishCode && enCached != null) {
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
      final episodeId = widget.episode.id ?? '';
      final result = await _grammarService.resolveSentenceExplanation(
        normalizedSentence,
        episodeId,
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

      if (context.mounted) {
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
      }
    } catch (e) {
      if (context.mounted) {
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
    Future<GrammarExplanation>? progressiveUpdate,
    required int lineNumber,
    required String sentence,
    required String selectedLanguageCode,
    required String targetLanguageCode,
    required bool englishAvailable,
  }) {
    var currentExplanation = explanation;
    var currentLang = selectedLanguageCode;
    var currentEnglishAvailable = englishAvailable;
    final savedItem =
        _savedGrammarService.getBySentence(explanation.sentence, widget.episode.id ?? '');
    final wasSaved = savedItem?.isPinned == true;
    showDialog(
      context: context,
      builder: (context) => GrammarExplanationDialog(
        explanation: explanation,
        progressiveUpdate: progressiveUpdate,
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
          if (next != null) {
            currentExplanation = next;
            currentLang = lang;
            if (lang == GrammarOpenPolicy.englishCode) {
              currentEnglishAvailable = true;
            }
          }
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
              duration: const Duration(seconds: 2),
            ),
          );
          _showGrammarDialog(
            context,
            currentExplanation,
            lineNumber: lineNumber,
            sentence: sentence,
            selectedLanguageCode: currentLang,
            targetLanguageCode: targetLanguageCode,
            englishAvailable: currentEnglishAvailable,
          );
        },
      ),
    );
  }

  Future<void> _maybeAskReviewReminderPermission(BuildContext context) async {
    final alreadyAsked = await _reviewReminderService.hasAskedPermission();
    if (alreadyAsked) return;
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

  Future<void> _translateLine(BuildContext context, String lineText, int lineIndex) async {
    // If already translated, toggle visibility (for now just show it)
    if (_lineTranslations.containsKey(lineText)) {
      // Already translated, do nothing (translation is always shown)
      return;
    }

    // If currently translating, ignore
    if (_lineTranslating[lineText] == true) {
      return;
    }

    setState(() {
      _lineTranslating[lineText] = true;
    });

    try {
      final episodeId = widget.episode.id ?? '';
      // Pass lineIndex as lineNumber for Firebase cache matching
      final translated = await _translationService.translateTranscriptLine(
        lineText,
        episodeId,
        lineIndex, // lineNumber for Firebase cache
      );

      if (mounted) {
        setState(() {
          _lineTranslations[lineText] = translated;
          _lineTranslating[lineText] = false;
        });
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

  /// Show error SnackBar with appropriate action button
  /// Shows "Watch Ads" button if NoHeartsException, otherwise "Retry"
  void _showErrorSnackBar(
    BuildContext context,
    dynamic error, {
    required VoidCallback onRetry,
  }) {
    final heartService = HeartService();
    final admobService = AdMobService();
    
    if (error is NoHeartsException && heartService.canEarnMoreHearts) {
      // Show "Watch Ads" button for NoHeartsException
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(AIErrorHandler.getErrorMessage(error)),
          action: SnackBarAction(
            label: 'Watch Ads',
            textColor: Theme.of(context).colorScheme.onInverseSurface,
            onPressed: () {
              if (admobService.isRewardedAdReady()) {
                admobService.showRewardedAd(
                  onRewarded: () {
                    heartService.earnHeart();
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('❤️ You earned 1 heart!'),
                        backgroundColor: Color(0xFF7A5CFF),
                        duration: Duration(seconds: 2),
                      ),
                    );
                    // Retry the action after earning heart
                    Future.delayed(const Duration(milliseconds: 500), onRetry);
                  },
                  onAdFailedToShow: (error) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('Failed to show ad: $error'),
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
    } else {
      // Show "Retry" button for other errors
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

  @override
  void dispose() {
    _shortTranscriptDwellTimer?.cancel();
    _scrollController.removeListener(_onScroll);
    _breathController.dispose();
    _scrollController.dispose();
    super.dispose();
  }
}





