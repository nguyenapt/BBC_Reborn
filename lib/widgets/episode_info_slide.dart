import 'package:flutter/material.dart';
import '../models/episode.dart';
import '../services/image_cache_service.dart';
import '../services/language_manager.dart';
import 'banner_ad_widget.dart';
import 'episode_detail_tab_panel.dart';
import 'learning_checklist_bar.dart';

class EpisodeInfoSlide extends StatelessWidget {
  static const double _mainThumbWidth = 150;
  static const double _mainThumbHeight = 85; // 266:150 aspect ratio
  static const double _listThumbWidth = 100;
  static const double _listThumbHeight = 56; // 266:150 aspect ratio

  final Episode episode;
  final List<Episode> topEpisodes;
  final Function(Episode) onEpisodeTap;
  final LanguageManager languageManager;
  final double scrollBottomInset;

  const EpisodeInfoSlide({
    super.key,
    required this.episode,
    required this.topEpisodes,
    required this.onEpisodeTap,
    required this.languageManager,
    this.scrollBottomInset = 0,
  });

  @override
  Widget build(BuildContext context) {
    return EpisodeDetailTabPanel(
      child: SingleChildScrollView(
        padding: EpisodeDetailTabPanel.scrollPadding(scrollBottomInset),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildCurrentEpisodeSection(context),
            const SizedBox(height: 24),
            const Padding(
              padding: EdgeInsets.only(
                right: LearningChecklistBar.adRightClearance,
              ),
              child: BannerAdWidget(),
            ),
            _buildTopEpisodesSection(context),
          ],
        ),
      ),
    );
  }

  Widget _buildCurrentEpisodeSection(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final categoryColor = colorScheme.primary;
    
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: colorScheme.outline.withOpacity(0.3),
          width: 1,
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Thumbnail
          ImageCacheService().buildCachedImage(
            imageUrl: episode.thumbImage,
            width: _mainThumbWidth,
            height: _mainThumbHeight,
            fit: BoxFit.cover,
            borderRadius: BorderRadius.circular(8),
            showWatermark: true,
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
                    languageManager.getText('noSummary'),
                    style: TextStyle(
                      fontSize: 14,
                      color: Theme.of(context).colorScheme.onSurface.withOpacity(0.5),
                      fontStyle: FontStyle.italic,
                    ),
                  ),                
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTopEpisodesSection(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final strongAccent = Color.lerp(colorScheme.primary, colorScheme.onSurface, 0.28)!;
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
              color: strongAccent,
              size: 21,
            ),
            const SizedBox(width: 8),
            Text(
              languageManager.getText('topEpisodes'),
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w800,
                color: strongAccent,
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
    final colorScheme = Theme.of(context).colorScheme;
    final isCurrentEpisode = topEpisode.id == episode.id;
    
    return Container(
      margin: const EdgeInsets.only(bottom: 4),
      child: InkWell(
        onTap: () => onEpisodeTap(topEpisode),
        borderRadius: BorderRadius.circular(8),
        child: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: isCurrentEpisode 
                ? colorScheme.primary.withOpacity(0.1)
                : colorScheme.surface,
            borderRadius: BorderRadius.circular(8),
            border: isCurrentEpisode
                ? Border.all(
                    color: colorScheme.primary.withOpacity(0.3),
                    width: 1,
                  )
                : null,
          ),
          child: Row(
            children: [
              // Thumbnail
              ImageCacheService().buildCachedImage(
                imageUrl: topEpisode.thumbImage,
                width: _listThumbWidth,
                height: _listThumbHeight,
                fit: BoxFit.cover,
                borderRadius: BorderRadius.circular(6),
                showWatermark: true,
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
                            ? colorScheme.primary
                            : colorScheme.onSurface,
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
                  color: colorScheme.primary,
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
      return languageManager.getTextWithParams('daysAgo', {'count': difference});
    } else {
      return '${date.day}/${date.month}/${date.year}';
    }
  }
}
