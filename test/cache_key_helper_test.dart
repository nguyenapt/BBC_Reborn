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

  group('CacheKeyHelper vocabulary by episode', () {
    test('vocabularyByEpisodeLookupKeys prefers wordHash first', () {
      const word = 'Hello';
      final wordHash = CacheKeyHelper.vocabularyWordHashKey(word);
      final keys = CacheKeyHelper.vocabularyByEpisodeLookupKeys(
        word,
        itemId: 'db-id-123',
      );
      expect(keys.first, wordHash);
      expect(keys.length, 2);
      expect(keys[1], CacheKeyHelper.sanitizeFirebaseKey('db-id-123'));
    });

    test('vocabularyByEpisodeLookupKeys is single key when no itemId', () {
      const word = 'test';
      final keys = CacheKeyHelper.vocabularyByEpisodeLookupKeys(word);
      expect(keys.length, 1);
      expect(keys.first, CacheKeyHelper.vocabularyWordHashKey(word));
    });

    test('normalizeVocabularyByEpisodePayload unwraps playMP3 schema v2', () {
      const raw = {
        'word': 'hello',
        'wordHash': 'abc',
        'schemaVersion': 2,
        'data': {
          'synonyms': ['hi'],
          'antonyms': ['bye'],
          'exampleSentences': [],
          'collocations': [],
        },
        'translation': {'vi': 'xin chào'},
      };
      final normalized =
          CacheKeyHelper.normalizeVocabularyByEpisodePayload(raw);
      expect(normalized['synonyms'], ['hi']);
      expect(normalized['antonyms'], ['bye']);
    });

    test('normalizeVocabularyByEpisodePayload passes through flat map', () {
      const flat = {
        'synonyms': ['a'],
        'antonyms': [],
      };
      expect(
        CacheKeyHelper.normalizeVocabularyByEpisodePayload(flat),
        flat,
      );
    });
  });
}
