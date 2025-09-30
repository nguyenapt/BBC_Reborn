import 'package:flutter/material.dart';
import '../models/episode.dart';
import '../utils/category_colors.dart';
import '../services/image_cache_service.dart';
import '../services/language_manager.dart';

class EpisodeInfoSlide extends StatelessWidget {
  final Episode episode;
  final List<Episode> topEpisodes;
  final Function(Episode) onEpisodeTap;
  final LanguageManager languageManager;
  const EpisodeInfoSlide({
    super.key,
    required this.episode,
    required this.topEpisodes,
    required this.onEpisodeTap,
    required this.languageManager,
  });

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Current Episode Section
          _buildCurrentEpisodeSection(context),
          const SizedBox(height: 24),
          // Top Episodes Section
          _buildTopEpisodesSection(context),
        ],
      ),
    );
  }

  Widget _buildCurrentEpisodeSection(BuildContext context) {
    final categoryColor = CategoryColors.getCategoryColor(episode.category);
    
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: categoryColor.withOpacity(0.3),
          width: 1,
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Thumbnail
          ImageCacheService().buildCachedImage(
            imageUrl: episode.thumbImage,
            width: 120,
            height: 120,
            fit: BoxFit.cover,
            borderRadius: BorderRadius.circular(8),
          ),
          const SizedBox(width: 16),
          // Episode Info
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Summary
                if (episode.summary != null && episode.summary!.isNotEmpty)
                  Text(
                    episode.summary!,
                    style: TextStyle(
                      fontSize: 16,
                      color: Theme.of(context).colorScheme.onSurface,
                      height: 1.4,
                    ),
                    maxLines: 6,
                    overflow: TextOverflow.ellipsis,
                  )
                else
                  Text(
                    'Không có tóm tắt cho episode này.',
                    style: TextStyle(
                      fontSize: 14,
                      color: Theme.of(context).colorScheme.onSurface.withOpacity(0.5),
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                const SizedBox(height: 12),
                // Year - Căn sang phải
                if (episode.year != null)
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      Icon(
                        Icons.calendar_month,
                        size: 16,
                        color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
                      )                      
                    ],
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTopEpisodesSection(BuildContext context) {
    if (topEpisodes.isEmpty) {
      return const SizedBox.shrink();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(
              Icons.star,
              color: CategoryColors.getCategoryColor(episode.category),
              size: 20,
            ),
            const SizedBox(width: 8),
            Text(
              'Top ${topEpisodes.length} Episodes cùng category',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: CategoryColors.getCategoryColor(episode.category),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        ...topEpisodes.take(10).map((topEpisode) => _buildTopEpisodeItem(context, topEpisode)),
      ],
    );
  }

  Widget _buildTopEpisodeItem(BuildContext context, Episode topEpisode) {
    final isCurrentEpisode = topEpisode.id == episode.id;
    
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      child: InkWell(
        onTap: () => onEpisodeTap(topEpisode),
        borderRadius: BorderRadius.circular(8),
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: isCurrentEpisode 
                ? CategoryColors.getCategoryColor(episode.category).withOpacity(0.1)
                : Theme.of(context).colorScheme.surface,
            borderRadius: BorderRadius.circular(8),
            border: isCurrentEpisode
                ? Border.all(
                    color: CategoryColors.getCategoryColor(episode.category).withOpacity(0.3),
                    width: 1,
                  )
                : null,
          ),
          child: Row(
            children: [
              // Thumbnail
              ImageCacheService().buildCachedImage(
                imageUrl: topEpisode.thumbImage,
                width: 60,
                height: 60,
                fit: BoxFit.cover,
                borderRadius: BorderRadius.circular(6),
              ),
              const SizedBox(width: 12),
              // Episode Info
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      topEpisode.episodeName,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: isCurrentEpisode ? FontWeight.bold : FontWeight.w500,
                        color: isCurrentEpisode 
                            ? CategoryColors.getCategoryColor(episode.category)
                            : Theme.of(context).colorScheme.onSurface,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Text(
                          topEpisode.duration,
                          style: TextStyle(
                            fontSize: 12,
                            color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          _formatDate(topEpisode.publishedDate),
                          style: TextStyle(
                            fontSize: 12,
                            color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              if (isCurrentEpisode)
                Icon(
                  Icons.play_circle_filled,
                  color: CategoryColors.getCategoryColor(episode.category),
                  size: 24,
                ),
            ],
          ),
        ),
      ),
    );
  }

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final difference = now.difference(date).inDays;
    
    if (difference == 0) {
      return languageManager.getText('today');
    } else if (difference == 1) {
      return languageManager.getText('yesterday');
    } else if (difference < 7) {
      return '${languageManager.getText('daysAgo')} $difference';
    } else {
      return '${date.day}/${date.month}/${date.year}';
    }
  }
}
