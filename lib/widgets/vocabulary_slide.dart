import 'package:flutter/material.dart';
import '../models/episode.dart';
import '../models/vocabulary_item.dart';
import '../utils/category_colors.dart';
import '../services/vocabulary_service.dart';
import 'native_ad_widget.dart';

class VocabularySlide extends StatefulWidget {
  final Episode episode;

  const VocabularySlide({
    super.key,
    required this.episode,
  });

  @override
  State<VocabularySlide> createState() => _VocabularySlideState();
}

class _VocabularySlideState extends State<VocabularySlide> {
  late final VocabularyService _vocabularyService;

  @override
  void initState() {
    super.initState();
    _vocabularyService = VocabularyService();
    _vocabularyService.initialize();
  }

  @override
  Widget build(BuildContext context) {
    // Parse vocabulary items từ episode
    final vocabularyItems = VocabularyItem.parseFromEpisode(
      vocabularies: widget.episode.vocabularies,
      vocabulary: widget.episode.vocabulary,
    );

    // Nếu không có vocabulary, hiển thị Native AdMob
    if (vocabularyItems.isEmpty) {
      return NativeAdWidget(
        category: widget.episode.category,
        // Có thể thêm adUnitId cụ thể cho từng category nếu cần
        // adUnitId: _getAdUnitIdForCategory(widget.episode.category),
      );
    }

    // Nếu có vocabulary, hiển thị bình thường
    return Container(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Row(
            children: [
              Icon(
                Icons.book,
                color: CategoryColors.getCategoryColor(widget.episode.category),
                size: 20,
              ),
              const SizedBox(width: 8),
              Text(
                'Vocabulary',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: CategoryColors.getCategoryColor(widget.episode.category),
                ),
              ),
              const Spacer(),
              Text(
                '${vocabularyItems.length} words',
                style: TextStyle(
                  fontSize: 14,
                  color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          // Vocabulary Content
          Expanded(
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surface,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: Theme.of(context).colorScheme.outline.withOpacity(0.3),
                  width: 1,
                ),
              ),
              child: ListenableBuilder(
                listenable: _vocabularyService,
                builder: (context, child) {
                  return ListView.builder(
                    itemCount: vocabularyItems.length,
                    itemBuilder: (context, index) {
                      final item = vocabularyItems[index];
                      final isSaved = _vocabularyService.isVocabularySaved(item.vocab);
                      
                      return Container(
                        margin: const EdgeInsets.only(bottom: 12),
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Theme.of(context).colorScheme.surfaceVariant.withOpacity(0.3),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: CategoryColors.getCategoryColor(widget.episode.category).withOpacity(0.2),
                            width: 1,
                          ),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Vocabulary word với save button
                            Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: CategoryColors.getCategoryColor(widget.episode.category),
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: Text(
                                    '${index + 1}',
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 12,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Text(
                                    item.vocab,
                                    style: TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.bold,
                                      color: CategoryColors.getCategoryColor(widget.episode.category),
                                    ),
                                  ),
                                ),
                                // Save button
                                IconButton(
                                  onPressed: () async {
                                    if (isSaved) {
                                      await _vocabularyService.removeVocabulary(item.vocab);
                                      if (mounted) {
                                        ScaffoldMessenger.of(context).showSnackBar(
                                          SnackBar(
                                            content: Text('Removed "${item.vocab}" from saved vocabulary'),
                                            duration: const Duration(seconds: 2),
                                          ),
                                        );
                                      }
                                    } else {
                                      final success = await _vocabularyService.saveVocabulary(item);
                                      if (mounted) {
                                        ScaffoldMessenger.of(context).showSnackBar(
                                          SnackBar(
                                            content: Text(success 
                                                ? 'Saved "${item.vocab}" to vocabulary' 
                                                : '"${item.vocab}" already saved'),
                                            duration: const Duration(seconds: 2),
                                          ),
                                        );
                                      }
                                    }
                                  },
                                  icon: Icon(
                                    isSaved ? Icons.bookmark : Icons.bookmark_border,
                                    color: isSaved 
                                        ? CategoryColors.getCategoryColor(widget.episode.category)
                                        : Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
                                  ),
                                  tooltip: isSaved ? 'Remove from saved vocabulary' : 'Save to vocabulary',
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            // Meaning
                            Text(
                              item.mean,
                              style: TextStyle(
                                fontSize: 16,
                                height: 1.5,
                                color: Theme.of(context).colorScheme.onSurface,
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  );
                },
              ),
            ),
          ),
        ],
      ),
    );
  }
}