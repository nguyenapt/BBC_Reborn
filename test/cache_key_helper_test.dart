import 'package:flutter_test/flutter_test.dart';
import 'package:bbc_reborn/utils/cache_key_helper.dart';

void main() {
  group('grammarEpisodeLineKey', () {
    test('uses 0-based line segment', () {
      expect(
        CacheKeyHelper.grammarEpisodeLineKey('Hello.', lineNumber: 0),
        'line_0',
      );
      expect(
        CacheKeyHelper.grammarEpisodeLineKey('World.', lineNumber: 3),
        'line_3',
      );
    });

    test('falls back to sentence hash when lineNumber omitted', () {
      final key = CacheKeyHelper.grammarEpisodeLineKey('Hello.');
      expect(key.startsWith('s_'), isTrue);
    });
  });

  group('findLineTranslation', () {
    test('matches by lineNumber only (0-based)', () {
      final translations = [
        {'original': 'A', 'translated': 'Một', 'lineNumber': 0},
        {'original': 'B', 'translated': 'Hai', 'lineNumber': 1},
      ];
      expect(
        CacheKeyHelper.findLineTranslation(translations, 'A', 0),
        'Một',
      );
      expect(
        CacheKeyHelper.findLineTranslation(translations, 'X', 3),
        isNull,
      );
    });
  });
}
