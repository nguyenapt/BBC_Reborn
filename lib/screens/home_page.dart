import 'package:flutter/material.dart';
import 'dart:math';
import '../models/category.dart';
import '../models/episode.dart';
import '../services/firebase_service.dart';
import '../services/episode_cache_service.dart';
import '../services/language_manager.dart';
import '../services/image_cache_service.dart';
import '../services/episode_detail_open_helper.dart';
import '../widgets/category_group_box.dart';
import '../widgets/heart_widget.dart';
import '../widgets/other_programs_category_widget.dart';
import '../utils/category_names.dart';
import 'categories_screen.dart';
import 'grammar_screen.dart';
import 'episode_search_screen.dart';

class HomePage extends StatefulWidget {
  final Function(String)? onNavigateToCategory;
  final Function(String)? onNavigateToGrammar;
  
  const HomePage({super.key, this.onNavigateToCategory, this.onNavigateToGrammar});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final FirebaseService _firebaseService = FirebaseService();
  final EpisodeCacheService _episodeCacheService = EpisodeCacheService();
  final LanguageManager _languageManager = LanguageManager();
  List<Category> _categories = [];
  List<Category> _anotherSeriesCategories = [];
  Category? _bsaCategory;
  bool _isLoading = true;
  String? _error;
  late final String _heroImageAsset;
  static String? _sessionHeroImageAsset;

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
    _loadData();
  }

  Future<void> _loadData() async {
    try {
      setState(() {
        _isLoading = true;
        _error = null;
      });

      print('Loading home page data...');
      final categories = await _firebaseService.getHomePageData();
      final anotherSeries = await _loadAnotherSeriesCategories();
      final bsaEpisodes =
          await _episodeCacheService.getAnotherSeriesFixedCategoryEpisodes('BSA');
      final bsaCategory =
          bsaEpisodes.isNotEmpty ? Category(name: 'BSA', episodes: bsaEpisodes) : null;
      print('Loaded ${categories.length} categories, Another Series: ${anotherSeries.length}');

      _preloadImages(categories, anotherSeries, bsaCategory: bsaCategory);

      setState(() {
        _categories = categories;
        _anotherSeriesCategories = anotherSeries;
        _bsaCategory = bsaCategory;
        _isLoading = false;
      });
    } catch (e) {
      print('Error loading data: $e');
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  Future<List<Category>> _loadAnotherSeriesCategories() async {
    try {
      final subKeys =
          await FirebaseService.fetchAnotherSeriesSubKeys(forHomePage: true);
      final list = <Category>[];
      for (final sub in subKeys) {
        final episodes = await _episodeCacheService.getAnotherSeriesSubEpisodes(
          sub,
          forHomePage: true,
        );
        if (episodes.isNotEmpty) {
          list.add(Category(name: sub, episodes: episodes));
        }
      }
      return list;
    } catch (e) {
      print('Another Series (home) load error: $e');
      return [];
    }
  }

  /// Preload images for better performance
  void _preloadImages(
    List<Category> categories,
    List<Category> anotherSeries, {
    Category? bsaCategory,
  }) {
    final imageUrls = <String>[];
    
    // Collect all image URLs from first few episodes of each category
    for (final category in [
      ...categories,
      ...anotherSeries,
      if (bsaCategory != null) bsaCategory,
    ]) {
      final episodes = category.episodes.take(3); // Only preload first 3 episodes
      for (final episode in episodes) {
        if (episode.thumbImage.isNotEmpty) {
          imageUrls.add(episode.thumbImage);
        }
      }
    }
    
    // Preload images in background
    if (imageUrls.isNotEmpty) {
      ImageCacheService().preloadImages(imageUrls);
    }
  }

  void _navigateToEpisodeDetail(Episode episode) {
    // Tìm category chứa episode này
    Category? episodeCategory;
    for (final category in _categories) {
      if (category.name == episode.category) {
        episodeCategory = category;
        break;
      }
    }
    if (episodeCategory == null) {
      for (final category in _anotherSeriesCategories) {
        if (category.name == episode.category) {
          episodeCategory = category;
          break;
        }
      }
    }
    if (episodeCategory == null && _bsaCategory != null) {
      if (_bsaCategory!.name == episode.category) {
        episodeCategory = _bsaCategory;
      }
    }

    final resolvedCategory = episodeCategory;
    if (resolvedCategory != null) {
      EpisodeDetailOpenHelper.open(
        context: context,
        episode: episode,
        categoryEpisodes: resolvedCategory.episodes,
      );
    } else {
      // Fallback nếu không tìm thấy category
      EpisodeDetailOpenHelper.open(
        context: context,
        episode: episode,
        categoryEpisodes: [episode],
      );
    }
  }

  void _navigateToCategory(String categoryName) {
    if (CategoryNames.opensAnotherSeriesTab(categoryName)) {
      if (widget.onNavigateToCategory != null) {
        widget.onNavigateToCategory!('AS');
      } else {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => const CategoriesScreen(initialTab: 'AS'),
          ),
        );
      }
      return;
    }

    // Kiểm tra nếu là category EG (English Grammar) thì navigate đến Grammar screen
    if (categoryName == 'EG') {
      if (widget.onNavigateToGrammar != null) {
        widget.onNavigateToGrammar!('English Grammar');
      } else {
        // Fallback: sử dụng Navigator.push
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => const GrammarScreen(initialTab: 'English Grammar'),
          ),
        );
      }
      return;
    }
    
    // Sử dụng callback từ main.dart nếu có, ngược lại sử dụng Navigator.push
    if (widget.onNavigateToCategory != null) {
      widget.onNavigateToCategory!(categoryName);
    } else {
      // Fallback: sử dụng Navigator.push
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => CategoriesScreen(initialTab: categoryName),
        ),
      );
    }
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
                      'Speak British',
                      style: theme.textTheme.headlineSmall!.copyWith(
                        color: colorScheme.onSurface,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'The English voice',
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
    for (final category in [
      ..._categories,
      ..._anotherSeriesCategories,
      if (_bsaCategory != null) _bsaCategory!,
    ]) {
      for (final episode in category.episodes) {
        if (latest == null || episode.publishedDate.isAfter(latest.publishedDate)) {
          latest = episode;
        }
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

  /// Categories từ [getHomePageData] chưa render ở block ưu tiên / Another Series.
  /// BSA bỏ qua khi đã có [_bsaCategory] (tránh trùng key `BSA` trong List/HomePage.json).
  List<Category> _remainingHomeCategories() {
    return _categories.where((c) {
      if (c.name == '6M' || c.name == 'TEWS' || c.name == 'REE') return false;
      if (c.name == 'BSA' && _bsaCategory != null) return false;
      return true;
    }).toList();
  }

  Widget _buildAnotherSeriesSection() {
    if (_anotherSeriesCategories.isEmpty) return const SizedBox.shrink();
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final strongAccent = Color.lerp(colorScheme.primary, colorScheme.onSurface, 0.22)!;

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 12, 16, 8),
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Container(
            decoration: BoxDecoration(
              color: colorScheme.surface,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: colorScheme.outlineVariant.withOpacity(0.35),
              ),
              boxShadow: [
                BoxShadow(
                  color: colorScheme.shadow.withOpacity(0.06),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 16),
                for (int i = 0; i < _anotherSeriesCategories.length; i++) ...[
                  OtherProgramsCategoryWidget(
                    categoryName: _anotherSeriesCategories[i].name,
                    episodes: _anotherSeriesCategories[i].episodes,
                    onEpisodeTap: _navigateToEpisodeDetail,
                    languageManager: _languageManager,
                    onViewAllTap: _navigateToCategory,
                  ),
                  if (i != _anotherSeriesCategories.length - 1)
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      child: Divider(
                        height: 18,
                        thickness: 1.2,
                        color: colorScheme.outlineVariant.withOpacity(0.55),
                      ),
                    ),
                ],
              ],
            ),
          ),
          Positioned(
            top: -10,
            left: 0,
            right: 0,
            child: Center(
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                decoration: BoxDecoration(
                  color: colorScheme.surface,
                  borderRadius: BorderRadius.circular(999),
                  border: Border.all(
                    color: colorScheme.outlineVariant.withOpacity(0.55),
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: colorScheme.shadow.withOpacity(0.06),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Text(
                  _languageManager.getText('homeAnotherSeriesSection'),
                  style: theme.textTheme.labelMedium!.copyWith(
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.2,
                    color: strongAccent,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
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
                  _buildCategoryCard(
                    width: cardWidth,
                    letter: '6',
                    title: _languageManager.getText('categorySixMinutes'),
                    subtitle: _languageManager.getText('categoryConversation'),
                    color: cardColor,
                    badgeColor: theme.colorScheme.primary,
                    onTap: () => _navigateToCategory('6M'),
                  ),
                  _buildCategoryCard(
                    width: cardWidth,
                    letter: 'T',
                    title: _languageManager.getText('categoryTheEnglish'),
                    subtitle: _languageManager.getText('categoryWeSpeak'),
                    color: cardColor,
                    badgeColor: theme.colorScheme.primary,
                    onTap: () => _navigateToCategory('TEWS'),
                  ),
                  _buildCategoryCard(
                    width: cardWidth,
                    letter: 'R',
                    title: _languageManager.getText('categoryRealEasy'),
                    subtitle: _languageManager.getText('categoryEnglish'),
                    color: cardColor,
                    badgeColor: theme.colorScheme.primary,
                    onTap: () => _navigateToCategory('REE'),
                  ),
                  _buildCategoryCard(
                    width: cardWidth,
                    letter: 'E',
                    title: _languageManager.getText('categoryEnglish'),
                    subtitle: _languageManager.getText('categoryGrammar'),
                    color: cardColor,
                    badgeColor: theme.colorScheme.primary,
                    onTap: () => _navigateToCategory('EG'),
                  ),
                  _buildCategoryCard(
                    width: constraints.maxWidth,
                    letter: 'A',
                    title: 'Another',
                    subtitle: 'Series',
                    color: cardColor,
                    badgeColor: theme.colorScheme.primary,
                    onTap: () => _navigateToCategory('AS'),
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
                      style: theme.textTheme.labelLarge!.copyWith(
                        color: theme.colorScheme.onPrimary,
                        fontWeight: FontWeight.bold,
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

    if (_categories.isEmpty &&
        _anotherSeriesCategories.isEmpty &&
        _bsaCategory == null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.inbox_outlined,
              size: 64,
              color: Theme.of(context).colorScheme.onSurface.withOpacity(0.45),
            ),
            const SizedBox(height: 16),
            Text(
              _languageManager.getText('noData'),
              style: TextStyle(
                fontSize: 18,
                color: Theme.of(context).colorScheme.onSurface.withOpacity(0.72),
              ),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadData,
      child: CustomScrollView(
        slivers: <Widget>[
          // PinnedHeaderSliver cho WelcomeHeader
          PinnedHeaderSliver(
            child: _buildPinnedHeader(),
          ),
          
          // CTA Hero
          SliverToBoxAdapter(
            child: _buildHeroSection(),
          ),

          // Category cards
          SliverToBoxAdapter(
            child: _buildCategorySection(),
          ),

          // Priority sections: 6M -> TEWS -> REE
          SliverList(
            delegate: SliverChildListDelegate(
              [
                for (final name in const ['6M', 'TEWS', 'REE'])
                  ..._categories
                      .where((c) => c.name == name)
                      .map(
                        (category) => CategoryGroupBox(
                          category: category,
                          onEpisodeTap: _navigateToEpisodeDetail,
                          onViewAllTap: _navigateToCategory,
                        ),
                      ),
                if (_bsaCategory != null)
                  CategoryGroupBox(
                    category: _bsaCategory!,
                    onEpisodeTap: _navigateToEpisodeDetail,
                    onViewAllTap: _navigateToCategory,
                  ),
              ],
            ),
          ),

          SliverToBoxAdapter(
            child: _buildAnotherSeriesSection(),
          ),

          // Remaining categories (HomePage slim)
          SliverList(
            delegate: SliverChildBuilderDelegate(
              (context, index) {
                final remaining = _remainingHomeCategories();
                final category = remaining[index];
                return CategoryGroupBox(
                  category: category,
                  onEpisodeTap: _navigateToEpisodeDetail,
                  onViewAllTap: _navigateToCategory,
                );
              },
              childCount: _remainingHomeCategories().length,
            ),
          ),          
          
          // Bottom padding
          const SliverToBoxAdapter(
            child: SizedBox(height: 20),
          ),
        ],
      ),
    );
      },
    );
  }
}
