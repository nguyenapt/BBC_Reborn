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
            return await RunGrammarPromptAsync(apiKeys, BuildPrompt(englishSentence, targetLanguageLabel)).ConfigureAwait(false);
        }

        /// <summary>
        /// Single-shot passage grammar (overall + sentenceAnalyses in one call).
        /// Used by playMP3 to prewarm cache without Flutter's progressive 2-request split.
        /// </summary>
        public static Task<JObject> ExplainGrammarPassageAsync(string apiKey, string passage, string targetLanguageLabel)
        {
            if (string.IsNullOrWhiteSpace(apiKey))
                throw new InvalidOperationException("GEMINI_API_KEY (or passed apiKey) is required for grammar passage fill.");
            return ExplainGrammarPassageAsync(new[] { apiKey.Trim() }, passage, targetLanguageLabel);
        }

        public static async Task<JObject> ExplainGrammarPassageAsync(
            IReadOnlyList<string> apiKeys,
            string passage,
            string targetLanguageLabel)
        {
            return await RunGrammarPromptAsync(apiKeys, BuildPassagePrompt(passage, targetLanguageLabel)).ConfigureAwait(false);
        }

        /// <summary>
        /// Translate learner-facing fields of a canonical English grammar JSON into
        /// <paramref name="targetLanguageLabel"/>. Quotes from the transcript stay English.
        /// </summary>
        public static async Task<JObject> TranslateGrammarPassageJsonAsync(
            IReadOnlyList<string> apiKeys,
            JObject englishJson,
            string targetLanguageLabel)
        {
            if (englishJson == null)
                throw new ArgumentNullException(nameof(englishJson));
            var raw = await RunGrammarPromptAsync(
                apiKeys,
                BuildTranslateGrammarJsonPrompt(englishJson, targetLanguageLabel)).ConfigureAwait(false);
            return MergeTranslatedGrammarJson(englishJson, raw);
        }

        private static async Task<JObject> RunGrammarPromptAsync(IReadOnlyList<string> apiKeys, string prompt)
        {
            var keys = NormalizeKeys(apiKeys);
            if (keys.Count == 0)
                throw new InvalidOperationException("Cần ít nhất một Gemini API key hợp lệ.");

            if (keys.Count == 1)
                return await ExplainGrammarSingleKeyWith429RetryAsync(keys[0], prompt).ConfigureAwait(false);

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

        private static async Task<JObject> ExplainGrammarSingleKeyWith429RetryAsync(string apiKey, string prompt)
        {
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

        /// <summary>Slim passage schema — aligned with Flutter gemini_provider.explainGrammarPassage.</summary>
        private static string BuildPassagePrompt(string passage, string targetLanguageLabel)
        {
            return @"Analyze this English passage for grammar learning.
You MUST return ONLY a valid JSON object, no markdown, no explanations, no other text.

Passage: """ + (passage ?? "").Replace("\"", "\\\"") + @"""

Return format (JSON object only, slim):
{
  ""overall"": {
    ""grammarTheme"": ""main grammar theme in this passage"",
    ""usageSummary"": ""concise summary in " + targetLanguageLabel + @""",
    ""keyStructures"": [""structure1"", ""structure2""]
  },
  ""sentenceAnalyses"": [
    {
      ""sentenceText"": ""exact sentence from passage"",
      ""mainStructure"": ""main grammar structure"",
      ""usageInContext"": ""contextual usage in " + targetLanguageLabel + @""",
      ""phraseBreakdown"": [
        {
          ""phrase"": ""exact phrase from sentence"",
          ""structure"": ""phrase structure"",
          ""usage"": ""phrase usage in " + targetLanguageLabel + @"""
        }
      ],
      ""examples"": [""example 1"", ""example 2""],
      ""commonMistakes"": [""mistake 1"", ""mistake 2""]
    }
  ]
}

Rules:
- Keep output concise and learner-friendly in " + targetLanguageLabel + @".
- phraseBreakdown is optional; include only important grammar-bearing phrases.
- Cover each meaningful sentence (a single-line passage may have one analysis).
Important: Return ONLY the JSON object, nothing else.";
        }

        /// <summary>
        /// Translate pedagogical fields; keep transcript quotes identical to English JSON.
        /// </summary>
        private static string BuildTranslateGrammarJsonPrompt(JObject englishJson, string targetLanguageLabel)
        {
            var json = (englishJson ?? new JObject()).ToString(Formatting.None);
            return @"Translate the LEARNER-FACING fields of this English grammar JSON into " + targetLanguageLabel + @".
You MUST return ONLY a valid JSON object with the SAME schema and the SAME array lengths.

KEEP these fields EXACTLY as in the input (English quotes from the transcript):
- sentence, passageText, sentenceText
- highlightedWords (array of exact fragments)
- phrase (inside each phraseBreakdown item)
- examples (keep English example sentences)

TRANSLATE into " + targetLanguageLabel + @":
- grammarPoint, explanation, whyThisForm, rulePattern
- overall.grammarTheme, overall.usageSummary, overall.keyStructures
- mainStructure, usageInContext, structure, usage
- commonMistakes, rewriteExercise

Do not add or remove sentenceAnalyses or phraseBreakdown items.
Do not invent new quotes from the transcript.

English JSON:
" + json + @"

JSON object only:";
        }

        /// <summary>
        /// Force transcript quotes from the English canonical JSON onto the translation.
        /// </summary>
        public static JObject MergeTranslatedGrammarJson(JObject english, JObject translated)
        {
            if (english == null)
                return translated ?? new JObject();
            var result = (JObject)(translated ?? english).DeepClone();
            CopyToken(result, english, "sentence");
            CopyToken(result, english, "passageText");
            CopyToken(result, english, "highlightedWords");

            var enAnalyses = english["sentenceAnalyses"] as JArray;
            if (enAnalyses != null)
            {
                var trAnalyses = result["sentenceAnalyses"] as JArray ?? new JArray();
                result["sentenceAnalyses"] = trAnalyses;
                while (trAnalyses.Count < enAnalyses.Count)
                    trAnalyses.Add(enAnalyses[trAnalyses.Count].DeepClone());
                while (trAnalyses.Count > enAnalyses.Count)
                    trAnalyses.RemoveAt(trAnalyses.Count - 1);

                for (var i = 0; i < enAnalyses.Count; i++)
                {
                    var enA = enAnalyses[i] as JObject;
                    var trA = trAnalyses[i] as JObject;
                    if (enA == null)
                        continue;
                    if (trA == null)
                    {
                        trAnalyses[i] = enA.DeepClone();
                        continue;
                    }
                    CopyToken(trA, enA, "sentenceText");
                    CopyToken(trA, enA, "examples");
                    var enPhrases = enA["phraseBreakdown"] as JArray;
                    if (enPhrases == null)
                        continue;
                    var trPhrases = trA["phraseBreakdown"] as JArray ?? new JArray();
                    trA["phraseBreakdown"] = trPhrases;
                    while (trPhrases.Count < enPhrases.Count)
                        trPhrases.Add(enPhrases[trPhrases.Count].DeepClone());
                    while (trPhrases.Count > enPhrases.Count)
                        trPhrases.RemoveAt(trPhrases.Count - 1);
                    for (var j = 0; j < enPhrases.Count; j++)
                    {
                        var enPh = enPhrases[j] as JObject;
                        var trPh = trPhrases[j] as JObject;
                        if (enPh == null)
                            continue;
                        if (trPh == null)
                        {
                            trPhrases[j] = enPh.DeepClone();
                            continue;
                        }
                        CopyToken(trPh, enPh, "phrase");
                    }
                }
            }

            return result;
        }

        private static void CopyToken(JObject dest, JObject source, string name)
        {
            var t = source[name];
            if (t != null)
                dest[name] = t.DeepClone();
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

        /// <summary>
        /// Map single-shot passage JSON to Flutter GrammarExplanation shape
        /// (overall + sentenceAnalyses, plus top-level grammarPoint/explanation for display).
        /// Does not write sentence-only schema into grammar_by_episode.
        /// </summary>
        public static JObject ToFlutterGrammarPassageData(JObject apiResponse, string passage)
        {
            var src = apiResponse ?? new JObject();
            var overall = src["overall"] as JObject ?? new JObject();
            var analyses = src["sentenceAnalyses"] as JArray ?? new JArray();
            var theme = overall["grammarTheme"]?.ToString();
            if (string.IsNullOrWhiteSpace(theme))
                theme = "Grammar Overview";
            var usage = overall["usageSummary"]?.ToString() ?? "";
            if (string.IsNullOrWhiteSpace(usage))
                usage = theme; // old apps require non-empty explanation
            if (overall["keyStructures"] == null || overall["keyStructures"].Type == JTokenType.Null)
                overall["keyStructures"] = new JArray();
            overall["grammarTheme"] = theme;
            overall["usageSummary"] = usage;

            var first = analyses.Count > 0 ? analyses[0] as JObject : null;
            var highlighted = new JArray();
            var commonMistakes = new JArray();
            if (first != null)
            {
                var phrases = first["phraseBreakdown"] as JArray;
                if (phrases != null)
                {
                    foreach (var p in phrases)
                    {
                        var phrase = (p as JObject)?["phrase"]?.ToString();
                        if (!string.IsNullOrWhiteSpace(phrase))
                            highlighted.Add(phrase.Trim());
                    }
                }
                var mistakes = first["commonMistakes"] as JArray;
                if (mistakes != null)
                {
                    foreach (var m in mistakes)
                    {
                        var s = m?.ToString();
                        if (!string.IsNullOrWhiteSpace(s))
                            commonMistakes.Add(s.Trim());
                    }
                }
            }

            return new JObject
            {
                ["sentence"] = passage ?? "",
                ["passageText"] = passage ?? "",
                ["grammarPoint"] = theme,
                ["explanation"] = usage,
                ["highlightedWords"] = highlighted,
                ["overall"] = overall,
                ["sentenceAnalyses"] = analyses,
                ["rulePattern"] = first?["mainStructure"]?.ToString() ?? "",
                ["whyThisForm"] = first?["usageInContext"]?.ToString() ?? "",
                ["commonMistakes"] = commonMistakes,
            };
        }
    }
}
