import 'package:bbc_reborn/models/heart_system_config.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('HeartSystemConfig', () {
    test('defaults match seed economy', () {
      const d = HeartSystemConfig.defaults;
      expect(d.allowCredit, isTrue);
      expect(d.allowCreditEpisodePass, isTrue);
      expect(d.allowCreditSpeaking, isTrue);
      expect(d.heartNumber, 5);
      expect(d.creditNumber, 10);
      expect(d.speakingTicketNumber, 5);
      expect(d.rewardedHearts, 1);
      expect(d.rewardedCredits, 5);
      expect(d.dailyLiveCap, 40);
      expect(d.adTopupMaxPerDay, 5);
      expect(d.heartRefillMaxPerEpisode, 1);
      expect(d.speakingMaxRecordingSeconds, 60);
    });

    test('fromJson parses allow_credit false as legacy kill-switch', () {
      final c = HeartSystemConfig.fromJson({
        'allow_credit': false,
        'heart_number': 5,
        'credit_number': 15,
        'allow_credit_episode_pass': true,
        'allow_credit_speaking': true,
      });
      expect(c.allowCredit, isFalse);
      expect(c.allowCreditEpisodePass, isFalse);
      expect(c.allowCreditSpeaking, isFalse);
      expect(c.creditNumber, 15);
    });

    test('fromJson parses module toggles when credit mode on', () {
      final c = HeartSystemConfig.fromJson({
        'allow_credit': true,
        'allow_credit_episode_pass': false,
        'allow_credit_speaking': true,
      });
      expect(c.allowCreditEpisodePass, isFalse);
      expect(c.allowCreditSpeaking, isTrue);
    });

    test('fromJson clamps extreme values', () {
      final c = HeartSystemConfig.fromJson({
        'allow_credit': true,
        'heart_number': 999,
        'credit_number': 0,
        'daily_live_cap': -1,
        'speaking_max_recording_seconds': 999,
      });
      expect(c.heartNumber, 50);
      expect(c.creditNumber, 1);
      expect(c.dailyLiveCap, 1);
      expect(c.speakingMaxRecordingSeconds, 180);
    });
  });
}
