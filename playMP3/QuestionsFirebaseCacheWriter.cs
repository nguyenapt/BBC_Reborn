using System;
using System.Net.Http;
using System.Text;
using System.Threading.Tasks;
using Newtonsoft.Json;
using Newtonsoft.Json.Linq;

namespace playMP3
{
    /// <summary>RTDB PUT aligned with Flutter <c>AIFirebaseCacheService.saveQuestions</c>: <c>ai_cache/questions/{episodeId}/{count}.json</c>.</summary>
    public static class QuestionsFirebaseCacheWriter
    {
        private static readonly HttpClient Http = new HttpClient { Timeout = TimeSpan.FromSeconds(30) };

        public static async Task PutQuestionsCacheAsync(string firebaseRtdbBaseUrl, string episodeId, int count, JArray questions)
        {
            if (string.IsNullOrWhiteSpace(episodeId))
                throw new ArgumentException("episodeId required.", nameof(episodeId));

            var baseUrl = GrammarCacheKeyHelper.NormalizeRtdbBaseUrl(firebaseRtdbBaseUrl);
            var data = new JObject
            {
                ["questions"] = questions ?? new JArray(),
                ["count"] = count,
            };

            var safeEpisodeId = GrammarCacheKeyHelper.SanitizeFirebaseKey(episodeId.Trim());
            var url = baseUrl + "/" + GrammarCacheConstants.AiCachePath
                      + "/questions/" + safeEpisodeId + "/" + count + ".json";

            var dto = GrammarAiCacheEntryDto.FromGrammarMap(
                data,
                GrammarCacheConstants.AiCacheEntryVersion,
                GrammarCacheConstants.AiCacheTtlDays);
            var json = JsonConvert.SerializeObject(dto);
            var content = new StringContent(json, Encoding.UTF8, "application/json");
            var resp = await Http.PutAsync(url, content).ConfigureAwait(false);
            var body = await resp.Content.ReadAsStringAsync().ConfigureAwait(false);
            if (!resp.IsSuccessStatusCode)
                throw new InvalidOperationException("Firebase PUT " + (int)resp.StatusCode + " " + url + " " + body);
        }
    }
}
