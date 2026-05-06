using System;
using System.Linq;
using System.Security.Cryptography;
using System.Text;

namespace playMP3
{
    /// <summary>
    /// Port of lib/utils/cache_key_helper.dart grammarKey + sanitizeFirebaseKey for RTDB paths.
    /// </summary>
    public static class GrammarCacheKeyHelper
    {
        /// <summary>Stable hash for one normalized sentence, independent from episode/model/prompt.</summary>
        public static string GrammarSentenceContentHash(string sentence)
        {
            return HashString((sentence ?? string.Empty).Trim());
        }

        /// <summary>16-char hex shared by all locales for one sentence (segment before _lang in RTDB path).</summary>
        public static string GrammarScopedContentHash(
            string sentence,
            string episodeId,
            string modelVersion,
            string promptVersion)
        {
            var scopedPayload = string.Join("|", new[]
            {
                (sentence ?? string.Empty).Trim(),
                (episodeId ?? string.Empty).Trim(),
                (modelVersion ?? string.Empty).Trim(),
                (promptVersion ?? string.Empty).Trim(),
            });
            return HashString(scopedPayload);
        }

        public static string GrammarKey(
            string sentence,
            string languageCode,
            string episodeId,
            string modelVersion,
            string promptVersion)
        {
            var hash = GrammarScopedContentHash(sentence, episodeId, modelVersion, promptVersion);
            return "grammar_" + hash + "_" + (languageCode ?? string.Empty).Trim();
        }

        /// <summary>Path segment used in .../ai_cache/grammar/{sentenceHash}/{lang}.json</summary>
        public static string GrammarSentenceHashPathSegment(string sentence, string languageCode, string episodeId, string modelVersion, string promptVersion)
        {
            var key = GrammarKey(sentence, languageCode, episodeId, modelVersion, promptVersion);
            if (key.StartsWith("grammar_", StringComparison.Ordinal))
                return key.Substring("grammar_".Length);
            return key;
        }

        /// <summary>
        /// Episode-based grammar line key used by ai_cache/grammar_by_episode/{episodeId}/{lineKey}/{lang}.
        /// </summary>
        public static string GrammarEpisodeLineKey(string sentence, int lineNumber = -1)
        {
            if (lineNumber >= 0)
                return "line_" + (lineNumber + 1);
            return "s_" + GrammarSentenceContentHash(sentence);
        }

        public static string HashString(string input)
        {
            var bytes = Encoding.UTF8.GetBytes(input ?? string.Empty);
            using (var sha = SHA256.Create())
            {
                var digest = sha.ComputeHash(bytes);
                var hex = string.Concat(digest.Select(b => b.ToString("x2")));
                return hex.Length >= 16 ? hex.Substring(0, 16) : hex;
            }
        }

        public static string SanitizeFirebaseKey(string key)
        {
            if (string.IsNullOrEmpty(key))
                return "empty";
            return key
                .Replace("$", "_dollar_")
                .Replace("#", "_hash_")
                .Replace("[", "_lbracket_")
                .Replace("]", "_rbracket_")
                .Replace("/", "_slash_")
                .Replace(".", "_dot_");
        }
    }
}
