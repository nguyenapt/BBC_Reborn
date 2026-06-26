import 'package:flutter/material.dart';

import '../models/daily_goal_config.dart';
import '../services/daily_goal_service.dart';
import '../services/language_manager.dart';

String difficultyLabel(DailyGoalDifficulty difficulty, LanguageManager lm) {
  final key =
      'dailyGoal${difficulty.name[0].toUpperCase()}${difficulty.name.substring(1)}';
  return lm.getText(key);
}

String difficultyShortLabel(DailyGoalDifficulty difficulty, LanguageManager lm) {
  final key =
      'dailyGoal${difficulty.name[0].toUpperCase()}${difficulty.name.substring(1)}Short';
  return lm.getText(key);
}

/// Mục tiêu hôm nay — tile cuối tab Hôm nay (My Hub), mở popup chọn mức.
class DailyGoalSettingsTile extends StatefulWidget {
  const DailyGoalSettingsTile({super.key});

  @override
  State<DailyGoalSettingsTile> createState() => _DailyGoalSettingsTileState();
}

class _DailyGoalSettingsTileState extends State<DailyGoalSettingsTile> {
  final DailyGoalService _goalService = DailyGoalService();
  final LanguageManager _languageManager = LanguageManager();
  late final VoidCallback _listener;

  @override
  void initState() {
    super.initState();
    _listener = () {
      if (mounted) setState(() {});
    };
    _goalService.addListener(_listener);
  }

  @override
  void dispose() {
    _goalService.removeListener(_listener);
    super.dispose();
  }

  Future<void> _showGoalPicker() async {
    final selected = await showDialog<DailyGoalDifficulty>(
      context: context,
      builder: (dialogContext) {
        var current = _goalService.difficulty;
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: Text(_languageManager.getText('dailyGoalTitle')),
              content: SizedBox(
                width: double.maxFinite,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: DailyGoalDifficulty.values.map((difficulty) {
                    return RadioListTile<DailyGoalDifficulty>(
                      value: difficulty,
                      groupValue: current,
                      title: Text(difficultyShortLabel(difficulty, _languageManager)),
                      subtitle: Text(
                        difficultyLabel(difficulty, _languageManager),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      onChanged: (value) {
                        if (value == null) return;
                        setDialogState(() => current = value);
                      },
                    );
                  }).toList(),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(dialogContext).pop(),
                  child: Text(_languageManager.getText('cancel')),
                ),
                FilledButton(
                  onPressed: () => Navigator.of(dialogContext).pop(current),
                  child: Text(_languageManager.getText('save')),
                ),
              ],
            );
          },
        );
      },
    );

    if (selected == null || !mounted) return;
    await _goalService.setDifficulty(selected);
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final current = _goalService.difficulty;

    return Card(
      margin: const EdgeInsets.fromLTRB(8, 12, 8, 4),
      child: ListTile(
        leading: Icon(Icons.flag_outlined, color: colorScheme.primary),
        title: Text(
          _languageManager.getText('dailyGoalTitle'),
          style: const TextStyle(fontWeight: FontWeight.w700),
        ),
        subtitle: Text(difficultyShortLabel(current, _languageManager)),
        trailing: Icon(
          Icons.tune_rounded,
          color: colorScheme.onSurface.withOpacity(0.55),
        ),
        onTap: _showGoalPicker,
      ),
    );
  }
}
