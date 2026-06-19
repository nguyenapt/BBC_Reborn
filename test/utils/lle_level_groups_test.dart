import 'package:bbc_reborn/models/episode.dart';
import 'package:bbc_reborn/utils/lle_level_groups.dart';
import 'package:flutter_test/flutter_test.dart';

Episode _episode({String? level, String name = 'Lesson'}) {
  return Episode(
    actor: '',
    category: 'LLE',
    duration: '1:00',
    publishedDate: DateTime(2024, 1, 1),
    episodeName: name,
    transcript: '',
    thumbImage: '',
    level: level,
  );
}

void main() {
  group('LleLevelGroups.normalizeLevel', () {
    test('normalizes casing and whitespace', () {
      expect(LleLevelGroups.normalizeLevel('a1'), 'A1');
      expect(LleLevelGroups.normalizeLevel(' B2 '), 'B2');
    });

    test('maps missing or unknown values to OTHER', () {
      expect(LleLevelGroups.normalizeLevel(null), LleLevelGroups.otherKey);
      expect(LleLevelGroups.normalizeLevel(''), LleLevelGroups.otherKey);
      expect(LleLevelGroups.normalizeLevel('C1'), LleLevelGroups.otherKey);
    });
  });

  group('LleLevelGroups.groupByLevel', () {
    test('groups episodes by A1-B2 and OTHER', () {
      final groups = LleLevelGroups.groupByLevel([
        _episode(level: 'A1', name: 'A1-1'),
        _episode(level: 'a2', name: 'A2-1'),
        _episode(level: null, name: 'Other'),
      ]);

      expect(groups['A1']!.length, 1);
      expect(groups['A2']!.length, 1);
      expect(groups[LleLevelGroups.otherKey]!.length, 1);
      expect(groups['B1'], isEmpty);
    });
  });

  group('LleLevelGroups.episodesForPlaylist', () {
    test('returns same-level episodes for classified LLE episode', () {
      final all = [
        _episode(level: 'A1', name: 'A1-1'),
        _episode(level: 'A1', name: 'A1-2'),
        _episode(level: 'B1', name: 'B1-1'),
      ];

      final playlist = LleLevelGroups.episodesForPlaylist(all[0], all);
      expect(playlist.map((e) => e.episodeName), ['A1-1', 'A1-2']);
    });

    test('falls back to full list when level is missing', () {
      final all = [
        _episode(level: 'A1'),
        _episode(level: null, name: 'No level'),
      ];

      final playlist =
          LleLevelGroups.episodesForPlaylist(all[1], all);
      expect(playlist.length, 2);
    });
  });
}
