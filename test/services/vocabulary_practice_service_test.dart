import 'dart:math';

import 'package:bbc_reborn/models/vocabulary_item.dart';
import 'package:bbc_reborn/models/vocabulary_practice_state.dart';
import 'package:bbc_reborn/services/vocabulary_practice_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  VocabularyItem makeWord(String word, String mean) {
    return VocabularyItem(
      id: word,
      bbcEpisodeId: '',
      vocab: word,
      mean: mean,
    );
  }

  group('VocabularyPracticeService', () {
    test('pickWordOfTheDay returns deterministic item by UTC day', () {
      final items = [
        makeWord('apple', 'qua tao'),
        makeWord('book', 'quyen sach'),
        makeWord('cat', 'con meo'),
      ];

      final selected = VocabularyPracticeService.pickWordOfTheDay(
        items,
        nowUtc: DateTime.utc(2020, 1, 4),
        epochUtc: DateTime.utc(2020, 1, 1),
      );

      expect(selected?.vocab, 'apple');
    });

    test('applyOutcome stillLearning resets interval and repetition', () {
      final previous = VocabularyPracticeState(
        key: 'hello::xin chao',
        repetitions: 3,
        intervalDays: 10,
        easeFactor: 2.3,
      );
      final next = VocabularyPracticeService.applyOutcome(
        key: previous.key,
        previous: previous,
        outcome: VocabularyPracticeOutcome.stillLearning,
        nowUtc: DateTime.utc(2026, 1, 1),
      );

      expect(next.repetitions, 0);
      expect(next.intervalDays, 1);
      expect(next.easeFactor, closeTo(2.1, 0.00001));
      expect(next.lastOutcome, VocabularyPracticeOutcome.stillLearning);
    });

    test('buildPracticeDeck prioritizes weak words with max cap', () {
      final service = VocabularyPracticeService();
      service.clearStateForTesting();

      final words = List.generate(12, (i) => makeWord('word_$i', 'mean_$i'));
      for (var i = 0; i < 10; i++) {
        final key = VocabularyPracticeService.keyForVocabulary(words[i]);
        service.setStateForTesting(
          key,
          VocabularyPracticeState(
            key: key,
            repetitions: 0,
            intervalDays: 1,
            nextReviewAt: DateTime.utc(2025, 1, 1),
            lastOutcome: VocabularyPracticeOutcome.stillLearning,
          ),
        );
      }

      final deck = service.buildPracticeDeck(
        words,
        sessionSize: 10,
        maxWeakInSession: 4,
        nowUtc: DateTime.utc(2026, 1, 1),
        random: Random(1),
      );

      final weakCount = deck.where((w) => service.isWeak(w, nowUtc: DateTime.utc(2026, 1, 1))).length;
      expect(deck.length, 10);
      expect(weakCount, greaterThanOrEqualTo(4));
    });
  });
}
