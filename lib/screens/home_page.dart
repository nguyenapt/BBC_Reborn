import 'package:flutter/material.dart';
import 'dart:math';
import 'dart:async';
import '../services/audio_player_service.dart';
import '../models/cefr_level.dart';
import '../models/episode_learning_progress.dart';
import '../models/episode.dart';
import '../models/vocabulary_item.dart';
import '../services/firebase_service.dart';
import '../services/language_manager.dart';
import '../services/image_cache_service.dart';
import '../services/episode_detail_open_helper.dart';
import '../services/learning_progress_service.dart';
import '../services/saved_grammar_service.dart';
import '../services/vocabulary_service.dart';
import '../services/vocabulary_practice_service.dart';
import '../widgets/heart_widget.dart';
import '../widgets/home_learning_dashboard.dart';
import '../widgets/streak_widget.dart';
import '../widgets/daily_goal_widget.dart';
import '../utils/user_facing_error.dart';
import 'categories_screen.dart';
import 'episode_search_screen.dart';
import 'vocabulary_practice_screen.dart';
import 'saved_screen.dart';
import '../widgets/floating_bottom_nav_bar.dart';

class HomePage extends StatefulWidget {
  final Function(String)? onNavigateToCategory;
  final Function(String)? onNavigateToGrammar;
  final VoidCallback? onNavigateToMyHubDailyGoal;

  const HomePage({
    super.key,
    this.onNavigateToCategory,
    this.onNavigateToGrammar,
    this.onNavigateToMyHubDailyGoal,
  });

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final FirebaseService _firebaseService = FirebaseService();
  final LanguageManager _languageManager = LanguageManager();
  final LearningProgressService _learningProgress = LearningProgressService();
  final VocabularyService _vocabularyService = VocabularyService();
  final VocabularyPracticeService _vocabPracticeService = VocabularyPracticeService();
  final SavedGrammarService _savedGrammarService = SavedGrammarService();
  List<Episode> _allEpisodes = [];
  bool _isLoading = true;
  String? _error;
  late final String _heroImageAsset;
  static String? _sessionHeroImageAsset;
  Episode? _continueEpisode;
  EpisodeLearningProgress? _continueProgress;
  VocabularyItem? _wordOfTheDay;

  static const List<String> _heroImageAssets = [
    'assets/images/hero/cta_modern.png',
    // Add more images here, e.g.
     'assets/images/hero/hero_01.png',
     'assets/images/hero/hero_02.png',
     'assets/images/hero/hero_03.png',
  ];

  @override
  void initState() {
    super.initState();
    _sessionHeroImageAsset ??= _pickHeroImageForSession(_heroImageAssets);
    _heroImageAsset = _sessionHeroImageAsset!;
    _learningProgress.addListener(_onLearningProgressChanged);
    _vocabularyService.addListener(_onLearningProgressChanged);
    unawaited(_bootstrapLearningDashboard());
    _loadData();
  }

  Future<void> _bootstrapLearningDashboard() async {
    await Future.wait([
      _vocabularyService.initialize(),
      _vocabPracticeService.initialize(),
      _learningProgress.initialize(),
    ]);
    await _refreshWordOfTheDay();
    if (mounted) {
      setState(() {});
    }
  }

  Future<void> _refreshWordOfTheDay() async {
    final items = _vocabularyService.savedVocabularies;
    final word = await _vocabPracticeService.pickWordOfTheDayCached(items);
    if (mounted) {
      _wordOfTheDay = word;
    }
  }

  @override
  void dispose() {
    _learningProgress.removeListener(_onLearningProgressChanged);
    _vocabularyService.removeListener(_onLearningProgressChanged);
    super.dispose();
  }

  Future<void> _loadData() async {
    try {
      setState(() {
        _isLoading = true;
        _error = null;
      });

      // CEFR flat list for continue / latest / thumbs — không còn HomePage 3-item sections.
      final episodes = await _firebaseService.getAllEpisodesFlat();
      _preloadImages(episodes);

      setState(() {
        _allEpisodes = episodes;
        _isLoading = false;
      });
      await _resolveContinueEpisode();
    } catch (e) {
      debugPrint('Error loading home data: $e');
      setState(() {
        _error = UserFacingError.message(e);
        _isLoading = false;
      });
    }
  }

  void _preloadImages(List<Episode> episodes) {
    final imageUrls = <String>[];
    for (final episode in episodes.take(6)) {
      if (episode.thumbImage.isNotEmpty) {
        imageUrls.add(episode.thumbImage);
      }
    }
    if (imageUrls.isNotEmpty) {
      ImageCacheService().preloadImages(imageUrls);
    }
  }

  void _navigateToEpisodeDetail(Episode episode) {
    final peers = _allEpisodes
        .where((e) => e.category == episode.category)
        .toList();
    EpisodeDetailOpenHelper.open(
      context: context,
      episode: episode,
      categoryEpisodes: peers.isNotEmpty ? peers : [episode],
    );
  }

  void _navigateToCategory(String levelCode) {
    final tab = CefrLevel.tryParse(levelCode)?.code ?? CefrLevel.a1.code;
    if (widget.onNavigateToCategory != null) {
      widget.onNavigateToCategory!(tab);
    } else {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => CategoriesScreen(initialTab: tab),
        ),
      );
    }
  }

  String _cefrSubtitle(CefrLevel level) {
    switch (level) {
      case CefrLevel.a1:
      case CefrLevel.a2:
        return _languageManager.getText('levelBeginner');
      case CefrLevel.b1:
      case CefrLevel.b2:
        return _languageManager.getText('levelIntermediate');
      case CefrLevel.c1:
      case CefrLevel.c2:
        return _languageManager.getText('levelAdvanced');
    }
  }

  Episode? _findEpisodeById(String episodeId) {
    for (final episode in _allEpisodes) {
      if (episode.id == episodeId || episode.resolvedStorageId == episodeId) {
        return episode;
      }
    }
    return null;
  }

  Future<void> _resolveContinueEpisode() async {
    await _learningProgress.initialize();
    await _vocabPracticeService.initialize();
    final progress = _learningProgress.getMostRecentContinue();
    if (progress == null) {
      if (mounted) {
        setState(() {
          _continueProgress = null;
          _continueEpisode = null;
        });
      }
      return;
    }

    var episode = _findEpisodeById(progress.episodeId);
    episode ??= await _learningProgress.resolveEpisodeForProgress(progress);

    if (mounted) {
      setState(() {
        _continueProgress = progress;
        _continueEpisode = episode;
      });
    }
  }

  void _onLearningProgressChanged() {
    if (mounted) {
      unawaited(_resolveContinueEpisode());
      unawaited(_refreshWordOfTheDay().then((_) {
        if (mounted) setState(() {});
      }));
    }
  }

  int _countDueVocab() {
    final items = _vocabularyService.savedVocabularies;
    return items.where((w) => _vocabPracticeService.isDue(w)).length;
  }

  /// Welcome CTA chỉ cho user mới chưa bắt đầu học.
  bool _shouldShowWelcomeHero() {
    final hasContinue =
        _continueProgress != null && _continueEpisode != null;
    if (hasContinue) return false;
    if (_learningProgress.hasEverLearned) return false;
    return true;
  }

  Widget _buildLearningDashboard() {
    final continueProgress = _continueProgress;
    final continueEpisode = _continueEpisode;
    final vocabItems = _vocabularyService.savedVocabularies;
    final wordOfDay = _wordOfTheDay;
    final latest = _getLatestEpisode();

    return HomeLearningDashboard(
      continueProgress: continueProgress,
      continueEpisode: continueEpisode,
      dueVocabCount: _countDueVocab(),
      dueGrammarCount: _savedGrammarService.dueReviewItems.length,
      wordOfTheDay: wordOfDay,
      latestEpisode: latest,
      onContinueTap: continueEpisode == null
          ? null
          : () => _openContinueLearning(continueEpisode, continueProgress!),
      onReviewVocabTap: vocabItems.isEmpty
          ? null
          : () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => VocabularyPracticeScreen(
                    allWords: vocabItems,
                  ),
                ),
              );
            },
      onReviewGrammarTap: _savedGrammarService.dueReviewItems.isEmpty
          ? null
          : () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const MyLearningScreen(),
                ),
              );
            },
      onWordOfDayTap: wordOfDay == null
          ? null
          : () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => VocabularyPracticeScreen(
                    allWords: vocabItems,
                    initialWords: [wordOfDay],
                  ),
                ),
              );
            },
      onLatestEpisodeTap: latest == null ? null : () => _navigateToEpisodeDetail(latest),
    );
  }

  void _openContinueLearning(
    Episode episode,
    EpisodeLearningProgress progress,
  ) {
    if (progress.lastPositionMs > 0) {
      AudioPlayerService().setPendingSeekPosition(
        Duration(milliseconds: progress.lastPositionMs),
      );
    }
    _navigateToEpisodeDetail(episode);
  }

  // Xây dựng Pinned Header với màu sắc theo theme
  Widget _buildPinnedHeader() {
    final ThemeData theme = Theme.of(context);
    final ColorScheme colorScheme = theme.colorScheme;

    return Container(
      decoration: BoxDecoration(
        color: colorScheme.surface,
        boxShadow: [
          BoxShadow(
            color: colorScheme.shadow.withOpacity(0.1),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      padding: EdgeInsets.only(
        top: MediaQuery.of(context).padding.top + 16,
        left: 16,
        right: 16,
        bottom: 16,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [          
              // App title
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      _languageManager.getText('homeTitleMain'),
                      style: theme.textTheme.headlineSmall!.copyWith(
                        color: colorScheme.onSurface,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      _languageManager.getText('homeTitleSub'),
                      style: theme.textTheme.bodySmall!.copyWith(
                        color: colorScheme.onSurface.withOpacity(0.8),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              IconButton(
                onPressed: _openSearch,
                icon: Icon(
                  Icons.search,
                  color: colorScheme.onSurface,
                ),
                tooltip: _languageManager.getText('searchEpisodes'),
              ),
              const SizedBox(width: 8),
              const StreakWidget(),
              const SizedBox(width: 8),
              const HeartWidget(),
            ],
          ),
        ],
      ),
    );
  }

  void _openSearch() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => const EpisodeSearchScreen(),
      ),
    );
  }

  Episode? _getLatestEpisode() {
    Episode? latest;
    for (final episode in _allEpisodes) {
      if (latest == null ||
          episode.publishedDate.isAfter(latest.publishedDate)) {
        latest = episode;
      }
    }
    return latest;
  }

  void _openLatestEpisode() {
    final latest = _getLatestEpisode();
    if (latest == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(_languageManager.getText('noData')),
          duration: const Duration(seconds: 2),
        ),
      );
      return;
    }
    _navigateToEpisodeDetail(latest);
  }

  Widget _buildHeroSection() {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final strongAccent = Color.lerp(colorScheme.primary, colorScheme.onSurface, 0.22)!;

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: colorScheme.shadow.withOpacity(0.08),
            blurRadius: 12,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _languageManager.getText('homeHeroTitle'),
                  style: theme.textTheme.titleMedium!.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  _languageManager.getText('homeHeroSubtitle'),
                  style: theme.textTheme.bodyMedium!.copyWith(
                    color: colorScheme.onSurface.withOpacity(0.7),
                  ),
                ),
                const SizedBox(height: 12),
                ElevatedButton(
                  onPressed: _openLatestEpisode,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: strongAccent,
                    foregroundColor: colorScheme.onPrimary,
                    padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    elevation: 0,
                  ),
                  child: Text(_languageManager.getText('startPracticingListening')),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: Image.asset(
              _heroImageAsset,
              width: 120,
              height: 120,
              fit: BoxFit.cover,
            ),
          ),
        ],
      ),
    );
  }

  String _pickHeroImageForSession(List<String> assets) {
    if (assets.isEmpty) {
      return 'assets/images/hero/cta_modern.png';
    }
    final index = Random().nextInt(assets.length);
    return assets[index];
  }

  Widget _buildCategorySection() {
    final theme = Theme.of(context);
    final cardColor = theme.colorScheme.surface;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            _languageManager.getText('chooseListeningCategory'),
            style: theme.textTheme.titleMedium!.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 12),
          LayoutBuilder(
            builder: (context, constraints) {
              final cardWidth = (constraints.maxWidth - 12) / 2;
              return Wrap(
                spacing: 12,
                runSpacing: 12,
                children: [
                  for (final level in CefrLevel.all)
                    _buildCategoryCard(
                      width: cardWidth,
                      letter: level.code,
                      title: level.code,
                      subtitle: _cefrSubtitle(level),
                      color: cardColor,
                      badgeColor: theme.colorScheme.primary,
                      onTap: () => _navigateToCategory(level.code),
                    ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildCategoryCard({
    required double width,
    required String letter,
    required String title,
    required String subtitle,
    required Color color,
    required Color badgeColor,
    required VoidCallback onTap,
  }) {
    final theme = Theme.of(context);
    return SizedBox(
      width: width,
      child: Container(
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: theme.colorScheme.outlineVariant.withOpacity(0.35),
          ),
          boxShadow: [
            BoxShadow(
              color: theme.colorScheme.shadow.withOpacity(0.06),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Material(
          color: Colors.transparent,
          borderRadius: BorderRadius.circular(14),
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(14),
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Row(
                children: [
                  Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: badgeColor,
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      letter,
                      style: theme.textTheme.labelMedium!.copyWith(
                        color: theme.colorScheme.onPrimary,
                        fontWeight: FontWeight.bold,
                        fontSize: letter.length > 1 ? 11 : 14,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          title,
                          style: theme.textTheme.bodyMedium!.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          subtitle,
                          style: theme.textTheme.bodySmall!.copyWith(
                            color: theme.colorScheme.onSurface.withOpacity(0.6),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: _languageManager,
      builder: (context, child) {
        if (_isLoading) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                CircularProgressIndicator(),
                SizedBox(height: 16),
                Text(_languageManager.getText('loading')),
              ],
            ),
          );
        }

    if (_error != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.error_outline,
              size: 64,
              color: Theme.of(context).colorScheme.error.withOpacity(0.75),
            ),
            const SizedBox(height: 16),
            Text(
              _languageManager.getText('errorOccurred'),
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: 8),
            Text(
              _error!,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Theme.of(context).colorScheme.onSurface.withOpacity(0.68),
              ),
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _loadData,
              child: Text(_languageManager.getText('tryAgain')),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadData,
      child: CustomScrollView(
        slivers: <Widget>[
          PinnedHeaderSliver(
            child: _buildPinnedHeader(),
          ),
          SliverToBoxAdapter(
            child: DailyGoalWidget(
              onTap: widget.onNavigateToMyHubDailyGoal,
            ),
          ),
          SliverToBoxAdapter(
            child: _buildLearningDashboard(),
          ),
          if (_shouldShowWelcomeHero())
            SliverToBoxAdapter(
              child: _buildHeroSection(),
            ),
          // Card chọn category (giữ như cũ) — đã bỏ block 3 items 6M/TEWS/AS
          SliverToBoxAdapter(
            child: _buildCategorySection(),
          ),
          SliverToBoxAdapter(
            child: SizedBox(
              height: FloatingBottomNavBar.scrollPadding(context).bottom,
            ),
          ),
        ],
      ),
    );
      },
    );
  }
}
