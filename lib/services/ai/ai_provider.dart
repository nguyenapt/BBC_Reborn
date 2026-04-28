/// Base abstract class for AI providers
abstract class AIProvider {
  /// Translate text to target language with optional context
  Future<String> translate(
    String text,
    String targetLanguage, {
    String? context,
  });
  
  /// Translate multiple vocabulary words in one request
  /// Returns a map of word -> translation
  Future<Map<String, String>> translateVocabularyBatch(
    List<Map<String, String>> vocabularyList, // List of {word, meaning, context?}
    String targetLanguage,
  );
  
  /// Explain grammar in a sentence
  Future<Map<String, dynamic>> explainGrammar(
    String sentence,
    String targetLanguage,
  );

  /// Explain grammar for a full passage (multi-sentence)
  Future<Map<String, dynamic>> explainGrammarPassage(
    String passage,
    String targetLanguage,
  );
  
  /// Generate questions from transcript
  Future<List<Map<String, dynamic>>> generateQuestions(
    String transcript,
    {int count = 5}
  );
  
  /// Enhance vocabulary with additional information
  Future<Map<String, dynamic>> enhanceVocabulary(
    String word,
    String meaning, {
    String? context,
  });

  /// Evaluate speaking performance based on reference and spoken transcript
  Future<Map<String, dynamic>> evaluateSpeech({
    required String referenceText,
    required String spokenText,
    String? language,
  });
  
  /// Check if provider is available
  Future<bool> isAvailable();
}

