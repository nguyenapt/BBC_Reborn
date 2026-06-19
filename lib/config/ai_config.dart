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

  // Azure Speech (local STT dev fallback when useCloudAI=false)
  static const String azureSpeechKey = 'AZURE_SPEECH_KEY';
  static const String azureSpeechRegion = 'southeastasia';
  static const String azureSpeechEndpoint = '';

  // Grammar cache versioning — keep in sync with functions/ai/config.js
  static const String grammarPromptVersion = 'v2_detailed_learning_no_quiz';
  static const String grammarSchemaVersion = 'v2';
  
  // Feature flags
  static const bool enableTranslation = true;
  static const bool enableGrammar = true;
  static const bool enableQuestions = true;
  static const bool enableVocabularyEnhancement = true;

  /// Production default: route AI/STT through Firebase Callable `aiRequest`.
  /// Override local dev: `--dart-define=USE_CLOUD_AI=false`
  static const bool useCloudAI = true;

  static bool get effectiveUseCloudAI {
    const envOverride = String.fromEnvironment('USE_CLOUD_AI');
    if (envOverride == 'false') return false;
    if (envOverride == 'true') return true;
    return useCloudAI;
  }
  
  // Primary provider
  static const AIProviderType primaryProvider = AIProviderType.gemini;
  
  // Get API key from environment variables first, then fallback to hardcoded constant
  // According to official guide: https://ai.google.dev/gemini-api/docs/api-key
  // Supports both GEMINI_API_KEY and GOOGLE_API_KEY (GOOGLE_API_KEY takes precedence)
  // SECURITY: For production, use environment variables! Hardcoded keys are for development only.
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
    
    // Fallback to hardcoded constant (for development)
    // WARNING: In production, use environment variables instead!
    if (geminiApiKey.isNotEmpty && geminiApiKey != 'YOUR_GEMINI_API_KEY') {
      return geminiApiKey;
    }
    
    // No API key found - return empty string (will cause error in provider)
    return '';
  }
  
  static String getOpenAIApiKey() {
    // Try to get from environment variable first
    const envKey = String.fromEnvironment('OPENAI_API_KEY');
    if (envKey.isNotEmpty && envKey != 'YOUR_OPENAI_API_KEY') {
      return envKey;
    }
    
    // Fallback to hardcoded constant (for development)
    // WARNING: In production, use environment variables instead!
    if (openaiApiKey.isNotEmpty && openaiApiKey != 'YOUR_OPENAI_API_KEY') {
      return openaiApiKey;
    }
    
    // No API key found - return empty string (will cause error in provider)
    return '';
  }

  static String getAzureSpeechKey() {
    const envKey = String.fromEnvironment('AZURE_SPEECH_KEY');
    if (envKey.isNotEmpty && envKey != 'YOUR_AZURE_SPEECH_KEY') {
      return envKey;
    }
    if (azureSpeechKey.isNotEmpty && azureSpeechKey != 'AZURE_SPEECH_KEY') {
      return azureSpeechKey;
    }
    return '';
  }

  static String getAzureSpeechRegion() {
    const envRegion = String.fromEnvironment('AZURE_SPEECH_REGION');
    if (envRegion.isNotEmpty && envRegion != 'YOUR_AZURE_SPEECH_REGION') {
      return envRegion;
    }
    return azureSpeechRegion;
  }

  static String getAzureSpeechEndpoint() {
    const envEndpoint = String.fromEnvironment('AZURE_SPEECH_ENDPOINT');
    if (envEndpoint.isNotEmpty) {
      return envEndpoint;
    }
    return azureSpeechEndpoint;
  }

  /// Whisper uses the OpenAI API key.
  static String getWhisperApiKey() => getOpenAIApiKey();
}

