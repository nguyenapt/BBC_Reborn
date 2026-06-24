import 'package:flutter/foundation.dart';

enum AIProviderType {
  gemini,
  openai,
}

class AIConfig {
  /// When true, LLM requests go through Firebase Callable `aiRequest` (mobile only).
  static const bool useCloudAI = true;

  /// Cloud AI requires Firebase + App Check on device; web is not configured yet.
  /// Override local dev: `--dart-define=USE_CLOUD_AI=false`
  static bool get effectiveUseCloudAI {
    const envOverride = String.fromEnvironment('USE_CLOUD_AI');
    if (envOverride == 'false') return false;
    if (envOverride == 'true') return true;
    return useCloudAI && !kIsWeb;
  }

  // Model names (used for cache keys / sync with server config)
  static const int geminiRateLimit = 15; // local GeminiProvider dev only
  static const String geminiModel = 'gemini-2.5-flash';
  static const String openaiModel = 'gpt-4o-mini';

  // Azure STT — local dev only when [effectiveUseCloudAI] is false.
  // Production uses Cloud Function transcribeSpeech + AI_AZURE_SPEECH_KEY secret.
  static const String azureSpeechKey = '';
  static const String azureSpeechRegion = 'southeastasia';
  /// Leave empty to build STT URL from [azureSpeechRegion].
  /// Do not use *.tts.speech.microsoft.com (that is Text-to-Speech, not STT).
  static const String azureSpeechEndpoint = '';

  // Feature flags
  static const bool enableTranslation = true;
  static const bool enableGrammar = true;
  static const bool enableQuestions = true;
  static const bool enableVocabularyEnhancement = true;

  // Primary provider (local dev only when useCloudAI is false)
  static const AIProviderType primaryProvider = AIProviderType.gemini;

  // Grammar behavior/versioning (MUST_SYNC playMP3/GrammarCacheConstants.cs)
  static const String grammarPromptVersion = 'v2_detailed_learning_no_quiz';
  static const String grammarSchemaVersion = 'v2';

  // Firebase-only guardrails (operational reminders)
  static const int keyRotationDays = 14;
  static const int dailyGrammarSoftCapPerUser = 120;

  /// Whisper STT — local dev only. Production STT is server-side (Azure/Whisper).
  static String getWhisperApiKey() {
    const envKey = String.fromEnvironment('OPENAI_API_KEY');
    if (envKey.isNotEmpty && envKey != 'YOUR_OPENAI_API_KEY') {
      return envKey;
    }
    return '';
  }

  /// Azure STT key — local dev only. Not used on Play Store when useCloudAI=true.
  static String getAzureSpeechKey() {
    const envKey = String.fromEnvironment('AZURE_SPEECH_KEY');
    if (envKey.isNotEmpty && envKey != 'YOUR_AZURE_SPEECH_KEY') {
      return envKey;
    }

    if (azureSpeechKey.isNotEmpty && azureSpeechKey != 'YOUR_AZURE_SPEECH_KEY') {
      return azureSpeechKey;
    }

    return '';
  }

  static String getAzureSpeechRegion() {
    const envRegion = String.fromEnvironment('AZURE_SPEECH_REGION');
    if (envRegion.isNotEmpty && envRegion != 'YOUR_AZURE_SPEECH_REGION') {
      return envRegion;
    }

    if (azureSpeechRegion.isNotEmpty &&
        azureSpeechRegion != 'YOUR_AZURE_SPEECH_REGION') {
      return azureSpeechRegion;
    }

    return '';
  }

  static String getAzureSpeechEndpoint() {
    const envEndpoint = String.fromEnvironment('AZURE_SPEECH_ENDPOINT');
    if (envEndpoint.isNotEmpty) {
      return envEndpoint;
    }

    return azureSpeechEndpoint;
  }
}
