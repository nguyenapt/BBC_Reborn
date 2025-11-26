import 'package:flutter/material.dart';
import '../models/episode.dart';
import '../services/firebase_service.dart';
import '../services/language_manager.dart';
import '../utils/category_names.dart';
import '../widgets/episode_row.dart';
import '../widgets/banner_ad_widget.dart';
import 'episode_detail_screen.dart';

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
  
  // Data cho từng tab
  Map<String, List<Episode>> _episodesData = {};
  Map<String, bool> _loadingStates = {
    '6M': false,
    'TEWS': false,
    'REE': false,
  };
  Map<String, String?> _errorStates = {
    '6M': null,
    'TEWS': null,
    'REE': null,
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

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    
    // Xác định tab ban đầu
    final categories = ['6M', 'TEWS', 'REE'];
    String initialCategory = '6M'; // Default
    
    if (widget.initialTab != null) {
      final tabIndex = categories.indexOf(widget.initialTab!);
      if (tabIndex != -1) {
        _tabController.index = tabIndex;
        initialCategory = widget.initialTab!;
      }
    }
    
    // Load data cho tab được chọn
    _loadCategoryData(initialCategory);
  }

  @override
  void dispose() {
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
      
      // Lấy dữ liệu từ 2 năm gần nhất
      final currentYearEpisodes = await FirebaseService.getCategoryData(category, currentYear);
      final previousYearEpisodes = await FirebaseService.getCategoryData(category, previousYear);
      
      // Gộp episodes và sắp xếp theo publishedDate (mới nhất trước)
      final allEpisodes = [...currentYearEpisodes, ...previousYearEpisodes];
      allEpisodes.sort((a, b) => b.publishedDate.compareTo(a.publishedDate));
      
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
      final nextYearEpisodes = await FirebaseService.getCategoryData(category, nextYear);
      
      // Gộp với episodes hiện có và sắp xếp lại
      final currentEpisodes = _episodesData[category] ?? [];
      final allEpisodes = [...currentEpisodes, ...nextYearEpisodes];
      allEpisodes.sort((a, b) => b.publishedDate.compareTo(a.publishedDate));
      
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
    final currentIndex = _tabController.index;
    final categories = ['6M', 'TEWS', 'REE'];
    final currentCategory = categories[currentIndex];
    
    _loadCategoryData(currentCategory);
  }

  void _navigateToEpisodeDetail(Episode episode) {
    // Tìm danh sách episodes của category hiện tại
    final currentIndex = _tabController.index;
    final categories = ['6M', 'TEWS', 'REE'];
    final currentCategory = categories[currentIndex];
    final categoryEpisodes = _episodesData[currentCategory] ?? [];

    // 50% hiển thị interstitial ads khi vào episode detail
    final shouldShowInterstitial = DateTime.now().millisecondsSinceEpoch % 2 == 0;

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => EpisodeDetailScreen(
          episode: episode,
          categoryEpisodes: categoryEpisodes,
          shouldShowInterstitialOnEnter: shouldShowInterstitial,
        ),
      ),
    );
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
        color: colorScheme.primary,
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
                    color: colorScheme.onPrimary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  _languageManager.getText('selectCategoryToExploreEpisodes'),
                  style: theme.textTheme.bodyMedium!.copyWith(
                    color: colorScheme.onPrimary.withOpacity(0.8),
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
              color: colorScheme.primaryContainer.withOpacity(0.3),
            ),
            child: Icon(
              Icons.list_outlined,
              color: colorScheme.onPrimary,
              size: 20,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTabBar() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20),
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
        onTap: (index) => _onTabChanged(),
        indicator: UnderlineTabIndicator(
          borderSide: BorderSide(
            color: Theme.of(context).colorScheme.primary,
            width: 3,
          ),
          insets: const EdgeInsets.symmetric(horizontal: 16),
        ),
        indicatorSize: TabBarIndicatorSize.tab,
        labelColor: Theme.of(context).colorScheme.primary,
        unselectedLabelColor: Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
        labelStyle: const TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w600,
        ),
        unselectedLabelStyle: const TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w500,
        ),
        dividerColor: Colors.transparent,
        tabs: const [
          Tab(text: '6 Minutes English'),
          Tab(text: 'The English We Speak'),
          Tab(text: 'Real Easy English'),
        ],
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
                      child: Text(_languageManager.getText('loadMore') ?? 'Load More'),
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
            return Container(
              margin: const EdgeInsets.only(bottom: 8),
              child: EpisodeRow(
                episode: episode,
                onTap: () => _navigateToEpisodeDetail(episode),
                languageManager: _languageManager,
              ),
            );
          }
          
          // Fallback - không nên xảy ra
          return const SizedBox.shrink();
        },
      ),
    );
  }
}
