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

class TranscriptSlide extends StatefulWidget {
  final Episode episode;
  final int? currentPositionMs; // Vị trí audio hiện tại (milliseconds)
  final Function(int startTimeMs)? onPlayAtTime; // Callback để play tại thời điểm cụ thể

  const TranscriptSlide({
    super.key,
    required this.episode,
    this.currentPositionMs,
    this.onPlayAtTime,
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
    
    // Ưu tiên sử dụng transcriptHtml (có time info)
    if (widget.episode.transcriptHtml != null && widget.episode.transcriptHtml!.isNotEmpty) {
      transcriptLines = TranscriptLine.parseTranscriptHtml(widget.episode.transcriptHtml);
      
      // Kiểm tra xem transcriptLines có time info không
      // Nếu tất cả các lines đều không có time info (startTime = 0 và endTime = 0)
      // nhưng vẫn có giá trị → split transcriptHtml theo newline
      if (transcriptLines.isNotEmpty && 
          transcriptLines.every((line) => line.startTime == 0 && line.endTime == 0)) {
        // Không có time info nhưng vẫn có giá trị, split transcriptHtml theo newline
        final lines = widget.episode.transcriptHtml!.split('\n').where((line) => line.trim().isNotEmpty).toList();
        transcriptLines = lines.map((line) {
          return TranscriptLine(
            speaker: 'Speaker',
            text: line.trim(),
            startTime: 0,
            endTime: 0,
          );
        }).toList().cast<TranscriptLine>();
      }
      // Nếu transcriptLines rỗng (parse không ra gì), fallback sang dùng field transcript
      else if (transcriptLines.isEmpty) {
        if (widget.episode.transcript.isNotEmpty) {
          final lines = widget.episode.transcript.split('\n').where((line) => line.trim().isNotEmpty).toList();
          transcriptLines = lines.map((line) {
            return TranscriptLine(
              speaker: 'Speaker',
              text: line.trim(),
              startTime: 0,
              endTime: 0,
            );
          }).toList().cast<TranscriptLine>();
        }
      }
    } else if (widget.episode.transcript.isNotEmpty) {
      // Không có transcriptHtml, dùng field transcript (split theo newline)
      final lines = widget.episode.transcript.split('\n').where((line) => line.trim().isNotEmpty).toList();
      transcriptLines = lines.map((line) {
        return TranscriptLine(
          speaker: 'Speaker',
          text: line.trim(),
          startTime: 0,
          endTime: 0,
        );
      }).toList().cast<TranscriptLine>();
    } else {
      // Không có cả transcriptHtml và transcript
      transcriptLines = [];
    }
    
    // Tính toán vị trí chèn native ads
    _calculateAdPositions();
    
    _updateActiveLine();
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
    if (oldWidget.currentPositionMs != widget.currentPositionMs) {
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
    return Container(
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Row(
            children: [
              Icon(
                Icons.description,
                color: CategoryColors.getCategoryColor(widget.episode.category),
                size: 20,
              ),
              const SizedBox(width: 8),
              Text(
                LanguageManager().getText('transcript'),
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: CategoryColors.getCategoryColor(widget.episode.category),
                ),
              ),
              const Spacer(),
              // Translation toggle button
              // TODO: Temporarily commented out - affects performance when translating long transcripts
              // Will be re-enabled after VIP feature implementation
              /*
              if (transcriptLines.isNotEmpty)
                IconButton(
                  icon: _isTranslating
                      ? SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor: AlwaysStoppedAnimation<Color>(
                              CategoryColors.getCategoryColor(widget.episode.category),
                            ),
                          ),
                        )
                      : Icon(
                          _showTranslation ? Icons.translate : Icons.translate_outlined,
                          color: _showTranslation
                              ? CategoryColors.getCategoryColor(widget.episode.category)
                              : Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
                        ),
                  onPressed: _isTranslating
                      ? null
                      : () async {
                          // Check if app language is English (default)
                          if (_languageManager.isTranslationNeeded()) {
                            // Show language picker to select translation language
                            TranslationLanguagePicker.show(
                              context,
                              currentLanguageCode: _languageManager.currentLocale.languageCode,
                              onLanguageSelected: (languageCode) async {
                                // Save selected language to settings (selected_language key)
                                await _languageManager.changeLanguage(Locale(languageCode));
                                // Clear old translations to force reload with new language
                                setState(() {
                                  _translations = null;
                                  _showTranslation = false;
                                });
                                // Load translations with new language
                                await _loadTranslations();
                              },
                            );
                          } else {
                            // App language is not English, translate directly
                            if (!_showTranslation && _translations == null) {
                              // Load translations
                              await _loadTranslations();
                            } else {
                              setState(() {
                                _showTranslation = !_showTranslation;
                              });
                            }
                          }
                        },
                  tooltip: _showTranslation ? 'Hide translation' : 'Show translation',
                ),
              */
            ],
          ),
          const SizedBox(height: 16),
              // Transcript Content
              Expanded(
                child: transcriptLines.isEmpty
                    ? Center(
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
                      )
                    : ListView.builder(
                    controller: _scrollController,
                    padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
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
                            borderRadius: BorderRadius.circular(8),
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
                      
                      return Container(
                        margin: const EdgeInsets.only(bottom: 4),
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: isActive 
                              ? CategoryColors.getCategoryColor(widget.episode.category).withOpacity(0.1)
                              : isPassed
                                  ? Theme.of(context).colorScheme.surfaceVariant.withOpacity(0.3)
                                  : Colors.transparent,
                          borderRadius: BorderRadius.circular(8),
                          border: isActive 
                              ? Border.all(
                                  color: CategoryColors.getCategoryColor(widget.episode.category),
                                  width: 2,
                                )
                              : null,
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Speaker name, Time info và Play button cùng một dòng (chỉ hiển thị nếu có time info)
                            if (hasTimeInfo)
                              Row(
                                children: [
                                  // Speaker name
                                  Expanded(
                                    child: Text(
                                      line.speaker,
                                      style: TextStyle(
                                        fontSize: 14,
                                        fontWeight: FontWeight.bold,
                                        color: isActive 
                                            ? CategoryColors.getCategoryColor(widget.episode.category)
                                            : Theme.of(context).colorScheme.primary,
                                      ),
                                    ),
                                  ),
                                  // Time info
                                  Text(
                                    '${(line.startTime / 1000).toStringAsFixed(1)}s - ${(line.endTime / 1000).toStringAsFixed(1)}s',
                                    style: TextStyle(
                                      fontSize: 10,
                                      color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
                                    ),
                                  ),
                                  const SizedBox(width: 4),
                                  // Play button
                                  IconButton(
                                    onPressed: () {
                                      // Gọi callback để play tại startTime của dòng này
                                      widget.onPlayAtTime?.call(line.startTime);
                                    },
                                    icon: Icon(
                                      Icons.play_arrow,
                                      color: CategoryColors.getCategoryColor(widget.episode.category),
                                      size: 20,
                                    ),
                                    tooltip: 'Play từ ${(line.startTime / 1000).toStringAsFixed(1)}s',
                                    padding: EdgeInsets.zero,
                                    constraints: const BoxConstraints(
                                      minWidth: 24,
                                      minHeight: 24,
                                    ),
                                  ),
                                  // Translate line button
                                  IconButton(
                                    onPressed: () => _translateLine(context, line.text, transcriptIndex),
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
                                      minWidth: 24,
                                      minHeight: 24,
                                    ),
                                  ),
                                  // Grammar explanation button
                                  IconButton(
                                    onPressed: () => _showGrammarExplanation(context, line.text),
                                    icon: Icon(
                                      Icons.lightbulb_outline,
                                      color: Colors.green.shade600,
                                      size: 18,
                                    ),
                                    tooltip: 'Explain grammar',
                                    padding: EdgeInsets.zero,
                                    constraints: const BoxConstraints(
                                      minWidth: 24,
                                      minHeight: 24,
                                    ),
                                  ),
                                ],
                              ),
                            if (hasTimeInfo) const SizedBox(height: 6),
                            // Text content
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                SelectableText(
                                  line.text,
                                  style: TextStyle(
                                    fontSize: 14,
                                    height: 1.5,
                                    color: isActive 
                                        ? Theme.of(context).colorScheme.onSurface
                                        : Theme.of(context).colorScheme.onSurface.withOpacity(0.8),
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
                                            const SnackBar(content: Text('Đã sao chép')),
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
                                          _openGoogleTranslate(context, selectedText);
                                          editableTextState.hideToolbar();
                                        }
                                      },
                                    ),
                                  ],
                                );
                              },
                            ),
                                // Line translation (if translated)
                                if (_lineTranslations.containsKey(line.text))
                                  Padding(
                                    padding: const EdgeInsets.only(top: 6),
                                    child: SelectableText(
                                      _lineTranslations[line.text]!,
                                      style: TextStyle(
                                        fontSize: 13,
                                        height: 1.4,
                                        fontStyle: FontStyle.italic,
                                        color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
                                      ),
                                    ),
                                  ),
                                // Full transcript translation (if enabled)
                                if (_showTranslation && _translations != null && !_lineTranslations.containsKey(line.text))
                                  Padding(
                                    padding: const EdgeInsets.only(top: 6),
                                    child: SelectableText(
                                      _translations![line.text] ?? '',
                                      style: TextStyle(
                                        fontSize: 13,
                                        height: 1.4,
                                        fontStyle: FontStyle.italic,
                                        color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                          ],
                        ),
                      );
                    },
                  ),
          ),
        ],
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
          const SnackBar(content: Text('Không thể mở Google Translate')),
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





