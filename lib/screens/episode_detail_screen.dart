import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:wakelock_plus/wakelock_plus.dart';
import '../models/episode.dart';
import '../utils/category_colors.dart';
import '../services/audio_player_service.dart';
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
  final bool shouldShowInterstitialOnEnter;

  const EpisodeDetailScreen({
    super.key,
    required this.episode,
    required this.categoryEpisodes,
    this.shouldShowInterstitialOnEnter = false,
  });

  @override
  State<EpisodeDetailScreen> createState() => _EpisodeDetailScreenState();
}

class _EpisodeDetailScreenState extends State<EpisodeDetailScreen> {
  late final AudioPlayerService _audioService;
  late final PageController _pageController;
  late final LanguageManager _languageManager;
  int _currentPageIndex = 0; // Transcript
  bool _hasShownInterstitialAd = false;

  @override
  void initState() {
    super.initState();
    _audioService = AudioPlayerService();
    _languageManager = LanguageManager();
    _pageController = PageController(initialPage: 0);

    // Load episode vào audio service với category episodes
    _audioService.loadEpisodeWithCategory(widget.episode, widget.categoryEpisodes);
    
    // Bật Always Display (Wakelock) để màn hình không tự tắt
    _enableAlwaysDisplay();
    
    // Tạo interstitial ad để sẵn sàng hiển thị
    AdMobService().createInterstitialAd();
    
    // Hiển thị interstitial ad ngay nếu flag = true (50% trường hợp)
    if (widget.shouldShowInterstitialOnEnter) {
      Future.delayed(const Duration(milliseconds: 500), () {
        AdMobService().showInterstitialAd();
        setState(() {
          _hasShownInterstitialAd = true;
        });
      });
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
    
    // Luôn hiển thị interstitial ad khi rời khỏi màn hình
    Future.delayed(const Duration(seconds: 2), () {
      AdMobService().showInterstitialAd();
    });
    
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
          IconButton(
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => SpeakingPracticeScreen(
                    episode: widget.episode,
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
      body: Column(
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
                        widget.episode.category,
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
                        widget.episode.episodeName,
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
                          widget.episode.duration,
                          style: TextStyle(
                            fontSize: 14,
                            color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
                          ),
                        ),
                        // Chỉ hiển thị date nếu không phải Other Programs category
                        if (!_isOtherProgramsCategory(widget.episode.category)) ...[
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
                      ],
                    ),
                  ],
                ),
              ],
            ),
          ),
          _buildDetailTabs(context, categoryColor),
          Expanded(
            child: PageView(
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
                      episode: widget.episode,
                      currentPositionMs: _audioService.currentPositionMs,
                      onPlayAtTime: (startTimeMs) {
                        _audioService.seekTo(Duration(milliseconds: startTimeMs));
                        _audioService.play();
                      },
                    );
                  },
                ),
                EpisodeInfoSlide(
                  languageManager: _languageManager,
                  episode: widget.episode,
                  topEpisodes: widget.categoryEpisodes,
                  onEpisodeTap: (episode) {
                    const shouldShowInterstitial = true;
                    Navigator.pushReplacement(
                      context,
                      MaterialPageRoute(
                        builder: (context) => EpisodeDetailScreen(
                          episode: episode,
                          categoryEpisodes: widget.categoryEpisodes,
                          shouldShowInterstitialOnEnter: shouldShowInterstitial,
                        ),
                      ),
                    );
                  },
                ),
                VocabularySlide(episode: widget.episode),
                QuestionSlide(episode: widget.episode),
              ],
            ),
          ),
          // Audio Player
          AudioPlayerWidget(
            audioService: _audioService,
            onPlayPressed: () async {
              // Nếu chưa hiển thị interstitial ads, hiển thị trước khi play
              if (!_hasShownInterstitialAd) {
                AdMobService().showInterstitialAd();
                setState(() {
                  _hasShownInterstitialAd = true;
                });
                // Đợi một chút để ad hiển thị
                await Future.delayed(const Duration(milliseconds: 500));
              }
            },
          ),
        ],
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
    const otherProgramsCategories = ['6MGB', '6MGI', '6MVB', '6MVI', 'DRM', 'EAW'];
    return otherProgramsCategories.contains(category);
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
          const SnackBar(content: Text('Không thể mở Google Translate')),
        );
      }
    }
  }
}
