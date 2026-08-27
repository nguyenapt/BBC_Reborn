import 'package:learn_speak_british_english/config/ai_config.dart';
import 'package:learn_speak_british_english/models/enhanced_vocabulary.dart';
import 'package:learn_speak_british_english/models/vocabulary_item.dart';
import 'package:learn_speak_british_english/utils/cache_key_helper.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('EnhancedVocabulary dual-format parse', () {
    final original = VocabularyItem(
      id: '1',
      bbcEpisodeId: 'ep',
      vocab: 'happy',
      mean: 'vui vẻ',
    );

    test('legacy string arrays only', () {
      final enhanced = EnhancedVocabulary.fromAIResponse(original, {
        'synonyms': ['glad', 'joyful'],
        'antonyms': ['sad'],
        'collocations': ['happy hour'],
        'exampleSentences': ['I am happy.'],
      });

      expect(enhanced.synonyms, ['glad', 'joyful']);
      expect(enhanced.displaySynonyms.map((e) => e.word), ['glad', 'joyful']);
      expect(enhanced.displaySynonyms.first.meaning, '');
      expect(enhanced.displayAntonyms.single.word, 'sad');
      expect(enhanced.displayCollocations.single.word, 'happy hour');
    });

    test('additive *Details with meanings', () {
      final enhanced = EnhancedVocabulary.fromAIResponse(original, {
        'synonyms': ['glad', 'joyful'],
        'antonyms': ['sad'],
        'collocations': ['happy hour'],
        'synonymDetails': [
          {'word': 'glad', 'meaning': 'pleased'},
          {'word': 'joyful', 'meaning': 'full of joy'},
        ],
        'antonymDetails': [
          {'word': 'sad', 'meaning': 'unhappy'},
        ],
        'collocationDetails': [
          {'word': 'happy hour', 'meaning': 'discounted drinks period'},
        ],
      });

      expect(enhanced.synonyms, ['glad', 'joyful']);
      expect(enhanced.displaySynonyms.first.meaning, 'pleased');
      expect(enhanced.displayAntonyms.single.meaning, 'unhappy');
      expect(enhanced.displayCollocations.single.meaning,
          'discounted drinks period');
    });

    test('details-only derives string lists', () {
      final enhanced = EnhancedVocabulary.fromAIResponse(original, {
        'synonymDetails': [
          {'word': 'glad', 'meaning': 'pleased'},
        ],
        'antonymDetails': [],
        'collocationDetails': [],
      });

      expect(enhanced.synonyms, ['glad']);
      expect(enhanced.displaySynonyms.single.meaning, 'pleased');
    });
  });

  group('grammar passage cache key isolation', () {
    test('single-shot key differs from progressive key', () {
      const passage = 'She has lived here for years.';
      const lang = 'vi';
      const episodeId = 'episode-guid';
      const model = 'gemini:gemini-2.5-flash:gpt-4o-mini';

      final single = CacheKeyHelper.grammarPassageKey(
        passage,
        lang,
        episodeId: episodeId,
        modelVersion: model,
        promptVersion: AIConfig.grammarPassageSinglePromptVersion,
        schemaVersion: AIConfig.grammarPassageSingleSchemaVersion,
      );

      final progressive = CacheKeyHelper.grammarPassageKey(
        passage,
        lang,
        episodeId: episodeId,
        modelVersion: model,
        promptVersion:
            '${AIConfig.grammarPromptVersion}_passage_v2_slim_progressive',
        schemaVersion:
            '${AIConfig.grammarSchemaVersion}_passage_v2_slim_progressive',
      );

      expect(single, isNot(equals(progressive)));
      expect(single.startsWith('grammar_passage_'), isTrue);
      expect(progressive.startsWith('grammar_passage_'), isTrue);
    });

    test('sentence grammar key differs from passage key', () {
      const text = 'She has lived here for years.';
      const lang = 'en';
      const episodeId = 'episode-guid';
      const model = 'gemini:gemini-2.5-flash:gpt-4o-mini';

      final sentence = CacheKeyHelper.grammarKey(
        text,
        lang,
        episodeId: episodeId,
        modelVersion: model,
        promptVersion: AIConfig.grammarPromptVersion,
      );
      final passage = CacheKeyHelper.grammarPassageKey(
        text,
        lang,
        episodeId: episodeId,
        modelVersion: model,
        promptVersion: AIConfig.grammarPassageSinglePromptVersion,
        schemaVersion: AIConfig.grammarPassageSingleSchemaVersion,
      );

      expect(sentence.startsWith('grammar_'), isTrue);
      expect(sentence.startsWith('grammar_passage_'), isFalse);
      expect(passage.startsWith('grammar_passage_'), isTrue);
      expect(sentence, isNot(equals(passage)));
    });

    test('playMP3 single prompt/schema constants match AIConfig', () {
      expect(
        AIConfig.grammarPassageSinglePromptVersion,
        'v2_detailed_learning_no_quiz_passage_v2_slim_single',
      );
      expect(
        AIConfig.grammarPassageSingleSchemaVersion,
        'v2_passage_v2_slim_single',
      );
    });
  });
}
