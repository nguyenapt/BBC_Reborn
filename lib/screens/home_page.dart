import 'package:flutter/material.dart';
import '../models/category.dart';
import '../models/episode.dart';
import '../services/firebase_service.dart';
import '../services/language_manager.dart';
import '../services/image_cache_service.dart';
import '../widgets/category_group_box.dart';
import '../widgets/welcome_header.dart';
import '../widgets/banner_ad_widget.dart';
import 'episode_detail_screen.dart';
import 'categories_screen.dart';

class HomePage extends StatefulWidget {
  final Function(String)? onNavigateToCategory;
  
  const HomePage({super.key, this.onNavigateToCategory});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final FirebaseService _firebaseService = FirebaseService();
  final LanguageManager _languageManager = LanguageManager();
  List<Category> _categories = [];
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
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
      print('Loaded ${categories.length} categories');
      
      // Preload images for better performance
      _preloadImages(categories);
      
      setState(() {
        _categories = categories;
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

  /// Preload images for better performance
  void _preloadImages(List<Category> categories) {
    final imageUrls = <String>[];
    
    // Collect all image URLs from first few episodes of each category
    for (final category in categories) {
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

    if (episodeCategory != null) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => EpisodeDetailScreen(
            episode: episode,
            categoryEpisodes: episodeCategory!.episodes,
          ),
        ),
      );
    } else {
      // Fallback nếu không tìm thấy category
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => EpisodeDetailScreen(
            episode: episode,
            categoryEpisodes: [episode],
          ),
        ),
      );
    }
  }

  void _navigateToCategory(String categoryName) {
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
          // Logo tròn đơn giản
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: colorScheme.primaryContainer,
              border: Border.all(
                color: colorScheme.outline.withOpacity(0.3),
                width: 1,
              ),
            ),
            child: Center(
              child: Text(
                emoji,
                style: const TextStyle(fontSize: 20),
              ),
            ),
          ),
          const SizedBox(width: 16),
          // Greeting text
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  greeting,
                  style: theme.textTheme.headlineSmall!.copyWith(
                    color: colorScheme.onPrimary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  _languageManager.getText('welcomeMessage'),
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
              Icons.school,
              color: colorScheme.onPrimary,
              size: 20,
            ),
          ),
        ],
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
              color: Colors.red[300],
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
              style: TextStyle(color: Colors.grey[600]),
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

    if (_categories.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.inbox_outlined,
              size: 64,
              color: Colors.grey,
            ),
            const SizedBox(height: 16),
            Text(
              _languageManager.getText('noData'),
              style: const TextStyle(fontSize: 18),
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
          
          // Banner Ad
          SliverToBoxAdapter(
            child: const BannerAdWidget(),
          ),
          
          // Categories
          SliverList(
            delegate: SliverChildBuilderDelegate(
              (context, index) {
                final category = _categories[index];
                return CategoryGroupBox(
                  category: category,
                  onEpisodeTap: _navigateToEpisodeDetail,
                  onViewAllTap: _navigateToCategory,
                );
              },
              childCount: _categories.length,
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
