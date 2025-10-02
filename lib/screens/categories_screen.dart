import 'package:flutter/material.dart';
import '../models/episode.dart';
import '../services/firebase_service.dart';
import '../services/language_manager.dart';
import '../widgets/episode_row.dart';
import '../widgets/banner_ad_widget.dart';
import 'episode_detail_screen.dart';

class CategoriesScreen extends StatefulWidget {
  const CategoriesScreen({super.key});

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

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    
    // Load data cho tab đầu tiên
    _loadCategoryData('6M');
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadCategoryData(String category) async {
    if (_episodesData.containsKey(category)) {
      return; // Đã load rồi
    }

    setState(() {
      _loadingStates[category] = true;
      _errorStates[category] = null;
    });

    try {
      final currentYear = DateTime.now().year;
      final episodes = await FirebaseService.getCategoryData(category, currentYear);
      
      setState(() {
        _episodesData[category] = episodes;
        _loadingStates[category] = false;
      });
    } catch (e) {
      setState(() {
        _errorStates[category] = e.toString();
        _loadingStates[category] = false;
      });
    }
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

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => EpisodeDetailScreen(
          episode: episode,
          categoryEpisodes: categoryEpisodes,
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
    return Container(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            _languageManager.getText('categories'),
            style: TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.bold,
              color: Theme.of(context).colorScheme.onSurface,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            _languageManager.getText('selectCategoryToExploreEpisodes'),
            style: TextStyle(
              fontSize: 16,
              color: Theme.of(context).colorScheme.onSurface.withOpacity(0.7),
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
          Tab(text: '6M'),
          Tab(text: 'TEWS'),
          Tab(text: 'REE'),
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
      onRefresh: () => _loadCategoryData(category),
      child: ListView.builder(
        padding: const EdgeInsets.all(12),
        itemCount: episodes.length + 1, // +1 for banner ad
        itemBuilder: (context, index) {
          if (index == episodes.length) {
            // Banner ad ở cuối danh sách
            return const BannerAdWidget();
          }
          
          if (index >= 0 && index < episodes.length) {
            final episode = episodes[index];
            return Container(
              margin: const EdgeInsets.only(bottom: 8),
              child: EpisodeRow(
                episode: episode,
                onTap: () => _navigateToEpisodeDetail(episode),
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
