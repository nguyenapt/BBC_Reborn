import 'package:flutter/material.dart';
import '../models/episode.dart';
import '../utils/category_colors.dart';
import '../utils/category_names.dart';
import '../utils/series_sub_badge_style.dart';
import '../services/image_cache_service.dart';
import '../services/language_manager.dart';
import 'compact_ghost_badge.dart';

class EpisodeRow extends StatelessWidget {
  final Episode episode;
  final VoidCallback onTap;
  final LanguageManager languageManager;
  final bool isLatest; // Flag để xác định episode mới nhất
  final bool showLevelBadge;
  final bool showCompactSubBadge;
  const EpisodeRow({
    super.key,
    required this.episode,
    required this.onTap,
    required this.languageManager,
    this.isLatest = false,
    this.showLevelBadge = false,
    this.showCompactSubBadge = false,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final subBadgeStyle = showCompactSubBadge &&
            CategoryNames.anotherSeriesSubCodes.contains(episode.category)
        ? SeriesSubBadgeStyle.forCode(
            episode.category,
            colorScheme,
            languageManager,
          )
        : null;
    return Card(
      //margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 3),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Padding(
          padding: const EdgeInsets.all(8),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Thumbnail bên trái theo tỉ lệ gốc 266:150
              ImageCacheService().buildCachedImage(
                imageUrl: episode.thumbImage,
                width: isLatest ? 150 : 100,
                height: isLatest ? 85 : 56,
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
                    // Episode Name (to hơn 2px nếu là episode mới nhất)
                    Text(
                      episode.episodeName,
                      style: TextStyle(
                        fontSize: isLatest ? 16 : 14,
                        fontWeight: FontWeight.bold,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 6),
                    // Summary (short text) với fallback là shortTranscript
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
                    // Duration và Published Date
                    //Căn phải 2 text này
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        if (showLevelBadge && episode.hasLevel) ...[
                          CompactGhostBadge(
                            icon: Icons.school_outlined,
                            label: episode.level!.trim(),
                            color: colorScheme.primary,
                          ),
                          const SizedBox(width: 10),
                        ],
                        if (showCompactSubBadge && subBadgeStyle != null) ...[
                          CompactGhostBadge(
                            icon: subBadgeStyle.icon,
                            label: subBadgeStyle.label,
                            color: subBadgeStyle.color,
                          ),
                          const SizedBox(width: 10),
                        ] else if (!showCompactSubBadge) ...[
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
                        const SizedBox(width: 6),
                        Icon(
                          Icons.calendar_today,
                          size: 14,
                          color: colorScheme.onSurface.withOpacity(0.65),
                        ),
                        const SizedBox(width: 4),
                        Text(
                          _formatDate(episode.publishedDate),
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
