import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';
import '../models/episode.dart';
import '../models/transcript_line.dart';
import '../utils/category_colors.dart';
import 'transcript_native_ad_widget.dart';

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
                                  const SizedBox(width: 8),
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
                                      minWidth: 32,
                                      minHeight: 32,
                                    ),
                                  ),
                                ],
                              ),
                            if (hasTimeInfo) const SizedBox(height: 6),
                            // Text content
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

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }
}





