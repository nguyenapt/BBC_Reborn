import 'package:flutter/material.dart';

import '../models/achievement.dart';
import '../services/achievement_service.dart';
import '../services/language_manager.dart';

class AchievementsSection extends StatelessWidget {
  const AchievementsSection({super.key});

  @override
  Widget build(BuildContext context) {
    final languageManager = LanguageManager();
    final achievementService = AchievementService();
    final colorScheme = Theme.of(context).colorScheme;

    return Card(
      margin: const EdgeInsets.fromLTRB(8, 8, 8, 4),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              languageManager.getText('achievementsTitle'),
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 12),
            ...AchievementDefinitions.all.map((def) {
              final unlocked = achievementService.isUnlocked(def.id);
              return Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Row(
                  children: [
                    Text(
                      def.emoji,
                      style: TextStyle(
                        fontSize: 24,
                        color: unlocked
                            ? null
                            : colorScheme.onSurface.withOpacity(0.35),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            languageManager.getText(def.titleKey),
                            style: TextStyle(
                              fontWeight: FontWeight.w700,
                              color: unlocked
                                  ? colorScheme.onSurface
                                  : colorScheme.onSurface.withOpacity(0.45),
                            ),
                          ),
                          Text(
                            languageManager.getText(def.descriptionKey),
                            style: TextStyle(
                              fontSize: 12,
                              color: colorScheme.onSurface.withOpacity(0.6),
                            ),
                          ),
                        ],
                      ),
                    ),
                    Icon(
                      unlocked ? Icons.check_circle : Icons.lock_outline,
                      color: unlocked
                          ? colorScheme.primary
                          : colorScheme.onSurface.withOpacity(0.35),
                      size: 20,
                    ),
                  ],
                ),
              );
            }),
          ],
        ),
      ),
    );
  }
}
