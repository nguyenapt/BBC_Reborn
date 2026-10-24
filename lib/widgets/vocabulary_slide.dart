import 'package:flutter/material.dart';
import '../models/episode.dart';
import '../models/vocabulary_item.dart';
import '../utils/category_colors.dart';
import '../services/vocabulary_service.dart';
import '../services/ai_translation_service.dart';
import '../services/ai_vocabulary_service.dart';
import '../services/ai/ai_error_handler.dart';
import '../models/enhanced_vocabulary.dart';
import '../services/language_manager.dart';
import 'native_ad_widget.dart';
import 'learning_checklist_bar.dart';
import 'translation_language_picker.dart';
import 'episode_tab_skeleton.dart';
import 'episode_detail_tab_panel.dart';
import 'heart_economy_ui.dart';

class VocabularySlide extends StatefulWidget {
  final Episode episode;
  /// Đang tải vocab đầy đủ từ RTDB — skeleton thay vì ad/empty.
  final bool isAwaitingFullEpisode;
  final double scrollBottomInset;

  const VocabularySlide({
    super.key,
    required this.episode,
    this.isAwaitingFullEpisode = false,
    this.scrollBottomInset = 0,
  });

  @override
  State<VocabularySlide> createState() => _VocabularySlideState();
}

class _VocabularySlideState extends State<VocabularySlide> {
  late final VocabularyService _vocabularyService;
  final AITranslationService _translationService = AITranslationService();
  final AIVocabularyService _vocabEnhanceService = AIVocabularyService();
  final LanguageManager _languageManager = LanguageManager();
  final Map<String, String> _vocabTranslations = {};
  final Map<String, EnhancedVocabulary?> _enhancedVocab = {};
  bool _showTranslation = false;
  bool _isTranslating = false;
  List<VocabularyItem> _vocabularyItems = [];
  String? _currentTranslationLanguageCode; // Track current translation language

  @override
  void initState() {
    super.initState();
    _vocabularyService = VocabularyService();
    _vocabularyService.initialize();
    
    // Parse vocabulary items từ episode
    _vocabularyItems = VocabularyItem.parseFromEpisode(
      vocabularies: widget.episode.vocabularies,
      vocabulary: widget.episode.vocabulary,
    );
    
    // Listen to language changes to clear translations if needed
    _languageManager.addListener(_onLanguageChanged);
  }
  
  @override
  void dispose() {
    _languageManager.removeListener(_onLanguageChanged);
    super.dispose();
  }
  
  @override
  void didUpdateWidget(VocabularySlide oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.episode.id != widget.episode.id ||
        oldWidget.episode.vocabulary != widget.episode.vocabulary ||
        oldWidget.episode.vocabularies != widget.episode.vocabularies) {
      setState(() {
        _vocabularyItems = VocabularyItem.parseFromEpisode(
          vocabularies: widget.episode.vocabularies,
          vocabulary: widget.episode.vocabulary,
        );
      });
    }
  }

  void _onLanguageChanged() {
    // If language changed and we're showing translations, clear them
    final newLanguageCode = _languageManager.currentLocale.languageCode;
    if (_currentTranslationLanguageCode != null && 
        _currentTranslationLanguageCode != newLanguageCode &&
        _showTranslation) {
      setState(() {
        _vocabTranslations.clear();
        _showTranslation = false;
        _currentTranslationLanguageCode = null;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final vocabularyItems = _vocabularyItems;
    
    // Listen to LanguageManager changes to rebuild when language changes
    return ListenableBuilder(
      listenable: _languageManager,
      builder: (context, child) {
        return _buildVocabularyContent(vocabularyItems);
      },
    );
  }

  Widget _buildVocabularyContent(List<VocabularyItem> vocabularyItems) {
    final categoryColor = CategoryColors.getCategoryColor(widget.episode.category);

    if (widget.isAwaitingFullEpisode && vocabularyItems.isEmpty) {
      return EpisodeDetailTabPanel(
        child: Padding(
          padding: EpisodeDetailTabPanel.scrollPadding(widget.scrollBottomInset),
          child: EpisodeTabSkeleton(accentColor: categoryColor, lineCount: 8),
        ),
      );
    }

    if (vocabularyItems.isEmpty) {
      return EpisodeDetailTabPanel(
        child: Column(
          children: [
            Expanded(
              child: LayoutBuilder(
                builder: (context, constraints) {
                  const margin = 12.0;
                  final w = constraints.maxWidth;
                  final clearance = LearningChecklistBar.adRightClearance;
                  final adWidth =
                      (w - clearance - margin * 2).clamp(0.0, double.infinity);
                  return SingleChildScrollView(
                    padding: EdgeInsets.fromLTRB(
                      margin,
                      margin,
                      clearance + margin,
                      margin,
                    ),
                    child: Align(
                      alignment: Alignment.topCenter,
                      child: SizedBox(
                        width: adWidth,
                        child: NativeAdWidget(
                          category: widget.episode.category,
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
            SizedBox(height: widget.scrollBottomInset),
          ],
        ),
      );
    }

    return EpisodeDetailTabPanel(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(4, 4, 4, 0),
        child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                '${vocabularyItems.length} ${LanguageManager().getText('words')}',
                style: TextStyle(
                  fontSize: 14,
                  color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
                ),
              ),
              const Spacer(),
              IconButton(
                icon: _isTranslating
                    ? SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor: AlwaysStoppedAnimation<Color>(
                            Theme.of(context).colorScheme.primary,
                          ),
                        ),
                      )
                    : Icon(
                        _showTranslation ? Icons.translate : Icons.translate_outlined,
                        color: _showTranslation
                            ? CategoryColors.getCategoryColor(widget.episode.category)
                            : Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
                      ),
                onPressed: _isTranslating
                    ? null
                    : () async {
                        // Check if app language is English (default)
                        if (_languageManager.isTranslationNeeded()) {
                          // If already showing translations, just toggle visibility
                          if (_showTranslation && _vocabTranslations.isNotEmpty) {
                            setState(() {
                              _showTranslation = !_showTranslation;
                            });
                            return;
                          }
                          
                          // Show language picker to select translation language
                          TranslationLanguagePicker.show(
                            context,
                            currentLanguageCode: _currentTranslationLanguageCode ?? _languageManager.currentLocale.languageCode,
                            onLanguageSelected: (languageCode) async {
                              // Save selected language to settings (selected_language key)
                              await _languageManager.changeLanguage(Locale(languageCode));
                              // Clear old translations to force reload with new language
                              setState(() {
                                _vocabTranslations.clear();
                                _showTranslation = false;
                                _currentTranslationLanguageCode = languageCode;
                              });
                              // Load translations with new language
                              await _loadTranslations();
                            },
                          );
                        } else {
                          // App language is not English, translate directly
                          final currentLanguageCode = _languageManager.currentLocale.languageCode;
                          
                          // If language changed or translations are empty, reload
                          if (_currentTranslationLanguageCode != currentLanguageCode || 
                              (!_showTranslation && _vocabTranslations.isEmpty)) {
                            setState(() {
                              _currentTranslationLanguageCode = currentLanguageCode;
                            });
                            // Load translations
                            await _loadTranslations();
                          } else {
                            // Just toggle visibility
                            setState(() {
                              _showTranslation = !_showTranslation;
                            });
                          }
                        }
                      },
                tooltip: _showTranslation ? 'Hide translation' : 'Show translation',
              ),
            ],
          ),
          const SizedBox(height: 4),
          Expanded(
            child: ListenableBuilder(
                listenable: _vocabularyService,
                builder: (context, child) {
                  return ListView.builder(
                    padding: EdgeInsets.only(
                      bottom: widget.scrollBottomInset + 12,
                    ),
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
                                    style: TextStyle(
                                      color: Theme.of(context).colorScheme.onPrimary,
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
                            // Meaning — nhỏ hơn transcript line (14)
                            Text(
                              item.mean,
                              style: TextStyle(
                                fontSize: 13,
                                height: 1.45,
                                color: Theme.of(context).colorScheme.onSurface,
                              ),
                            ),
                            // Translation (only show if enabled)
                            if (_showTranslation && _vocabTranslations.containsKey(item.vocab))
                              Padding(
                                padding: const EdgeInsets.only(top: 6),
                                child: Text(
                                  _vocabTranslations[item.vocab]!,
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontStyle: FontStyle.italic,
                                    color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
                                  ),
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
        ],
        ),
      ),
    );
  }

  Future<void> _loadTranslations() async {
    if (_vocabularyItems.isEmpty) return;
    
    setState(() {
      _isTranslating = true;
    });

    try {
      // Prepare vocabulary list for batch translation
      final vocabularyList = <Map<String, String>>[];
      
      for (final item in _vocabularyItems) {
        if (!_vocabTranslations.containsKey(item.vocab)) {
          vocabularyList.add({
            'word': item.vocab,
            'meaning': item.mean,
            'context': widget.episode.transcript,
          });
        }
      }
      
      // If no words to translate, just show existing translations
      if (vocabularyList.isEmpty) {
        if (mounted) {
          setState(() {
            _showTranslation = true;
            _isTranslating = false;
            _currentTranslationLanguageCode = _languageManager.currentLocale.languageCode;
          });
        }
        return;
      }
      
      // Batch translate all words in one request
      final translations = await _translationService.translateVocabularyBatch(vocabularyList);
      
      // Update translations map
      _vocabTranslations.addAll(translations);

      if (mounted) {
        setState(() {
          _showTranslation = true;
          _isTranslating = false;
          // Update current translation language code
          _currentTranslationLanguageCode = _languageManager.currentLocale.languageCode;
        });
      }
    } catch (e) {
      debugPrint('Error loading translations: $e');
      if (mounted) {
        setState(() {
          _isTranslating = false;
        });
        
        _showErrorSnackBar(context, e, onRetry: () => _loadTranslations());
      }
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
                    Theme.of(context).colorScheme.primary,
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
        episodeId: widget.episode.id,
      );

      _enhancedVocab[item.vocab] = enhanced;

      if (context.mounted) {
        Navigator.of(context).pop(); // Close loading dialog
        _showEnhancedDialog(context, enhanced);
      }
    } catch (e) {
      if (context.mounted) {
        Navigator.of(context).pop(); // Close loading dialog

        _showErrorSnackBar(
          context,
          e,
          onRetry: () => _showEnhancedInfo(context, item),
        );
      }
    }
  }

  void _showEnhancedDialog(BuildContext context, EnhancedVocabulary enhanced) {
    final categoryColor = CategoryColors.getCategoryColor(widget.episode.category);
    final maxW = MediaQuery.of(context).size.width * 0.92;

    showDialog(
      context: context,
      builder: (dialogContext) => Dialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        child: StatefulBuilder(
          builder: (context, setDialogState) {
            return Container(
              constraints: BoxConstraints(
                maxWidth: maxW < 720 ? maxW : 720,
                maxHeight: 640,
              ),
              padding: const EdgeInsets.all(20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
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
                        onPressed: () => Navigator.of(dialogContext).pop(),
                      ),
                    ],
                  ),
                  const Divider(),
                  const SizedBox(height: 16),
                  Expanded(
                    child: SingleChildScrollView(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (enhanced.wordForm != null ||
                              enhanced.pronunciation != null)
                            Wrap(
                              crossAxisAlignment: WrapCrossAlignment.center,
                              spacing: 8,
                              runSpacing: 4,
                              children: [
                                if (enhanced.wordForm != null)
                                  Chip(
                                    label: Text(enhanced.wordForm!),
                                    backgroundColor:
                                        categoryColor.withOpacity(0.1),
                                  ),
                                if (enhanced.pronunciation != null)
                                  Text(
                                    enhanced.pronunciation!,
                                    style: TextStyle(
                                      fontSize: 14,
                                      fontStyle: FontStyle.italic,
                                      color: Theme.of(context)
                                          .colorScheme
                                          .onSurface
                                          .withOpacity(0.6),
                                    ),
                                  ),
                              ],
                            ),
                          if (enhanced.wordForm != null ||
                              enhanced.pronunciation != null)
                            const SizedBox(height: 16),
                          if (enhanced.displaySynonyms.isNotEmpty) ...[
                            _buildTermSection(
                              context,
                              'Synonyms',
                              enhanced.displaySynonyms,
                              categoryColor,
                              Icons.sync_alt,
                              onChanged: () => setDialogState(() {}),
                            ),
                            const SizedBox(height: 16),
                          ],
                          if (enhanced.displayAntonyms.isNotEmpty) ...[
                            _buildTermSection(
                              context,
                              'Antonyms',
                              enhanced.displayAntonyms,
                              categoryColor,
                              Icons.swap_horiz,
                              onChanged: () => setDialogState(() {}),
                            ),
                            const SizedBox(height: 16),
                          ],
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
                          if (enhanced.displayCollocations.isNotEmpty) ...[
                            _buildTermSection(
                              context,
                              'Collocations',
                              enhanced.displayCollocations,
                              categoryColor,
                              Icons.link,
                              onChanged: () => setDialogState(() {}),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: () => Navigator.of(dialogContext).pop(),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: categoryColor,
                        foregroundColor:
                            Theme.of(context).colorScheme.onPrimary,
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
            );
          },
        ),
      ),
    );
  }

  Widget _buildTermSection(
    BuildContext context,
    String title,
    List<VocabTermDetail> items,
    Color categoryColor,
    IconData icon, {
    required VoidCallback onChanged,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, color: categoryColor, size: 20),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                title,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: categoryColor,
                ),
              ),
            ),
            TextButton.icon(
              onPressed: () async {
                await _saveAllTerms(context, items);
                onChanged();
              },
              icon: const Icon(Icons.bookmark_add_outlined, size: 18),
              label: const Text('Save all'),
              style: TextButton.styleFrom(
                foregroundColor: categoryColor,
                visualDensity: VisualDensity.compact,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        ...items.map((item) {
          final isSaved = _vocabularyService.isVocabularySaved(item.word);
          return Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              decoration: BoxDecoration(
                color: categoryColor.withOpacity(0.05),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          item.word,
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: Theme.of(context).colorScheme.onSurface,
                          ),
                        ),
                        if (item.meaning.trim().isNotEmpty) ...[
                          const SizedBox(height: 2),
                          Text(
                            item.meaning,
                            style: TextStyle(
                              fontSize: 13,
                              color: Theme.of(context)
                                  .colorScheme
                                  .onSurface
                                  .withOpacity(0.75),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  IconButton(
                    tooltip: isSaved ? 'Saved' : 'Save',
                    onPressed: () async {
                      await _saveTerm(context, item);
                      onChanged();
                    },
                    icon: Icon(
                      isSaved ? Icons.bookmark : Icons.bookmark_border,
                      size: 20,
                      color: isSaved
                          ? categoryColor
                          : Theme.of(context)
                              .colorScheme
                              .onSurface
                              .withOpacity(0.55),
                    ),
                  ),
                ],
              ),
            ),
          );
        }),
      ],
    );
  }

  Future<void> _saveTerm(BuildContext context, VocabTermDetail term) async {
    final word = term.word.trim();
    if (word.isEmpty) return;

    if (_vocabularyService.isVocabularySaved(word)) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('"$word" already saved'),
          duration: const Duration(seconds: 2),
        ),
      );
      return;
    }

    final item = term.toVocabularyItem(
      bbcEpisodeId: widget.episode.id ?? '',
    );
    final success = await _vocabularyService.saveVocabulary(item);
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          success ? 'Saved "$word" to vocabulary' : '"$word" already saved',
        ),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  Future<void> _saveAllTerms(
    BuildContext context,
    List<VocabTermDetail> terms,
  ) async {
    var saved = 0;
    var skipped = 0;
    for (final term in terms) {
      final word = term.word.trim();
      if (word.isEmpty) continue;
      if (_vocabularyService.isVocabularySaved(word)) {
        skipped++;
        continue;
      }
      final ok = await _vocabularyService.saveVocabulary(
        term.toVocabularyItem(bbcEpisodeId: widget.episode.id ?? ''),
      );
      if (ok) {
        saved++;
      } else {
        skipped++;
      }
    }
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          saved == 0
              ? 'No new words saved ($skipped already saved)'
              : 'Saved $saved word(s)'
                  '${skipped > 0 ? ', skipped $skipped' : ''}',
        ),
        duration: const Duration(seconds: 2),
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

  Future<void> _showErrorSnackBar(
    BuildContext context,
    dynamic error, {
    required VoidCallback onRetry,
  }) async {
    final episodeId = widget.episode.id ?? '';
    final handled = await HeartEconomyUi.handleError(
      context,
      error,
      onRetry: onRetry,
      episodeId: episodeId,
    );
    if (handled || !context.mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(AIErrorHandler.getErrorMessage(error)),
        action: SnackBarAction(
          label: 'Retry',
          onPressed: onRetry,
        ),
      ),
    );
  }
}