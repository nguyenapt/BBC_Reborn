using System;
using System.Collections.Generic;
using System.Threading;

namespace playMP3
{
    /// <summary>
    /// Process-wide round-robin start index for Gemini API keys.
    /// Each logical request takes the next start slot once; on failure the caller
    /// walks remaining keys via <see cref="EnumerateFrom"/> (wrap-around).
    /// </summary>
    public static class GeminiApiKeyRotator
    {
        private static int _next;

        /// <summary>
        /// Returns the start index for this request and advances the cursor for the next request.
        /// </summary>
        public static int TakeStartIndex(int keyCount)
        {
            if (keyCount <= 0)
                throw new ArgumentOutOfRangeException(nameof(keyCount));
            if (keyCount == 1)
                return 0;

            var raw = Interlocked.Increment(ref _next) - 1;
            // Avoid negative modulo if _next wraps to int.MinValue after long runs.
            var mod = raw % keyCount;
            return mod < 0 ? mod + keyCount : mod;
        }

        /// <summary>
        /// Yields keys starting at <paramref name="startIndex"/>, wrapping until all keys are tried once.
        /// </summary>
        public static IEnumerable<string> EnumerateFrom(IReadOnlyList<string> keys, int startIndex)
        {
            if (keys == null || keys.Count == 0)
                yield break;

            var n = keys.Count;
            var start = ((startIndex % n) + n) % n;
            for (var i = 0; i < n; i++)
                yield return keys[(start + i) % n];
        }

#if DEBUG
        /// <summary>Test helper — reset cursor between smoke checks.</summary>
        internal static void ResetForTests()
        {
            Interlocked.Exchange(ref _next, 0);
        }
#endif
    }
}
