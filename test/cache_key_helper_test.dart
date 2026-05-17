import 'package:bbc_reborn/utils/cache_key_helper.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('CacheKeyHelper grammar line keys (0-based)', () {
    test('grammarByEpisodeLineKey uses 0-based index', () {
      expect(CacheKeyHelper.grammarByEpisodeLineKey(0), 'line_0');
      expect(CacheKeyHelper.grammarByEpisodeLineKey(3), 'line_3');
    });

    test('grammarEpisodeLineKey prefers lineNumber over sentence hash', () {
      expect(
        CacheKeyHelper.grammarEpisodeLineKey('any text', lineNumber: 0),
        'line_0',
      );
      expect(
        CacheKeyHelper.grammarEpisodeLineKey('Hello', lineNumber: null).length,
        greaterThan(2),
      );
    });

    test('findLineTranslation matches by lineNumber only', () {
      const data = [
        {
          'original': 'Version A',
          'translated': 'Bản A',
          'lineNumber': 3,
        },
        {
          'original': 'Different text same line',
          'translated': 'Bản đúng',
          'lineNumber': 3,
        },
      ];

      expect(
        CacheKeyHelper.findLineTranslation(data, 3),
        'Bản đúng',
      );
      expect(CacheKeyHelper.findLineTranslation(data, 0), isNull);
    });
  });
}
