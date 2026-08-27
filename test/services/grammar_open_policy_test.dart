import 'package:flutter_test/flutter_test.dart';
import 'package:learn_speak_british_english/models/grammar_explanation.dart';

void main() {
  group('GrammarOpenPolicy.displayLanguageCode', () {
    test('prefers target when both EN and target exist', () {
      expect(
        GrammarOpenPolicy.displayLanguageCode(
          targetLanguageCode: 'vi',
          englishAvailable: true,
          targetAvailable: true,
        ),
        'vi',
      );
    });

    test('shows English when only EN is cached', () {
      expect(
        GrammarOpenPolicy.displayLanguageCode(
          targetLanguageCode: 'vi',
          englishAvailable: true,
          targetAvailable: false,
        ),
        'en',
      );
    });

    test('shows target when only target is cached', () {
      expect(
        GrammarOpenPolicy.displayLanguageCode(
          targetLanguageCode: 'pt',
          englishAvailable: false,
          targetAvailable: true,
        ),
        'pt',
      );
    });

    test('falls back to target (generate) when neither is cached', () {
      expect(
        GrammarOpenPolicy.displayLanguageCode(
          targetLanguageCode: 'vi',
          englishAvailable: false,
          targetAvailable: false,
        ),
        'vi',
      );
    });

    test('uses English when app locale is English', () {
      expect(
        GrammarOpenPolicy.displayLanguageCode(
          targetLanguageCode: 'en',
          englishAvailable: false,
          targetAvailable: false,
        ),
        'en',
      );
    });
  });

  group('GrammarOpenPolicy.showLanguageSwitcher', () {
    test('shows EN + target when English is cached and target is not English', () {
      expect(
        GrammarOpenPolicy.showLanguageSwitcher(
          targetLanguageCode: 'vi',
          englishAvailable: true,
        ),
        isTrue,
      );
    });

    test('hides switcher when English is not cached', () {
      expect(
        GrammarOpenPolicy.showLanguageSwitcher(
          targetLanguageCode: 'vi',
          englishAvailable: false,
        ),
        isFalse,
      );
    });

    test('hides switcher when target locale is English', () {
      expect(
        GrammarOpenPolicy.showLanguageSwitcher(
          targetLanguageCode: 'en',
          englishAvailable: true,
        ),
        isFalse,
      );
    });
  });
}
