import 'package:flutter/material.dart';
import '../models/episode.dart';
import '../models/speaking_feedback.dart';
import '../services/language_manager.dart';
import '../utils/category_colors.dart';

/// Màn phân tích AI sau khi hoàn tất ghi âm — màu nền & accent theo category + Theme.
class SpeakingAiAnalysisScreen extends StatelessWidget {
  final Episode episode;
  final SpeakingFeedback feedback;
  final String? recognizedText;

  const SpeakingAiAnalysisScreen({
    super.key,
    required this.episode,
    required this.feedback,
    this.recognizedText,
  });

  static int _scorePercent(double raw) {
    final v = raw.clamp(0, 100);
    return v.round();
  }

  String _fluencyLabel(LanguageManager lm, double score) {
    final s = score.clamp(0, 100);
    if (s >= 85) return lm.getText('speakingAiFluencyExcellent');
    if (s >= 70) return lm.getText('speakingAiFluencyGood');
    if (s >= 55) return lm.getText('speakingAiFluencyFair');
    return lm.getText('speakingAiFluencyNeedsWork');
  }

  List<String> _focusTags(LanguageManager lm) {
    final tags = feedback.mistakes
        .map((m) => m.expected.trim())
        .where((s) => s.isNotEmpty)
        .take(4)
        .toList();
    if (tags.isEmpty) {
      return [lm.getText('speakingAiFocusFallbackTag')];
    }
    return tags;
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: LanguageManager(),
      builder: (context, _) {
        final lm = LanguageManager();
        final theme = Theme.of(context);
        final cs = theme.colorScheme;
        final categoryColor = CategoryColors.getCategoryColor(episode.category);
        final categoryBg = CategoryColors.getCategoryBackgroundColor(episode.category);

        final screenBg = Color.lerp(categoryBg, cs.surface, 0.42)!;
        final pronunciation = _scorePercent(feedback.pronunciationScore);
        final fluencyPct = _scorePercent(feedback.fluencyScore);
        final fluencyTitle = _fluencyLabel(lm, feedback.fluencyScore);
        final fluencyHeading = lm.getTextWithParams(
          'speakingAiFluencyWithLevel',
          {'level': fluencyTitle},
        );
        final feedbackBody = feedback.feedback.isNotEmpty
            ? feedback.feedback
            : lm.getTextWithParams('speakingAiFluencyFallback', {'percent': '$fluencyPct'});
        final overallLine = lm.getTextWithParams('speakingAiOverallAccuracy', {
          'overall': feedback.overallScore.toStringAsFixed(0),
          'accuracy': '${_scorePercent(feedback.accuracyScore)}',
        });

        return Scaffold(
          backgroundColor: screenBg,
          appBar: AppBar(
            backgroundColor: CategoryColors.getCategoryColor(episode.category),
            foregroundColor: Colors.white,
            elevation: 0,
            title: Text(lm.getText('speakingAiAnalysisTitle')),
            leading: IconButton(
              icon: const Icon(Icons.close),
              onPressed: () => Navigator.of(context).pop(),
            ),
          ),
          body: SafeArea(
            top: false,
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 24),
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: Color.lerp(categoryBg, cs.surface, 0.55),
                  borderRadius: BorderRadius.circular(24),
                  boxShadow: [
                    BoxShadow(
                      color: cs.shadow.withValues(alpha: 0.08),
                      blurRadius: 20,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 20, 20, 22),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              lm.getText('speakingAiAnalysisTitle'),
                              style: theme.textTheme.titleLarge?.copyWith(
                                fontWeight: FontWeight.bold,
                                color: cs.onSurface,
                              ),
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                            decoration: BoxDecoration(
                              color: Color.lerp(
                                    CategoryColors.getCategoryBackgroundColor(episode.category),
                                    cs.tertiaryContainer,
                                    0.5,
                                  ) ??
                                  cs.tertiaryContainer,
                              borderRadius: BorderRadius.circular(999),
                            ),
                            child: Text(
                              lm.getText('speakingAiRealtimeBadge'),
                              style: theme.textTheme.labelSmall?.copyWith(
                                fontWeight: FontWeight.w700,
                                color: cs.onTertiaryContainer,
                                letterSpacing: 0.6,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 22),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.baseline,
                        textBaseline: TextBaseline.alphabetic,
                        children: [
                          Expanded(
                            child: Text(
                              lm.getText('speakingAiPronunciation'),
                              style: theme.textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.bold,
                                color: cs.onSurface,
                              ),
                            ),
                          ),
                          Text(
                            '$pronunciation%',
                            style: theme.textTheme.headlineSmall?.copyWith(
                              fontWeight: FontWeight.bold,
                              color: categoryColor.withValues(alpha: 0.95),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(999),
                        child: LinearProgressIndicator(
                          value: pronunciation / 100.0,
                          minHeight: 10,
                          backgroundColor: cs.surfaceContainerHighest.withValues(alpha: 0.85),
                          valueColor: AlwaysStoppedAnimation<Color>(
                            categoryColor,
                          ),
                        ),
                      ),
                      if (recognizedText != null && recognizedText!.trim().isNotEmpty) ...[
                        const SizedBox(height: 14),
                        Text(
                          lm.getTextWithParams(
                            'speakingAiYouSaidLine',
                            {'line': recognizedText!.trim()},
                          ),
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: cs.onSurfaceVariant,
                          ),
                        ),
                      ],
                      const SizedBox(height: 20),
                      DecoratedBox(
                        decoration: BoxDecoration(
                          color: cs.surface,
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Container(
                                width: 48,
                                height: 48,
                                decoration: BoxDecoration(
                                  color: Color.lerp(categoryBg, cs.primaryContainer, 0.4),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Icon(
                                  Icons.auto_awesome_rounded,
                                  color: categoryColor,
                                  size: 26,
                                ),
                              ),
                              const SizedBox(width: 14),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      fluencyHeading,
                                      style: theme.textTheme.titleSmall?.copyWith(
                                        fontWeight: FontWeight.bold,
                                        color: cs.onSurface,
                                      ),
                                    ),
                                    const SizedBox(height: 6),
                                    Text(
                                      feedbackBody,
                                      style: theme.textTheme.bodyMedium?.copyWith(
                                        color: cs.onSurfaceVariant,
                                        height: 1.35,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 22),
                      Text(
                        lm.getText('speakingAiFocusArea'),
                        style: theme.textTheme.labelMedium?.copyWith(
                          fontWeight: FontWeight.w800,
                          color: categoryColor.withValues(alpha: 0.9),
                          letterSpacing: 0.8,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: _focusTags(lm).map((tag) {
                          return Material(
                            color: cs.surface,
                            elevation: 0,
                            borderRadius: BorderRadius.circular(999),
                            child: Padding(
                              padding:
                                  const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                              child: Text(
                                tag.length > 32 ? '${tag.substring(0, 29)}…' : tag,
                                style: theme.textTheme.labelLarge?.copyWith(
                                  color: cs.onSurface,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          );
                        }).toList(),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        overallLine,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: cs.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
