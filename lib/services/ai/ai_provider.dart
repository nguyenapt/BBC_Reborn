/// Base abstract class for AI providers
abstract class AIProvider {
  /// Translate text to target language with optional context
  Future<String> translate(
    String text,
    String targetLanguage, {
    String? context,
  });
  
  /// Explain grammar in a sentence
  Future<Map<String, dynamic>> explainGrammar(
    String sentence,
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
  
  /// Check if provider is available
  Future<bool> isAvailable();
}

