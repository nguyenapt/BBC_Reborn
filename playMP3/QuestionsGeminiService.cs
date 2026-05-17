using System;
using System.Collections.Generic;
using System.Net.Http;
using System.Text;
using System.Threading.Tasks;
using Newtonsoft.Json;
using Newtonsoft.Json.Linq;
using playMP3.Base;

namespace playMP3
{
    /// <summary>Gemini generateContent for transcript quiz JSON array — aligned with Flutter <c>GeminiProvider.generateQuestions</c>.</summary>
    public static class QuestionsGeminiService
    {
        private static readonly HttpClient Http = new HttpClient { Timeout = TimeSpan.FromMinutes(2) };

        private const int MaxLoop = 20;
        private const int MaxNon429Retries = 4;
        private const int MaxQuickRetriesPerKey = 4;

        public static async Task<List<QuestionGridRowModel>> GenerateQuestionsAsync(
            IReadOnlyList<string> apiKeys,
            string transcript,
            int count)
        {
            if (count < 1)
                count = 1;

            var prompt = BuildQuestionsPrompt(transcript ?? "", count);
            var raw = await RunPromptPlainAsync(apiKeys, prompt).ConfigureAwait(false);
            var trimmed = StripMarkdownJsonFence((raw ?? "").Trim()).Trim();
            var token = JToken.Parse(trimmed);
            if (!(token is JArray arr))
                throw new InvalidOperationException("Questions: Gemini không trả về JSON array.");

            var list = new List<QuestionGridRowModel>();
            for (var i = 0; i < arr.Count; i++)
            {
                try
                {
                    list.Add(QuestionGridRowModel.FromAiObject(arr[i]));
                }
                catch
                {
                    // bỏ phần tử lỗi, giữ các câu khác
                }
            }

            return list;
        }

        private static string BuildQuestionsPrompt(string transcript, int count)
        {
            var esc = (transcript ?? "").Replace("\"", "\\\"");
            return @"Generate exactly " + count + @" English learning questions from this transcript.
You MUST return ONLY a valid JSON array, no markdown, no explanations, no other text.

Transcript: """ + esc + @"""

Return format (JSON array only):
[
  {
    ""type"": ""multipleChoice"",
    ""question"": ""question text"",
    ""options"": [""option A"", ""option B"", ""option C"", ""option D""],
    ""correctAnswer"": ""option A"",
    ""explanation"": ""why this is correct""
  }
]

Important: Return ONLY the JSON array, nothing else.";
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
                var tr = k.Trim();
                if (seen.Contains(tr))
                    continue;
                seen.Add(tr);
                r.Add(tr);
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
