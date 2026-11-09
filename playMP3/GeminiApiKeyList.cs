using System;
using System.Collections.Generic;

namespace playMP3
{
    /// <summary>
    /// Parse Gemini API keys separated by <c>;</c> or <c>,</c> (trim, dedupe, preserve order).
    /// Prefer semicolon: <c>key1;key2;key3</c>.
    /// </summary>
    public static class GeminiApiKeyList
    {
        public static string[] Parse(string raw)
        {
            if (string.IsNullOrWhiteSpace(raw))
                return Array.Empty<string>();

            var seen = new HashSet<string>(StringComparer.Ordinal);
            var list = new List<string>();
            foreach (var segment in raw.Split(new[] { ';', ',' }, StringSplitOptions.RemoveEmptyEntries))
            {
                var k = segment.Trim();
                if (k.Length == 0 || seen.Contains(k))
                    continue;
                seen.Add(k);
                list.Add(k);
            }

            return list.ToArray();
        }
    }
}
