import 'package:flutter/material.dart';
import '../models/episode.dart';
import '../services/image_cache_service.dart';
import '../utils/category_colors.dart';
import '../utils/category_names.dart';
import '../utils/series_sub_badge_style.dart';
import '../services/language_manager.dart';
import 'another_series_sub_section.dart';
import 'compact_ghost_badge.dart';

class OtherProgramsCategoryWidget extends StatelessWidget {
  final String categoryName;
  final List<Episode> episodes;
  final Function(Episode) onEpisodeTap;
  final LanguageManager languageManager;
  final Function(String)? onViewAllTap;

  /// When true and [episodes] is empty, still show the category header (Another Series fixed slots).
  final bool showPlaceholderWhenEmpty;

  const OtherProgramsCategoryWidget({
    super.key,
    required this.categoryName,
    required this.episodes,
    required this.onEpisodeTap,
    required this.languageManager,
    this.onViewAllTap,
    this.showPlaceholderWhenEmpty = false,
  });

  Widget _titleRow(BuildContext context, Color strongAccent) {
    final colorScheme = Theme.of(context).colorScheme;
    final isAnotherSeriesSub =
        CategoryNames.anotherSeriesSubCodes.contains(categoryName);

    if (isAnotherSeriesSub) {
      final style = SeriesSubBadgeStyle.forCode(
        categoryName,
        colorScheme,
      );
      return Padding(
        padding: const EdgeInsets.fromLTRB(12, 10, 12, 8),
        child: CompactGhostBadge(
          icon: style.icon,
          label: style.label,
          color: style.color,
          fontSize: 12,
          fontWeight: FontWeight.w700,
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 8),
      child: Row(
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: CategoryColors.getCategoryBackgroundColor(categoryName),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(
              _getCategoryIcon(categoryName),
              color: strongAccent,
              size: 20,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              CategoryNames.getDisplayName(categoryName),
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

  @override
  Widget build(BuildContext context) {
    if (CategoryNames.anotherSeriesSubCodes.contains(categoryName)) {
      return AnotherSeriesSubSection(
        categoryCode: categoryName,
        episodes: episodes,
        languageManager: languageManager,
        onEpisodeTap: onEpisodeTap,
        onViewAllTap: onViewAllTap,
        compact: true,
        showPlaceholderWhenEmpty: showPlaceholderWhenEmpty,
      );
    }

    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final strongAccent = Color.lerp(colorScheme.primary, colorScheme.onSurface, 0.22)!;
    if (episodes.isEmpty) {
      if (!showPlaceholderWhenEmpty) {
        return const SizedBox.shrink();
      }
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _titleRow(context, strongAccent),
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 0, 12, 16),
            child: Text(
              languageManager.getText('noData'),
              style: TextStyle(
                fontSize: 14,
                color: colorScheme.onSurface.withOpacity(0.62),
              ),
            ),
          ),
        ],
      );
    }

    final sorted = _sortedByDateDesc(episodes);
    final displayEpisodes = onViewAllTap != null
        ? sorted.take(3).toList()
        : sorted;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _titleRow(context, strongAccent),
        const SizedBox(height: 8),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: _buildFirstEpisode(displayEpisodes.first, context),
        ),
        const SizedBox(height: 12),
        if (displayEpisodes.length > 1 || onViewAllTap != null)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: _buildHorizontalEpisodeStrip(context, displayEpisodes),
          ),
        const SizedBox(height: 16),
      ],
    );
  }

  List<Episode> _sortedByDateDesc(List<Episode> source) {
    final sorted = List<Episode>.from(source);
    sorted.sort((a, b) => b.publishedDate.compareTo(a.publishedDate));
    return sorted;
  }

  static const double _horizontalItemWidth = 100.0;
  static const double _horizontalItemSpacing = 8.0;
  static const double _horizontalThumbHeight = 56.0;
  static const double _horizontalStripHeight = 140.0;

  Widget _buildHorizontalEpisodeStrip(BuildContext context, List<Episode> sorted) {
    final horizontalEpisodes = _getHorizontalEpisodes(sorted);

    if (onViewAllTap != null) {
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
                  _buildHorizontalEpisodeItem(
                    horizontalEpisodes[i],
                    context,
                    width: _horizontalItemWidth,
                  ),
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
        separatorBuilder: (_, __) => const SizedBox(width: _horizontalItemSpacing),
        itemBuilder: (context, index) => _buildHorizontalEpisodeItem(
          horizontalEpisodes[index],
          context,
          width: _horizontalItemWidth,
        ),
      ),
    );
  }

  Widget _buildFirstEpisode(Episode episode, BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Card(
      child: InkWell(
        onTap: () => onEpisodeTap(episode),
        borderRadius: BorderRadius.circular(8),
        child: Padding(
          padding: const EdgeInsets.all(8),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Thumbnail theo tỉ lệ gốc 266:150
              ImageCacheService().buildCachedImage(
                imageUrl: episode.thumbImage,
                width: 150,
                height: 85,
                fit: BoxFit.cover,
                borderRadius: BorderRadius.circular(8),
                showWatermark: true,
              ),
              const SizedBox(width: 10),
              // Thông tin bên phải
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 6),
                    // Episode Name (16px)
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
                    // Summary
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
                    // Category và Duration (bỏ date)
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
                        if (CategoryNames.anotherSeriesSubCodes
                            .contains(episode.category)) ...[
                          Builder(
                            builder: (context) {
                              final style = SeriesSubBadgeStyle.forCode(
                                episode.category,
                                colorScheme,
                              );
                              return CompactGhostBadge(
                                icon: style.icon,
                                label: style.label,
                                color: style.color,
                              );
                            },
                          ),
                          const SizedBox(width: 10),
                        ] else ...[
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 3,
                            ),
                            decoration: BoxDecoration(
                              color: CategoryColors.getCategoryBackgroundColor(
                                episode.category,
                              ),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: CategoryColors.getCategoryBorderColor(
                                  episode.category,
                                ),
                                width: 1,
                              ),
                            ),
                            child: Text(
                              episode.category,
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                                color: CategoryColors.getCategoryColor(
                                  episode.category,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 6),
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

  List<Episode> _getHorizontalEpisodes(List<Episode> sortedNewestFirst) {
    if (sortedNewestFirst.length <= 1) return [];
    final rest = sortedNewestFirst.sublist(1);
    if (onViewAllTap != null && rest.length > 2) {
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
        onTap: () => onViewAllTap!(categoryName),
        borderRadius: BorderRadius.circular(8),
        child: Container(
          decoration: BoxDecoration(
            color: CategoryColors.getCategoryBackgroundColor(categoryName),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: CategoryColors.getCategoryBorderColor(categoryName),
              width: 1,
            ),
          ),
          alignment: Alignment.center,
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          child: Text(
            languageManager.getText('viewAll'),
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

  Widget _buildHorizontalEpisodeItem(
    Episode episode,
    BuildContext context, {
    required double width,
  }) {
    return SizedBox(
      width: width,
      child: InkWell(
        onTap: () => onEpisodeTap(episode),
        borderRadius: BorderRadius.circular(8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Image theo tỉ lệ gốc 266:150
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
            // Episode Name
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

  IconData _getCategoryIcon(String code) {
    switch (code) {
      case 'CD':
        return Icons.groups_outlined;
      case 'EK':
        return Icons.all_inclusive_outlined;
      case 'AMS':
        return Icons.auto_stories_outlined;
      case 'LLE':
        return Icons.school_outlined;
      case 'ON':
        return Icons.article_outlined;
      case 'NC':
        return Icons.forum_outlined;
      case 'SC':
        return Icons.chat_outlined;
      case '6M':
      case '6MGB':
      case '6MGI':
        return Icons.timer;
      case 'OF':
        return Icons.business_center_outlined;
      case 'EIM':
        return Icons.flash_on_outlined;
      case 'TEWS':
        return Icons.chat_bubble_outline;
      case 'BSA':
        return Icons.record_voice_over_outlined;
      case 'REE':
        return Icons.record_voice_over;
      case 'EG':
        return Icons.menu_book;
      default:
        return Icons.category;
    }
  }
}

