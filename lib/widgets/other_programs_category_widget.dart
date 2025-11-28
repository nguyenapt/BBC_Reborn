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

  const OtherProgramsCategoryWidget({
    super.key,
    required this.categoryName,
    required this.episodes,
    required this.onEpisodeTap,
    required this.languageManager,
  });

  @override
  Widget build(BuildContext context) {
    if (episodes.isEmpty) {
      return const SizedBox.shrink();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Category Title
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: Text(
            CategoryNames.getDisplayName(categoryName),
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: CategoryColors.getCategoryColor(categoryName),
            ),
          ),
        ),
        const SizedBox(height: 8),
        // Episode đầu tiên - UI giống các tab khác
        if (episodes.isNotEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: _buildFirstEpisode(episodes[0], context),
          ),
        const SizedBox(height: 12),
        // Các episode khác - List ngang
        if (episodes.length > 1)
          SizedBox(
            height: 140,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              itemCount: episodes.length - 1, // Bỏ qua episode đầu tiên
              itemBuilder: (context, index) {
                final episode = episodes[index + 1]; // Bắt đầu từ index 1
                return _buildHorizontalEpisodeItem(episode, context);
              },
            ),
          ),
        const SizedBox(height: 16),
      ],
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
              // Thumbnail 150x150
              ImageCacheService().buildCachedImage(
                imageUrl: episode.thumbImage,
                width: 150,
                height: 150,
                fit: BoxFit.cover,
                borderRadius: BorderRadius.circular(8),
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
                        color: Colors.grey[600],
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

  Widget _buildHorizontalEpisodeItem(Episode episode, BuildContext context) {
    return Container(
      width: 100,
      margin: const EdgeInsets.only(right: 12),
      child: InkWell(
        onTap: () => onEpisodeTap(episode),
        borderRadius: BorderRadius.circular(8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Image 100x100
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: ImageCacheService().buildCachedImage(
                imageUrl: episode.thumbImage,
                width: 100,
                height: 100,
                fit: BoxFit.cover,
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
}

