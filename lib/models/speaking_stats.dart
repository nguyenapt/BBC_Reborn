class SpeakingStats {
  final int totalSessions;
  final int totalAttempts;
  final double averageScore;
  final DateTime? lastPracticedAt;

  const SpeakingStats({
    required this.totalSessions,
    required this.totalAttempts,
    required this.averageScore,
    required this.lastPracticedAt,
  });

  factory SpeakingStats.empty() {
    return const SpeakingStats(
      totalSessions: 0,
      totalAttempts: 0,
      averageScore: 0,
      lastPracticedAt: null,
    );
  }
}
