namespace playMP3
{
    /// <summary>
    /// MUST_SYNC with Flutter:
    /// - lib/config/ai_config.dart (grammarPromptVersion, geminiModel, openaiModel, primaryProvider)
    /// - lib/services/ai_grammar_service.dart (modelVersion string, promptVersion passed to cache)
    /// </summary>
    public static class GrammarCacheConstants
    {
        /// <summary>AIConfig.grammarPromptVersion (sentence-level only).</summary>
        public const string GrammarPromptVersion = "v2_detailed_learning_no_quiz";

        /// <summary>
        /// MUST match Flutter <c>AIGrammarService.explainSentence</c> cache key:
        /// <c>${AIConfig.primaryProvider.name}:${AIConfig.geminiModel}:${AIConfig.openaiModel}</c>
        /// (= gemini:gemini-2.5-flash:gpt-4o-mini với cấu hình hiện tại). Không dùng <see cref="GeminiModelId"/> ở đây — đó chỉ là model gọi REST trong tool.
        /// </summary>
        public const string GrammarModelVersion = "gemini:gemini-2.5-flash:gpt-4o-mini";

        /// <summary>
        /// playMP3 single-shot passage fill. MUST_SYNC Flutter lookup when reading prewarmed
        /// <c>ai_cache/grammar_passage</c> — distinct from app progressive
        /// <c>${grammarPromptVersion}_passage_v2_slim_progressive</c>.
        /// </summary>
        public const string GrammarPassagePromptVersion = "v2_detailed_learning_no_quiz_passage_v2_slim_single";

        /// <summary>MUST_SYNC Flutter passage schemaVersion for single-shot cache keys.</summary>
        public const string GrammarPassageSchemaVersion = "v2_passage_v2_slim_single";

        /// <summary>
        /// Legacy BBC default only. playMP3 must pass CloudService <c>txtUrl</c> into cache writers —
        /// do not use this for VOA uploads.
        /// </summary>
        public const string FirebaseRtdbBaseUrl = "https://bbc-listening-english.firebaseio.com";

        public const string AiCachePath = "ai_cache";
        public const string GrammarByEpisodePath = "grammar_by_episode";
        public const string GrammarPassagePath = "grammar_passage";
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

        /// <summary>Số từ/cụm gợi ý mặc định khi Get Vocab from transcript.</summary>
        public const int DefaultVocabularySuggestionCount = 10;

        /// <summary>RTDB child segment names under <c>ai_cache</c> (cleanup UI).</summary>
        public static readonly string[] AiCacheNodeNames =
        {
            "grammar",
            "grammar_by_episode",
            "grammar_passage",
            "questions",
            "translations",
            "vocabulary",
            "vocabulary_by_episode",
        };

        /// <summary>Gemini REST model id (playMP3 tool); intentionally flash-lite for speed/cost vs Flutter app.</summary>
        public const string GeminiModelId = "gemini-2.5-flash-lite";
    }
}
