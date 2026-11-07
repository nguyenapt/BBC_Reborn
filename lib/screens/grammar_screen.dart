import 'package:flutter/material.dart';
import '../models/episode.dart';
import '../services/episode_cache_service.dart';
import '../services/language_manager.dart';
import '../services/episode_detail_open_helper.dart';
import '../widgets/episode_row.dart';
import '../widgets/banner_ad_widget.dart';
import '../widgets/floating_bottom_nav_bar.dart';
import '../utils/category_names.dart';
import '../utils/user_facing_error.dart';

class GrammarScreen extends StatefulWidget {
  final String? initialTab;

  const GrammarScreen({super.key, this.initialTab});

  @override
  State<GrammarScreen> createState() => _GrammarScreenState();
}

class _GrammarScreenState extends State<GrammarScreen> {
  final EpisodeCacheService _episodeCacheService = EpisodeCacheService();
  final LanguageManager _languageManager = LanguageManager();

  List<Episode> _egEpisodes = [];
  bool _isLoadingEG = false;
  String? _errorEG;
  List<int> _loadedYears = [];
  bool _loadingMoreEG = false;

  @override
  void initState() {
    super.initState();
    _loadEGData();
  }

  Future<void> _loadEGData() async {
    if (_egEpisodes.isNotEmpty && _loadedYears.isNotEmpty) {
      return;
    }

    setState(() {
      _isLoadingEG = true;
      _errorEG = null;
    });

    try {
      // Giống 6M/TEWS: chỉ 2 năm gần nhất; Load more lấy năm cũ hơn.
      final currentYear = DateTime.now().year;
      const yearsBack = 1;
      final allEpisodes = await _episodeCacheService.getCategoryEpisodesYearMerged(
        'EG',
        yearsBack: yearsBack,
      );

      setState(() {
        _egEpisodes = allEpisodes;
        _loadedYears = [currentYear, currentYear - 1];
        _isLoadingEG = false;
      });
    } catch (e) {
      setState(() {
        _errorEG = UserFacingError.message(e);
        _isLoadingEG = false;
      });
    }
  }

  Future<void> _loadMoreEGYears() async {
    if (_loadingMoreEG) {
      return;
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

      final minLoadedYear = _loadedYears.reduce((a, b) => a < b ? a : b);
      final nextYear = minLoadedYear - 1;

      if (nextYear < CategoryNames.yearBasedMinYear) {
        setState(() {
          _loadingMoreEG = false;
        });
        return;
      }

      final nextYearEpisodes =
          await _episodeCacheService.getCategoryEpisodes('EG', nextYear);

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
      print('Error loading more years for EG: $e');
    }
  }

  bool _canLoadMoreEG() {
    if (_loadedYears.isEmpty) return false;

    final minLoadedYear = _loadedYears.reduce((a, b) => a < b ? a : b);
    return minLoadedYear > CategoryNames.yearBasedMinYear;
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
              _buildHeader(),
              const SizedBox(height: 16),
              Expanded(child: _buildEnglishGrammarContent()),
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
          Expanded(
            child: Text(
              _languageManager.getText('grammar'),
              style: theme.textTheme.headlineSmall!.copyWith(
                color: colorScheme.onSurface,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
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
        _loadedYears = [];
        _egEpisodes = [];
        return _loadEGData();
      },
      child: ListView.builder(
        padding: FloatingBottomNavBar.scrollPadding(context),
        itemCount: _egEpisodes.length + 1 + (_canLoadMoreEG() ? 1 : 0) + 1,
        itemBuilder: (context, index) {
          if (_canLoadMoreEG() && index == _egEpisodes.length) {
            return Container(
              margin: const EdgeInsets.symmetric(vertical: 8),
              child: _loadingMoreEG
                  ? const Center(
                      child: Padding(
                        padding: EdgeInsets.all(16),
                        child: CircularProgressIndicator(),
                      ),
                    )
                  : ElevatedButton(
                      onPressed: _loadMoreEGYears,
                      child: Text(
                          _languageManager.getText('loadMore') ?? 'Load More'),
                    ),
            );
          }

          final bannerAdIndex =
              _canLoadMoreEG() ? _egEpisodes.length + 1 : _egEpisodes.length;
          if (index == bannerAdIndex) {
            return const BannerAdWidget();
          }

          if (index >= 0 && index < _egEpisodes.length) {
            final episode = _egEpisodes[index];
            final isLatest = index == 0;
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

          return const SizedBox.shrink();
        },
      ),
    );
  }
}
