import 'package:flutter/material.dart';
import '../models/cefr_category.dart';
import '../models/cefr_level.dart';
import '../models/episode.dart';
import '../models/sub_category.dart';
import '../services/episode_cache_service.dart';
import '../services/language_manager.dart';
import '../services/learning_progress_service.dart';
import '../services/episode_detail_open_helper.dart';
import '../widgets/episode_row.dart';
import '../widgets/banner_ad_widget.dart';
import '../widgets/floating_bottom_nav_bar.dart';
import '../utils/user_facing_error.dart';

class CategoriesScreen extends StatefulWidget {
  final String? initialTab;

  const CategoriesScreen({super.key, this.initialTab});

  @override
  State<CategoriesScreen> createState() => _CategoriesScreenState();
}

class _CategoriesScreenState extends State<CategoriesScreen>
    with SingleTickerProviderStateMixin {
  static const int _viewAllIndex = -1;

  late TabController _tabController;
  final LanguageManager _languageManager = LanguageManager();
  final EpisodeCacheService _episodeCacheService = EpisodeCacheService();
  final LearningProgressService _learningProgress = LearningProgressService();

  late final VoidCallback _learningProgressListener;

  final Map<String, CefrCategory> _levelData = {};
  final Map<String, bool> _loadingStates = {
    for (final code in CefrLevel.codes) code: false,
  };
  final Map<String, String?> _errorStates = {
    for (final code in CefrLevel.codes) code: null,
  };

  /// Selected subcategory index per level; [_viewAllIndex] = View all.
  final Map<String, int> _selectedSubIndex = {
    for (final code in CefrLevel.codes) code: 0,
  };

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: CefrLevel.codes.length, vsync: this);

    var initialIndex = 0;
    if (widget.initialTab != null) {
      final tabIndex = CefrLevel.codes.indexOf(widget.initialTab!.toUpperCase());
      if (tabIndex != -1) {
        initialIndex = tabIndex;
        _tabController.index = tabIndex;
      }
    }

    _loadLevel(CefrLevel.codes[initialIndex]);
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

  String get _currentLevelCode => CefrLevel.codes[_tabController.index];

  void _onTabChanged() {
    if (_tabController.indexIsChanging) return;
    _loadLevel(_currentLevelCode);
  }

  Future<void> _loadLevel(String levelCode) async {
    if (_levelData.containsKey(levelCode)) return;
    if (_loadingStates[levelCode] == true) return;

    setState(() {
      _loadingStates[levelCode] = true;
      _errorStates[levelCode] = null;
    });

    try {
      final level = await _episodeCacheService.getLevel(levelCode);
      if (!mounted) return;
      setState(() {
        _levelData[levelCode] = level;
        _selectedSubIndex[levelCode] =
            level.subCategories.isNotEmpty ? level.subCategories.first.index : _viewAllIndex;
        _loadingStates[levelCode] = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _errorStates[levelCode] = UserFacingError.message(e);
        _loadingStates[levelCode] = false;
      });
    }
  }

  List<Episode> _episodesForLevel(String levelCode) {
    final level = _levelData[levelCode];
    if (level == null) return const [];
    final selected = _selectedSubIndex[levelCode] ?? 0;
    if (selected == _viewAllIndex) {
      return level.allEpisodesInSubOrder;
    }
    return level.subAt(selected)?.episodes ?? const [];
  }

  void _navigateToEpisodeDetail(Episode episode) {
    final categoryEpisodes = _episodesForLevel(_currentLevelCode);
    EpisodeDetailOpenHelper.open(
      context: context,
      episode: episode,
      categoryEpisodes: categoryEpisodes,
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
              const SizedBox(height: 12),
              _buildTabBar(),
              Expanded(
                child: TabBarView(
                  controller: _tabController,
                  children: [
                    for (final code in CefrLevel.codes) _buildLevelContent(code),
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
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

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
              _languageManager.getText('categories'),
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
              color: colorScheme.surfaceContainerHighest,
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
      margin: const EdgeInsets.symmetric(horizontal: 8),
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
        isScrollable: true,
        tabAlignment: TabAlignment.start,
        indicator: UnderlineTabIndicator(
          borderSide: BorderSide(
            color: Theme.of(context).colorScheme.primary,
            width: 3,
          ),
          insets: const EdgeInsets.symmetric(horizontal: 4),
        ),
        indicatorSize: TabBarIndicatorSize.tab,
        labelColor: Theme.of(context).colorScheme.primary,
        unselectedLabelColor:
            Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
        labelStyle: const TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w700,
        ),
        unselectedLabelStyle: const TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w500,
        ),
        dividerColor: Colors.transparent,
        tabs: [for (final code in CefrLevel.codes) Tab(text: code)],
      ),
    );
  }

  Widget _buildLevelContent(String levelCode) {
    if (_loadingStates[levelCode] == true) {
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

    final error = _errorStates[levelCode];
    if (error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                error,
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Theme.of(context).colorScheme.error,
                ),
              ),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: () {
                  _levelData.remove(levelCode);
                  _loadLevel(levelCode);
                },
                child: Text(_languageManager.getText('tryAgain')),
              ),
            ],
          ),
        ),
      );
    }

    final level = _levelData[levelCode];
    if (level == null) {
      return const SizedBox.shrink();
    }

    final episodes = _episodesForLevel(levelCode);
    final bottomPad = FloatingBottomNavBar.scrollPadding(context).bottom;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _buildSubCategoryChips(levelCode, level.subCategories),
        Expanded(
          child: episodes.isEmpty
              ? Center(
                  child: Text(
                    _languageManager.getText('noData'),
                    style: TextStyle(
                      fontSize: 16,
                      color: Theme.of(context)
                          .colorScheme
                          .onSurface
                          .withOpacity(0.7),
                    ),
                  ),
                )
              : ListView.builder(
                  padding: EdgeInsets.fromLTRB(12, 8, 12, bottomPad + 16),
                  itemCount: episodes.length + 1,
                  itemBuilder: (context, index) {
                    if (index == 0) {
                      return const Padding(
                        padding: EdgeInsets.only(bottom: 8),
                        child: BannerAdWidget(),
                      );
                    }
                    final episode = episodes[index - 1];
                    final progress = _learningProgress
                        .getProgress(episode.resolvedStorageId);
                    return EpisodeRow(
                      episode: episode,
                      onTap: () => _navigateToEpisodeDetail(episode),
                      languageManager: _languageManager,
                      learningProgress: progress,
                    );
                  },
                ),
        ),
      ],
    );
  }

  Widget _buildSubCategoryChips(
    String levelCode,
    List<SubCategory> subs,
  ) {
    final selected = _selectedSubIndex[levelCode] ?? 0;
    final viewAllLabel = _languageManager.getText('viewAll');

    return SizedBox(
      height: 48,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        children: [
          for (final sub in subs) ...[
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: ChoiceChip(
                label: Text(
                  sub.text.isNotEmpty ? sub.text : 'Sub ${sub.index + 1}',
                ),
                selected: selected == sub.index,
                onSelected: (_) {
                  setState(() => _selectedSubIndex[levelCode] = sub.index);
                },
              ),
            ),
          ],
          Padding(
            padding: const EdgeInsets.only(right: 4),
            child: ChoiceChip(
              label: Text(viewAllLabel),
              selected: selected == _viewAllIndex,
              onSelected: (_) {
                setState(() => _selectedSubIndex[levelCode] = _viewAllIndex);
              },
            ),
          ),
        ],
      ),
    );
  }
}
