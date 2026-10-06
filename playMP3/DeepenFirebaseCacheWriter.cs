using System;
using System.Net.Http;
using System.Text;
using System.Threading.Tasks;
using Newtonsoft.Json;
using Newtonsoft.Json.Linq;

namespace playMP3
{
    /// <summary>
    /// PUT <c>ai_cache/deepen_by_episode/{episodeId}/line_{n}/{featureKey}/{lang}.json</c>
    /// MUST_SYNC Flutter AIFirebaseCacheService.saveDeepenByEpisode.
    /// </summary>
    public static class DeepenFirebaseCacheWriter
    {
        private static readonly HttpClient Http = new HttpClient { Timeout = TimeSpan.FromSeconds(30) };

        public static async Task PutDeepenCacheAsync(
            string firebaseRtdbBaseUrl,
            string episodeId,
            int lineNumber,
            string featureKey,
            string languageCode,
            JObject deepenDataMap,
            string sourceSentence = null)
        {
            if (string.IsNullOrWhiteSpace(episodeId))
                throw new ArgumentException("episodeId required.", nameof(episodeId));
            if (lineNumber < 0)
                throw new ArgumentOutOfRangeException(nameof(lineNumber));
            if (string.IsNullOrWhiteSpace(featureKey))
                throw new ArgumentException("featureKey required.", nameof(featureKey));

            var baseUrl = GrammarCacheKeyHelper.NormalizeRtdbBaseUrl(firebaseRtdbBaseUrl);
            var safeEpisodeId = GrammarCacheKeyHelper.SanitizeFirebaseKey(episodeId.Trim());
            var lineKey = GrammarCacheKeyHelper.GrammarEpisodeLineKey(
                sourceSentence ?? string.Empty, lineNumber);
            var safeFeature = GrammarCacheKeyHelper.SanitizeFirebaseKey(featureKey.Trim());
            var safeLang = GrammarCacheKeyHelper.SanitizeFirebaseKey(languageCode);
            var url = baseUrl + "/" + GrammarCacheConstants.AiCachePath
                      + "/" + GrammarCacheConstants.DeepenByEpisodePath + "/"
                      + safeEpisodeId + "/" + lineKey + "/" + safeFeature + "/" + safeLang + ".json";

            var normalizedData = (deepenDataMap ?? new JObject()).DeepClone() as JObject ?? new JObject();
            normalizedData["episodeId"] = episodeId.Trim();
            normalizedData["lineKey"] = lineKey;
            normalizedData["lineNumber"] = lineNumber;
            normalizedData["featureKey"] = featureKey.Trim();
            normalizedData["languageCode"] = languageCode;
            normalizedData["schemaVersion"] = GrammarCacheConstants.DeepenSchemaVersion;
            if (!string.IsNullOrWhiteSpace(sourceSentence))
                normalizedData["sourceSentence"] = sourceSentence.Trim();

            var dto = GrammarAiCacheEntryDto.FromGrammarMap(
                normalizedData,
                GrammarCacheConstants.AiCacheEntryVersion,
                GrammarCacheConstants.AiCacheTtlDays);
            var json = JsonConvert.SerializeObject(dto);

            var resp = await Http.PutAsync(url, new StringContent(json, Encoding.UTF8, "application/json"))
                .ConfigureAwait(false);
            var body = await resp.Content.ReadAsStringAsync().ConfigureAwait(false);
            if (!resp.IsSuccessStatusCode)
                throw new InvalidOperationException(
                    "Firebase PUT " + (int)resp.StatusCode + " " + url + " " + body);
        }
    }
}
