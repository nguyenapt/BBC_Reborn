import 'package:flutter/material.dart';

import '../services/language_manager.dart';
import '../services/learning_progress_service.dart';

class StreakSlidePanel extends StatelessWidget {
  const StreakSlidePanel({super.key});

  static int _minutesFromMs(int ms) => (ms / 60000).floor();

  @override
  Widget build(BuildContext context) {
    final lm = LanguageManager();
    final thresholdMin =
        LearningProgressService.activeListeningThresholdMs ~/ 60000;

    return ListenableBuilder(
      listenable: LearningProgressService(),
      builder: (context, child) {
        final progress = LearningProgressService();
        final streak = progress.currentStreak;
        final longest = progress.longestStreak;
        final activeToday = progress.isActiveToday;
        final listenedMin = _minutesFromMs(progress.todayListeningMs);
        final listenProgress = (progress.todayListeningMs /
                LearningProgressService.activeListeningThresholdMs)
            .clamp(0.0, 1.0);

        return SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.local_fire_department_rounded,
                    size: 36,
                    color: streak > 0
                        ? Colors.deepOrange
                        : Colors.grey.shade400,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    '$streak',
                    style: const TextStyle(
                      fontSize: 32,
                      fontWeight: FontWeight.w900,
                      height: 1,
                    ),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    lm.getText('dayStreak'),
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: Colors.grey.shade700,
                    ),
                  ),
                ],
              ),
              if (longest > 0) ...[
                const SizedBox(height: 6),
                Text(
                  lm.getTextWithParams('streakPanelLongest', {
                    'count': '$longest',
                  }),
                  style: TextStyle(
                    fontSize: 13,
                    color: Colors.grey.shade600,
                  ),
                ),
              ],
              const SizedBox(height: 20),
              Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  lm.getText('streakPanelHowTo'),
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              const SizedBox(height: 12),
              _RuleTile(
                icon: Icons.headphones_rounded,
                text: lm.getTextWithParams('streakPanelListenRule', {
                  'minutes': '$thresholdMin',
                }),
              ),
              _RuleTile(
                icon: Icons.translate_rounded,
                text: lm.getText('streakPanelVocabRule'),
              ),
              _RuleTile(
                icon: Icons.menu_book_rounded,
                text: lm.getText('streakPanelGrammarRule'),
              ),
              _RuleTile(
                icon: Icons.mic_rounded,
                text: lm.getText('streakPanelSpeakingRule'),
              ),
              const SizedBox(height: 16),
              if (!activeToday) ...[
                Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    lm.getTextWithParams('streakPanelListeningProgress', {
                      'current': '$listenedMin',
                      'target': '$thresholdMin',
                    }),
                    style: TextStyle(
                      fontSize: 13,
                      color: Colors.grey.shade700,
                    ),
                  ),
                ),
                const SizedBox(height: 6),
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: listenProgress,
                    minHeight: 6,
                    backgroundColor: Colors.orange.shade50,
                    valueColor: AlwaysStoppedAnimation(Colors.deepOrange.shade400),
                  ),
                ),
                const SizedBox(height: 12),
              ],
              Container(
                width: double.infinity,
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: BoxDecoration(
                  color: activeToday
                      ? Colors.green.shade50
                      : Colors.orange.shade50,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: activeToday
                        ? Colors.green.shade200
                        : Colors.orange.shade200,
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      activeToday
                          ? Icons.check_circle_rounded
                          : Icons.info_outline_rounded,
                      size: 20,
                      color: activeToday
                          ? Colors.green.shade700
                          : Colors.orange.shade800,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        activeToday
                            ? lm.getText('streakPanelCountedToday')
                            : lm.getText('streakPanelNotYet'),
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: activeToday
                              ? Colors.green.shade800
                              : Colors.orange.shade900,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _RuleTile extends StatelessWidget {
  final IconData icon;
  final String text;

  const _RuleTile({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 20, color: Colors.deepOrange.shade400),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                fontSize: 14,
                height: 1.35,
                color: Colors.grey.shade800,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
