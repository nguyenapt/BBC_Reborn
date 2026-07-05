enum EnglishLevel { beginner, intermediate, advanced }

enum LearningFocus { listening, vocabulary, speaking }

class UserLearningProfile {
  final EnglishLevel level;
  final LearningFocus focus;
  final String? recommendedEpisodeId;
  final DateTime savedAt;

  const UserLearningProfile({
    required this.level,
    required this.focus,
    this.recommendedEpisodeId,
    required this.savedAt,
  });

  Map<String, dynamic> toJson() => {
        'level': level.name,
        'focus': focus.name,
        'recommendedEpisodeId': recommendedEpisodeId,
        'savedAt': savedAt.toIso8601String(),
      };

  factory UserLearningProfile.fromJson(Map<String, dynamic> json) {
    return UserLearningProfile(
      level: EnglishLevel.values.firstWhere(
        (e) => e.name == json['level'],
        orElse: () => EnglishLevel.intermediate,
      ),
      focus: LearningFocus.values.firstWhere(
        (e) => e.name == json['focus'],
        orElse: () => LearningFocus.listening,
      ),
      recommendedEpisodeId: json['recommendedEpisodeId'] as String?,
      savedAt: DateTime.tryParse(json['savedAt']?.toString() ?? '') ??
          DateTime.now(),
    );
  }
}
