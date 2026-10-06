using System;
using System.Collections.Generic;
using System.Net.Http;
using System.Text;
using System.Threading.Tasks;
using Newtonsoft.Json;
using Newtonsoft.Json.Linq;

namespace playMP3
{
    /// <summary>
    /// Gemini deepen fill for playMP3 — prompts aligned with functions/ai/prompts.js deepen builders.
    /// Reuses the same HTTP/retry pattern as <see cref="GrammarGeminiService"/>.
    /// </summary>
    public static class DeepenGeminiService
    {
        private static readonly HttpClient Http = new HttpClient { Timeout = TimeSpan.FromMinutes(2) };

        private const int MaxQuickRetriesPerKey = 4;

        public static Task<JObject> DeepenAsync(
            IReadOnlyList<string> apiKeys,
            string featureKey,
            string englishSentence,
            string targetLanguageLabel,
            string surroundingContext = null)
        {
            var prompt = BuildPrompt(featureKey, englishSentence, targetLanguageLabel, surroundingContext);
            return RunPromptAsync(apiKeys, prompt);
        }

        private static string BuildPrompt(
            string featureKey,
            string text,
            string targetLanguage,
            string context)
        {
            var ctx = string.IsNullOrWhiteSpace(context)
                ? ""
                : "\n\nSurrounding context (for accuracy only; focus on the line):\n" + context.Trim();

            switch ((featureKey ?? "").Trim().ToLowerInvariant())
            {
                case "paraphrase":
                    return "You help English learners expand how to say the same idea.\n"
                        + "Return ONLY a valid JSON object. No markdown.\n\n"
                        + "Line: \"" + text + "\"\n"
                        + "Explain labels/notes in: " + targetLanguage + ctx + "\n\n"
                        + "Return format:\n"
                        + "{\n"
                        + "  \"schemaVersion\": \"deepen_v1\",\n"
                        + "  \"featureKey\": \"paraphrase\",\n"
                        + "  \"alternatives\": [\n"
                        + "    {\"text\": \"English paraphrase\", \"register\": \"formal|casual|neutral\", \"note\": \"short note in "
                        + targetLanguage + "\"}\n"
                        + "  ]\n"
                        + "}\n\n"
                        + "Rules: Provide 3 to 5 alternatives. Return ONLY the JSON object.";
                case "chunks":
                    return "Extract useful multi-word chunks from this English line.\n"
                        + "Return ONLY a valid JSON object. No markdown.\n\n"
                        + "Line: \"" + text + "\"\n"
                        + "Meanings in: " + targetLanguage + ctx + "\n\n"
                        + "Return format:\n"
                        + "{\n"
                        + "  \"schemaVersion\": \"deepen_v1\",\n"
                        + "  \"featureKey\": \"chunks\",\n"
                        + "  \"chunks\": [\n"
                        + "    {\"phrase\": \"chunk\", \"meaning\": \"in " + targetLanguage
                        + "\", \"example\": \"new English example\"}\n"
                        + "  ]\n"
                        + "}\n\n"
                        + "Rules: Provide 3 to 6 chunks (2-5 words). Return ONLY the JSON object.";
                case "simplify":
                    return "Simplify this English line for learners.\n"
                        + "Return ONLY a valid JSON object. No markdown.\n\n"
                        + "Line: \"" + text + "\"\n"
                        + "Hard-word meanings in: " + targetLanguage + ctx + "\n\n"
                        + "Return format:\n"
                        + "{\n"
                        + "  \"schemaVersion\": \"deepen_v1\",\n"
                        + "  \"featureKey\": \"simplify\",\n"
                        + "  \"simplified\": [\"easier sentence\"],\n"
                        + "  \"hardWords\": [{\"word\": \"x\", \"meaning\": \"in " + targetLanguage + "\"}]\n"
                        + "}\n\n"
                        + "Rules: 1-2 simplified sentences; up to 6 hard words. Return ONLY the JSON object.";
                case "nuance":
                    return "Explain register and nuance of this English line.\n"
                        + "Return ONLY a valid JSON object. No markdown.\n\n"
                        + "Line: \"" + text + "\"\n"
                        + "Write explanations in: " + targetLanguage + ctx + "\n\n"
                        + "Return format:\n"
                        + "{\n"
                        + "  \"schemaVersion\": \"deepen_v1\",\n"
                        + "  \"featureKey\": \"nuance\",\n"
                        + "  \"register\": \"formal|informal|neutral\",\n"
                        + "  \"implication\": \"in " + targetLanguage + "\",\n"
                        + "  \"britishNote\": \"in " + targetLanguage + " or empty\",\n"
                        + "  \"whyThisPhrasing\": \"in " + targetLanguage + "\"\n"
                        + "}\n\n"
                        + "Rules: Be concise. Return ONLY the JSON object.";
                default:
                    throw new ArgumentException("Unknown deepen featureKey: " + featureKey, nameof(featureKey));
            }
        }

        private static async Task<JObject> RunPromptAsync(IReadOnlyList<string> apiKeys, string prompt)
        {
            var keys = GrammarGeminiServiceNormalizeKeys(apiKeys);
            if (keys.Count == 0)
                throw new InvalidOperationException("Cần ít nhất một Gemini API key hợp lệ.");

            var bodyObj = new JObject
            {
                ["contents"] = new JArray
                {
                    new JObject
                    {
                        ["parts"] = new JArray { new JObject { ["text"] = prompt } },
                    },
                },
                ["generationConfig"] = new JObject
                {
                    ["temperature"] = 0.4,
                    ["responseMimeType"] = "application/json",
                },
            };

            string lastDetail = null;
            var start = GeminiApiKeyRotator.TakeStartIndex(keys.Count);

            foreach (var key in GeminiApiKeyRotator.EnumerateFrom(keys, start))
            {
                var url = "https://generativelanguage.googleapis.com/v1beta/models/"
                          + GrammarCacheConstants.GeminiModelId + ":generateContent?key=" + Uri.EscapeDataString(key);

                for (var attempt = 0; attempt < MaxQuickRetriesPerKey; attempt++)
                {
                    var content = new StringContent(bodyObj.ToString(Formatting.None), Encoding.UTF8, "application/json");
                    var resp = await Http.PostAsync(url, content).ConfigureAwait(false);
                    var respText = await resp.Content.ReadAsStringAsync().ConfigureAwait(false);
                    var code = (int)resp.StatusCode;

                    if (code == 404 && respText != null
                        && (respText.IndexOf("NOT_FOUND", StringComparison.OrdinalIgnoreCase) >= 0
                            || respText.IndexOf("not found", StringComparison.OrdinalIgnoreCase) >= 0))
                    {
                        throw new InvalidOperationException(
                            "Gemini model not found (" + GrammarCacheConstants.GeminiModelId
                            + "). Update <GeminiModelId> in service.config. Detail: " + Truncate(respText, 240));
                    }

                    if (code == 429 || code == 400 || code == 401 || code == 403)
                    {
                        lastDetail = code + " " + Truncate(respText, 200);
                        if (code == 429)
                            await Task.Delay(300).ConfigureAwait(false);
                        break;
                    }

                    if (!resp.IsSuccessStatusCode)
                    {
                        lastDetail = code + " " + Truncate(respText, 200);
                        if (attempt + 1 >= MaxQuickRetriesPerKey)
                            break;
                        await Task.Delay(400).ConfigureAwait(false);
                        continue;
                    }

                    return ParseGeminiJsonObject(respText);
                }
            }

            throw new InvalidOperationException("Deepen Gemini failed: " + (lastDetail ?? "unknown"));
        }

        private static List<string> GrammarGeminiServiceNormalizeKeys(IReadOnlyList<string> apiKeys)
        {
            var keys = new List<string>();
            if (apiKeys == null)
                return keys;
            foreach (var k in apiKeys)
            {
                var t = (k ?? "").Trim();
                if (t.Length > 0 && !keys.Contains(t))
                    keys.Add(t);
            }
            return keys;
        }

        private static JObject ParseGeminiJsonObject(string respText)
        {
            var root = JObject.Parse(respText);
            var text = root["candidates"]?[0]?["content"]?["parts"]?[0]?["text"]?.ToString();
            if (string.IsNullOrWhiteSpace(text))
                throw new InvalidOperationException("Empty Gemini deepen response.");

            text = text.Trim();
            if (text.StartsWith("```"))
            {
                var firstNl = text.IndexOf('\n');
                if (firstNl > 0)
                    text = text.Substring(firstNl + 1);
                if (text.EndsWith("```"))
                    text = text.Substring(0, text.Length - 3);
                text = text.Trim();
            }

            return JObject.Parse(text);
        }

        private static string Truncate(string s, int max)
        {
            if (string.IsNullOrEmpty(s))
                return "";
            s = s.Replace("\r\n", " ").Replace("\n", " ");
            return s.Length <= max ? s : s.Substring(0, max) + "...";
        }
    }
}
