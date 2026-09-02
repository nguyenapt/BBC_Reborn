import 'package:flutter/material.dart';
import '../models/episode.dart';
import '../services/episode_cache_service.dart';
import '../services/language_manager.dart';
import '../services/learning_progress_service.dart';
import '../services/episode_detail_open_helper.dart';
import '../widgets/episode_row.dart';
import '../widgets/banner_ad_widget.dart';
import '../widgets/floating_bottom_nav_bar.dart';
import '../widgets/another_series_sub_section.dart';
import '../utils/category_names.dart';
import '../utils/lle_level_groups.dart';

class CategoriesScreen extends StatefulWidget {
  final String? initialTab;
  
  const CategoriesScreen({super.key, this.initialTab});

  @override
  State<CategoriesScreen> createState() => _CategoriesScreenState();
}

class _CategoriesScreenState extends State<CategoriesScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final LanguageManager _languageManager = LanguageManager();
  final EpisodeCacheService _episodeCacheService = EpisodeCacheService();
  final LearningProgressService _learningProgress = LearningProgressService();
  
  late final VoidCallback _learningProgressListener;
  // Data cho từng tab
  Map<String, List<Episode>> _episodesData = {};
  final Map<String, bool> _loadingStates = {
    for (final c in CategoryNames.primaryTabCodes) c: false,
  };
  final Map<String, String?> _errorStates = {
    for (final c in CategoryNames.primaryTabCodes) c: null,
  };
  // Theo dõi các năm đã load cho mỗi category
  final Map<String, List<int>> _loadedYears = {
    for (final c in CategoryNames.primaryTabCodes) c: <int>[],
  };
  // Trạng thái loading more cho mỗi category
  final Map<String, bool> _loadingMoreStates = {
    for (final c in CategoryNames.primaryTabCodes) c: false,
  };
  // Data cho tab Another Series riêng (map sub -> episodes)
  Map<String, List<Episode>> _anotherSeriesData = {};
  List<String> _anotherSeriesDisplayOrder = [];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(
      length: CategoryNames.primaryTabCodes.length,
      vsync: this,
    );

    final categories = CategoryNames.primaryTabCodes;
    String initialCategory = categories.first;

    String? resolvedInitialTab = widget.initialTab;
    if (resolvedInitialTab != null &&
        CategoryNames.anotherSeriesSubCodes.contains(resolvedInitialTab)) {
      resolvedInitialTab = 'AS';
    }

    if (resolvedInitialTab != null) {
      final tabIndex = categories.indexOf(resolvedInitialTab);
      if (tabIndex != -1) {
        _tabController.index = tabIndex;
        initialCategory = resolvedInitialTab;
      }
    }

    if (initialCategory == 'AS') {
      _loadAnotherSeriesTabData();
    } else {
      _loadCategoryData(initialCategory);
    }
    
    // Listen to tab changes
    _tabController.addListener(_onTabChanged);
    _learningProgressListener = () {
      if (mounted) setState(() {});
    };
    _learningProgress.addListener(_learningProgressListener);
    _learningProgress.initialize();
  }

  @override
  void dispose() {
    _learningProgress.removeListener(_learningProgressListener);
    _tabController.removeListener(_onTabChanged);
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadCategoryData(String category) async {
    if (category == 'AS') return;

    if (_episodesData.containsKey(category) && _loadedYears[category]!.isNotEmpty) {
      return; // Đã load rồi
    }

    setState(() {
      _loadingStates[category] = true;
      _errorStates[category] = null;
    });

    try {
      final List<Episode> allEpisodes;
      final List<int> loadedYears;

      // Flat list tabs: RTDB slim list phẳng `List/{CAT}.json` (không có /{year}).
      if (CategoryNames.usesFlatEpisodeList(category)) {
        allEpisodes = await _episodeCacheService
            .getCategoryEpisodesWithoutYear(category);
        allEpisodes.sort((a, b) => b.publishedDate.compareTo(a.publishedDate));
        loadedYears = [DateTime.now().year];
      } else {
        final currentYear = DateTime.now().year;
        final previousYear = currentYear - 1;

        final currentYearEpisodes =
            await _episodeCacheService.getCategoryEpisodes(category, currentYear);
        final previousYearEpisodes =
            await _episodeCacheService.getCategoryEpisodes(category, previousYear);

        final Map<String, Episode> uniqueEpisodes = {};
        for (final episode in [...currentYearEpisodes, ...previousYearEpisodes]) {
          final key = episode.id ??
              '${episode.episodeName}-${episode.publishedDate.toIso8601String()}';
          uniqueEpisodes[key] = episode;
        }
        allEpisodes = uniqueEpisodes.values.toList()
          ..sort((a, b) => b.publishedDate.compareTo(a.publishedDate));
        loadedYears = [currentYear, previousYear];
      }

      setState(() {
        _episodesData[category] = allEpisodes;
        _loadedYears[category] = loadedYears;
        _loadingStates[category] = false;
      });
    } catch (e) {
      setState(() {
        _errorStates[category] = e.toString();
        _loadingStates[category] = false;
      });
    }
  }

  Future<void> _loadMoreYears(String category) async {
    if (_loadingMoreStates[category] == true) {
      return; // Đang load rồi
    }

    setState(() {
      _loadingMoreStates[category] = true;
    });

    try {
      final loadedYears = _loadedYears[category]!;
      if (loadedYears.isEmpty) {
        setState(() {
          _loadingMoreStates[category] = false;
        });
        return;
      }

      // Tìm năm nhỏ nhất đã load
      final minLoadedYear = loadedYears.reduce((a, b) => a < b ? a : b);
      final nextYear = minLoadedYear - 1;

      // Giới hạn load đến năm 2020
      if (nextYear < 2020) {
        setState(() {
          _loadingMoreStates[category] = false;
        });
        return;
      }

      // Lấy dữ liệu năm tiếp theo
      final nextYearEpisodes = await _episodeCacheService.getCategoryEpisodes(category, nextYear);
      
      // Gộp với episodes hiện có và sắp xếp lại
      final currentEpisodes = _episodesData[category] ?? [];
      final Map<String, Episode> uniqueEpisodes = {};
      for (final episode in [...currentEpisodes, ...nextYearEpisodes]) {
        final key = episode.id ?? '${episode.episodeName}-${episode.publishedDate.toIso8601String()}';
        uniqueEpisodes[key] = episode;
      }
      final allEpisodes = uniqueEpisodes.values.toList()
        ..sort((a, b) => b.publishedDate.compareTo(a.publishedDate));
      
      setState(() {
        _episodesData[category] = allEpisodes;
        _loadedYears[category] = [...loadedYears, nextYear];
        _loadingMoreStates[category] = false;
      });
    } catch (e) {
      setState(() {
        _loadingMoreStates[category] = false;
      });
      // Không hiển thị error khi load more, chỉ im lặng fail
      print('Error loading more years for $category: $e');
    }
  }

  bool _canLoadMore(String category) {
    if (CategoryNames.usesFlatEpisodeList(category)) return false;

    final loadedYears = _loadedYears[category] ?? [];
    if (loadedYears.isEmpty) return false;

    final minLoadedYear = loadedYears.reduce((a, b) => a < b ? a : b);
    return minLoadedYear > 2020; // Có thể load thêm nếu năm nhỏ nhất > 2020
  }

  void _onTabChanged() {
    if (!_tabController.indexIsChanging) {
      final currentCategory =
          CategoryNames.primaryTabCodes[_tabController.index];
      if (currentCategory == 'AS') {
        _loadAnotherSeriesTabData();
      } else {
        _loadCategoryData(currentCategory);
      }
    }
  }

  void _navigateToEpisodeDetail(Episode episode) {
    final currentCategory =
        CategoryNames.primaryTabCodes[_tabController.index];
    final List<Episode> categoryEpisodes;
    if (currentCategory == 'AS') {
      final subEpisodes = _anotherSeriesData[episode.category] ?? [];
      categoryEpisodes =
          LleLevelGroups.episodesForPlaylist(episode, subEpisodes);
    } else if (episode.category == 'LLE') {
      final allLle = _anotherSeriesData['LLE'] ??
          _episodesData['LLE'] ??
          const <Episode>[];
      categoryEpisodes = LleLevelGroups.episodesForPlaylist(episode, allLle);
    } else {
      categoryEpisodes = _episodesData[currentCategory] ?? [];
    }

    EpisodeDetailOpenHelper.open(
      context: context,
      episode: episode,
      categoryEpisodes: categoryEpisodes,
    );
  }

  Future<void> _loadAnotherSeriesTabData() async {
    if (_loadingStates['AS'] == true) {
      return;
    }

    final hasAllSubs = CategoryNames.anotherSeriesSubCodes
        .every((c) => _anotherSeriesData.containsKey(c));
    final hasData =
        _anotherSeriesData.values.any((episodes) => episodes.isNotEmpty);
    if (hasData && hasAllSubs) {
      return;
    }

    setState(() {
      _loadingStates['AS'] = true;
      _errorStates['AS'] = null;
    });

    try {
      final Map<String, List<Episode>> allData = {};

      for (final code in CategoryNames.anotherSeriesSubCodes) {
        final episodes = await _episodeCacheService
            .getCategoryEpisodesWithoutYear(code);
        episodes.sort((a, b) => b.publishedDate.compareTo(a.publishedDate));
        allData[code] = episodes;
      }

      setState(() {
        _anotherSeriesData = allData;
        _anotherSeriesDisplayOrder =
            List<String>.from(CategoryNames.anotherSeriesSubCodes);
        _loadingStates['AS'] = false;
      });
    } catch (e) {
      print('Error loading Another Series tab data: $e');
      setState(() {
        _errorStates['AS'] = e.toString();
        _loadingStates['AS'] = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: _languageManager,
      builder: (context, child) {
        return Scaffold(
          backgroundColor: Theme.of(context).colorScheme.surface,
          body: Column(
            children: [
              // Custom Header
              _buildHeader(),

              const SizedBox(height: 16),
              
              // TabBar với shadow
              _buildTabBar(),
              // TabBarView content
              Expanded(
                child: TabBarView(
                  controller: _tabController,
                  children: [
                    for (final code in CategoryNames.primaryTabCodes)
                      code == 'AS'
                          ? _buildAnotherSeriesContent()
                          : _buildCategoryContent(code),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildHeader() {
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
      child: Row(
        children: [         
          // Title và subtitle
          Expanded(
            child: Text(
              _languageManager.getText('categories'),
              style: theme.textTheme.headlineSmall!.copyWith(
                color: colorScheme.onSurface,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          // App icon đơn giản
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: colorScheme.surfaceVariant,
            ),
            child: Icon(
              Icons.list_outlined,
              color: colorScheme.onSurface,
              size: 20,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTabBar() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 4),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Theme.of(context).colorScheme.shadow.withOpacity(0.1),
            spreadRadius: 1,
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: TabBar(
        controller: _tabController,
        indicator: UnderlineTabIndicator(
          borderSide: BorderSide(
            color: Theme.of(context).colorScheme.primary,
            width: 3,
          ),
          insets: const EdgeInsets.symmetric(horizontal: 4),
        ),
        indicatorSize: TabBarIndicatorSize.tab,
        labelColor: Theme.of(context).colorScheme.primary,
        unselectedLabelColor: Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
        labelStyle: const TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w600,
        ),
        unselectedLabelStyle: const TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w500,
        ),
        dividerColor: Theme.of(context).colorScheme.surface.withOpacity(0),
        labelPadding: const EdgeInsets.symmetric(horizontal: 1, vertical: 1),
        tabs: [
          for (var i = 0; i < CategoryNames.primaryTabCodes.length; i++)
            _buildTabLabelForCode(i, CategoryNames.primaryTabCodes[i]),
        ],
      ),
    );
  }

  Widget _buildTabLabelForCode(int index, String code) {
    final lines = CategoryNames.primaryTabDisplayLines(code);
    return _buildTabLabel(index, lines[0], lines[1]);
  }

  Widget _buildTabLabel(int index, String firstLine, String secondLine) {
    return Tab(
      child: ListenableBuilder(
        listenable: _tabController,
        builder: (context, child) {
          final isSelected = _tabController.index == index;
          final color = isSelected
              ? Theme.of(context).colorScheme.primary
              : Theme.of(context).colorScheme.onSurface.withOpacity(0.6);
          
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 2),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  firstLine,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: color,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  secondLine,
                  style: TextStyle(
                    fontSize: 9,
                    fontWeight: FontWeight.w400,
                    color: color,
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildCategoryContent(String category) {
    if (_loadingStates[category] == true) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const CircularProgressIndicator(),
            const SizedBox(height: 16),
            Text(
              _languageManager.getText('loading'),
              style: TextStyle(
                fontSize: 16,
                color: Theme.of(context).colorScheme.onSurface,
              ),
            ),
          ],
        ),
      );
    }

    if (_errorStates[category] != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.error_outline,
              size: 64,
              color: Theme.of(context).colorScheme.onSurface.withOpacity(0.4),
            ),
            const SizedBox(height: 16),
            Text(
              _languageManager.getText('errorOccurred'),
              style: TextStyle(
                fontSize: 18, 
                fontWeight: FontWeight.bold,
                color: Theme.of(context).colorScheme.onSurface,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              _errorStates[category]!,
              style: TextStyle(
                fontSize: 14, 
                color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: () => _loadCategoryData(category),
              child: Text(_languageManager.getText('tryAgain')),
            ),
          ],
        ),
      );
    }

    final episodes = _episodesData[category] ?? [];
    
    if (episodes.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.library_music_outlined,
              size: 64,
              color: Theme.of(context).colorScheme.onSurface.withOpacity(0.4),
            ),
            const SizedBox(height: 16),
            Text(
              _languageManager.getText('noData'),
              style: TextStyle(
                fontSize: 18, 
                fontWeight: FontWeight.bold,
                color: Theme.of(context).colorScheme.onSurface,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'No episodes available for $category',
              style: TextStyle(
                fontSize: 14, 
                color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
              ),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: () {
        // Reset loaded years khi refresh
        _loadedYears[category] = [];
        _episodesData.remove(category);
        return _loadCategoryData(category);
      },
      child: ListView.builder(
        padding: FloatingBottomNavBar.scrollPadding(context),
        itemCount: episodes.length + 1 + (_canLoadMore(category) ? 1 : 0) + 1, // +1 for load more button, +1 for banner ad
        itemBuilder: (context, index) {
          // Load More button (trước banner ad)
          if (_canLoadMore(category) && index == episodes.length) {
            return Container(
              margin: const EdgeInsets.symmetric(vertical: 8),
              child: _loadingMoreStates[category] == true
                  ? Center(
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: CircularProgressIndicator(),
                      ),
                    )
                  : ElevatedButton(
                      onPressed: () => _loadMoreYears(category),
                      child: Text(_languageManager.getText('loadMore')),
                    ),
            );
          }
          
          // Banner ad ở cuối danh sách
          final bannerAdIndex = _canLoadMore(category) ? episodes.length + 1 : episodes.length;
          if (index == bannerAdIndex) {
            return const BannerAdWidget();
          }
          
          if (index >= 0 && index < episodes.length) {
            final episode = episodes[index];
            final isLatest = index == 0; // Episode đầu tiên là mới nhất
            return Container(
              margin: const EdgeInsets.only(bottom: 8),
              child: EpisodeRow(
                episode: episode,
                onTap: () => _navigateToEpisodeDetail(episode),
                languageManager: _languageManager,
                isLatest: isLatest,
                learningProgress: _learningProgress.getProgressForEpisode(episode),
              ),
            );
          }
          
          // Fallback - không nên xảy ra
          return const SizedBox.shrink();
        },
      ),
    );
  }

  Widget _buildAnotherSeriesContent() {
    if (_loadingStates['AS'] == true) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const CircularProgressIndicator(),
            const SizedBox(height: 16),
            Text(
              _languageManager.getText('loading'),
              style: TextStyle(
                fontSize: 16,
                color: Theme.of(context).colorScheme.onSurface,
              ),
            ),
          ],
        ),
      );
    }

    if (_errorStates['AS'] != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.error_outline,
              size: 64,
              color: Theme.of(context).colorScheme.onSurface.withOpacity(0.4),
            ),
            const SizedBox(height: 16),
            Text(
              _languageManager.getText('errorOccurred'),
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Theme.of(context).colorScheme.onSurface,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              _errorStates['AS']!,
              style: TextStyle(
                fontSize: 14,
                color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: () => _loadAnotherSeriesTabData(),
              child: Text(_languageManager.getText('tryAgain')),
            ),
          ],
        ),
      );
    }

    if (_anotherSeriesData.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.library_music_outlined,
              size: 64,
              color: Theme.of(context).colorScheme.onSurface.withOpacity(0.4),
            ),
            const SizedBox(height: 16),
            Text(
              _languageManager.getText('noData'),
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Theme.of(context).colorScheme.onSurface,
              ),
            ),
          ],
        ),
      );
    }

    // Tránh trạng thái "màn trắng": map có key nhưng tất cả list episode rỗng
    final hasAnyEpisodes =
        _anotherSeriesData.values.any((episodes) => episodes.isNotEmpty);
    if (!hasAnyEpisodes) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.library_music_outlined,
              size: 64,
              color: Theme.of(context).colorScheme.onSurface.withOpacity(0.4),
            ),
            const SizedBox(height: 16),
            Text(
              _languageManager.getText('noData'),
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Theme.of(context).colorScheme.onSurface,
              ),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: () {
        _anotherSeriesData.clear();
        _anotherSeriesDisplayOrder.clear();
        return _loadAnotherSeriesTabData();
      },
      child: ListView(
        padding: FloatingBottomNavBar.scrollPadding(
          context,
          left: 0,
          top: 8,
          right: 0,
          bottom: 8,
        ),
        children: [
          for (final code in CategoryNames.anotherSeriesSubCodes)
            AnotherSeriesSubSection(
              categoryCode: code,
              episodes: _anotherSeriesData[code] ?? [],
              languageManager: _languageManager,
              onEpisodeTap: _navigateToEpisodeDetail,
            ),
          const BannerAdWidget(),
        ],
      ),
    );
  }

}
