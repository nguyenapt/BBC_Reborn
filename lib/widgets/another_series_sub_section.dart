import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/episode.dart';
import '../services/image_cache_service.dart';
import '../services/language_manager.dart';
import '../utils/category_colors.dart';
import '../utils/category_names.dart';
import '../utils/lle_level_groups.dart';
import '../utils/series_sub_badge_style.dart';
import 'compact_ghost_badge.dart';
import 'level_filter_chips_row.dart';

/// NC / SC block: title → level chips → episodes (home preview or full tab list).
class AnotherSeriesSubSection extends StatefulWidget {
  final String categoryCode;
  final List<Episode> episodes;
  final LanguageManager languageManager;
  final void Function(Episode episode) onEpisodeTap;
  final bool compact;
  final void Function(String)? onViewAllTap;
  final bool showPlaceholderWhenEmpty;

  const AnotherSeriesSubSection({
    super.key,
    required this.categoryCode,
    required this.episodes,
    required this.languageManager,
    required this.onEpisodeTap,
    this.compact = false,
    this.onViewAllTap,
    this.showPlaceholderWhenEmpty = false,
  });

  @override
  State<AnotherSeriesSubSection> createState() =>
      _AnotherSeriesSubSectionState();
}

class _AnotherSeriesSubSectionState extends State<AnotherSeriesSubSection> {
  String _selectedFilter = LleLevelGroups.allFilterKey;
  bool _prefsLoaded = false;

  static const double _horizontalItemWidth = 100.0;
  static const double _horizontalItemSpacing = 8.0;
  static const double _horizontalThumbHeight = 56.0;
  static const double _horizontalStripHeight = 140.0;

  @override
  void initState() {
    super.initState();
    _loadSavedFilter();
  }

  Future<void> _loadSavedFilter() async {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getString(LleLevelGroups.asSubPrefsKey(widget.categoryCode));
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
    await prefs.setString(
      LleLevelGroups.asSubPrefsKey(widget.categoryCode),
      filter,
    );
  }

  List<Episode> _filteredEpisodes() {
    final groups = LleLevelGroups.groupByLevel(widget.episodes);
    if (_selectedFilter == LleLevelGroups.allFilterKey) {
      final sorted = List<Episode>.from(widget.episodes);
      sorted.sort((a, b) => b.publishedDate.compareTo(a.publishedDate));
      return sorted;
    }
    return groups[_selectedFilter] ?? [];
  }

  Widget _buildTitleRow(ColorScheme colorScheme, Color strongAccent) {
    final style = SeriesSubBadgeStyle.forCode(
      widget.categoryCode,
      colorScheme,
      widget.languageManager,
    );
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 0),
      child: Row(
        children: [
          Icon(style.icon, color: style.color, size: 20),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              CategoryNames.getDisplayName(widget.categoryCode),
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: strongAccent,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLevelChips(List<String> availableLevels) {
    if (!_prefsLoaded) {
      return const SizedBox(
        height: 36,
        child: Center(
          child: SizedBox(
            width: 18,
            height: 18,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
        ),
      );
    }

    if (_selectedFilter != LleLevelGroups.allFilterKey &&
        !availableLevels.contains(_selectedFilter) &&
        _selectedFilter != LleLevelGroups.otherKey) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _selectFilter(LleLevelGroups.allFilterKey);
      });
    }

    return LevelFilterChipsRow(
      selectedFilter: _selectedFilter,
      availableLevels: availableLevels,
      onSelect: _selectFilter,
      languageManager: widget.languageManager,
    );
  }

  Widget _buildFirstEpisodeCard(Episode episode, BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Card(
      child: InkWell(
        onTap: () => widget.onEpisodeTap(episode),
        borderRadius: BorderRadius.circular(8),
        child: Padding(
          padding: const EdgeInsets.all(8),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ImageCacheService().buildCachedImage(
                imageUrl: episode.thumbImage,
                width: 150,
                height: 85,
                fit: BoxFit.cover,
                borderRadius: BorderRadius.circular(8),
                showWatermark: true,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 6),
                    Text(
                      episode.episodeName,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 6),
                    Text(
                      episode.summary?.isNotEmpty == true
                          ? episode.summary!
                          : episode.shortTranscript,
                      style: TextStyle(
                        fontSize: 12,
                        color: colorScheme.onSurface.withOpacity(0.68),
                        height: 1.4,
                      ),
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 6),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        if (episode.hasLevel) ...[
                          CompactGhostBadge(
                            icon: Icons.school_outlined,
                            label: episode.level!.trim(),
                            color: colorScheme.primary,
                          ),
                          const SizedBox(width: 10),
                        ],
                        Icon(
                          Icons.access_time,
                          size: 14,
                          color: colorScheme.onSurface.withOpacity(0.65),
                        ),
                        const SizedBox(width: 4),
                        Text(
                          episode.duration,
                          style: TextStyle(
                            fontSize: 10,
                            color: colorScheme.onSurface.withOpacity(0.65),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  List<Episode> _horizontalEpisodes(List<Episode> sorted) {
    if (sorted.length <= 1) return [];
    final rest = sorted.sublist(1);
    if (widget.onViewAllTap != null && rest.length > 2) {
      return rest.sublist(0, 2);
    }
    return rest;
  }

  Widget _buildViewAllItem(BuildContext context, {required double width}) {
    final colorScheme = Theme.of(context).colorScheme;
    final strongAccent =
        Color.lerp(colorScheme.primary, colorScheme.onSurface, 0.22)!;
    return SizedBox(
      width: width,
      height: _horizontalThumbHeight,
      child: InkWell(
        onTap: () => widget.onViewAllTap!(widget.categoryCode),
        borderRadius: BorderRadius.circular(8),
        child: Container(
          decoration: BoxDecoration(
            color: CategoryColors.getCategoryBackgroundColor(widget.categoryCode),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: CategoryColors.getCategoryBorderColor(widget.categoryCode),
              width: 1,
            ),
          ),
          alignment: Alignment.center,
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          child: Text(
            widget.languageManager.getText('viewAll'),
            textAlign: TextAlign.center,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: strongAccent,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHorizontalStrip(
    BuildContext context,
    List<Episode> sorted,
  ) {
    final horizontalEpisodes = _horizontalEpisodes(sorted);
    if (widget.onViewAllTap != null) {
      return LayoutBuilder(
        builder: (context, constraints) {
          final remainingWidth = (constraints.maxWidth -
                  (horizontalEpisodes.length * _horizontalItemWidth) -
                  (horizontalEpisodes.length * _horizontalItemSpacing))
              .clamp(0.0, constraints.maxWidth);
          return SizedBox(
            height: _horizontalStripHeight,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                for (int i = 0; i < horizontalEpisodes.length; i++) ...[
                  if (i > 0) const SizedBox(width: _horizontalItemSpacing),
                  _buildHorizontalItem(horizontalEpisodes[i], context),
                ],
                if (horizontalEpisodes.isNotEmpty)
                  const SizedBox(width: _horizontalItemSpacing),
                _buildViewAllItem(context, width: remainingWidth),
              ],
            ),
          );
        },
      );
    }
    return SizedBox(
      height: _horizontalStripHeight,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: horizontalEpisodes.length,
        separatorBuilder: (_, __) =>
            const SizedBox(width: _horizontalItemSpacing),
        itemBuilder: (context, index) =>
            _buildHorizontalItem(horizontalEpisodes[index], context),
      ),
    );
  }

  Widget _buildHorizontalItem(Episode episode, BuildContext context) {
    return SizedBox(
      width: _horizontalItemWidth,
      child: InkWell(
        onTap: () => widget.onEpisodeTap(episode),
        borderRadius: BorderRadius.circular(8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: ImageCacheService().buildCachedImage(
                imageUrl: episode.thumbImage,
                width: _horizontalItemWidth,
                height: _horizontalThumbHeight,
                fit: BoxFit.cover,
                showWatermark: true,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              episode.episodeName,
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w500,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final strongAccent =
        Color.lerp(colorScheme.primary, colorScheme.onSurface, 0.22)!;

    if (widget.episodes.isEmpty) {
      if (!widget.showPlaceholderWhenEmpty) {
        return const SizedBox.shrink();
      }
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildTitleRow(colorScheme, strongAccent),
          _buildLevelChips(const []),
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 16),
            child: Text(
              widget.languageManager.getText('noData'),
              style: TextStyle(
                fontSize: 14,
                color: colorScheme.onSurface.withOpacity(0.62),
              ),
            ),
          ),
        ],
      );
    }

    final groups = LleLevelGroups.groupByLevel(widget.episodes);
    final availableLevels = LleLevelGroups.availableLevels(groups);
    final filtered = _filteredEpisodes();
    final display =
        widget.compact ? filtered.take(3).toList() : filtered;

    if (display.isEmpty) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildTitleRow(colorScheme, strongAccent),
          _buildLevelChips(availableLevels),
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 16),
            child: Text(
              widget.languageManager.getText('noData'),
              style: TextStyle(
                fontSize: 14,
                color: colorScheme.onSurface.withOpacity(0.62),
              ),
            ),
          ),
        ],
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildTitleRow(colorScheme, strongAccent),
        _buildLevelChips(availableLevels),
        const SizedBox(height: 8),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: _buildFirstEpisodeCard(display.first, context),
        ),
        if (display.length > 1 || widget.onViewAllTap != null) ...[
          const SizedBox(height: 12),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: _buildHorizontalStrip(context, display),
          ),
        ],
        const SizedBox(height: 16),
      ],
    );
  }
}
