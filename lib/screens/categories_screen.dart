import 'package:flutter/material.dart';
import '../models/episode.dart';
import '../services/episode_cache_service.dart';
import '../services/firebase_service.dart';
import '../services/language_manager.dart';
import '../services/learning_progress_service.dart';
import '../services/episode_detail_open_helper.dart';
import '../widgets/episode_row.dart';
import '../widgets/banner_ad_widget.dart';
import '../widgets/floating_bottom_nav_bar.dart';
import '../widgets/other_programs_category_widget.dart';
import '../utils/category_names.dart';

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
  Map<String, bool> _loadingStates = {
    '6M': false,
    'TEWS': false,
    'REE': false,
    'AS': false,
  };
  Map<String, String?> _errorStates = {
    '6M': null,
    'TEWS': null,
    'REE': null,
    'AS': null,
  };
  // Theo dõi các năm đã load cho mỗi category
  Map<String, List<int>> _loadedYears = {
    '6M': [],
    'TEWS': [],
    'REE': [],
  };
  // Trạng thái loading more cho mỗi category
  Map<String, bool> _loadingMoreStates = {
    '6M': false,
    'TEWS': false,
    'REE': false,
  };
  // Data cho tab Another Series riêng (map sub -> episodes)
  Map<String, List<Episode>> _anotherSeriesData = {};
  List<String> _anotherSeriesDisplayOrder = [];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    
    // Xác định tab ban đầu
    final categories = ['6M', 'TEWS', 'REE', 'AS'];
    String initialCategory = '6M'; // Default
    
    if (widget.initialTab != null) {
      final tabIndex = categories.indexOf(widget.initialTab!);
      if (tabIndex != -1) {
        _tabController.index = tabIndex;
        initialCategory = widget.initialTab!;
      }
    }
    
    // Load data cho tab được chọn
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
    if (_episodesData.containsKey(category) && _loadedYears[category]!.isNotEmpty) {
      return; // Đã load rồi
    }

    setState(() {
      _loadingStates[category] = true;
      _errorStates[category] = null;
    });

    try {
      final currentYear = DateTime.now().year;
      final previousYear = currentYear - 1;
      
      // Lấy dữ liệu từ cache trước, API chỉ gọi nếu chưa fetch hôm nay
      final currentYearEpisodes = await _episodeCacheService.getCategoryEpisodes(category, currentYear);
      final previousYearEpisodes = await _episodeCacheService.getCategoryEpisodes(category, previousYear);
      
      // Gộp episodes và loại trùng theo id
      final Map<String, Episode> uniqueEpisodes = {};
      for (final episode in [...currentYearEpisodes, ...previousYearEpisodes]) {
        final key = episode.id ?? '${episode.episodeName}-${episode.publishedDate.toIso8601String()}';
        uniqueEpisodes[key] = episode;
      }
      final allEpisodes = uniqueEpisodes.values.toList()
        ..sort((a, b) => b.publishedDate.compareTo(a.publishedDate));
      
      setState(() {
        _episodesData[category] = allEpisodes;
        _loadedYears[category] = [currentYear, previousYear];
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
    final loadedYears = _loadedYears[category] ?? [];
    if (loadedYears.isEmpty) return false;
    
    final minLoadedYear = loadedYears.reduce((a, b) => a < b ? a : b);
    return minLoadedYear > 2020; // Có thể load thêm nếu năm nhỏ nhất > 2020
  }

  void _onTabChanged() {
    if (!_tabController.indexIsChanging) {
      final currentIndex = _tabController.index;
      final categories = ['6M', 'TEWS', 'REE', 'AS'];
      final currentCategory = categories[currentIndex];
      
      print('Tab changed to: $currentCategory (index: $currentIndex)');
      
      if (currentCategory == 'AS') {
        print('Loading Another Series tab data...');
        _loadAnotherSeriesTabData();
      } else {
        _loadCategoryData(currentCategory);
      }
    }
  }

  void _navigateToEpisodeDetail(Episode episode) {
    // Tìm danh sách episodes của category hiện tại
    final currentIndex = _tabController.index;
    final categories = ['6M', 'TEWS', 'REE', 'AS'];
    final currentCategory = categories[currentIndex];
    
    List<Episode> categoryEpisodes = [];
    if (currentCategory == 'AS') {
      // Lấy tất cả episodes từ các sub trong Another Series tab
      _anotherSeriesData.values.forEach((episodes) {
        categoryEpisodes.addAll(episodes);
      });
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
      print('Another Series tab data is already loading...');
      return;
    }

    // Đã load đủ map (gồm mọi mục cố định như BSA) và có ít nhất một list episode?
    final fixedCodes = CategoryNames.anotherSeriesFixedProgramCodes;
    final hasAllFixedSlots =
        fixedCodes.every((c) => _anotherSeriesData.containsKey(c));
    final hasData = _anotherSeriesData.values.any((episodes) => episodes.isNotEmpty);
    if (hasData && hasAllFixedSlots) {
      print('Another Series tab data already loaded');
      return;
    }

    print('Loading Another Series tab data from List/AS.json...');
    setState(() {
      _loadingStates['AS'] = true;
      _errorStates['AS'] = null;
    });

    try {
      final asSubs =
          await FirebaseService.fetchAnotherSeriesSubKeys(forHomePage: false);
      print('Another Series subs=$asSubs');

      final Map<String, List<Episode>> allData = {};
      final subsWithData = <String>[];

      for (final sub in asSubs) {
        try {
          print('Loading Another Series sub: $sub...');
          // Cache SQLite + chỉ fetch tối đa 1 lần/ngày (nếu có data).
          final episodes = await _episodeCacheService.getAnotherSeriesSubEpisodes(
            sub,
            forHomePage: false,
          );
          print('$sub - Total: ${episodes.length} episodes');
          if (episodes.isNotEmpty) {
            allData[sub] = episodes;
            subsWithData.add(sub);
          }
        } catch (e) {
          print('Error loading Another Series sub $sub: $e');
        }
      }

      for (final category in CategoryNames.anotherSeriesFixedProgramCodes) {
        try {
          print('Loading fixed section $category...');
          final episodes = await _episodeCacheService
              .getAnotherSeriesFixedCategoryEpisodes(category);
          print('$category - Total: ${episodes.length} episodes');
          allData[category] = episodes;
        } catch (e) {
          print('Error loading fixed section $category: $e');
          allData[category] = [];
        }
      }

      final fixedCodes = CategoryNames.anotherSeriesFixedProgramCodes;
      final fixedSet = fixedCodes.toSet();
      final subsOrdered =
          subsWithData.where((s) => !fixedSet.contains(s)).toList();

      setState(() {
        _anotherSeriesData = allData;
        _anotherSeriesDisplayOrder = [...subsOrdered, ...fixedCodes];
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
                    _buildCategoryContent('6M'),
                    _buildCategoryContent('TEWS'),
                    _buildCategoryContent('REE'),
                    _buildAnotherSeriesContent(),
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
          _buildTabLabel(0, '6 Minutes', 'English'),
          _buildTabLabel(1, 'The English', 'We Speak'),
          _buildTabLabel(2, 'Real Easy', 'English'),
          _buildTabLabel(3, 'Another', 'Series'),
        ],
      ),
    );
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

    final subs = _anotherSeriesDisplayOrder;

    return RefreshIndicator(
      onRefresh: () {
        _anotherSeriesData.clear();
        _anotherSeriesDisplayOrder.clear();
        return _loadAnotherSeriesTabData();
      },
      child: ListView.builder(
        padding: FloatingBottomNavBar.scrollPadding(
          context,
          left: 0,
          top: 8,
          right: 0,
          bottom: 8,
        ),
        itemCount: subs.length + 1, // +1 for banner ad
        itemBuilder: (context, index) {
          // Banner ad ở cuối
          if (index == subs.length) {
            return const BannerAdWidget();
          }

          final sub = subs[index];
          final episodes = _anotherSeriesData[sub] ?? [];
          final fixedSlots =
              CategoryNames.anotherSeriesFixedProgramCodes.toSet();

          if (episodes.isEmpty && !fixedSlots.contains(sub)) {
            return const SizedBox.shrink();
          }

          return OtherProgramsCategoryWidget(
            categoryName: sub,
            episodes: episodes,
            onEpisodeTap: (episode) => _navigateToEpisodeDetail(episode),
            languageManager: _languageManager,
            showPlaceholderWhenEmpty: fixedSlots.contains(sub),
          );
        },
      ),
    );
  }

}
