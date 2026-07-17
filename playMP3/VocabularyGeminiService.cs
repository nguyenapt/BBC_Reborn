using System;
using System.Collections.Generic;
using System.Globalization;
using System.Net.Http;
using System.Text;
using System.Threading.Tasks;
using Newtonsoft.Json;
using Newtonsoft.Json.Linq;

namespace playMP3
{
    /// <summary>Gemini generateContent for EN vocabulary JSON + meaning translation; locale grids reuse EN JSON unchanged.</summary>
    public static class VocabularyGeminiService
    {
        private static readonly HttpClient Http = new HttpClient { Timeout = TimeSpan.FromMinutes(2) };

        private const int MaxLoop = 20;
        private const int MaxNon429Retries = 4;
        private const int MaxQuickRetriesPerKey = 4;

        public static Task<string> EnhanceVocabularyJsonAsync(string apiKey, string word, string meaning)
        {
            return EnhanceVocabularyJsonAsync(new[] { apiKey.Trim() }, word, meaning);
        }

        public static async Task<string> EnhanceVocabularyJsonAsync(IReadOnlyList<string> apiKeys, string word, string meaning)
        {
            var prompt = BuildEnhancePrompt(word ?? "", meaning ?? "");
            return await RunPromptPlainAsync(apiKeys, prompt).ConfigureAwait(false);
        }

        /// <summary>
        /// Gợi ý vocabulary từ transcript tiếng Anh — mỗi phần tử là (word, English meaning gloss).
        /// </summary>
        public static async Task<List<Tuple<string, string>>> ExtractVocabularyFromTranscriptAsync(
            IReadOnlyList<string> apiKeys,
            string transcript,
            int count)
        {
            if (count < 1)
                count = 1;

            var prompt = BuildExtractFromTranscriptPrompt(transcript ?? "", count);
            var raw = await RunPromptPlainAsync(apiKeys, prompt).ConfigureAwait(false);
            return ParseExtractedVocabulary(raw, count);
        }

        private static string BuildExtractFromTranscriptPrompt(string transcript, int count)
        {
            var esc = (transcript ?? "").Replace("\"", "\\\"");
            return @"From this English learning transcript, extract up to " + count.ToString(CultureInfo.InvariantCulture) + @" vocabulary words or short phrases for English learners.

CRITICAL — topic relevance:
- Infer the main topic/theme of the article from the transcript.
- Every selected word/phrase MUST be clearly related to that topic (topic-specific terms, key concepts, domain vocabulary used in the piece).
- Do NOT pick random ""useful"" words that are only generic English (e.g. everyday verbs/adverbs) unless they are central to the article's subject.
- Prefer words/phrases that actually appear in the transcript (or their dictionary lemma) and help learners understand this specific content.

Also focus on less-common words, idioms, and phrasal verbs when they support the topic. Avoid ultra-basic words (a, the, is, are, and, to, of…).
You MUST return ONLY a valid JSON array, no markdown, no explanations, no other text.

Transcript: """ + esc + @"""

Return format (JSON array only):
[
  { ""word"": ""example word or phrase"", ""meaning"": ""short English definition/gloss"" }
]

Important:
- Return at most " + count.ToString(CultureInfo.InvariantCulture) + @" items.
- ""word"" must be the English lemma/phrase as it appears or its dictionary form, and topic-relevant.
- ""meaning"" must be a concise English gloss (not a translation into another language).
- Return ONLY the JSON array, nothing else.";
        }

        private static List<Tuple<string, string>> ParseExtractedVocabulary(string raw, int maxCount)
        {
            var list = new List<Tuple<string, string>>();
            var trimmed = StripMarkdownJsonFence((raw ?? "").Trim()).Trim();
            var token = JToken.Parse(trimmed);
            if (!(token is JArray arr))
                throw new InvalidOperationException("Vocab from transcript: Gemini không trả về JSON array.");

            var seen = new HashSet<string>(StringComparer.OrdinalIgnoreCase);
            foreach (var item in arr)
            {
                if (list.Count >= maxCount)
                    break;

                string word = null;
                string meaning = null;
                if (item is JObject jo)
                {
                    word = (jo["word"] ?? jo["text"] ?? jo["vocab"] ?? jo["lemma"])?.ToString();
                    meaning = (jo["meaning"] ?? jo["mean"] ?? jo["definition"] ?? jo["gloss"])?.ToString();
                }
                else if (item is JArray pair && pair.Count >= 1)
                {
                    word = pair[0]?.ToString();
                    meaning = pair.Count >= 2 ? pair[1]?.ToString() : "";
                }
                else if (item is JValue jv)
                {
                    word = jv.ToString();
                    meaning = "";
                }

                word = (word ?? "").Trim();
                meaning = (meaning ?? "").Trim();
                if (word.Length == 0)
                    continue;
                if (!seen.Add(word))
                    continue;

                list.Add(Tuple.Create(word, meaning));
            }

            return list;
        }

        public static Task<string> TranslateMeaningAsync(IReadOnlyList<string> apiKeys, string englishMeaning, string targetLanguageLabel)
        {
            var prompt = @"Translate the following English vocabulary definition/gloss into " + targetLanguageLabel + @".
Return ONLY the translation text, no quotes, no explanations.

English meaning:
""" + (englishMeaning ?? "").Replace("\"", "\\\"") + @"""

Translation:";
            return RunPromptPlainAsync(apiKeys, prompt);
        }

        /// <summary>One Gemini call per target language: map 1..n English glosses to translated text.</summary>
        public static async Task<Dictionary<int, string>> TranslateMeaningsBatchAsync(
            IReadOnlyList<string> apiKeys,
            IReadOnlyList<Tuple<string, string>> lemmaMeaningPairs,
            string targetLanguageLabel)
        {
            if (lemmaMeaningPairs == null || lemmaMeaningPairs.Count == 0)
                return new Dictionary<int, string>();

            var sb = new StringBuilder();
            for (var i = 0; i < lemmaMeaningPairs.Count; i++)
            {
                var lemma = lemmaMeaningPairs[i].Item1 ?? "";
                var mean = lemmaMeaningPairs[i].Item2 ?? "";
                sb.Append((i + 1).ToString(CultureInfo.InvariantCulture));
                sb.Append(". Word: \"");
                sb.Append(lemma.Replace("\"", "\\\""));
                sb.Append("\" Meaning: \"");
                sb.Append(mean.Replace("\"", "\\\""));
                sb.AppendLine("\"");
            }

            var prompt = @"Translate ONLY each English ""Meaning"" gloss below into " + targetLanguageLabel + @".
The Word is context only — do NOT translate the Word into " + targetLanguageLabel + @" as the main output; output must be the translated gloss only.

Return ONLY a valid JSON object: keys are ""1"", ""2"", ... matching item numbers; values are the translated gloss strings.
If a Meaning is empty, use """" for that key.

Items:
" + sb + @"

JSON object only:";

            var raw = await RunPromptPlainAsync(apiKeys, prompt).ConfigureAwait(false);
            return ParseMeaningBatchJson(raw, lemmaMeaningPairs.Count);
        }

        private static Dictionary<int, string> ParseMeaningBatchJson(string raw, int expectedCount)
        {
            var dict = new Dictionary<int, string>();
            var trimmed = StripMarkdownJsonFence((raw ?? "").Trim()).Trim();
            var token = JToken.Parse(trimmed);

            if (token is JObject jo)
            {
                foreach (var p in jo.Properties())
                {
                    if (int.TryParse(p.Name, NumberStyles.Integer, CultureInfo.InvariantCulture, out var idx))
                        dict[idx] = p.Value?.ToString() ?? "";
                }
            }
            else if (token is JArray arr)
            {
                for (var i = 0; i < arr.Count; i++)
                    dict[i + 1] = arr[i]?.ToString() ?? "";
            }
            else
                throw new InvalidOperationException("Batch meaning: JSON không phải object/array.");

            for (var k = 1; k <= expectedCount; k++)
            {
                if (!dict.ContainsKey(k))
                    dict[k] = "";
            }

            return dict;
        }

        private static string BuildEnhancePrompt(string word, string meaning)
        {
            return @"Enhance this English vocabulary with additional information.
You MUST return ONLY a valid JSON object, no markdown, no explanations, no other text.

Word: """ + word.Replace("\"", "\\\"") + @"""
Meaning: """ + meaning.Replace("\"", "\\\"") + @"""

Return format (JSON object only):
{
  ""synonyms"": [""word1"", ""word2""],
  ""antonyms"": [""word3""],
  ""exampleSentences"": [""sentence1"", ""sentence2""],
  ""collocations"": [""collocation1"", ""collocation2""],
  ""pronunciation"": ""/pronunciation/"",
  ""wordForm"": ""noun""
}

Important: Return ONLY the JSON object, nothing else.";
        }

        private static async Task<string> RunPromptPlainAsync(IReadOnlyList<string> apiKeys, string prompt)
        {
            var keys = NormalizeKeys(apiKeys);
            if (keys.Count == 0)
                throw new InvalidOperationException("Cần ít nhất một Gemini API key hợp lệ.");

            if (keys.Count == 1)
                return await RunPromptSingleKeyAsync(keys[0], prompt).ConfigureAwait(false);

            var bodyObj = BuildRequestBody(prompt);
            var body = bodyObj.ToString(Formatting.None);
            string lastDetail = null;

            for (var ki = 0; ki < keys.Count; ki++)
            {
                var key = keys[ki];
                var url = BuildGeminiUrl(key);

                for (var attempt = 0; attempt < MaxQuickRetriesPerKey; attempt++)
                {
                    var content = new StringContent(body, Encoding.UTF8, "application/json");
                    var resp = await Http.PostAsync(url, content).ConfigureAwait(false);
                    var respText = await resp.Content.ReadAsStringAsync().ConfigureAwait(false);
                    var code = (int)resp.StatusCode;

                    if (code == 429)
                    {
                        lastDetail = GrammarGeminiService.FormatGeminiHttpError(429, respText);
                        await Task.Delay(300).ConfigureAwait(false);
                        break;
                    }

                    if (code == 400 || code == 401 || code == 403)
                    {
                        lastDetail = GrammarGeminiService.FormatGeminiHttpError(code, respText);
                        break;
                    }

                    if (!resp.IsSuccessStatusCode)
                    {
                        if (attempt + 1 >= MaxQuickRetriesPerKey)
                        {
                            lastDetail = GrammarGeminiService.FormatGeminiHttpError(code, respText);
                            break;
                        }

                        await Task.Delay(500 * (attempt + 1)).ConfigureAwait(false);
                        continue;
                    }

                    try
                    {
                        return ExtractPlainText(respText);
                    }
                    catch (Exception ex)
                    {
                        lastDetail = ex.Message;
                        if (attempt + 1 >= MaxQuickRetriesPerKey)
                            break;
                        await Task.Delay(500).ConfigureAwait(false);
                    }
                }
            }

            throw new InvalidOperationException(
                "Tất cả " + keys.Count + " API key đều thất bại." + (lastDetail != null ? " " + lastDetail : string.Empty));
        }

        private static async Task<string> RunPromptSingleKeyAsync(string apiKey, string prompt)
        {
            var bodyObj = BuildRequestBody(prompt);
            var body = bodyObj.ToString(Formatting.None);
            var url = BuildGeminiUrl(apiKey);
            var non429Failures = 0;

            for (var i = 0; i < MaxLoop; i++)
            {
                var content = new StringContent(body, Encoding.UTF8, "application/json");
                var resp = await Http.PostAsync(url, content).ConfigureAwait(false);
                var respText = await resp.Content.ReadAsStringAsync().ConfigureAwait(false);
                var code = (int)resp.StatusCode;

                if (code == 429)
                {
                    var waitMs = Math.Min(120_000, Math.Max(5_000, GrammarGeminiService.TryGetRetryMillisecondsFromGemini429Body(respText)));
                    await Task.Delay(waitMs).ConfigureAwait(false);
                    continue;
                }

                if (!resp.IsSuccessStatusCode)
                {
                    non429Failures++;
                    if (non429Failures >= MaxNon429Retries)
                        throw new InvalidOperationException(GrammarGeminiService.FormatGeminiHttpError(code, respText));
                    await Task.Delay(600 * non429Failures).ConfigureAwait(false);
                    continue;
                }

                try
                {
                    return ExtractPlainText(respText);
                }
                catch (Exception)
                {
                    non429Failures++;
                    if (non429Failures >= MaxNon429Retries)
                        throw;
                    await Task.Delay(500).ConfigureAwait(false);
                }
            }

            throw new InvalidOperationException("Gemini 429: đã chờ nhiều lần vẫn hết quota.");
        }

        private static string ExtractPlainText(string respText)
        {
            var root = JObject.Parse(respText);
            var text = root["candidates"]?[0]?["content"]?["parts"]?[0]?["text"]?.ToString();
            if (string.IsNullOrWhiteSpace(text))
                throw new InvalidOperationException("Gemini không trả về nội dung text.");
            return StripMarkdownJsonFence(text.Trim()).Trim();
        }

        private static string StripMarkdownJsonFence(string t)
        {
            if (t.StartsWith("```", StringComparison.Ordinal))
            {
                var firstNl = t.IndexOf('\n');
                if (firstNl > 0)
                    t = t.Substring(firstNl + 1);
                var end = t.LastIndexOf("```", StringComparison.Ordinal);
                if (end >= 0)
                    t = t.Substring(0, end).Trim();
            }

            return t.Trim();
        }

        private static List<string> NormalizeKeys(IReadOnlyList<string> apiKeys)
        {
            var r = new List<string>();
            var seen = new HashSet<string>(StringComparer.Ordinal);
            foreach (var k in apiKeys)
            {
                if (string.IsNullOrWhiteSpace(k))
                    continue;
                var t = k.Trim();
                if (seen.Contains(t))
                    continue;
                seen.Add(t);
                r.Add(t);
            }

            return r;
        }

        private static JObject BuildRequestBody(string prompt)
        {
            return new JObject
            {
                ["contents"] = new JArray
                {
                    new JObject
                    {
                        ["parts"] = new JArray { new JObject { ["text"] = prompt } },
                    },
                },
            };
        }

        private static string BuildGeminiUrl(string apiKey)
        {
            return "https://generativelanguage.googleapis.com/v1beta/models/" + GrammarCacheConstants.GeminiModelId
                   + ":generateContent?key=" + Uri.EscapeDataString(apiKey);
        }
    }
}
