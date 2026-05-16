import 'package:flutter/material.dart';
import '../models/episode.dart';
import '../services/image_cache_service.dart';
import '../utils/category_colors.dart';
import '../utils/category_names.dart';
import '../services/language_manager.dart';

class OtherProgramsCategoryWidget extends StatelessWidget {
  final String categoryName;
  final List<Episode> episodes;
  final Function(Episode) onEpisodeTap;
  final LanguageManager languageManager;
  final VoidCallback? onViewAllTap;

  /// Giới hạn số episode preview trên Home (giống [CategoryGroupBox]).
  final int maxPreviewCount;

  /// When true and [episodes] is empty, still show the category header (Another Series fixed slots).
  final bool showPlaceholderWhenEmpty;

  const OtherProgramsCategoryWidget({
    super.key,
    required this.categoryName,
    required this.episodes,
    required this.onEpisodeTap,
    required this.languageManager,
    this.onViewAllTap,
    this.maxPreviewCount = 3,
    this.showPlaceholderWhenEmpty = false,
  });

  Widget _titleRow(BuildContext context, Color strongAccent) {
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

    final preview = _latestPreviewEpisodes(episodes, maxPreviewCount);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _titleRow(context, strongAccent),
        const SizedBox(height: 8),
        if (preview.isNotEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: _buildFirstEpisode(preview.first, context),
          ),
        const SizedBox(height: 10),
        if (preview.length > 1 || onViewAllTap != null)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: LayoutBuilder(
              builder: (context, constraints) {
                const itemWidth = 100.0;
                const itemSpacing = 8.0;
                final horizontalEpisodes = _horizontalPreviewEpisodes(preview);
                final items = <Widget>[];

                for (final episode in horizontalEpisodes) {
                  items.add(
                    _buildHorizontalEpisodeItem(
                      episode,
                      context,
                      width: itemWidth,
                    ),
                  );
                }

                if (onViewAllTap != null) {
                  final remainingWidth = (constraints.maxWidth -
                          (horizontalEpisodes.length * itemWidth) -
                          (horizontalEpisodes.length * itemSpacing))
                      .clamp(0.0, constraints.maxWidth);
                  items.add(
                    _buildViewAllItem(
                      context,
                      strongAccent,
                      width: remainingWidth,
                    ),
                  );
                }

                return SizedBox(
                  height: 140,
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      for (int i = 0; i < items.length; i++) ...[
                        if (i > 0) const SizedBox(width: itemSpacing),
                        items[i],
                      ],
                    ],
                  ),
                );
              },
            ),
          ),
        const SizedBox(height: 16),
      ],
    );
  }

  List<Episode> _latestPreviewEpisodes(List<Episode> source, int count) {
    final sorted = List<Episode>.from(source);
    sorted.sort((a, b) => b.publishedDate.compareTo(a.publishedDate));
    return sorted.take(count).toList();
  }

  List<Episode> _horizontalPreviewEpisodes(List<Episode> preview) {
    if (preview.length <= 1) return [];
    final rest = preview.sublist(1);
    return rest.length > 2 ? rest.sublist(0, 2) : rest;
  }

  Widget _buildViewAllItem(
    BuildContext context,
    Color strongAccent, {
    required double width,
  }) {
    return SizedBox(
      width: width,
      height: 56,
      child: InkWell(
        onTap: onViewAllTap,
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
          padding: const EdgeInsets.all(8),
          child: Text(
            languageManager.getText('viewAll'),
            textAlign: TextAlign.center,
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
                        // Category
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                          decoration: BoxDecoration(
                            color: CategoryColors.getCategoryBackgroundColor(episode.category),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: CategoryColors.getCategoryBorderColor(episode.category),
                              width: 1,
                            ),
                          ),
                          child: Text(
                            episode.category,
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                              color: CategoryColors.getCategoryColor(episode.category),
                            ),
                          ),
                        ),
                        const SizedBox(width: 6),
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
                width: width,
                height: 56,
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

