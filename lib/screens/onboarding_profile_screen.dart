import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../main.dart';
import '../models/daily_goal_config.dart';
import '../models/episode.dart';
import '../models/user_learning_profile.dart';
import '../services/local_database_service.dart';
import '../services/language_manager.dart';
import '../services/user_profile_service.dart';
import 'ads_support_notice_screen.dart';

class OnboardingProfileScreen extends StatefulWidget {
  const OnboardingProfileScreen({super.key});

  @override
  State<OnboardingProfileScreen> createState() =>
      _OnboardingProfileScreenState();
}

class _OnboardingProfileScreenState extends State<OnboardingProfileScreen> {
  static const String _adsNoticeSeenKey = 'ads_notice_seen_v1';

  final LanguageManager _languageManager = LanguageManager();
  final LocalDatabaseService _databaseService = LocalDatabaseService();
  final UserProfileService _profileService = UserProfileService();

  EnglishLevel _level = EnglishLevel.intermediate;
  LearningFocus _focus = LearningFocus.listening;
  bool _isSaving = false;

  Future<void> _continue() async {
    if (_isSaving) return;
    setState(() => _isSaving = true);

    try {
      String? recommendedId;
      try {
        final year = DateTime.now().year;
        var episodes =
            await _databaseService.getEpisodesByCategoryYear('6M', year);
        if (episodes.isEmpty) {
          episodes =
              await _databaseService.getEpisodesByCategoryYear('6M', year - 1);
        }
        final sorted = List<Episode>.from(episodes)
          ..sort((a, b) => b.publishedDate.compareTo(a.publishedDate));
        if (sorted.isNotEmpty) {
          recommendedId = sorted.first.resolvedStorageId;
        }
      } catch (e) {
        debugPrint('OnboardingProfile: episode lookup failed: $e');
      }

      await _profileService.saveProfile(
        level: _level,
        focus: _focus,
        recommendedEpisodeId: recommendedId,
      );

      if (!mounted) return;
      final prefs = await SharedPreferences.getInstance();
      final hasSeenAdsNotice = prefs.getBool(_adsNoticeSeenKey) ?? false;
      if (!hasSeenAdsNotice) {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(
            builder: (context) => AdsSupportNoticeScreen(
              onContinue: (noticeContext) async {
                final localPrefs = await SharedPreferences.getInstance();
                await localPrefs.setBool(_adsNoticeSeenKey, true);
                if (!noticeContext.mounted) return;
                Navigator.of(noticeContext).pushAndRemoveUntil(
                  MaterialPageRoute(
                    builder: (context) => const BBCLearningAppStateful(),
                  ),
                  (route) => false,
                );
              },
            ),
          ),
        );
        return;
      }

      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (context) => const BBCLearningAppStateful()),
        (route) => false,
      );
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Scaffold(
      backgroundColor: colorScheme.surface,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 18, 24, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                _languageManager.getText('onboardingProfileTitle'),
                style: TextStyle(
                  fontSize: 26,
                  fontWeight: FontWeight.w800,
                  color: colorScheme.onSurface,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                _languageManager.getText('onboardingProfileSubtitle'),
                style: TextStyle(
                  fontSize: 15,
                  color: colorScheme.onSurface.withOpacity(0.74),
                  height: 1.4,
                ),
              ),
              const SizedBox(height: 28),
              Text(
                _languageManager.getText('onboardingLevelLabel'),
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: colorScheme.onSurface,
                ),
              ),
              const SizedBox(height: 12),
              _buildLevelChips(colorScheme),
              const SizedBox(height: 28),
              Text(
                _languageManager.getText('onboardingFocusLabel'),
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: colorScheme.onSurface,
                ),
              ),
              const SizedBox(height: 12),
              _buildFocusChips(colorScheme),
              const Spacer(),
              Text(
                _languageManager.getTextWithParams('onboardingGoalHint', {
                  'difficulty': _defaultGoalLabel(),
                }),
                style: TextStyle(
                  fontSize: 13,
                  color: colorScheme.onSurface.withOpacity(0.65),
                ),
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                height: 52,
                child: FilledButton(
                  onPressed: _isSaving ? null : _continue,
                  style: FilledButton.styleFrom(
                    backgroundColor: colorScheme.primary,
                    foregroundColor: colorScheme.onPrimary,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  child: _isSaving
                      ? const SizedBox(
                          width: 22,
                          height: 22,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : Text(
                          _languageManager.getText('onboardingProfileContinue'),
                          style: const TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _defaultGoalLabel() {
    final difficulty = switch (_level) {
      EnglishLevel.beginner => DailyGoalDifficulty.easy,
      EnglishLevel.intermediate => DailyGoalDifficulty.normal,
      EnglishLevel.advanced => DailyGoalDifficulty.hard,
    };
    return _languageManager.getText('dailyGoal${difficulty.name[0].toUpperCase()}${difficulty.name.substring(1)}');
  }

  Widget _buildLevelChips(ColorScheme colorScheme) {
    return Wrap(
      spacing: 10,
      runSpacing: 10,
      children: EnglishLevel.values.map((level) {
        final selected = _level == level;
        return ChoiceChip(
          label: Text(_languageManager.getText('level${level.name[0].toUpperCase()}${level.name.substring(1)}')),
          selected: selected,
          onSelected: (_) => setState(() => _level = level),
          selectedColor: colorScheme.primary.withOpacity(0.18),
          labelStyle: TextStyle(
            fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
            color: selected ? colorScheme.primary : colorScheme.onSurface,
          ),
        );
      }).toList(),
    );
  }

  Widget _buildFocusChips(ColorScheme colorScheme) {
    return Wrap(
      spacing: 10,
      runSpacing: 10,
      children: LearningFocus.values.map((focus) {
        final selected = _focus == focus;
        return ChoiceChip(
          label: Text(_languageManager.getText('focus${focus.name[0].toUpperCase()}${focus.name.substring(1)}')),
          selected: selected,
          onSelected: (_) => setState(() => _focus = focus),
          selectedColor: colorScheme.secondary.withOpacity(0.18),
          labelStyle: TextStyle(
            fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
            color: selected ? colorScheme.secondary : colorScheme.onSurface,
          ),
        );
      }).toList(),
    );
  }
}
