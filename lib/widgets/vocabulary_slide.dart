import 'package:flutter/material.dart';
import '../models/episode.dart';
import '../models/vocabulary_item.dart';
import '../utils/category_colors.dart';
import '../services/vocabulary_service.dart';
import '../services/ai_translation_service.dart';
import '../services/ai_vocabulary_service.dart';
import '../services/ai/ai_error_handler.dart';
import '../models/enhanced_vocabulary.dart';
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
  final AITranslationService _translationService = AITranslationService();
  final AIVocabularyService _vocabEnhanceService = AIVocabularyService();
  final Map<String, String> _vocabTranslations = {};
  final Map<String, EnhancedVocabulary?> _enhancedVocab = {};

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
      padding: const EdgeInsets.all(12),
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
              padding: const EdgeInsets.all(12),
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
                        margin: const EdgeInsets.only(bottom: 4),
                        padding: const EdgeInsets.all(8),
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
                                // Enhance button
                                IconButton(
                                  onPressed: () => _showEnhancedInfo(context, item),
                                  icon: Icon(
                                    Icons.auto_awesome,
                                    color: CategoryColors.getCategoryColor(widget.episode.category),
                                    size: 20,
                                  ),
                                  tooltip: 'Enhance vocabulary',
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
                            // Translation (lazy load)
                            FutureBuilder<String>(
                              future: _getTranslation(item.vocab, item.mean),
                              builder: (context, snapshot) {
                                if (snapshot.connectionState == ConnectionState.waiting) {
                                  return Padding(
                                    padding: const EdgeInsets.only(top: 4),
                                    child: SizedBox(
                                      width: 16,
                                      height: 16,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        valueColor: AlwaysStoppedAnimation<Color>(
                                          CategoryColors.getCategoryColor(widget.episode.category),
                                        ),
                                      ),
                                    ),
                                  );
                                }
                                if (snapshot.hasData && snapshot.data != null && snapshot.data!.isNotEmpty) {
                                  return Padding(
                                    padding: const EdgeInsets.only(top: 6),
                                    child: Text(
                                      snapshot.data!,
                                      style: TextStyle(
                                        fontSize: 14,
                                        fontStyle: FontStyle.italic,
                                        color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
                                      ),
                                    ),
                                  );
                                }
                                return const SizedBox.shrink();
                              },
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

  Future<String> _getTranslation(String vocab, String meaning) async {
    // Check cache first
    if (_vocabTranslations.containsKey(vocab)) {
      return _vocabTranslations[vocab]!;
    }

    try {
      final translated = await _translationService.translateVocabulary(
        vocab,
        meaning,
        context: widget.episode.transcript,
      );
      
      _vocabTranslations[vocab] = translated;
      return translated;
    } catch (e) {
      debugPrint('Error translating vocabulary $vocab: $e');
      return ''; // Return empty on error
    }
  }

  Future<void> _showEnhancedInfo(BuildContext context, VocabularyItem item) async {
    // Check cache first
    if (_enhancedVocab.containsKey(item.vocab) && _enhancedVocab[item.vocab] != null) {
      _showEnhancedDialog(context, _enhancedVocab[item.vocab]!);
      return;
    }

    // Show loading dialog
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => Center(
        child: Card(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                CircularProgressIndicator(
                  valueColor: AlwaysStoppedAnimation<Color>(
                    CategoryColors.getCategoryColor(widget.episode.category),
                  ),
                ),
                const SizedBox(height: 16),
                const Text('Enhancing vocabulary...'),
              ],
            ),
          ),
        ),
      ),
    );

    try {
      final enhanced = await _vocabEnhanceService.enhanceVocabulary(
        item,
        context: widget.episode.transcript,
      );

      _enhancedVocab[item.vocab] = enhanced;

      if (context.mounted) {
        Navigator.of(context).pop(); // Close loading dialog
        _showEnhancedDialog(context, enhanced);
      }
    } catch (e) {
      if (context.mounted) {
        Navigator.of(context).pop(); // Close loading dialog

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(AIErrorHandler.getErrorMessage(e)),
            action: SnackBarAction(
              label: 'Retry',
              onPressed: () => _showEnhancedInfo(context, item),
            ),
          ),
        );
      }
    }
  }

  void _showEnhancedDialog(BuildContext context, EnhancedVocabulary enhanced) {
    final categoryColor = CategoryColors.getCategoryColor(widget.episode.category);

    showDialog(
      context: context,
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        child: Container(
          constraints: const BoxConstraints(maxWidth: 500, maxHeight: 600),
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Row(
                children: [
                  Icon(
                    Icons.auto_awesome,
                    color: categoryColor,
                    size: 24,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      enhanced.original.vocab,
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: categoryColor,
                      ),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
              const Divider(),
              const SizedBox(height: 16),
              
              // Content
              Expanded(
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Word form and pronunciation
                      if (enhanced.wordForm != null || enhanced.pronunciation != null)
                        Row(
                          children: [
                            if (enhanced.wordForm != null) ...[
                              Chip(
                                label: Text(enhanced.wordForm!),
                                backgroundColor: categoryColor.withOpacity(0.1),
                              ),
                              const SizedBox(width: 8),
                            ],
                            if (enhanced.pronunciation != null)
                              Text(
                                enhanced.pronunciation!,
                                style: TextStyle(
                                  fontSize: 14,
                                  fontStyle: FontStyle.italic,
                                  color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
                                ),
                              ),
                          ],
                        ),
                      if (enhanced.wordForm != null || enhanced.pronunciation != null)
                        const SizedBox(height: 16),
                      
                      // Synonyms
                      if (enhanced.synonyms.isNotEmpty) ...[
                        _buildSection(
                          context,
                          'Synonyms',
                          enhanced.synonyms,
                          categoryColor,
                          Icons.sync_alt,
                        ),
                        const SizedBox(height: 16),
                      ],
                      
                      // Antonyms
                      if (enhanced.antonyms.isNotEmpty) ...[
                        _buildSection(
                          context,
                          'Antonyms',
                          enhanced.antonyms,
                          categoryColor,
                          Icons.swap_horiz,
                        ),
                        const SizedBox(height: 16),
                      ],
                      
                      // Example sentences
                      if (enhanced.exampleSentences.isNotEmpty) ...[
                        _buildSection(
                          context,
                          'Examples',
                          enhanced.exampleSentences,
                          categoryColor,
                          Icons.format_quote,
                        ),
                        const SizedBox(height: 16),
                      ],
                      
                      // Collocations
                      if (enhanced.collocations.isNotEmpty) ...[
                        _buildSection(
                          context,
                          'Collocations',
                          enhanced.collocations,
                          categoryColor,
                          Icons.link,
                        ),
                      ],
                    ],
                  ),
                ),
              ),
              
              const SizedBox(height: 16),
              
              // Close button
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () => Navigator.of(context).pop(),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: categoryColor,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  child: const Text('Close'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSection(
    BuildContext context,
    String title,
    List<String> items,
    Color categoryColor,
    IconData icon,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, color: categoryColor, size: 20),
            const SizedBox(width: 8),
            Text(
              title,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: categoryColor,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        ...items.map((item) => Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: categoryColor.withOpacity(0.05),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  item,
                  style: TextStyle(
                    fontSize: 14,
                    color: Theme.of(context).colorScheme.onSurface,
                  ),
                ),
              ),
            )),
      ],
    );
  }
}