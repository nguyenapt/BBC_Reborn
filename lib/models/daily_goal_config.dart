enum DailyGoalDifficulty { easy, normal, hard }

class DailyGoalTargets {
  final int listeningMinutes;
  final int vocabReviews;

  const DailyGoalTargets({
    required this.listeningMinutes,
    required this.vocabReviews,
  });

  static DailyGoalTargets forDifficulty(DailyGoalDifficulty difficulty) {
    return switch (difficulty) {
      DailyGoalDifficulty.easy =>
        const DailyGoalTargets(listeningMinutes: 3, vocabReviews: 5),
      DailyGoalDifficulty.normal =>
        const DailyGoalTargets(listeningMinutes: 5, vocabReviews: 10),
      DailyGoalDifficulty.hard =>
        const DailyGoalTargets(listeningMinutes: 10, vocabReviews: 20),
    };
  }
}
