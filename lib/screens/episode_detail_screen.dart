import 'package:flutter/material.dart';
import 'package:wakelock_plus/wakelock_plus.dart';
import '../models/episode.dart';
import '../utils/category_colors.dart';
import '../services/audio_player_service.dart';
import '../services/language_manager.dart';
import '../widgets/audio_player_widget.dart';
import '../widgets/episode_info_slide.dart';
import '../widgets/transcript_slide.dart';
import '../widgets/vocabulary_slide.dart';
import '../services/admob_service.dart';

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
  late final AudioPlayerService _audioService;
  late final PageController _pageController;
  late final LanguageManager _languageManager;
  int _currentPageIndex = 1; // Mặc định là slide thứ 1 (Episode Info)

  @override
  void initState() {
    super.initState();
    _audioService = AudioPlayerService();
    _languageManager = LanguageManager();
    _pageController = PageController(initialPage: 1); // Khởi tạo ở slide thứ 1 (Episode Info)

    // Load episode vào audio service với category episodes
    _audioService.loadEpisodeWithCategory(widget.episode, widget.categoryEpisodes);
    
    // Bật Always Display (Wakelock) để màn hình không tự tắt
    _enableAlwaysDisplay();
    
    // Tạo interstitial ad để sẵn sàng hiển thị
    AdMobService().createInterstitialAd();
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
    
    // Giảm tần suất interstitial ad khi rời khỏi màn hình
    // Chỉ hiển thị 50% thời gian để giảm quảng cáo
    if (DateTime.now().millisecondsSinceEpoch % 2 == 0) {
      Future.delayed(const Duration(seconds: 2), () {
        AdMobService().showInterstitialAd();
      });
    }
    
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: _languageManager,
      builder: (context, child) {
        final categoryColor = CategoryColors.getCategoryColor(widget.episode.category);
        
        return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surface,
      appBar: AppBar(
        backgroundColor: categoryColor,
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          // Favourite button
          ListenableBuilder(
            listenable: _audioService,
            builder: (context, child) {
              return IconButton(
                onPressed: () => _audioService.toggleFavourite(),
                icon: Icon(
                  _audioService.isFavourite ? Icons.favorite : Icons.favorite_border,
                  color: Colors.white,
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
                  color: Colors.white,
                ),
              );
            },
          ),
        ],
      ),
      body: Column(
        children: [
          // Episode Name Header
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(20),
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
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Episode Name
                Text(
                  widget.episode.episodeName,
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    height: 1.3,
                    color: Theme.of(context).colorScheme.onSurface,
                  ),
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 8),
                // Category Badge, Duration and Date - Cùng một dòng
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    // Category Badge
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: categoryColor,
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Text(
                        widget.episode.category,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    // Duration and Date
                    Row(
                      children: [
                        Icon(
                          Icons.access_time,
                          size: 16,
                          color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
                        ),
                        const SizedBox(width: 4),
                        Text(
                          widget.episode.duration,
                          style: TextStyle(
                            fontSize: 14,
                            color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
                          ),
                        ),
                        const SizedBox(width: 16),
                        Icon(
                          Icons.calendar_today,
                          size: 16,
                          color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
                        ),
                        const SizedBox(width: 4),
                        Text(
                          _formatDate(widget.episode.publishedDate),
                          style: TextStyle(
                            fontSize: 14,
                            color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ],
            ),
          ),
          // Carousel Indicators
          Container(
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(3, (index) {
                return Container(
                  margin: const EdgeInsets.symmetric(horizontal: 4),
                  width: _currentPageIndex == index ? 24 : 8,
                  height: 8,
                  decoration: BoxDecoration(
                    color: _currentPageIndex == index 
                        ? categoryColor 
                        : Theme.of(context).colorScheme.onSurface.withOpacity(0.3),
                    borderRadius: BorderRadius.circular(4),
                  ),
                );
              }),
            ),
          ),
          // Carousel Content
          Expanded(
            child: PageView(
              controller: _pageController,
              onPageChanged: (index) {
                setState(() {
                  _currentPageIndex = index;
                });
              },
              children: [
                // Slide 1: Episode Info
                EpisodeInfoSlide(
                  languageManager: _languageManager,
                  episode: widget.episode,
                  topEpisodes: widget.categoryEpisodes,
                  onEpisodeTap: (episode) {
                    // Navigate to new episode detail với cùng category episodes
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
                // Slide 2: Transcript
                ListenableBuilder(
                  listenable: _audioService,
                  builder: (context, child) {
                    return TranscriptSlide(
                      episode: widget.episode,
                      currentPositionMs: _audioService.currentPositionMs,
                      onPlayAtTime: (startTimeMs) {
                        // Seek audio đến thời điểm cụ thể và play
                        _audioService.seekTo(Duration(milliseconds: startTimeMs));
                        _audioService.play();
                      },
                    );
                  },
                ),
                // Slide 3: Vocabulary
                VocabularySlide(episode: widget.episode),
              ],
            ),
          ),
          // Audio Player
          AudioPlayerWidget(audioService: _audioService),
        ],
      ),
        );
      },
    );
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
}
