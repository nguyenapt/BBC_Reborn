import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/episode.dart';
import '../services/language_manager.dart';
import '../utils/lle_level_groups.dart';
import 'banner_ad_widget.dart';
import 'compact_ghost_badge.dart';
import 'episode_row.dart';
import 'floating_bottom_nav_bar.dart';
import 'level_filter_chips_row.dart';

class LleLevelEpisodeList extends StatefulWidget {
  final List<Episode> episodes;
  final LanguageManager languageManager;
  final void Function(Episode episode) onEpisodeTap;
  final Future<void> Function() onRefresh;
  final String prefsKey;

  const LleLevelEpisodeList({
    super.key,
    required this.episodes,
    required this.languageManager,
    required this.onEpisodeTap,
    required this.onRefresh,
    this.prefsKey = LleLevelGroups.prefsKey,
  });

  @override
  State<LleLevelEpisodeList> createState() => _LleLevelEpisodeListState();
}

class _LleLevelEpisodeListState extends State<LleLevelEpisodeList> {
  String _selectedFilter = LleLevelGroups.allFilterKey;
  bool _prefsLoaded = false;

  @override
  void initState() {
    super.initState();
    _loadSavedFilter();
  }

  Future<void> _loadSavedFilter() async {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getString(widget.prefsKey);
    if (!mounted) return;
    setState(() {
      if (saved != null && saved.isNotEmpty) {
        _selectedFilter = saved;
      }
      _prefsLoaded = true;
    });
  }

  Future<void> _selectFilter(String filter) async {
    setState(() => _selectedFilter = filter);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(widget.prefsKey, filter);
  }

  String _levelLabel(String levelKey) {
    if (levelKey == LleLevelGroups.otherKey) {
      return widget.languageManager.getText('lleLevelOther');
    }
    return levelKey;
  }

  Widget _buildFilterChips(
    ThemeData theme,
    List<String> availableLevels,
  ) {
    if (_selectedFilter != LleLevelGroups.allFilterKey &&
        !availableLevels.contains(_selectedFilter)) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          _selectFilter(LleLevelGroups.allFilterKey);
        }
      });
    }

    return Material(
      color: theme.colorScheme.surface,
      elevation: 1,
      child: LevelFilterChipsRow(
        selectedFilter: _selectedFilter,
        availableLevels: availableLevels,
        onSelect: _selectFilter,
        languageManager: widget.languageManager,
      ),
    );
  }

  Widget _buildSectionHeader(String title, ColorScheme colorScheme) {
    final strongAccent =
        Color.lerp(colorScheme.primary, colorScheme.onSurface, 0.22)!;
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 14, 4, 6),
      child: CompactGhostBadge(
        icon: Icons.school_outlined,
        label: title,
        color: strongAccent,
        fontSize: 12,
        fontWeight: FontWeight.w700,
      ),
    );
  }

  Widget _buildEpisodeTile(Episode episode, {required bool isLatest}) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      child: EpisodeRow(
        episode: episode,
        onTap: () => widget.onEpisodeTap(episode),
        languageManager: widget.languageManager,
        isLatest: isLatest,
        showLevelBadge: true,
      ),
    );
  }

  List<Widget> _buildAllSections(
    Map<String, List<Episode>> groups,
    ColorScheme colorScheme,
  ) {
    final widgets = <Widget>[];
    for (final section in LleLevelGroups.sectionsForAllView(groups)) {
      final sectionEpisodes = groups[section] ?? [];
      if (sectionEpisodes.isEmpty) continue;

      widgets.add(_buildSectionHeader(_levelLabel(section), colorScheme));
      for (var i = 0; i < sectionEpisodes.length; i++) {
        widgets.add(
          _buildEpisodeTile(
            sectionEpisodes[i],
            isLatest: i == 0,
          ),
        );
      }
    }
    widgets.add(const BannerAdWidget());
    return widgets;
  }

  List<Widget> _buildSingleLevelList(
    Map<String, List<Episode>> groups,
  ) {
    final levelEpisodes = groups[_selectedFilter] ?? [];
    final widgets = <Widget>[];

    for (var i = 0; i < levelEpisodes.length; i++) {
      widgets.add(
        _buildEpisodeTile(
          levelEpisodes[i],
          isLatest: i == 0,
        ),
      );
    }
    widgets.add(const BannerAdWidget());
    return widgets;
  }

  @override
  Widget build(BuildContext context) {
    if (!_prefsLoaded) {
      return const Center(child: CircularProgressIndicator());
    }

    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final groups = LleLevelGroups.groupByLevel(widget.episodes);
    final availableLevels = LleLevelGroups.availableLevels(groups);

    if (widget.episodes.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.library_music_outlined,
              size: 64,
              color: colorScheme.onSurface.withOpacity(0.4),
            ),
            const SizedBox(height: 16),
            Text(
              widget.languageManager.getText('noData'),
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: colorScheme.onSurface,
              ),
            ),
          ],
        ),
      );
    }

    final listChildren = _selectedFilter == LleLevelGroups.allFilterKey
        ? _buildAllSections(groups, colorScheme)
        : _buildSingleLevelList(groups);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _buildFilterChips(theme, availableLevels),
        Expanded(
          child: RefreshIndicator(
            onRefresh: widget.onRefresh,
            child: ListView(
              padding: FloatingBottomNavBar.scrollPadding(
                context,
                left: 12,
                top: 8,
                right: 12,
                bottom: 8,
              ),
              children: listChildren,
            ),
          ),
        ),
      ],
    );
  }
}
