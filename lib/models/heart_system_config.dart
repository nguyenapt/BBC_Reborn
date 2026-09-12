/// Remote / local defaults for hearts + episode credits economy.
class HeartSystemConfig {
  final bool allowCredit;
  /// Episode Pass + per-episode credits (translate, grammar, vocabulary…).
  final bool allowCreditEpisodePass;
  /// Speaking ticket + per-session attempts.
  final bool allowCreditSpeaking;
  final int heartNumber;
  final int creditNumber;
  final int speakingTicketNumber;
  final int rewardedHearts;
  final int rewardedCredits;
  final int dailyLiveCap;
  final int adTopupMaxPerDay;
  /// Max times user may spend 1 heart to refill credits after Pass already opened (same episode/day).
  final int heartRefillMaxPerEpisode;
  /// Auto-stop mic after this many seconds per sentence (avoids hour-long recordings).
  final int speakingMaxRecordingSeconds;

  const HeartSystemConfig({
    required this.allowCredit,
    required this.allowCreditEpisodePass,
    required this.allowCreditSpeaking,
    required this.heartNumber,
    required this.creditNumber,
    required this.speakingTicketNumber,
    required this.rewardedHearts,
    required this.rewardedCredits,
    required this.dailyLiveCap,
    required this.adTopupMaxPerDay,
    required this.heartRefillMaxPerEpisode,
    required this.speakingMaxRecordingSeconds,
  });

  /// Defaults when RTDB missing / offline (matches seed).
  static const HeartSystemConfig defaults = HeartSystemConfig(
    allowCredit: true,
    allowCreditEpisodePass: true,
    allowCreditSpeaking: true,
    heartNumber: 5,
    creditNumber: 10,
    speakingTicketNumber: 5,
    rewardedHearts: 1,
    rewardedCredits: 5,
    dailyLiveCap: 40,
    adTopupMaxPerDay: 5,
    heartRefillMaxPerEpisode: 1,
    speakingMaxRecordingSeconds: 60,
  );

  factory HeartSystemConfig.fromJson(Map<String, dynamic> json) {
    int i(String key, int fallback) {
      final v = json[key];
      if (v is int) return v;
      if (v is num) return v.toInt();
      return int.tryParse('$v') ?? fallback;
    }

    bool b(String key, bool fallback) {
      final v = json[key];
      if (v is bool) return v;
      if (v is num) return v != 0;
      if (v is String) {
        final s = v.toLowerCase().trim();
        if (s == 'true' || s == '1') return true;
        if (s == 'false' || s == '0') return false;
      }
      return fallback;
    }

    final d = defaults;
    final allowCredit = b('allow_credit', d.allowCredit);
    return HeartSystemConfig(
      allowCredit: allowCredit,
      allowCreditEpisodePass: allowCredit
          ? b('allow_credit_episode_pass', d.allowCreditEpisodePass)
          : false,
      allowCreditSpeaking: allowCredit
          ? b('allow_credit_speaking', d.allowCreditSpeaking)
          : false,
      heartNumber: i('heart_number', d.heartNumber).clamp(1, 50),
      creditNumber: i('credit_number', d.creditNumber).clamp(1, 100),
      speakingTicketNumber:
          i('speaking_ticket_number', d.speakingTicketNumber).clamp(1, 100),
      rewardedHearts: i('rewarded_hearts', d.rewardedHearts).clamp(1, 20),
      rewardedCredits: i('rewarded_credits', d.rewardedCredits).clamp(1, 100),
      dailyLiveCap: i('daily_live_cap', d.dailyLiveCap).clamp(1, 500),
      adTopupMaxPerDay:
          i('ad_topup_max_per_day', d.adTopupMaxPerDay).clamp(0, 50),
      heartRefillMaxPerEpisode:
          i('heart_refill_max_per_episode', d.heartRefillMaxPerEpisode)
              .clamp(0, 10),
      speakingMaxRecordingSeconds: i(
        'speaking_max_recording_seconds',
        d.speakingMaxRecordingSeconds,
      ).clamp(15, 180),
    );
  }

  Map<String, dynamic> toJson() => {
        'allow_credit': allowCredit,
        'allow_credit_episode_pass': allowCreditEpisodePass,
        'allow_credit_speaking': allowCreditSpeaking,
        'heart_number': heartNumber,
        'credit_number': creditNumber,
        'speaking_ticket_number': speakingTicketNumber,
        'rewarded_hearts': rewardedHearts,
        'rewarded_credits': rewardedCredits,
        'daily_live_cap': dailyLiveCap,
        'ad_topup_max_per_day': adTopupMaxPerDay,
        'heart_refill_max_per_episode': heartRefillMaxPerEpisode,
        'speaking_max_recording_seconds': speakingMaxRecordingSeconds,
      };
}
