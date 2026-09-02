import 'package:flutter_test/flutter_test.dart';
import 'package:bbc_reborn/services/ai/grammar_passage_dual_map.dart';
import 'package:bbc_reborn/models/grammar_explanation.dart';

void main() {
  group('toFlutterGrammarPassageData', () {
    test('synthesizes legacy fields and keeps passage structure', () {
      final dual = toFlutterGrammarPassageData(
        {
          'overall': {
            'grammarTheme': 'Present Perfect',
            'usageSummary': 'Used for past with present relevance',
            'keyStructures': ['have/has + V3'],
          },
          'sentenceAnalyses': [
            {
              'sentenceText': 'I have finished.',
              'mainStructure': 'have + V3',
              'usageInContext': 'Completed action',
              'phraseBreakdown': [
                {
                  'phrase': 'have finished',
                  'structure': 'aux+V3',
                  'usage': 'perfect',
                },
              ],
              'examples': ['She has left.'],
              'commonMistakes': ['I have finish'],
            },
          ],
        },
        'I have finished.',
      );

      expect(dual['grammarPoint'], 'Present Perfect');
      expect(dual['explanation'], 'Used for past with present relevance');
      expect(dual['explanation'], isNotEmpty);
      expect(dual['overall'], isA<Map>());
      expect(dual['sentenceAnalyses'], isA<List>());
      expect((dual['highlightedWords'] as List).first, 'have finished');
      expect(dual['rulePattern'], 'have + V3');
      expect(dual['whyThisForm'], 'Completed action');
      expect((dual['commonMistakes'] as List).first, 'I have finish');
    });

    test('falls back usageSummary to theme for old-app explanation', () {
      final dual = toFlutterGrammarPassageData(
        {
          'overall': {
            'grammarTheme': 'Passive Voice',
            'usageSummary': '',
          },
          'sentenceAnalyses': [],
        },
        'It was done.',
      );
      expect(dual['explanation'], 'Passive Voice');
      expect(dual['grammarPoint'], 'Passive Voice');
    });
  });

  group('GrammarExplanation isPassageMode via dual map', () {
    test('mapped dual response enables passage UI', () {
      final dual = toFlutterGrammarPassageData(
        {
          'overall': {
            'grammarTheme': 'Comparatives',
            'usageSummary': 'Compare two things',
            'keyStructures': ['adj-er than'],
          },
          'sentenceAnalyses': [
            {
              'sentenceText': 'She is taller than him.',
              'mainStructure': 'adj-er than',
              'usageInContext': 'Comparison',
              'phraseBreakdown': [],
              'examples': [],
              'commonMistakes': [],
            },
          ],
        },
        'She is taller than him.',
      );

      final explanation = GrammarExplanation(
        sentence: 'She is taller than him.',
        passageText: dual['passageText']?.toString(),
        grammarPoint: dual['grammarPoint'] as String,
        explanation: dual['explanation'] as String,
        highlightedWords: const [],
        overall: GrammarPassageOverall.fromJson(
          Map<String, dynamic>.from(dual['overall'] as Map),
        ),
        sentenceAnalyses: (dual['sentenceAnalyses'] as List)
            .whereType<Map>()
            .map(
              (e) => GrammarSentenceAnalysis.fromJson(
                Map<String, dynamic>.from(e),
              ),
            )
            .toList(),
      );

      expect(explanation.isPassageMode, isTrue);
      expect(explanation.overall?.grammarTheme, 'Comparatives');
      expect(explanation.sentenceAnalyses, isNotEmpty);
    });
  });
}
