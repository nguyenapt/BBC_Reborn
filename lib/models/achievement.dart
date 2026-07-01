enum AchievementId {
  streak7,
  vocab50,
  episodes10,
  speaking80,
}

class AchievementDefinition {
  final AchievementId id;
  final String titleKey;
  final String descriptionKey;
  final String emoji;

  const AchievementDefinition({
    required this.id,
    required this.titleKey,
    required this.descriptionKey,
    required this.emoji,
  });
}

class AchievementDefinitions {
  static const List<AchievementDefinition> all = [
    AchievementDefinition(
      id: AchievementId.streak7,
      titleKey: 'achievementStreak7Title',
      descriptionKey: 'achievementStreak7Desc',
      emoji: '🔥',
    ),
    AchievementDefinition(
      id: AchievementId.vocab50,
      titleKey: 'achievementVocab50Title',
      descriptionKey: 'achievementVocab50Desc',
      emoji: '📚',
    ),
    AchievementDefinition(
      id: AchievementId.episodes10,
      titleKey: 'achievementEpisodes10Title',
      descriptionKey: 'achievementEpisodes10Desc',
      emoji: '🎧',
    ),
    AchievementDefinition(
      id: AchievementId.speaking80,
      titleKey: 'achievementSpeaking80Title',
      descriptionKey: 'achievementSpeaking80Desc',
      emoji: '🎤',
    ),
  ];

  static AchievementDefinition? byId(AchievementId id) {
    for (final def in all) {
      if (def.id == id) return def;
    }
    return null;
  }
}
