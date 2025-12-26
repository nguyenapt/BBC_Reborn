enum AIProviderType {
  gemini,
  openai,
}

class AIConfig {
  // Gemini (Free)
  // Get free API key from: https://aistudio.google.com/app/apikey
  // Official guide: https://ai.google.dev/gemini-api/docs/api-key
  // SECURITY: Never commit API keys to source control!
  // Use environment variable GEMINI_API_KEY or GOOGLE_API_KEY instead
  static const String geminiApiKey = 'GEMINI_API_KEY';
  static const int geminiRateLimit = 15; // requests per minute
  static const String geminiModel = 'gemini-2.5-flash'; // Official model name from https://ai.google.dev/gemini-api/docs/api-key
  
  // OpenAI (Backup)
  // TODO: Replace with your actual API key
  // Get API key from: https://platform.openai.com/api-keys
  static const String openaiApiKey = 'OPENAI_API_KEY';
  static const String openaiModel = 'gpt-3.5-turbo'; // Cheaper option
  
  // Feature flags
  static const bool enableTranslation = true;
  static const bool enableGrammar = true;
  static const bool enableQuestions = true;
  static const bool enableVocabularyEnhancement = true;
  
  // Primary provider
  static const AIProviderType primaryProvider = AIProviderType.gemini;
  
  // Get API key from environment variables only
  // According to official guide: https://ai.google.dev/gemini-api/docs/api-key
  // Supports both GEMINI_API_KEY and GOOGLE_API_KEY (GOOGLE_API_KEY takes precedence)
  // SECURITY: Never hardcode API keys! Always use environment variables.
  static String getGeminiApiKey() {
    // Try GOOGLE_API_KEY first (takes precedence according to Google docs)
    const googleApiKey = String.fromEnvironment('GOOGLE_API_KEY');
    if (googleApiKey.isNotEmpty && googleApiKey != 'YOUR_GOOGLE_API_KEY') {
      return googleApiKey;
    }
    
    // Try GEMINI_API_KEY
    const geminiApiKeyEnv = String.fromEnvironment('GEMINI_API_KEY');
    if (geminiApiKeyEnv.isNotEmpty && geminiApiKeyEnv != 'YOUR_GEMINI_API_KEY') {
      return geminiApiKeyEnv;
    }
    
    // No API key found - return empty string (will cause error in provider)
    // This ensures developers must set environment variables
    return '';
  }
  
  static String getOpenAIApiKey() {
    // Try to get from environment variable only
    const envKey = String.fromEnvironment('OPENAI_API_KEY');
    if (envKey.isNotEmpty && envKey != 'YOUR_OPENAI_API_KEY') {
      return envKey;
    }
    
    // No API key found - return empty string (will cause error in provider)
    // This ensures developers must set environment variables
    return '';
  }
}

