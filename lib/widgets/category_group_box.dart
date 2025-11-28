import 'package:flutter/material.dart';
import '../models/category.dart';
import '../models/episode.dart';
import '../utils/category_colors.dart';
import '../utils/category_names.dart';
import 'episode_row.dart';
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
    final latestEpisodes = category.latestEpisodes;
    final languageManager = LanguageManager();

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
        border: Border.all(
          color: Colors.grey,
          width: 1,
        ),
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
                
                // View All button
                if (category.episodes.length > 3)
                  Container(
                    width: double.infinity,
                    margin: const EdgeInsets.only(top: 8),
                    child: TextButton.icon(
                      onPressed: () {
                        if (onViewAllTap != null) {
                          onViewAllTap!(category.name);
                        } else {
                          // Fallback: hiển thị SnackBar nếu không có callback
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text('${languageManager.getText('viewAll')} ${CategoryNames.getDisplayName(category.name)} ${languageManager.getText('episodes')}'),
                              duration: const Duration(seconds: 2),
                            ),
                          );
                        }
                      },
                      icon: Icon(
                        Icons.arrow_forward,
                        color: CategoryColors.getCategoryColor(category.name),
                        size: 16,
                      ),
                      label: Text(
                        '${languageManager.getText('viewAll')} ${CategoryNames.getDisplayName(category.name)} (${category.episodes.length})',
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
}

