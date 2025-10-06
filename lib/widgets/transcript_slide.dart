import 'package:flutter/material.dart';
import '../models/episode.dart';
import '../models/transcript_line.dart';
import '../utils/category_colors.dart';

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

  @override
  void initState() {
    super.initState();
    _scrollController = ScrollController();
    transcriptLines = TranscriptLine.parseTranscriptHtml(widget.episode.transcriptHtml);
    
    
    _updateActiveLine();
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
      padding: const EdgeInsets.all(16),
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
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    itemCount: transcriptLines.length,
                    itemBuilder: (context, index) {
                      final line = transcriptLines[index];
                      final isActive = _currentActiveIndex == index;
                      final isPassed = widget.currentPositionMs != null && 
                          line.isPassedAt(widget.currentPositionMs!);
                      
                      return Container(
                        margin: const EdgeInsets.only(bottom: 6),
                        padding: const EdgeInsets.all(6),
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
                            // Speaker name
                            Text(
                              line.speaker,
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.bold,
                                color: isActive 
                                    ? CategoryColors.getCategoryColor(widget.episode.category)
                                    : Theme.of(context).colorScheme.primary,
                              ),
                            ),
                            const SizedBox(height: 6),
                            // Text content
                            Text(
                              line.text,
                              style: TextStyle(
                                fontSize: 14,
                                height: 1.5,
                                color: isActive 
                                    ? Theme.of(context).colorScheme.onSurface
                                    : Theme.of(context).colorScheme.onSurface.withOpacity(0.8),
                              ),
                            ),
                            const SizedBox(height: 6),
                            // Play button thay vì time info
                            Row(
                              children: [
                                IconButton(
                                  onPressed: () {
                                    // Gọi callback để play tại startTime của dòng này
                                    widget.onPlayAtTime?.call(line.startTime);
                                  },
                                  icon: Icon(
                                    Icons.play_arrow,
                                    color: CategoryColors.getCategoryColor(widget.episode.category),
                                    size: 16,
                                  ),
                                  tooltip: 'Play từ ${(line.startTime / 1000).toStringAsFixed(1)}s',
                                  padding: EdgeInsets.zero,
                                  constraints: const BoxConstraints(
                                    minWidth: 24,
                                    minHeight: 24,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  '${(line.startTime / 1000).toStringAsFixed(1)}s - ${(line.endTime / 1000).toStringAsFixed(1)}s',
                                  style: TextStyle(
                                    fontSize: 10,
                                    color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
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

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }
}




