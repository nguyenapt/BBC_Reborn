import 'package:flutter/material.dart';

import '../services/daily_goal_service.dart';
import '../services/language_manager.dart';
import 'daily_goal_picker_sheet.dart';

/// Mục tiêu hôm nay — tile cuối tab Hôm nay (My Hub), mở sheet chọn mức.
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
    final selected = await showDailyGoalPickerSheet(
      context,
      initial: _goalService.difficulty,
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
        subtitle: Text(
          '${difficultyShortLabel(current, _languageManager)} · ${_languageManager.getTextWithParams('dailyGoalRewardShort', {'hearts': _goalService.targets.heartReward})}',
        ),
        trailing: Icon(
          Icons.tune_rounded,
          color: colorScheme.onSurface.withOpacity(0.55),
        ),
        onTap: _showGoalPicker,
      ),
    );
  }
}
