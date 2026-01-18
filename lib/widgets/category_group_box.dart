import 'package:flutter/material.dart';
import '../models/category.dart';
import '../models/episode.dart';
import '../utils/category_colors.dart';
import '../utils/category_names.dart';
import 'episode_row.dart';
import '../services/image_cache_service.dart';
import '../services/language_manager.dart';


class CategoryGroupBox extends StatelessWidget {
  final Category category;
  final Function(Episode) onEpisodeTap;
  final Function(String)? onViewAllTap;

  const CategoryGroupBox({
    super.key,
    required this.category,
    required this.onEpisodeTap,
    this.onViewAllTap,
  });

  @override
  Widget build(BuildContext context) {
    final languageManager = LanguageManager();
    final useHorizontalLayout = _shouldUseHorizontalLayout(category.name);
    final latestEpisodes = useHorizontalLayout
        ? _getLatestEpisodes(category.episodes, 3)
        : category.latestEpisodes;

    if (latestEpisodes.isEmpty) {
      return const SizedBox.shrink();
    }

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            spreadRadius: 1,
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () {
            if (onViewAllTap != null) {
              onViewAllTap!(category.name);
            }
          },
          borderRadius: BorderRadius.circular(12),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header của GroupBox
                Row(
                  children: [
                    // Icon với background
                    Container(
                      width: 32,
                      height: 32,
                      decoration: BoxDecoration(
                        color: CategoryColors.getCategoryColor(category.name).withOpacity(0.2),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Icon(
                        _getCategoryIcon(category.name),
                        color: CategoryColors.getCategoryColor(category.name),
                        size: 20,
                      ),
                    ),
                    const SizedBox(width: 12),
                    // Tên category
                    Expanded(
                      child: Text(
                        CategoryNames.getDisplayName(category.name),
                        style: TextStyle(
                          color: CategoryColors.getCategoryColor(category.name),
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    
                  ],
                ),
                const SizedBox(height: 12),               
                
                
                if (useHorizontalLayout) ...[
                  _buildFirstEpisode(latestEpisodes.first, context),
                  const SizedBox(height: 10),
                  if (latestEpisodes.length > 1 || onViewAllTap != null)
                    LayoutBuilder(
                      builder: (context, constraints) {
                        final itemWidth = (constraints.maxWidth - 16) / 3;
                        final horizontalEpisodes = _getHorizontalEpisodes(latestEpisodes);
                        final items = <Widget>[];

                        for (final episode in horizontalEpisodes) {
                          items.add(_buildHorizontalEpisodeItem(
                            episode,
                            context,
                            width: itemWidth,
                          ));
                        }

                        items.add(_buildViewAllItem(
                          context,
                          languageManager,
                          category.name,
                          width: itemWidth,
                        ));

                        return SizedBox(
                          height: 140,
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              for (int i = 0; i < items.length; i++) ...[
                                if (i > 0) const SizedBox(width: 8),
                                items[i],
                              ]
                            ],
                          ),
                        );
                      },
                    ),
                ] else ...[
                  // Danh sách episodes
                  ...latestEpisodes.asMap().entries.map((entry) {
                    final index = entry.key;
                    final episode = entry.value;
                    return Container(
                      margin: const EdgeInsets.only(bottom: 6),
                      child: EpisodeRow(
                        episode: episode,
                        onTap: () => onEpisodeTap(episode),
                        languageManager: languageManager,
                        isLatest: index == 0, // Episode đầu tiên là mới nhất
                      ),
                    );
                  }),
                ],
                
              ],
            ),
          ),
        ),
      ),
    );
  }

  IconData _getCategoryIcon(String categoryName) {
    switch (categoryName) {
      case '6M':
      case '6MGB':
      case '6MGI':
        return Icons.timer;
      case 'NewsReview':
        return Icons.newspaper;
      case 'REE':
        return Icons.record_voice_over;
      case 'TEWS':
        return Icons.chat_bubble_outline;
      case 'Grammar':
        return Icons.menu_book;
      case 'Vocabulary':
        return Icons.library_books;
      case 'Pronunciation':
        return Icons.mic;
      default:
        return Icons.category;
    }
  }

  bool _shouldUseHorizontalLayout(String categoryName) {
    return categoryName == '6M' ||
        categoryName == 'TEWS' ||
        categoryName == 'REE' ||
        categoryName == 'EG';
  }

  List<Episode> _getLatestEpisodes(List<Episode> episodes, int count) {
    final sorted = List<Episode>.from(episodes);
    sorted.sort((a, b) => b.publishedDate.compareTo(a.publishedDate));
    return sorted.take(count).toList();
  }

  List<Episode> _getHorizontalEpisodes(List<Episode> latestEpisodes) {
    if (latestEpisodes.length <= 1) return [];
    final rest = latestEpisodes.sublist(1);
    return rest.length > 2 ? rest.sublist(0, 2) : rest;
  }

  Widget _buildViewAllItem(
    BuildContext context,
    LanguageManager languageManager,
    String categoryName, {
    required double width,
  }) {
    return Container(
      width: width,
      height: 100,
      child: InkWell(
        onTap: () {
          if (onViewAllTap != null) {
            onViewAllTap!(categoryName);
          } else {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(
                  '${languageManager.getText('viewAll')} ${CategoryNames.getDisplayName(categoryName)} ${languageManager.getText('episodes')}',
                ),
                duration: const Duration(seconds: 2),
              ),
            );
          }
        },
        borderRadius: BorderRadius.circular(8),
        child: Container(
          decoration: BoxDecoration(
            color: CategoryColors.getCategoryColor(categoryName).withOpacity(0.1),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: CategoryColors.getCategoryColor(categoryName).withOpacity(0.4),
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
              color: CategoryColors.getCategoryColor(categoryName),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildFirstEpisode(Episode episode, BuildContext context) {
    return Card(
      child: InkWell(
        onTap: () => onEpisodeTap(episode),
        borderRadius: BorderRadius.circular(8),
        child: Padding(
          padding: const EdgeInsets.all(8),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ImageCacheService().buildCachedImage(
                imageUrl: episode.thumbImage,
                width: 150,
                height: 150,
                fit: BoxFit.cover,
                borderRadius: BorderRadius.circular(8),
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
                        color: Colors.grey[600],
                        height: 1.4,
                      ),
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 6),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                          decoration: BoxDecoration(
                            color: CategoryColors.getCategoryColor(episode.category).withOpacity(0.2),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: CategoryColors.getCategoryColor(episode.category).withOpacity(0.5),
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
                          color: Colors.grey[600],
                        ),
                        const SizedBox(width: 4),
                        Text(
                          episode.duration,
                          style: TextStyle(
                            fontSize: 10,
                            color: Colors.grey[600],
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
    return Container(
      width: width,
      child: InkWell(
        onTap: () => onEpisodeTap(episode),
        borderRadius: BorderRadius.circular(8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: ImageCacheService().buildCachedImage(
                imageUrl: episode.thumbImage,
                width: width,
                height: 100,
                fit: BoxFit.cover,
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
}

