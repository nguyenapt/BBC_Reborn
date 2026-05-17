using System;
using System.Net.Http;
using System.Text;
using System.Threading.Tasks;
using Newtonsoft.Json;
using Newtonsoft.Json.Linq;

namespace playMP3
{
    /// <summary>
    /// RTDB PUT aligned with Flutter <c>AIFirebaseCacheService.saveTranslation</c>:
    /// <c>ai_cache/translations/{episodeId}/{languageCode}.json</c>
    /// with <c>data.translations</c> as array of { original, translated, lineNumber }.
    /// </summary>
    public static class TranslationsFirebaseCacheWriter
    {
        private static readonly HttpClient Http = new HttpClient { Timeout = TimeSpan.FromSeconds(30) };

        public static async Task PutTranslationsCacheAsync(string episodeId, string languageCode, JArray translationsArray)
        {
            if (string.IsNullOrWhiteSpace(episodeId))
                throw new ArgumentException("episodeId required.", nameof(episodeId));

            var safeEpisodeId = GrammarCacheKeyHelper.SanitizeFirebaseKey(episodeId.Trim());
            var safeLang = GrammarCacheKeyHelper.SanitizeFirebaseKey(languageCode ?? string.Empty);

            var data = new JObject
            {
                ["translations"] = translationsArray ?? new JArray(),
                ["originalEpisodeId"] = episodeId.Trim(),
                ["originalLanguageCode"] = languageCode ?? string.Empty,
            };

            var url = GrammarCacheConstants.FirebaseRtdbBaseUrl + "/" + GrammarCacheConstants.AiCachePath
                      + "/translations/" + safeEpisodeId + "/" + safeLang + ".json";

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
