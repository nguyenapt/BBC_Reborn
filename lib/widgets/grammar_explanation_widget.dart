import 'package:flutter/material.dart';
import '../models/grammar_explanation.dart';
import '../services/language_manager.dart';
import 'transcript_native_ad_widget.dart';

/// Dialog widget for displaying grammar explanation
class GrammarExplanationDialog extends StatefulWidget {
  final GrammarExplanation explanation;
  final Future<GrammarExplanation>? progressiveUpdate;
  final String? category;
  final bool isSaved;
  final VoidCallback? onToggleSaved;
  final VoidCallback? onOpenEpisode;
  final void Function(bool isCorrect)? onQuizChecked;

  const GrammarExplanationDialog({
    super.key,
    required this.explanation,
    this.progressiveUpdate,
    this.category,
    this.isSaved = false,
    this.onToggleSaved,
    this.onOpenEpisode,
    this.onQuizChecked,
  });

  @override
  State<GrammarExplanationDialog> createState() => _GrammarExplanationDialogState();
}

class _GrammarExplanationDialogState extends State<GrammarExplanationDialog> {
  final LanguageManager _languageManager = LanguageManager();
  String? _selectedQuizOption;
  bool _quizSubmitted = false;
  late GrammarExplanation _explanation;
  bool _isUpdating = false;

  @override
  Widget build(BuildContext context) {
    final categoryColor = Theme.of(context).colorScheme.primary;
    final explanation = _explanation;

    return Dialog.fullscreen(
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
            Row(
              children: [
                Icon(Icons.lightbulb, color: categoryColor, size: 24),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    _languageManager.getText('grammarExplanationTitle'),
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
            Expanded(
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(
                        color: categoryColor.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: categoryColor.withOpacity(0.3),
                          width: 1,
                        ),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.school, color: categoryColor, size: 20),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              explanation.grammarPoint,
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: categoryColor,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 14),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        if (widget.onToggleSaved != null)
                          OutlinedButton.icon(
                            onPressed: widget.onToggleSaved,
                            icon: Icon(
                              widget.isSaved ? Icons.bookmark : Icons.bookmark_border,
                              size: 18,
                            ),
                            label: Text(
                              widget.isSaved
                                  ? _languageManager.getText('saved')
                                  : _languageManager.getText('save'),
                            ),
                          ),
                        if (widget.onOpenEpisode != null)
                          OutlinedButton.icon(
                            onPressed: widget.onOpenEpisode,
                            icon: const Icon(Icons.open_in_new, size: 18),
                            label: Text(_languageManager.getText('openEpisode')),
                          ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    if (explanation.isPassageMode) ...[
                      _buildPassageOverview(context, explanation),
                      const SizedBox(height: 12),
                      TranscriptNativeAdWidget(
                        category: widget.category ?? 'grammar',
                      ),
                      const SizedBox(height: 12),
                    ],
                    if (_isUpdating) ...[
                      Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: Row(
                          children: [
                            SizedBox(
                              width: 14,
                              height: 14,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              'Loading sentence details…',
                              style: TextStyle(
                                color: Theme.of(context)
                                    .colorScheme
                                    .onSurface
                                    .withOpacity(0.7),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                    Text(
                      _languageManager.getText('sentenceLabel'),
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: Theme.of(context).colorScheme.onSurface.withOpacity(0.7),
                      ),
                    ),
                    const SizedBox(height: 8),
                    _buildHighlightedSentence(context, categoryColor),
                    if (explanation.rulePattern != null &&
                        explanation.rulePattern!.trim().isNotEmpty) ...[
                      const SizedBox(height: 12),
                      Text(
                        '${_languageManager.getText('rulePatternLabel')}: ${explanation.rulePattern!}',
                        style: TextStyle(
                          fontSize: 14,
                          color: Theme.of(context).colorScheme.onSurface.withOpacity(0.92),
                        ),
                      ),
                    ],
                    const SizedBox(height: 14),
                    Text(
                      _languageManager.getText('explanationLabel'),
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: Theme.of(context).colorScheme.onSurface.withOpacity(0.7),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      explanation.explanation,
                      style: TextStyle(
                        fontSize: 15,
                        height: 1.6,
                        color: Theme.of(context).colorScheme.onSurface,
                      ),
                    ),
                    if (explanation.whyThisForm != null &&
                        explanation.whyThisForm!.trim().isNotEmpty) ...[
                      const SizedBox(height: 12),
                      Text(
                        _languageManager.getText('whyThisFormLabel'),
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: Theme.of(context).colorScheme.onSurface.withOpacity(0.8),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        explanation.whyThisForm!,
                        style: TextStyle(
                          fontSize: 14,
                          height: 1.45,
                          color: Theme.of(context).colorScheme.onSurface.withOpacity(0.92),
                        ),
                      ),
                    ],
                    if (explanation.commonMistakes.isNotEmpty) ...[
                      const SizedBox(height: 12),
                      Text(
                        _languageManager.getText('commonMistakesLabel'),
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: Theme.of(context).colorScheme.onSurface.withOpacity(0.8),
                        ),
                      ),
                      const SizedBox(height: 4),
                      ...explanation.commonMistakes.map(
                        (mistake) => Padding(
                          padding: const EdgeInsets.only(bottom: 4),
                          child: Text(
                            '- $mistake',
                            style: TextStyle(
                              fontSize: 14,
                              color: Theme.of(context).colorScheme.onSurface.withOpacity(0.92),
                            ),
                          ),
                        ),
                      ),
                    ],
                    if (explanation.miniQuiz != null) ...[
                      const SizedBox(height: 12),
                      _buildMiniQuiz(context, explanation.miniQuiz!),
                    ],
                    const SizedBox(height: 12),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () => Navigator.of(context).pop(),
                style: ElevatedButton.styleFrom(
                  backgroundColor: categoryColor,
                  foregroundColor: Theme.of(context).colorScheme.onPrimary,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                child: Text(_languageManager.getText('close')),
              ),
            ),
          ],
          ),
        ),
      ),
    );
  }

  Widget _buildMiniQuiz(BuildContext context, GrammarMiniQuiz quiz) {
    final isCorrect = _isQuizAnswerCorrect(_selectedQuizOption, quiz);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(10),
        color: Theme.of(context).colorScheme.surfaceContainerHighest.withOpacity(0.4),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            _languageManager.getText('quickQuizLabel'),
            style: TextStyle(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 6),
          Text(quiz.question),
          const SizedBox(height: 8),
          ...quiz.options.map(
            (option) => RadioListTile<String>(
              value: option,
              groupValue: _selectedQuizOption,
              dense: true,
              contentPadding: EdgeInsets.zero,
              title: Text(option),
              onChanged: (value) {
                setState(() {
                  _selectedQuizOption = value;
                  _quizSubmitted = false;
                });
              },
            ),
          ),
          ElevatedButton(
            onPressed: _selectedQuizOption == null
                ? null
                : () {
                    final currentIsCorrect =
                        _isQuizAnswerCorrect(_selectedQuizOption, quiz);
                    setState(() {
                      _quizSubmitted = true;
                    });
                    widget.onQuizChecked?.call(currentIsCorrect);
                  },
            child: Text(_languageManager.getText('checkLabel')),
          ),
          if (_quizSubmitted) ...[
            const SizedBox(height: 6),
            Text(
              isCorrect
                  ? _languageManager.getText('quizCorrect')
                  : _languageManager.getText('quizTryAgain'),
              style: TextStyle(
                color: isCorrect ? Colors.green : Theme.of(context).colorScheme.error,
                fontWeight: FontWeight.w700,
              ),
            ),
            if (quiz.explanation.trim().isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(
                  quiz.explanation,
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.onSurface.withOpacity(0.85),
                  ),
                ),
              ),
          ],
        ],
      ),
    );
  }

  Widget _buildPassageOverview(BuildContext context, GrammarExplanation explanation) {
    final overall = explanation.overall;
    if (overall == null) {
      return const SizedBox.shrink();
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(10),
        color: Theme.of(context).colorScheme.surfaceContainerHighest.withOpacity(0.35),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Overall grammar for this passage',
            style: TextStyle(
              fontWeight: FontWeight.w700,
              color: Theme.of(context).colorScheme.onSurface,
            ),
          ),
          const SizedBox(height: 6),
          Text(overall.grammarTheme, style: const TextStyle(fontWeight: FontWeight.w600)),
          if (overall.usageSummary.trim().isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(overall.usageSummary),
          ],
          if (overall.keyStructures.isNotEmpty) ...[
            const SizedBox(height: 6),
            ...overall.keyStructures.map((e) => Text('- $e')),
          ],
          if (explanation.sentenceAnalyses.isNotEmpty) ...[
            const SizedBox(height: 8),
            ...explanation.sentenceAnalyses.asMap().entries.map(
              (entry) => ExpansionTile(
                tilePadding: EdgeInsets.zero,
                childrenPadding: const EdgeInsets.only(bottom: 6),
                title: Text(
                  'Sentence ${entry.key + 1}: ${entry.value.sentenceText}',
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                ),
                children: [
                  _buildAnalysisDetails(context, entry.value),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  @override
  void initState() {
    super.initState();
    _explanation = widget.explanation;

    final future = widget.progressiveUpdate;
    if (future != null) {
      _isUpdating = true;
      future.then((updated) {
        if (!mounted) return;
        setState(() {
          _explanation = updated;
          _isUpdating = false;
        });
      }).catchError((_) {
        if (!mounted) return;
        setState(() {
          _isUpdating = false;
        });
      });
    }
  }

  bool _isQuizAnswerCorrect(String? selectedOption, GrammarMiniQuiz quiz) {
    if (selectedOption == null) return false;
    final selected = selectedOption.trim();
    final correctRaw = quiz.correctAnswer.trim();
    if (selected.isEmpty || correctRaw.isEmpty) return false;

    // Case 1: Provider returns full option text ("B. Hi")
    if (_normalizeOptionText(selected) == _normalizeOptionText(correctRaw)) {
      return true;
    }

    // Case 2: Provider returns option key only ("B")
    final correctKey = _extractOptionKey(correctRaw);
    if (correctKey != null) {
      final selectedKey = _extractOptionKey(selected);
      if (selectedKey != null) {
        return selectedKey == correctKey;
      }

      // Case 3: selected text without key, fallback by option position
      final selectedIndex = quiz.options.indexWhere(
        (option) => _normalizeOptionText(option) == _normalizeOptionText(selected),
      );
      if (selectedIndex >= 0) {
        const alphabet = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ';
        if (selectedIndex < alphabet.length) {
          return alphabet[selectedIndex] == correctKey;
        }
      }
    }

    return false;
  }

  String _normalizeOptionText(String text) {
    return text.trim().toLowerCase().replaceAll(RegExp(r'\s+'), ' ');
  }

  String? _extractOptionKey(String value) {
    final match = RegExp(r'^\s*([A-Da-d])(?:[\.\):\-\s]|$)').firstMatch(value);
    if (match == null) return null;
    return match.group(1)?.toUpperCase();
  }

  Widget _buildAnalysisDetails(BuildContext context, GrammarSentenceAnalysis analysis) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (analysis.mainStructure.trim().isNotEmpty) Text('Structure: ${analysis.mainStructure}'),
        if (analysis.usageInContext.trim().isNotEmpty) ...[
          const SizedBox(height: 4),
          Text('Usage: ${analysis.usageInContext}'),
        ],
        if (analysis.phraseBreakdown.isNotEmpty) ...[
          const SizedBox(height: 4),
          const Text('Phrase breakdown:', style: TextStyle(fontWeight: FontWeight.w600)),
          ...analysis.phraseBreakdown.map(
            (phrase) => Text('- ${phrase.phrase}: ${phrase.usage}'),
          ),
        ],
        if (analysis.examples.isNotEmpty) ...[
          const SizedBox(height: 4),
          const Text('Examples:', style: TextStyle(fontWeight: FontWeight.w600)),
          ...analysis.examples.map((e) => Text('- $e')),
        ],
        if (analysis.commonMistakes.isNotEmpty) ...[
          const SizedBox(height: 4),
          const Text('Mistakes:', style: TextStyle(fontWeight: FontWeight.w600)),
          ...analysis.commonMistakes.map((e) => Text('- $e')),
        ],
        if ((analysis.rewriteExercise ?? '').trim().isNotEmpty) ...[
          const SizedBox(height: 4),
          Text('Rewrite: ${analysis.rewriteExercise}'),
        ],
      ],
    );
  }

  Widget _buildHighlightedSentence(BuildContext context, Color highlightColor) {
    final explanation = widget.explanation;
    if (explanation.highlightedWords.isEmpty) {
      return Text(
        explanation.sentence,
        style: TextStyle(
          fontSize: 15,
          fontStyle: FontStyle.italic,
          color: Theme.of(context).colorScheme.onSurface,
        ),
      );
    }

    final sentence = explanation.sentence;
    final spans = <TextSpan>[];
    var lastIndex = 0;

    for (final word in explanation.highlightedWords) {
      final index = sentence.toLowerCase().indexOf(word.toLowerCase(), lastIndex);
      if (index != -1) {
        if (index > lastIndex) {
          spans.add(
            TextSpan(
              text: sentence.substring(lastIndex, index),
              style: TextStyle(
                fontSize: 15,
                fontStyle: FontStyle.italic,
                color: Theme.of(context).colorScheme.onSurface,
              ),
            ),
          );
        }
        spans.add(
          TextSpan(
            text: sentence.substring(index, index + word.length),
            style: TextStyle(
              fontSize: 15,
              fontStyle: FontStyle.italic,
              fontWeight: FontWeight.bold,
              color: highlightColor,
              backgroundColor: highlightColor.withOpacity(0.1),
            ),
          ),
        );
        lastIndex = index + word.length;
      }
    }

    if (lastIndex < sentence.length) {
      spans.add(
        TextSpan(
          text: sentence.substring(lastIndex),
          style: TextStyle(
            fontSize: 15,
            fontStyle: FontStyle.italic,
            color: Theme.of(context).colorScheme.onSurface,
          ),
        ),
      );
    }

    return RichText(text: TextSpan(children: spans));
  }
}

