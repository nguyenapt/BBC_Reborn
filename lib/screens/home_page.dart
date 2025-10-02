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
      child: ListView.builder(
        padding: const EdgeInsets.only(bottom: 4),
        itemCount: _categories.length + 2, // +1 for welcome header, +1 for banner ad
        itemBuilder: (context, index) {
          if (index == 0) {
            // Welcome header ở đầu
            return const WelcomeHeader();
          }
          
          if (index == 1) {
            // Banner ad sau welcome header
            return const BannerAdWidget();
          }
          
          // Categories bắt đầu từ index 2
          final categoryIndex = index - 2;
          if (categoryIndex >= 0 && categoryIndex < _categories.length) {
            final category = _categories[categoryIndex];
            return CategoryGroupBox(
              category: category,
              onEpisodeTap: _navigateToEpisodeDetail,
              onViewAllTap: _navigateToCategory,
            );
          }
          
          // Fallback - không nên xảy ra
          return const SizedBox.shrink();
        },
      ),
    );
      },
    );
  }
}
