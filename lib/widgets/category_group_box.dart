import 'package:flutter/material.dart';
import '../models/category.dart';
import '../models/episode.dart';
import '../utils/category_colors.dart';
import 'episode_row.dart';
import '../services/language_manager.dart';


class CategoryGroupBox extends StatelessWidget {
  final Category category;
  final Function(Episode) onEpisodeTap;

  const CategoryGroupBox({
    super.key,
    required this.category,
    required this.onEpisodeTap,
  });

  @override
  Widget build(BuildContext context) {
    final latestEpisodes = category.latestEpisodes;
    final languageManager = LanguageManager();

    if (latestEpisodes.isEmpty) {
      return const SizedBox.shrink();
    }

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: CategoryColors.getCategoryBackgroundColor(category.name),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: CategoryColors.getCategoryBorderColor(category.name),
          width: 2,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            spreadRadius: 1,
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header của GroupBox
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: CategoryColors.getCategoryColor(category.name),
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(10),
                topRight: Radius.circular(10),
              ),
            ),
            child: Row(
              children: [
                // Icon cho category
                Icon(
                  _getCategoryIcon(category.name),
                  color: Colors.white,
                  size: 20,
                ),
                const SizedBox(width: 8),
                // Tên category
                Expanded(
                  child: Text(
                    category.name,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                // Số lượng episodes
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    '${category.episodes.length} episodes',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),
          ),
          // Nội dung episodes
          Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              children: [
                // Subtitle
                Row(
                  children: [
                    Icon(
                      Icons.star,
                      color: CategoryColors.getCategoryColor(category.name),
                      size: 16,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      '${languageManager.getText('newEpisodes')} (${latestEpisodes.length})',
                      style: TextStyle(
                        color: CategoryColors.getCategoryColor(category.name),
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                // Danh sách episodes
                ...latestEpisodes.map((episode) => Container(
                  margin: const EdgeInsets.only(bottom: 6),
                  child: EpisodeRow(
                    episode: episode,
                    onTap: () => onEpisodeTap(episode),
                  ),
                )),
                // View All button
                if (category.episodes.length > 3)
                  Container(
                    width: double.infinity,
                    margin: const EdgeInsets.only(top: 8),
                    child: TextButton.icon(
                      onPressed: () {
                        // TODO: Navigate to category detail page
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text('${languageManager.getText('viewAll')} ${category.name} ${languageManager.getText('episodes')}'),
                            duration: const Duration(seconds: 2),
                          ),
                        );
                      },
                      icon: Icon(
                        Icons.arrow_forward,
                        color: CategoryColors.getCategoryColor(category.name),
                        size: 16,
                      ),
                      label: Text(
                        '${languageManager.getText('viewAll')} (${category.episodes.length})',
                        style: TextStyle(
                          color: CategoryColors.getCategoryColor(category.name),
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      style: TextButton.styleFrom(
                        backgroundColor: CategoryColors.getCategoryColor(category.name).withOpacity(0.1),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ],
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
}

