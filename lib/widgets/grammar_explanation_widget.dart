import 'package:flutter/material.dart';
import '../models/grammar_explanation.dart';
import '../utils/category_colors.dart';

/// Dialog widget for displaying grammar explanation
class GrammarExplanationDialog extends StatelessWidget {
  final GrammarExplanation explanation;
  final String? category;

  const GrammarExplanationDialog({
    super.key,
    required this.explanation,
    this.category,
  });

  @override
  Widget build(BuildContext context) {
    final categoryColor = category != null
        ? CategoryColors.getCategoryColor(category!)
        : Theme.of(context).colorScheme.primary;

    return Dialog(
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
                  Icons.lightbulb,
                  color: categoryColor,
                  size: 24,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Grammar Explanation',
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
            
            // Grammar Point
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
                  Icon(
                    Icons.school,
                    color: categoryColor,
                    size: 20,
                  ),
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
            const SizedBox(height: 16),
            
            // Sentence with highlighted words
            Text(
              'Sentence:',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: Theme.of(context).colorScheme.onSurface.withOpacity(0.7),
              ),
            ),
            const SizedBox(height: 8),
            _buildHighlightedSentence(context, categoryColor),
            const SizedBox(height: 16),
            
            // Explanation
            Text(
              'Explanation:',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: Theme.of(context).colorScheme.onSurface.withOpacity(0.7),
              ),
            ),
            const SizedBox(height: 8),
            Expanded(
              child: SingleChildScrollView(
                child: Text(
                  explanation.explanation,
                  style: TextStyle(
                    fontSize: 15,
                    height: 1.6,
                    color: Theme.of(context).colorScheme.onSurface,
                  ),
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
    );
  }

  Widget _buildHighlightedSentence(BuildContext context, Color highlightColor) {
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

    // Build text spans with highlights
    String sentence = explanation.sentence;
    final spans = <TextSpan>[];
    int lastIndex = 0;

    // Find and highlight words
    for (final word in explanation.highlightedWords) {
      final index = sentence.toLowerCase().indexOf(word.toLowerCase(), lastIndex);
      if (index != -1) {
        // Add text before highlight
        if (index > lastIndex) {
          spans.add(TextSpan(
            text: sentence.substring(lastIndex, index),
            style: TextStyle(
              fontSize: 15,
              fontStyle: FontStyle.italic,
              color: Theme.of(context).colorScheme.onSurface,
            ),
          ));
        }

        // Add highlighted word
        spans.add(TextSpan(
          text: sentence.substring(index, index + word.length),
          style: TextStyle(
            fontSize: 15,
            fontStyle: FontStyle.italic,
            fontWeight: FontWeight.bold,
            color: highlightColor,
            backgroundColor: highlightColor.withOpacity(0.1),
          ),
        ));

        lastIndex = index + word.length;
      }
    }

    // Add remaining text
    if (lastIndex < sentence.length) {
      spans.add(TextSpan(
        text: sentence.substring(lastIndex),
        style: TextStyle(
          fontSize: 15,
          fontStyle: FontStyle.italic,
          color: Theme.of(context).colorScheme.onSurface,
        ),
      ));
    }

    return RichText(
      text: TextSpan(children: spans),
    );
  }
}

