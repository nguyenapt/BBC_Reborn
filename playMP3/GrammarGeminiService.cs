using System;
using System.Collections.Generic;
using System.Globalization;
using System.Net.Http;
using System.Text;
using System.Text.RegularExpressions;
using System.Threading.Tasks;
using Newtonsoft.Json;
using Newtonsoft.Json.Linq;

namespace playMP3
{
    /// <summary>Minimal Gemini generateContent call for grammar JSON (aligned with Flutter gemini_provider explainGrammar).</summary>
    public static class GrammarGeminiService
    {
        private static readonly HttpClient Http = new HttpClient { Timeout = TimeSpan.FromMinutes(2) };

        private const int MaxLoop = 20;
        private const int MaxNon429Retries = 4;
        private const int MaxQuickRetriesPerKey = 4;

        public static Task<JObject> ExplainGrammarAsync(string apiKey, string englishSentence, string targetLanguageLabel)
        {
            if (string.IsNullOrWhiteSpace(apiKey))
                throw new InvalidOperationException("GEMINI_API_KEY (or passed apiKey) is required for grammar fill.");
            return ExplainGrammarAsync(new[] { apiKey.Trim() }, englishSentence, targetLanguageLabel);
        }

        /// <summary>Multiple keys: on 429 / 401 / 403 try next key. Single key: keep long 429 backoff retries on same key.</summary>
        public static async Task<JObject> ExplainGrammarAsync(IReadOnlyList<string> apiKeys, string englishSentence, string targetLanguageLabel)
        {
            var keys = NormalizeKeys(apiKeys);
            if (keys.Count == 0)
                throw new InvalidOperationException("Cần ít nhất một Gemini API key hợp lệ.");

            if (keys.Count == 1)
                return await ExplainGrammarSingleKeyWith429RetryAsync(keys[0], englishSentence, targetLanguageLabel).ConfigureAwait(false);

            var prompt = BuildPrompt(englishSentence, targetLanguageLabel);
            var bodyObj = BuildRequestBody(prompt);
            string lastDetail = null;

            for (var ki = 0; ki < keys.Count; ki++)
            {
                var key = keys[ki];
                var url = BuildGeminiUrl(key);

                for (var attempt = 0; attempt < MaxQuickRetriesPerKey; attempt++)
                {
                    var content = new StringContent(bodyObj.ToString(Formatting.None), Encoding.UTF8, "application/json");
                    var resp = await Http.PostAsync(url, content).ConfigureAwait(false);
                    var respText = await resp.Content.ReadAsStringAsync().ConfigureAwait(false);
                    var code = (int)resp.StatusCode;

                    if (code == 429)
                    {
                        lastDetail = FormatGeminiHttpError(429, respText);
                        await Task.Delay(300).ConfigureAwait(false);
                        break;
                    }

                    if (code == 400 || code == 401 || code == 403)
                    {
                        lastDetail = FormatGeminiHttpError(code, respText);
                        break;
                    }

                    if (!resp.IsSuccessStatusCode)
                    {
                        if (attempt + 1 >= MaxQuickRetriesPerKey)
                        {
                            lastDetail = FormatGeminiHttpError(code, respText);
                            break;
                        }

                        await Task.Delay(500 * (attempt + 1)).ConfigureAwait(false);
                        continue;
                    }

                    try
                    {
                        return ExtractGrammarFromGenerateContentResponse(respText);
                    }
                    catch (JsonException jx)
                    {
                        lastDetail = jx.Message;
                        if (attempt + 1 >= MaxQuickRetriesPerKey)
                            break;
                        await Task.Delay(500).ConfigureAwait(false);
                    }
                    catch (InvalidOperationException ex)
                    {
                        lastDetail = ex.Message;
                        if (attempt + 1 >= MaxQuickRetriesPerKey)
                            break;
                        await Task.Delay(500).ConfigureAwait(false);
                    }
                }
            }

            throw new InvalidOperationException(
                "Tất cả " + keys.Count + " API key đều thất bại (quota hoặc lỗi)." + (lastDetail != null ? " " + lastDetail : string.Empty));
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

        private static JObject ExtractGrammarFromGenerateContentResponse(string respText)
        {
            var root = JObject.Parse(respText);
            var text = root["candidates"]?[0]?["content"]?["parts"]?[0]?["text"]?.ToString();
            if (string.IsNullOrWhiteSpace(text))
                throw new InvalidOperationException("Gemini không trả về nội dung text (có thể bị chặn nội dung hoặc lỗi model).");

            text = StripMarkdownJsonFence(text.Trim());
            return ParseGrammarJson(text);
        }

        private static async Task<JObject> ExplainGrammarSingleKeyWith429RetryAsync(
            string apiKey,
            string englishSentence,
            string targetLanguageLabel)
        {
            var prompt = BuildPrompt(englishSentence, targetLanguageLabel);
            var bodyObj = BuildRequestBody(prompt);
            var url = BuildGeminiUrl(apiKey);
            var non429Failures = 0;

            for (var i = 0; i < MaxLoop; i++)
            {
                var content = new StringContent(bodyObj.ToString(Formatting.None), Encoding.UTF8, "application/json");
                var resp = await Http.PostAsync(url, content).ConfigureAwait(false);
                var respText = await resp.Content.ReadAsStringAsync().ConfigureAwait(false);
                var code = (int)resp.StatusCode;

                if (code == 429)
                {
                    var waitMs = Math.Min(120_000, Math.Max(5_000, TryGetRetryMillisecondsFromGemini429Body(respText)));
                    await Task.Delay(waitMs).ConfigureAwait(false);
                    continue;
                }

                if (!resp.IsSuccessStatusCode)
                {
                    non429Failures++;
                    if (non429Failures >= MaxNon429Retries)
                        throw new InvalidOperationException(FormatGeminiHttpError(code, respText));
                    await Task.Delay(600 * non429Failures).ConfigureAwait(false);
                    continue;
                }

                try
                {
                    return ExtractGrammarFromGenerateContentResponse(respText);
                }
                catch (JsonException)
                {
                    non429Failures++;
                    if (non429Failures >= MaxNon429Retries)
                        throw new InvalidOperationException("Gemini trả về JSON không hợp lệ (không parse được phản hồi).");
                    await Task.Delay(500).ConfigureAwait(false);
                }
                catch (InvalidOperationException)
                {
                    non429Failures++;
                    if (non429Failures >= MaxNon429Retries)
                        throw;
                    await Task.Delay(500).ConfigureAwait(false);
                }
            }

            throw new InvalidOperationException("Gemini 429: đã chờ nhiều lần vẫn hết quota / quá giới hạn. Thử lại sau vài phút hoặc kiểm tra billing/plan.");
        }

        /// <summary>Parse retry hint from Gemini RESOURCE_EXHAUSTED body; default ~65s.</summary>
        internal static int TryGetRetryMillisecondsFromGemini429Body(string respText)
        {
            if (string.IsNullOrWhiteSpace(respText))
                return 65_000;
            try
            {
                var jo = JObject.Parse(respText);
                var msg = jo["error"]?["message"]?.ToString() ?? "";
                var m = Regex.Match(msg, @"retry in\s+([\d.]+)\s*s", RegexOptions.IgnoreCase);
                if (m.Success && double.TryParse(m.Groups[1].Value, NumberStyles.Any, CultureInfo.InvariantCulture, out var sec))
                    return (int)Math.Ceiling(sec * 1000) + 1500;

                var details = jo["error"]?["details"] as JArray;
                if (details != null)
                {
                    foreach (var d in details)
                    {
                        var rd = d["retryDelay"]?.ToString();
                        if (string.IsNullOrEmpty(rd))
                            continue;
                        var m2 = Regex.Match(rd, @"^([\d.]+)s?\s*$", RegexOptions.IgnoreCase);
                        if (m2.Success && double.TryParse(m2.Groups[1].Value, NumberStyles.Any, CultureInfo.InvariantCulture, out var sec2))
                            return (int)Math.Ceiling(sec2 * 1000) + 1500;
                    }
                }
            }
            catch
            {
                // ignore
            }

            return 65_000;
        }

        internal static string FormatGeminiHttpError(int statusCode, string respText)
        {
            var shortMsg = "HTTP " + statusCode;
            try
            {
                var jo = JObject.Parse(respText);
                var em = jo["error"]?["message"]?.ToString();
                if (!string.IsNullOrWhiteSpace(em))
                {
                    var one = em.Replace("\r\n", " ").Replace("\n", " ").Trim();
                    if (one.Length > 220)
                        one = one.Substring(0, 217) + "...";
                    shortMsg += ": " + one;
                    return "Gemini " + shortMsg;
                }
            }
            catch
            {
                // ignore
            }

            return "Gemini " + shortMsg + " (xem console/network để biết chi tiết).";
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

        private static JObject ParseGrammarJson(string text)
        {
            try
            {
                return JObject.Parse(text);
            }
            catch (JsonException ex)
            {
                throw new InvalidOperationException("Invalid grammar JSON: " + ex.Message + "\n" + text, ex);
            }
        }

        private static string BuildPrompt(string sentence, string targetLanguageLabel)
        {
            return @"Analyze this English sentence for learning purposes.
You MUST return ONLY a valid JSON object, no markdown, no explanations, no other text.

Sentence: """ + sentence.Replace("\"", "\\\"") + @"""

Return format (JSON object only):
{
  ""grammarPoint"": ""name of grammar rule (short)"",
  ""rulePattern"": ""concise pattern, e.g. Subject + have/has + V3"",
  ""whyThisForm"": ""why this form is used in this sentence, in " + targetLanguageLabel + @""",
  ""explanation"": ""clear explanation in " + targetLanguageLabel + @""",
  ""highlightedWords"": [""word_or_phrase_1"", ""word_or_phrase_2""],
  ""commonMistakes"": [""mistake 1 in " + targetLanguageLabel + @""", ""mistake 2 in " + targetLanguageLabel + @"""]
}

Rules:
- Keep explanations practical and concise.
- ""highlightedWords"" must be exact fragments from the input sentence.
- Do NOT include quizzes, exercises, or multiple-choice questions.
- If uncertain, still return best-effort pedagogical output.
Important: Return ONLY the JSON object, nothing else.";
        }

        /// <summary>Merge API fields with sentence for Flutter GrammarExplanation.fromJson.</summary>
        public static JObject ToFlutterGrammarData(JObject apiResponse, string englishSentence)
        {
            var o = (JObject)apiResponse.DeepClone();
            o["sentence"] = englishSentence ?? "";
            if (o["highlightedWords"] == null || o["highlightedWords"].Type == JTokenType.Null)
                o["highlightedWords"] = new JArray();
            if (o["commonMistakes"] == null || o["commonMistakes"].Type == JTokenType.Null)
                o["commonMistakes"] = new JArray();
            if (string.IsNullOrWhiteSpace(o["grammarPoint"]?.ToString()))
                o["grammarPoint"] = "Grammar Pattern";
            if (string.IsNullOrWhiteSpace(o["explanation"]?.ToString()))
                o["explanation"] = "";
            return o;
        }
    }
}
