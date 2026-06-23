import 'package:flutter/material.dart';
import '../models/episode_learning_progress.dart';
import '../services/language_manager.dart';

class LearningChecklistBar extends StatelessWidget {
  final EpisodeLearningProgress? progress;

  const LearningChecklistBar({super.key, this.progress});

  @override
  Widget build(BuildContext context) {
    final lm = LanguageManager();
    final colorScheme = Theme.of(context).colorScheme;
    final p = progress;
    final steps = [
      _Step(
        done: p?.listenedComplete == true || (p?.listenProgressRatio ?? 0) >= 0.85,
        label: lm.getText('checklistListen'),
      ),
      _Step(done: p?.transcriptViewed == true, label: lm.getText('checklistTranscript')),
      _Step(done: p?.vocabViewed == true, label: lm.getText('checklistVocab')),
      _Step(
        done: p?.questionsViewed == true || p?.speakingDone == true,
        label: lm.getText('checklistPractice'),
      ),
    ];

    return Container(
      margin: const EdgeInsets.fromLTRB(12, 0, 12, 8),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest.withOpacity(0.45),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: colorScheme.outlineVariant.withOpacity(0.4)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                lm.getText('learningProgress'),
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: colorScheme.onSurface.withOpacity(0.85),
                ),
              ),
              const Spacer(),
              Text(
                '${p?.checklistCompletedCount ?? 0}/${EpisodeLearningProgress.checklistTotal}',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: colorScheme.primary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              for (int i = 0; i < steps.length; i++) ...[
                if (i > 0) const SizedBox(width: 6),
                Expanded(
                  child: _ChecklistChip(step: steps[i]),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }
}

class _Step {
  final bool done;
  final String label;
  const _Step({required this.done, required this.label});
}

class _ChecklistChip extends StatelessWidget {
  final _Step step;
  const _ChecklistChip({required this.step});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 6),
      decoration: BoxDecoration(
        color: step.done
            ? colorScheme.primary.withOpacity(0.12)
            : colorScheme.surface,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: step.done
              ? colorScheme.primary.withOpacity(0.45)
              : colorScheme.outlineVariant.withOpacity(0.45),
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            step.done ? Icons.check_circle_rounded : Icons.radio_button_unchecked,
            size: 14,
            color: step.done
                ? colorScheme.primary
                : colorScheme.onSurface.withOpacity(0.4),
          ),
          const SizedBox(width: 4),
          Flexible(
            child: Text(
              step.label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w600,
                color: colorScheme.onSurface.withOpacity(step.done ? 0.9 : 0.55),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
