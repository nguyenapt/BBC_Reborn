namespace playMP3
{
    /// <summary>
    /// MUST_SYNC with Flutter:
    /// - lib/config/ai_config.dart (grammarPromptVersion, geminiModel, openaiModel, primaryProvider)
    /// - lib/services/ai_grammar_service.dart (modelVersion string, promptVersion passed to cache)
    /// </summary>
    public static class GrammarCacheConstants
    {
        /// <summary>AIConfig.grammarPromptVersion</summary>
        public const string GrammarPromptVersion = "v2_detailed_learning_no_quiz";

        /// <summary>
        /// MUST match Flutter <c>AIGrammarService.explainSentence</c> cache key:
        /// <c>${AIConfig.primaryProvider.name}:${AIConfig.geminiModel}:${AIConfig.openaiModel}</c>
        /// (= gemini:gemini-2.5-flash:gpt-4o-mini với cấu hình hiện tại). Không dùng <see cref="GeminiModelId"/> ở đây — đó chỉ là model gọi REST trong tool.
        /// </summary>
        public const string GrammarModelVersion = "gemini:gemini-2.5-flash:gpt-4o-mini";

        public const string FirebaseRtdbBaseUrl = "https://bbc-listening-english.firebaseio.com";

        public const string AiCachePath = "ai_cache";
        public const string GrammarByEpisodePath = "grammar_by_episode";
        public const string VocabularyByEpisodePath = "vocabulary_by_episode";

        /// <summary>transcriptLineIndex / lineNumber / lineKey are 0-based (line_0 = first line). Re-upload RTDB after changing from old 1-based keys.</summary>
        public const string LineIndexConvention = "0-based";

        public const int AiCacheEntryVersion = 1;
        public const int GrammarByEpisodeSchemaVersion = 2;

        public const int AiCacheTtlDays = 90;

        /// <summary>MUST_SYNC Flutter <c>AIFirebaseCacheService._vocabularyTtlDays</c> (180).</summary>
        public const int VocabularyAiCacheTtlDays = 180;

        /// <summary>MUST_SYNC Flutter <c>QuestionSlide</c> / <c>AIQuestionService.generateQuestions</c> default count (5).</summary>
        public const int DefaultQuestionCount = 5;

        /// <summary>Gemini REST model id (playMP3 tool); intentionally flash-lite for speed/cost vs Flutter app.</summary>
        public const string GeminiModelId = "gemini-2.5-flash-lite";
    }
}
