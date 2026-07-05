import 'dart:async';

import 'package:flutter/material.dart';

import '../services/daily_goal_service.dart';
import '../services/language_manager.dart';
import '../services/learning_progress_service.dart';

class DailyGoalWidget extends StatefulWidget {
  final VoidCallback? onTap;

  const DailyGoalWidget({super.key, this.onTap});

  @override
  State<DailyGoalWidget> createState() => _DailyGoalWidgetState();
}

class _DailyGoalWidgetState extends State<DailyGoalWidget> {
  final DailyGoalService _goalService = DailyGoalService();
  final LearningProgressService _progressService = LearningProgressService();
  final LanguageManager _languageManager = LanguageManager();

  late final VoidCallback _goalListener;
  late final VoidCallback _progressListener;

  @override
  void initState() {
    super.initState();
    _goalListener = () {
      if (mounted) setState(() {});
    };
    _progressListener = () {
      if (mounted) {
        _goalService.onListeningProgressChanged();
        setState(() {});
      }
    };
    _goalService.addListener(_goalListener);
    _progressService.addListener(_progressListener);
    unawaited(_goalService.initialize());
  }

  @override
  void dispose() {
    _goalService.removeListener(_goalListener);
    _progressService.removeListener(_progressListener);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final targets = _goalService.targets;
    final completed = _goalService.isCompletedToday;
    final progress = _goalService.overallProgress;

    final content = Container(
      margin: const EdgeInsets.fromLTRB(16, 14, 16, 0),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: completed
            ? colorScheme.primaryContainer.withOpacity(0.35)
            : colorScheme.surfaceContainerHighest.withOpacity(0.55),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: completed
              ? colorScheme.primary.withOpacity(0.35)
              : colorScheme.outlineVariant.withOpacity(0.4),
        ),
      ),
      child: Row(
        children: [
          SizedBox(
            width: 52,
            height: 52,
            child: Stack(
              alignment: Alignment.center,
              children: [
                CircularProgressIndicator(
                  value: progress,
                  strokeWidth: 5,
                  backgroundColor: colorScheme.surface.withOpacity(0.5),
                  color: completed ? colorScheme.primary : colorScheme.secondary,
                ),
                Text(
                  completed ? '🎉' : '${(progress * 100).round()}%',
                  style: TextStyle(
                    fontSize: completed ? 18 : 11,
                    fontWeight: FontWeight.w800,
                    color: colorScheme.onSurface,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _languageManager.getText('dailyGoalTitle'),
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  completed
                      ? (_goalService.lastCompletionReward > 0
                          ? _languageManager.getTextWithParams(
                              'dailyGoalCompleted',
                              {'hearts': _goalService.lastCompletionReward},
                            )
                          : _languageManager.getText('dailyGoalCompletedNoReward'))
                      : _languageManager.getTextWithParams(
                          'dailyGoalProgress',
                          {
                            'listen': _goalService.todayListeningMinutes,
                            'listenTarget': targets.listeningMinutes,
                            'vocab': _goalService.todayVocabReviews,
                            'vocabTarget': targets.vocabReviews,
                            'hearts': targets.heartReward,
                          },
                        ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 12,
                    color: colorScheme.onSurface.withOpacity(0.72),
                    height: 1.3,
                  ),
                ),
              ],
            ),
          ),
          if (widget.onTap != null)
            Icon(
              Icons.chevron_right,
              color: colorScheme.onSurface.withOpacity(0.45),
            ),
        ],
      ),
    );

    if (widget.onTap == null) return content;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: widget.onTap,
        borderRadius: BorderRadius.circular(14),
        child: content,
      ),
    );
  }
}
