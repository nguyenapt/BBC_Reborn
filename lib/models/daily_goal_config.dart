enum DailyGoalDifficulty { easy, normal, hard }

class DailyGoalTargets {
  final int listeningMinutes;
  final int vocabReviews;
  final int heartReward;

  const DailyGoalTargets({
    required this.listeningMinutes,
    required this.vocabReviews,
    required this.heartReward,
  });

  static DailyGoalTargets forDifficulty(DailyGoalDifficulty difficulty) {
    return switch (difficulty) {
      DailyGoalDifficulty.easy =>
        const DailyGoalTargets(
          listeningMinutes: 3,
          vocabReviews: 3,
          heartReward: 1,
        ),
      DailyGoalDifficulty.normal =>
        const DailyGoalTargets(
          listeningMinutes: 5,
          vocabReviews: 5,
          heartReward: 2,
        ),
      DailyGoalDifficulty.hard =>
        const DailyGoalTargets(
          listeningMinutes: 10,
          vocabReviews: 10,
          heartReward: 5,
        ),
    };
  }
}
