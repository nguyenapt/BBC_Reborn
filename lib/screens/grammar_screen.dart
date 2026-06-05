import 'package:flutter/material.dart';
import '../models/grammar.dart';
import '../models/episode.dart';
import '../services/grammar_service.dart';
import '../services/episode_cache_service.dart';
import '../services/language_manager.dart';
import '../services/episode_detail_open_helper.dart';
import '../widgets/episode_row.dart';
import '../widgets/banner_ad_widget.dart';
import '../widgets/floating_bottom_nav_bar.dart';
import 'grammar_detail_screen.dart';

class GrammarScreen extends StatefulWidget {
  final String? initialTab;
  
  const GrammarScreen({super.key, this.initialTab});

  @override
  State<GrammarScreen> createState() => _GrammarScreenState();
}

class _GrammarScreenState extends State<GrammarScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final GrammarService _grammarService = GrammarService();
  final EpisodeCacheService _episodeCacheService = EpisodeCacheService();
  final LanguageManager _languageManager = LanguageManager();
  
  // Basic Grammar state
  List<Grammar> _grammars = [];
  bool _isLoadingGrammar = true;
  String? _errorGrammar;
  
  // English Grammar state
  List<Episode> _egEpisodes = [];
  bool _isLoadingEG = false;
  String? _errorEG;
  List<int> _loadedYears = [];
  bool _loadingMoreEG = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    
    // Xác định tab ban đầu
    String initialTabName = 'English Grammar'; // Default
    if (widget.initialTab != null && widget.initialTab == 'Basic Grammar') {
      _tabController.index = 1; // Basic Grammar là tab thứ hai
      initialTabName = 'Basic Grammar';
    } else {
      _tabController.index = 0; // English Grammar là tab đầu tiên
    }
    
    // Load data cho tab được chọn
    if (initialTabName == 'English Grammar') {
      _loadEGData();
    } else {
      _loadGrammars();
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

  void _onTabChanged() {
    if (!_tabController.indexIsChanging) {
      final currentIndex = _tabController.index;
      
      if (currentIndex == 0) {
        // English Grammar tab
        if (_egEpisodes.isEmpty && !_isLoadingEG) {
          _loadEGData();
        }
      } else {
        // Basic Grammar tab
        if (_grammars.isEmpty && !_isLoadingGrammar) {
          _loadGrammars();
        }
      }
    }
  }

  Future<void> _loadGrammars() async {
    try {
      setState(() {
        _isLoadingGrammar = true;
        _errorGrammar = null;
      });

      final grammars = await _grammarService.getAllGrammars();
      
      setState(() {
        _grammars = grammars;
        _isLoadingGrammar = false;
      });
    } catch (e) {
      setState(() {
        _errorGrammar = e.toString();
        _isLoadingGrammar = false;
      });
    }
  }

  Future<void> _loadEGData() async {
    if (_egEpisodes.isNotEmpty && _loadedYears.isNotEmpty) {
      return; // Đã load rồi
    }

    setState(() {
      _isLoadingEG = true;
      _errorEG = null;
    });

    try {
      final currentYear = DateTime.now().year;
      final previousYear = currentYear - 1;
      
      // Lấy dữ liệu từ 2 năm gần nhất
      final currentYearEpisodes = await _episodeCacheService.getCategoryEpisodes('EG', currentYear);
      final previousYearEpisodes = await _episodeCacheService.getCategoryEpisodes('EG', previousYear);
      
      // Gộp episodes và sắp xếp theo publishedDate (mới nhất trước)
      final allEpisodes = [...currentYearEpisodes, ...previousYearEpisodes];
      allEpisodes.sort((a, b) => b.publishedDate.compareTo(a.publishedDate));
      
      setState(() {
        _egEpisodes = allEpisodes;
        _loadedYears = [currentYear, previousYear];
        _isLoadingEG = false;
      });
    } catch (e) {
      setState(() {
        _errorEG = e.toString();
        _isLoadingEG = false;
      });
    }
  }

  Future<void> _loadMoreEGYears() async {
    if (_loadingMoreEG) {
      return; // Đang load rồi
    }

    setState(() {
      _loadingMoreEG = true;
    });

    try {
      if (_loadedYears.isEmpty) {
        setState(() {
          _loadingMoreEG = false;
        });
        return;
      }

      // Tìm năm nhỏ nhất đã load
      final minLoadedYear = _loadedYears.reduce((a, b) => a < b ? a : b);
      final nextYear = minLoadedYear - 1;

      // Giới hạn load đến năm 2020
      if (nextYear < 2020) {
        setState(() {
          _loadingMoreEG = false;
        });
        return;
      }

      // Lấy dữ liệu năm tiếp theo
      final nextYearEpisodes = await _episodeCacheService.getCategoryEpisodes('EG', nextYear);
      
      // Gộp với episodes hiện có và sắp xếp lại
      final allEpisodes = [..._egEpisodes, ...nextYearEpisodes];
      allEpisodes.sort((a, b) => b.publishedDate.compareTo(a.publishedDate));
      
      setState(() {
        _egEpisodes = allEpisodes;
        _loadedYears = [..._loadedYears, nextYear];
        _loadingMoreEG = false;
      });
    } catch (e) {
      setState(() {
        _loadingMoreEG = false;
      });
      // Không hiển thị error khi load more, chỉ im lặng fail
      print('Error loading more years for EG: $e');
    }
  }

  bool _canLoadMoreEG() {
    if (_loadedYears.isEmpty) return false;
    
    final minLoadedYear = _loadedYears.reduce((a, b) => a < b ? a : b);
    return minLoadedYear > 2020; // Có thể load thêm nếu năm nhỏ nhất > 2020
  }

  void _navigateToGrammarDetail(Grammar grammar) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => GrammarDetailScreen(grammar: grammar),
      ),
    );
  }

  void _navigateToEpisodeDetail(Episode episode) {
    EpisodeDetailOpenHelper.open(
      context: context,
      episode: episode,
      categoryEpisodes: _egEpisodes,
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
                    _buildEnglishGrammarContent(),
                    _buildBasicGrammarContent(),
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
                  _languageManager.getText('grammar'),
                  style: theme.textTheme.headlineSmall!.copyWith(
                    color: colorScheme.onSurface,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  _languageManager.getText('grammarDesc'),
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
              Icons.menu_book,
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
        dividerColor: Colors.transparent,
        labelPadding: const EdgeInsets.symmetric(horizontal: 1, vertical: 1),
        tabs: [
          _buildTabLabel(0, 'English', 'Grammar'),
          _buildTabLabel(1, 'Basic', 'Grammar'),
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

  Widget _buildEnglishGrammarContent() {
    if (_isLoadingEG) {
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

    if (_errorEG != null) {
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
              _errorEG!,
              style: TextStyle(
                fontSize: 14, 
                color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _loadEGData,
              child: Text(_languageManager.getText('tryAgain')),
            ),
          ],
        ),
      );
    }

    if (_egEpisodes.isEmpty) {
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
              'No episodes available for English Grammar',
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
        _loadedYears = [];
        _egEpisodes = [];
        return _loadEGData();
      },
      child: ListView.builder(
        padding: FloatingBottomNavBar.scrollPadding(context),
        itemCount: _egEpisodes.length + 1 + (_canLoadMoreEG() ? 1 : 0) + 1, // +1 for load more button, +1 for banner ad
        itemBuilder: (context, index) {
          // Load More button (trước banner ad)
          if (_canLoadMoreEG() && index == _egEpisodes.length) {
            return Container(
              margin: const EdgeInsets.symmetric(vertical: 8),
              child: _loadingMoreEG
                  ? Center(
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: CircularProgressIndicator(),
                      ),
                    )
                  : ElevatedButton(
                      onPressed: _loadMoreEGYears,
                      child: Text(_languageManager.getText('loadMore') ?? 'Load More'),
                    ),
            );
          }

          // Banner Ad (sau load more button hoặc sau episodes)
          final bannerAdIndex = _canLoadMoreEG() ? _egEpisodes.length + 1 : _egEpisodes.length;
          if (index == bannerAdIndex) {
            return const BannerAdWidget();
          }

          // Episode row - chỉ xử lý nếu index trong phạm vi episodes
          if (index >= 0 && index < _egEpisodes.length) {
            final episode = _egEpisodes[index];
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

  Widget _buildBasicGrammarContent() {
    if (_isLoadingGrammar) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const CircularProgressIndicator(),
            const SizedBox(height: 16),
            Text(_languageManager.getText('loading')),
          ],
        ),
      );
    }

    if (_errorGrammar != null) {
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
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: 8),
            Text(
              _errorGrammar!,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
              ),
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _loadGrammars,
              child: Text(_languageManager.getText('tryAgain')),
            ),
          ],
        ),
      );
    }

    if (_grammars.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.menu_book_outlined,
              size: 64,
              color: Theme.of(context).colorScheme.onSurface.withOpacity(0.4),
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
      onRefresh: _loadGrammars,
      child: ListView.builder(
        padding: FloatingBottomNavBar.scrollPadding(context),
        itemCount: _grammars.length,
        itemBuilder: (context, index) {
          final grammar = _grammars[index];
          return Container(
            margin: const EdgeInsets.only(bottom: 8),
            child: Card(
              elevation: 2,
              child: ListTile(
                leading: Container(
                  width: 50,
                  height: 50,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        Theme.of(context).colorScheme.primary,
                        Theme.of(context).colorScheme.primary.withOpacity(0.7),
                      ],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    Icons.menu_book_rounded,
                    color: Theme.of(context).colorScheme.onPrimary,
                    size: 24,
                  ),
                ),
                title: Text(
                  grammar.name,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                subtitle: Row(
                  children: [
                    Icon(
                      Icons.library_books_outlined,
                      size: 14,
                      color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
                    ),
                    const SizedBox(width: 4),
                    Text(
                      '${grammar.parts.length} ${_languageManager.getText('parts')}',
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
                trailing: Icon(
                  Icons.arrow_forward_ios,
                  size: 16,
                  color: Theme.of(context).colorScheme.onSurface.withOpacity(0.4),
                ),
                onTap: () => _navigateToGrammarDetail(grammar),
              ),
            ),
          );
        },
      ),
    );
  }
}
