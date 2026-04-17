import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';
import '../models/episode.dart';
import '../models/transcript_line.dart';
import '../utils/category_colors.dart';
import '../services/ai_translation_service.dart';
import '../services/ai_grammar_service.dart';
import '../services/ai/ai_error_handler.dart';
import '../services/ai/exceptions.dart';
import '../models/grammar_explanation.dart';
import '../services/language_manager.dart';
import '../services/admob_service.dart';
import '../services/heart_service.dart';
import 'grammar_explanation_widget.dart';
import 'transcript_native_ad_widget.dart';
import 'translation_language_picker.dart';
import 'episode_tab_skeleton.dart';

class TranscriptSlide extends StatefulWidget {
  final Episode episode;
  final int? currentPositionMs; // Vị trí audio hiện tại (milliseconds)
  final Function(int startTimeMs)? onPlayAtTime; // Callback để play tại thời điểm cụ thể
  /// Đang tải transcript đầy đủ từ RTDB (list mỏng) — hiển thị skeleton thay vì "No transcript".
  final bool isAwaitingFullEpisode;

  const TranscriptSlide({
    super.key,
    required this.episode,
    this.currentPositionMs,
    this.onPlayAtTime,
    this.isAwaitingFullEpisode = false,
  });

  @override
  State<TranscriptSlide> createState() => _TranscriptSlideState();
}

class _TranscriptSlideState extends State<TranscriptSlide> {
  late List<TranscriptLine> transcriptLines;
  late ScrollController _scrollController;
  int? _currentActiveIndex;
  List<int> _adPositions = []; // Vị trí chèn native ads
  
  // Translation state
  bool _showTranslation = false;
  Map<String, String>? _translations;
  bool _isTranslating = false;
  final AITranslationService _translationService = AITranslationService();
  final LanguageManager _languageManager = LanguageManager();
  
  // Grammar state
  final AIGrammarService _grammarService = AIGrammarService();
  final Map<String, GrammarExplanation> _grammarCache = {};
  
  // Line translation state (cache translations for each line)
  final Map<String, String> _lineTranslations = {};
  final Map<String, bool> _lineTranslating = {};

  @override
  void initState() {
    super.initState();
    _scrollController = ScrollController();
    _buildTranscriptLinesFromEpisode();
    _calculateAdPositions();
    _updateActiveLine();
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
    }
    if (oldWidget.currentPositionMs != widget.currentPositionMs || transcriptChanged) {
      _updateActiveLine();
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
    final panelBg = categoryColor.withOpacity(0.12);

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

      return ListView.builder(
                    controller: _scrollController,
                    padding: const EdgeInsets.fromLTRB(12, 12, 12, 16),
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
                        // Chèn native ad với style giống transcript items
                        return Container(
                          margin: const EdgeInsets.only(bottom: 4),
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: Colors.transparent,
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: TranscriptNativeAdWidget(
                            category: widget.episode.category,
                          ),
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
                        padding: const EdgeInsets.only(bottom: 10),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 220),
                          curve: Curves.easeOutCubic,
                          decoration: BoxDecoration(
                            color: isActive
                                ? Theme.of(context).colorScheme.surface
                                : Colors.transparent,
                            borderRadius: BorderRadius.circular(10),
                            boxShadow: isActive
                                ? [
                                    BoxShadow(
                                      color: Colors.black.withOpacity(0.06),
                                      blurRadius: 8,
                                      offset: const Offset(0, 2),
                                    ),
                                  ]
                                : null,
                            border: isPassed && !isActive
                                ? Border.all(
                                    color: Theme.of(context).colorScheme.outline.withOpacity(0.2),
                                  )
                                : null,
                          ),
                          padding: EdgeInsets.all(isActive ? 12 : 8),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                crossAxisAlignment: CrossAxisAlignment.center,
                                children: [
                                  CircleAvatar(
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
                                  if (hasTimeInfo) ...[
                                    Text(
                                      '${(line.startTime / 1000).toStringAsFixed(1)}s · ${(line.endTime / 1000).toStringAsFixed(1)}s',
                                      style: TextStyle(
                                        fontSize: 10,
                                        color: Theme.of(context).colorScheme.onSurface.withOpacity(0.55),
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Tooltip(
                                      message: _languageManager
                                          .getTextWithParams(
                                        'transcriptPlayFromSeconds',
                                        {
                                          'seconds': (line.startTime / 1000)
                                              .toStringAsFixed(1),
                                        },
                                      ),
                                      child: Material(
                                        color: categoryColor,
                                        borderRadius: BorderRadius.circular(6),
                                        child: InkWell(
                                          onTap: () =>
                                              widget.onPlayAtTime?.call(line.startTime),
                                          borderRadius: BorderRadius.circular(6),
                                          child: const Padding(
                                            padding: EdgeInsets.all(7),
                                            child: Icon(
                                              Icons.volume_up_rounded,
                                              color: Colors.white,
                                              size: 19,
                                            ),
                                          ),
                                        ),
                                      ),
                                    ),
                                  ],
                                  IconButton(
                                    onPressed: () =>
                                        _translateLine(context, line.text, transcriptIndex),
                                    icon: _lineTranslating[line.text] == true
                                        ? SizedBox(
                                            width: 18,
                                            height: 18,
                                            child: CircularProgressIndicator(
                                              strokeWidth: 2,
                                              valueColor: AlwaysStoppedAnimation<Color>(
                                                Colors.blue.shade600,
                                              ),
                                            ),
                                          )
                                        : Icon(
                                            _lineTranslations.containsKey(line.text)
                                                ? Icons.translate
                                                : Icons.translate_outlined,
                                            color: Colors.blue.shade600,
                                            size: 18,
                                          ),
                                    tooltip: _lineTranslations.containsKey(line.text)
                                        ? 'Show translation'
                                        : 'Translate line',
                                    padding: EdgeInsets.zero,
                                    constraints: const BoxConstraints(
                                      minWidth: 32,
                                      minHeight: 32,
                                    ),
                                  ),
                                  IconButton(
                                    onPressed: () =>
                                        _showGrammarExplanation(context, line.text),
                                    icon: Icon(
                                      Icons.lightbulb_outline,
                                      color: Colors.green.shade600,
                                      size: 18,
                                    ),
                                    tooltip: 'Explain grammar',
                                    padding: EdgeInsets.zero,
                                    constraints: const BoxConstraints(
                                      minWidth: 32,
                                      minHeight: 32,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 8),
                              SelectableText(
                                quoted,
                                style: TextStyle(
                                  fontSize: 14,
                                  height: 1.55,
                                  fontStyle:
                                      isActive ? FontStyle.italic : FontStyle.normal,
                                  color: Theme.of(context).colorScheme.onSurface.withOpacity(
                                        isPassed && !isActive ? 0.55 : 0.9,
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
                                  padding: const EdgeInsets.only(top: 6),
                                  child: SelectableText(
                                    _lineTranslations[line.text]!,
                                    style: TextStyle(
                                      fontSize: 13,
                                      height: 1.4,
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
                                  padding: const EdgeInsets.only(top: 6),
                                  child: SelectableText(
                                    _translations![line.text] ?? '',
                                    style: TextStyle(
                                      fontSize: 13,
                                      height: 1.4,
                                      fontStyle: FontStyle.italic,
                                      color: Theme.of(context)
                                          .colorScheme
                                          .onSurface
                                          .withOpacity(0.6),
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        ),
                      );
                    },
                  );
    }

    // TranscriptSlide nằm trong PageView — không dùng Expanded (chỉ hợp lệ trong Row/Column).
    // SizedBox.expand để nhận đủ chiều cao viewport; Android sẽ không còn vùng trống.
    return SizedBox.expand(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(6, 0, 6, 4),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: ColoredBox(
            color: panelBg,
            child: emptyOrList(),
          ),
        ),
      ),
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

  Future<void> _showGrammarExplanation(BuildContext context, String sentence) async {
    // Check cache first
    if (_grammarCache.containsKey(sentence)) {
      _showGrammarDialog(context, _grammarCache[sentence]!);
      return;
    }

    // Show loading dialog
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
                    CategoryColors.getCategoryColor(widget.episode.category),
                  ),
                ),
                const SizedBox(height: 16),
                const Text('Analyzing grammar...'),
              ],
            ),
          ),
        ),
      ),
    );

    try {
      final episodeId = widget.episode.id ?? '';
      final explanation = await _grammarService.explainSentence(sentence, episodeId);
      
      _grammarCache[sentence] = explanation;

      if (context.mounted) {
        Navigator.of(context).pop(); // Close loading dialog
        _showGrammarDialog(context, explanation);
      }
    } catch (e) {
      if (context.mounted) {
        Navigator.of(context).pop(); // Close loading dialog
        
        _showErrorSnackBar(
          context,
          e,
          onRetry: () => _showGrammarExplanation(context, sentence),
        );
      }
    }
  }

  void _showGrammarDialog(BuildContext context, GrammarExplanation explanation) {
    showDialog(
      context: context,
      builder: (context) => GrammarExplanationDialog(
        explanation: explanation,
        category: widget.episode.category,
      ),
    );
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
            textColor: Colors.white,
            onPressed: () {
              if (admobService.isRewardedAdReady()) {
                admobService.showRewardedAd(
                  onRewarded: () {
                    heartService.earnHeart();
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('❤️ You earned 1 heart!'),
                        backgroundColor: Colors.green,
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
                        backgroundColor: Colors.red,
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
    _scrollController.dispose();
    super.dispose();
  }
}





