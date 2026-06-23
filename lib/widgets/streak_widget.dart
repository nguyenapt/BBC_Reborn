import 'package:flutter/material.dart';
import '../services/learning_progress_service.dart';
import '../services/language_manager.dart';

class StreakWidget extends StatelessWidget {
  const StreakWidget({super.key});

  @override
  Widget build(BuildContext context) {
    final languageManager = LanguageManager();
    return ListenableBuilder(
      listenable: LearningProgressService(),
      builder: (context, child) {
        final streak = LearningProgressService().currentStreak;
        final colorScheme = Theme.of(context).colorScheme;
        return Tooltip(
          message: languageManager.getText('dayStreak'),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: colorScheme.primaryContainer.withOpacity(0.65),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: colorScheme.outlineVariant.withOpacity(0.5),
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.local_fire_department_rounded,
                  size: 18,
                  color: streak > 0
                      ? Colors.deepOrange
                      : colorScheme.onSurface.withOpacity(0.45),
                ),
                const SizedBox(width: 4),
                Text(
                  '$streak',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                    color: colorScheme.onSurface,
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
