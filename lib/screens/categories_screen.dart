import 'package:flutter/material.dart';
import '../models/episode.dart';
import '../services/episode_cache_service.dart';
import '../services/firebase_service.dart';
import '../services/language_manager.dart';
import '../services/episode_detail_open_helper.dart';
import '../widgets/episode_row.dart';
import '../widgets/banner_ad_widget.dart';
import '../widgets/other_programs_category_widget.dart';

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
  
  // Data cho từng tab
  Map<String, List<Episode>> _episodesData = {};
  Map<String, bool> _loadingStates = {
    '6M': false,
    'TEWS': false,
    'REE': false,
    'OTHER': false,
  };
  Map<String, String?> _errorStates = {
    '6M': null,
    'TEWS': null,
    'REE': null,
    'OTHER': null,
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
  // Data cho Other Programs (map category name -> episodes)
  Map<String, List<Episode>> _otherProgramsData = {};
  /// Thứ tự hiển thị: AS động trước, sau đó 6MGB…
  List<String> _otherProgramsDisplayOrder = [];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    
    // Xác định tab ban đầu
    final categories = ['6M', 'TEWS', 'REE', 'OTHER'];
    String initialCategory = '6M'; // Default
    
    if (widget.initialTab != null) {
      final tabIndex = categories.indexOf(widget.initialTab!);
      if (tabIndex != -1) {
        _tabController.index = tabIndex;
        initialCategory = widget.initialTab!;
      }
    }
    
    // Load data cho tab được chọn
    if (initialCategory == 'OTHER') {
      _loadOtherProgramsData();
    } else {
      _loadCategoryData(initialCategory);
    }
    
    // Listen to tab changes
    _tabController.addListener(_onTabChanged);
  }

  @override
  void dispose() {
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
      final categories = ['6M', 'TEWS', 'REE', 'OTHER'];
      final currentCategory = categories[currentIndex];
      
      print('Tab changed to: $currentCategory (index: $currentIndex)');
      
      if (currentCategory == 'OTHER') {
        print('Loading Other Programs data...');
        _loadOtherProgramsData();
      } else {
        _loadCategoryData(currentCategory);
      }
    }
  }

  void _navigateToEpisodeDetail(Episode episode) {
    // Tìm danh sách episodes của category hiện tại
    final currentIndex = _tabController.index;
    final categories = ['6M', 'TEWS', 'REE', 'OTHER'];
    final currentCategory = categories[currentIndex];
    
    List<Episode> categoryEpisodes = [];
    if (currentCategory == 'OTHER') {
      // Lấy tất cả episodes từ các category trong Other Programs
      _otherProgramsData.values.forEach((episodes) {
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

  Future<void> _loadOtherProgramsData() async {
    if (_loadingStates['OTHER'] == true) {
      print('Other Programs data is already loading...');
      return; // Đang load rồi
    }

    // Kiểm tra xem đã có data chưa (có ít nhất 1 category có episodes)
    final hasData = _otherProgramsData.values.any((episodes) => episodes.isNotEmpty);
    if (hasData) {
      print('Other Programs data already loaded');
      return; // Đã load rồi
    }

    print('Loading Other Programs data...');
    setState(() {
      _loadingStates['OTHER'] = true;
      _errorStates['OTHER'] = null;
    });

    try {
      final asSubs =
          await FirebaseService.fetchAnotherSeriesSubKeys(forHomePage: false);
      const fixedCategories = [
        '6MGB',
        '6MGI',
        '6MVB',
        '6MVI',
        'DRM',
        'EAW',
      ];

      print(
        'Loading Other Programs: AS subs=$asSubs, fixed=$fixedCategories',
      );

      final Map<String, List<Episode>> allData = {};

      for (final sub in asSubs) {
        try {
          print('Loading Another Series list branch: $sub...');
          final episodes =
              await _episodeCacheService.getAnotherSeriesSubEpisodes(
            sub,
            forHomePage: false,
          );
          print('$sub - Total: ${episodes.length} episodes');
          allData[sub] = episodes;
        } catch (e) {
          print('Error loading Another Series $sub: $e');
          allData[sub] = [];
        }
      }

      for (final category in fixedCategories) {
        try {
          print('Loading $category...');
          final episodes =
              await _episodeCacheService.getCategoryEpisodesWithoutYear(category);

          print('$category - Total: ${episodes.length} episodes');

          allData[category] = episodes;
        } catch (e) {
          print('Error loading $category: $e');
          allData[category] = [];
        }
      }

      print(
        'Other Programs data loaded. Total categories with data: ${allData.values.where((list) => list.isNotEmpty).length}',
      );

      setState(() {
        _otherProgramsData = allData;
        _otherProgramsDisplayOrder = [...asSubs, ...fixedCategories];
        _loadingStates['OTHER'] = false;
      });
    } catch (e) {
      print('Error loading Other Programs data: $e');
      setState(() {
        _errorStates['OTHER'] = e.toString();
        _loadingStates['OTHER'] = false;
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
                    _buildOtherProgramsContent(),
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
    final now = DateTime.now();
    final hour = now.hour;
    
    String greeting;
    String emoji;
    
    if (hour < 12) {
      greeting = _languageManager.getText('goodMorning');
      emoji = '🌅';
    } else if (hour < 17) {
      greeting = _languageManager.getText('goodAfternoon');
      emoji = '☀️';
    } else {
      greeting = _languageManager.getText('goodEvening');
      emoji = '🌙';
    }

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
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  _languageManager.getText('categories'),
                  style: theme.textTheme.headlineSmall!.copyWith(
                    color: colorScheme.onSurface,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  _languageManager.getText('selectCategoryToExploreEpisodes'),
                  style: theme.textTheme.bodyMedium!.copyWith(
                    color: colorScheme.onSurface.withOpacity(0.8),
                  ),
                ),
              ],
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
          _buildTabLabel(3, 'Other', 'Programs'),
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
        padding: const EdgeInsets.all(12),
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
              ),
            );
          }
          
          // Fallback - không nên xảy ra
          return const SizedBox.shrink();
        },
      ),
    );
  }

  Widget _buildOtherProgramsContent() {
    if (_loadingStates['OTHER'] == true) {
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

    if (_errorStates['OTHER'] != null) {
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
              _errorStates['OTHER']!,
              style: TextStyle(
                fontSize: 14,
                color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: () => _loadOtherProgramsData(),
              child: Text(_languageManager.getText('tryAgain')),
            ),
          ],
        ),
      );
    }

    if (_otherProgramsData.isEmpty) {
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

    final categories = _otherProgramsDisplayOrder;

    return RefreshIndicator(
      onRefresh: () {
        _otherProgramsData.clear();
        _otherProgramsDisplayOrder.clear();
        return _loadOtherProgramsData();
      },
      child: ListView.builder(
        padding: const EdgeInsets.symmetric(vertical: 8),
        itemCount: categories.length + 1, // +1 for banner ad
        itemBuilder: (context, index) {
          // Banner ad ở cuối
          if (index == categories.length) {
            return const BannerAdWidget();
          }

          final categoryName = categories[index];
          final episodes = _otherProgramsData[categoryName] ?? [];

          if (episodes.isEmpty) {
            return const SizedBox.shrink();
          }

          return OtherProgramsCategoryWidget(
            categoryName: categoryName,
            episodes: episodes,
            onEpisodeTap: (episode) => _navigateToEpisodeDetail(episode),
            languageManager: _languageManager,
          );
        },
      ),
    );
  }
}
