import 'package:flutter/material.dart';

import '../models/daily_goal_config.dart';
import '../services/language_manager.dart';

String difficultyShortLabel(DailyGoalDifficulty difficulty, LanguageManager lm) {
  final key =
      'dailyGoal${difficulty.name[0].toUpperCase()}${difficulty.name.substring(1)}Short';
  return lm.getText(key);
}

String difficultyDescLabel(DailyGoalDifficulty difficulty, LanguageManager lm) {
  final key =
      'dailyGoal${difficulty.name[0].toUpperCase()}${difficulty.name.substring(1)}';
  return lm.getText(key);
}

Future<DailyGoalDifficulty?> showDailyGoalPickerSheet(
  BuildContext context, {
  required DailyGoalDifficulty initial,
}) {
  final lm = LanguageManager();
  return showModalBottomSheet<DailyGoalDifficulty>(
    context: context,
    showDragHandle: true,
    builder: (sheetContext) {
      var current = initial;
      return StatefulBuilder(
        builder: (context, setSheetState) {
          return SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    lm.getText('dailyGoalTitle'),
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                  ),
                  const SizedBox(height: 4),
                  ...DailyGoalDifficulty.values.map((difficulty) {
                    return RadioListTile<DailyGoalDifficulty>(
                      value: difficulty,
                      groupValue: current,
                      contentPadding: EdgeInsets.zero,
                      title: Text(
                        difficultyShortLabel(difficulty, lm),
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),
                      subtitle: Text(
                        difficultyDescLabel(difficulty, lm),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      onChanged: (value) {
                        if (value == null) return;
                        setSheetState(() => current = value);
                      },
                    );
                  }),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () => Navigator.of(sheetContext).pop(),
                          child: Text(lm.getText('cancel')),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: FilledButton(
                          onPressed: () =>
                              Navigator.of(sheetContext).pop(current),
                          child: Text(lm.getText('save')),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          );
        },
      );
    },
  );
}
