import 'package:flutter/material.dart';
import '../models/category.dart';
import '../models/episode.dart';
import '../utils/category_colors.dart';
import '../utils/category_names.dart';
import 'episode_row.dart';
import '../services/language_manager.dart';
import '../services/learning_progress_service.dart';
import 'episode_progress_ring.dart';


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
    final colorScheme = Theme.of(context).colorScheme;
    final strongAccent = Color.lerp(colorScheme.primary, colorScheme.onSurface, 0.22)!;
    final languageManager = LanguageManager();
    final progressService = LearningProgressService();
    final useHorizontalLayout = _shouldUseHorizontalLayout(category.name);
    final latestEpisodes = useHorizontalLayout
        ? _getLatestEpisodes(category.episodes, 3)
        : category.latestEpisodes;

    if (latestEpisodes.isEmpty) {
      return const SizedBox.shrink();
    }

    return ListenableBuilder(
      listenable: progressService,
      builder: (context, child) {
        return Container(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: colorScheme.surface,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: colorScheme.shadow.withOpacity(0.1),
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
                        color: CategoryColors.getCategoryBackgroundColor(category.name),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Icon(
                        _getCategoryIcon(category.name),
                        color: strongAccent,
                        size: 20,
                      ),
                    ),
                    const SizedBox(width: 12),
                    // Tên category
                    Expanded(
                      child: Text(
                        CategoryNames.getDisplayName(category.name),
                        style: TextStyle(
                          color: strongAccent,
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    
                  ],
                ),
                const SizedBox(height: 12),               
                
                
                if (useHorizontalLayout) ...[
                  EpisodeRow(
                    episode: latestEpisodes.first,
                    onTap: () => onEpisodeTap(latestEpisodes.first),
                    languageManager: languageManager,
                    isLatest: true,
                    learningProgress: progressService
                        .getProgressForEpisode(latestEpisodes.first),
                  ),
                  const SizedBox(height: 10),
                  if (latestEpisodes.length > 1 || onViewAllTap != null)
                    LayoutBuilder(
                      builder: (context, constraints) {
                        const itemWidth = 100.0;
                        const itemSpacing = 8.0;
                        final horizontalEpisodes = _getHorizontalEpisodes(latestEpisodes);
                        final items = <Widget>[];

                        for (final episode in horizontalEpisodes) {
                          items.add(_buildHorizontalEpisodeItem(
                            episode,
                            context,
                            progressService: progressService,
                            width: itemWidth,
                          ));
                        }

                        final remainingWidth = (constraints.maxWidth -
                                (horizontalEpisodes.length * itemWidth) -
                                (horizontalEpisodes.length * itemSpacing))
                            .clamp(0.0, constraints.maxWidth);

                        items.add(_buildViewAllItem(
                          context,
                          languageManager,
                          category.name,
                          width: remainingWidth,
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
                        isLatest: index == 0,
                        learningProgress: progressService
                            .getProgressForEpisode(episode),
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
      },
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
      case 'BSA':
        return Icons.record_voice_over_outlined;
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
        categoryName == 'BSA' ||
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
    final colorScheme = Theme.of(context).colorScheme;
    final strongAccent = Color.lerp(colorScheme.primary, colorScheme.onSurface, 0.22)!;
    return Container(
      width: width,
      height: 56,
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

  Widget _buildHorizontalEpisodeItem(
    Episode episode,
    BuildContext context, {
    required LearningProgressService progressService,
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
            EpisodeThumbnailWithProgress(
              imageUrl: episode.thumbImage,
              width: width,
              height: 56,
              learningProgress: progressService.getProgressForEpisode(episode),
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

