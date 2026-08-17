import 'package:bbc_reborn/models/heart_system_config.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('HeartSystemConfig', () {
    test('defaults match seed economy', () {
      const d = HeartSystemConfig.defaults;
      expect(d.allowCredit, isTrue);
      expect(d.heartNumber, 5);
      expect(d.creditNumber, 10);
      expect(d.speakingTicketNumber, 10);
      expect(d.rewardedHearts, 1);
      expect(d.rewardedCredits, 5);
      expect(d.dailyLiveCap, 80);
      expect(d.adTopupMaxPerDay, 5);
      expect(d.heartRefillMaxPerEpisode, 1);
      expect(d.dailyLiveCap, 80);
      expect(d.adTopupMaxPerDay, 5);
    });

    test('fromJson parses allow_credit false as legacy kill-switch', () {
      final c = HeartSystemConfig.fromJson({
        'allow_credit': false,
        'heart_number': 5,
        'credit_number': 15,
      });
      expect(c.allowCredit, isFalse);
      expect(c.creditNumber, 15);
    });

    test('fromJson clamps extreme values', () {
      final c = HeartSystemConfig.fromJson({
        'allow_credit': true,
        'heart_number': 999,
        'credit_number': 0,
        'daily_live_cap': -1,
      });
      expect(c.heartNumber, 50);
      expect(c.creditNumber, 1);
      expect(c.dailyLiveCap, 1);
    });
  });
}
