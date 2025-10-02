import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import '../models/episode.dart';
import '../models/vocabulary_item.dart';
import '../models/favourite_episode.dart';
import '../services/storage_service.dart';
import '../services/firebase_storage_service.dart';
import '../services/user_service.dart';
import '../services/auth_service.dart';
import '../services/language_manager.dart';
import '../services/vocabulary_service.dart';
import '../widgets/episode_row.dart';
import 'episode_detail_screen.dart';

class SavedScreen extends StatefulWidget {
  const SavedScreen({super.key});

  @override
  State<SavedScreen> createState() => _SavedScreenState();
}

class _SavedScreenState extends State<SavedScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final StorageService _storageService = StorageService();
  final FirebaseStorageService _firebaseStorageService = FirebaseStorageService();
  final UserService _userService = UserService();
  final LanguageManager _languageManager = LanguageManager();
  final AuthService _authService = AuthService();
  final VocabularyService _vocabularyService = VocabularyService();

  List<FavouriteEpisode> _favouriteEpisodes = [];
  List<VocabularyItem> _savedVocabularies = [];
  bool _isLoadingFavourites = true;
  bool _isLoadingVocabularies = true;
  String? _favouritesError;
  String? _vocabulariesError;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadData();
    
    // Listen to vocabulary changes
    _vocabularyService.addListener(() {
      if (mounted) {
        _loadSavedVocabularies();
      }
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    _vocabularyService.removeListener(() {});
    super.dispose();
  }

  Future<void> _loadData() async {
    await _loadFavouriteEpisodes();
    await _loadSavedVocabularies();
  }

  Future<void> _loadFavouriteEpisodes() async {
    setState(() {
      _isLoadingFavourites = true;
      _favouritesError = null;
    });

    try {
      // Always load from local storage first (faster and more reliable)
      final localEpisodes = await _storageService.getFavouriteEpisodes();
      debugPrint('Loaded ${localEpisodes.length} episodes from local storage');
      
      if (localEpisodes.isNotEmpty) {
        setState(() {
          _favouriteEpisodes = localEpisodes;
        });
        debugPrint('Set ${_favouriteEpisodes.length} episodes to state');
      } else if (_authService.isLoggedIn) {
        // Only try Firebase if user is logged in and local storage is empty
        try {
          final firebaseEpisodes = await _firebaseStorageService.getFavouriteEpisodes(_userService.userId);
          // Convert Episode list to FavouriteEpisode list
          final favouriteEpisodes = firebaseEpisodes.map((episode) => FavouriteEpisode.fromEpisode(episode)).toList();
          setState(() {
            _favouriteEpisodes = favouriteEpisodes;
          });
        } catch (firebaseError) {
          debugPrint('Firebase load failed: $firebaseError');
          // Keep local episodes (empty list)
        }
      }
    } catch (e) {
      setState(() {
        _favouritesError = e.toString();
      });
    } finally {
      setState(() {
        _isLoadingFavourites = false;
      });
    }
  }

  Future<void> _loadSavedVocabularies() async {
    setState(() {
      _isLoadingVocabularies = true;
      _vocabulariesError = null;
    });

    try {
      // Load từ VocabularyService
      final savedVocabularies = _vocabularyService.savedVocabularies;
      setState(() {
        _savedVocabularies = savedVocabularies;
      });
    } catch (e) {
      setState(() {
        _vocabulariesError = e.toString();
      });
    } finally {
      setState(() {
        _isLoadingVocabularies = false;
      });
    }
  }

  void _navigateToEpisodeDetail(FavouriteEpisode favouriteEpisode) {
    // Convert FavouriteEpisode to Episode for navigation
    final episode = favouriteEpisode.toEpisode();
    final episodes = _favouriteEpisodes.map((fe) => fe.toEpisode()).toList();
    
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => EpisodeDetailScreen(
          episode: episode,
          categoryEpisodes: episodes,
        ),
      ),
    );
  }

  Future<void> _removeVocabulary(String vocab) async {
    try {
      await _vocabularyService.removeVocabulary(vocab);
      
      // Reload vocabulary list
      await _loadSavedVocabularies();
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Đã xóa "$vocab" khỏi vocabulary cá nhân'),
          duration: const Duration(seconds: 2),
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Có lỗi xảy ra: $e'),
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: Listenable.merge([_languageManager, _vocabularyService]),
      builder: (context, child) {
        return Scaffold(
          backgroundColor: Theme.of(context).colorScheme.background,
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
                    _buildFavouriteEpisodesTab(),
                    _buildVocabulariesTab(),
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
            _languageManager.getText('saved'),
            style: Theme.of(context).textTheme.headlineLarge?.copyWith(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Text(
            _languageManager.getText('savedDesc'),
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: Colors.grey[600]),
          ),
        ],
      ),
    );
  }

  Widget _buildTabBar() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
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
          insets: const EdgeInsets.symmetric(horizontal: 16),
        ),
        indicatorSize: TabBarIndicatorSize.tab,
        labelColor: Theme.of(context).colorScheme.primary,
        unselectedLabelColor: Colors.grey[600],
        labelStyle: const TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w600,
        ),
        unselectedLabelStyle: const TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w500,
        ),
        dividerColor: Colors.transparent,
        tabs: [
          Tab(
            icon: const Icon(Icons.favorite, size: 20),
            text: _languageManager.getText('favouriteEpisodes'),
          ),
          Tab(
            icon: const Icon(Icons.book, size: 20),
            text: _languageManager.getText('vocabularies'),
          ),
        ],
      ),
    );
  }

  Widget _buildFavouriteEpisodesTab() {
    if (_isLoadingFavourites) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 16),
            Text('Đang tải danh sách yêu thích...'),
          ],
        ),
      );
    }

    if (_favouritesError != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.error_outline, color: Colors.red, size: 40),
              const SizedBox(height: 16),
              Text(
                'Lỗi: $_favouritesError',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.red),
              ),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: _loadFavouriteEpisodes,
                child: const Text('Thử lại'),
              ),
            ],
          ),
        ),
      );
    }

    if (_favouriteEpisodes.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.favorite_border, color: Colors.grey, size: 60),
            const SizedBox(height: 16),
            Text(
              'Chưa có episode yêu thích nào',
              style: TextStyle(
                fontSize: 18,
                color: Colors.grey[600],
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Hãy bấm vào icon trái tim để thêm episode vào danh sách yêu thích',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey[500],
              ),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadFavouriteEpisodes,
      child: ListView.builder(
        itemCount: _favouriteEpisodes.length,
        itemBuilder: (context, index) {
          final favouriteEpisode = _favouriteEpisodes[index];
          final episode = favouriteEpisode.toEpisode();
          return EpisodeRow(
            episode: episode,
            onTap: () => _navigateToEpisodeDetail(favouriteEpisode),
          );
        },
      ),
    );
  }

  Widget _buildVocabulariesTab() {
    if (_isLoadingVocabularies) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 16),
            Text('Đang tải vocabulary...'),
          ],
        ),
      );
    }

    if (_vocabulariesError != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.error_outline, color: Colors.red, size: 40),
              const SizedBox(height: 16),
              Text(
                'Lỗi: $_vocabulariesError',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.red),
              ),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: _loadSavedVocabularies,
                child: const Text('Thử lại'),
              ),
            ],
          ),
        ),
      );
    }

    if (_savedVocabularies.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.book_outlined, color: Colors.grey, size: 60),
            const SizedBox(height: 16),
            Text(
              'Chưa có vocabulary nào được lưu',
              style: TextStyle(
                fontSize: 18,
                color: Colors.grey[600],
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Hãy bấm vào icon bookmark để lưu từ vựng vào danh sách cá nhân',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey[500],
              ),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadSavedVocabularies,
      child: ListView.builder(
        itemCount: _savedVocabularies.length,
        itemBuilder: (context, index) {
          final vocabulary = _savedVocabularies[index];
          return Card(
            margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        Icons.bookmark,
                        color: Theme.of(context).colorScheme.primary,
                        size: 20,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          vocabulary.vocab,
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Colors.black87,
                          ),
                        ),
                      ),
                      IconButton(
                        onPressed: () => _removeVocabulary(vocabulary.vocab),
                        icon: const Icon(Icons.delete_outline),
                        color: Colors.red[400],
                        tooltip: 'Xóa từ vựng',
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    vocabulary.mean,
                    style: TextStyle(
                      fontSize: 16,
                      color: Colors.grey[700],
                      height: 1.4,
                    ),
                  ),
                  if (vocabulary.bbcEpisodeId.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Text(
                      'Episode ID: ${vocabulary.bbcEpisodeId}',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey[500],
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}
