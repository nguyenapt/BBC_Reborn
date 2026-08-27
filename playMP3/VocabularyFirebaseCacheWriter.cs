using System;
using System.Net.Http;
using System.Text;
using System.Threading.Tasks;
using Newtonsoft.Json;
using Newtonsoft.Json.Linq;

namespace playMP3
{
    /// <summary>
    /// RTDB PUT aligned with Flutter <c>AIFirebaseCacheService.saveVocabulary</c>:
    /// <c>ai_cache/vocabulary/{wordHash}/{sanitizedLang}.json</c> where wordHash = first 16 hex chars of SHA256(lowercase trimmed word).
    /// </summary>
    public static class VocabularyFirebaseCacheWriter
    {
        private static readonly HttpClient Http = new HttpClient { Timeout = TimeSpan.FromSeconds(30) };

        public static async Task PutVocabularyCacheAsync(string word, string languageCode, JObject vocabularyDataMap, string episodeId = null)
        {
            var wordHash = GrammarCacheKeyHelper.HashString((word ?? string.Empty).Trim().ToLowerInvariant());
            var safeLang = GrammarCacheKeyHelper.SanitizeFirebaseKey(languageCode);
            var vocabularyUrl = ActiveRtdbContext.BaseUrl + "/" + GrammarCacheConstants.AiCachePath
                                + "/vocabulary/" + wordHash + "/" + safeLang + ".json";

            var dto = GrammarAiCacheEntryDto.FromGrammarMap(
                vocabularyDataMap,
                GrammarCacheConstants.AiCacheEntryVersion,
                GrammarCacheConstants.VocabularyAiCacheTtlDays);
            var json = JsonConvert.SerializeObject(dto);
            var resp = await Http.PutAsync(vocabularyUrl, new StringContent(json, Encoding.UTF8, "application/json")).ConfigureAwait(false);
            var body = await resp.Content.ReadAsStringAsync().ConfigureAwait(false);
            if (!resp.IsSuccessStatusCode)
                throw new InvalidOperationException("Firebase PUT " + (int)resp.StatusCode + " " + vocabularyUrl + " " + body);

            if (!string.IsNullOrWhiteSpace(episodeId))
            {
                var safeEpisodeId = GrammarCacheKeyHelper.SanitizeFirebaseKey(episodeId.Trim());
                var byEpisodeUrl = ActiveRtdbContext.BaseUrl + "/" + GrammarCacheConstants.AiCachePath
                                   + "/" + GrammarCacheConstants.VocabularyByEpisodePath + "/" + safeEpisodeId + "/" + wordHash + ".json";

                var existingTranslationMap = new JObject();
                try
                {
                    var getResp = await Http.GetAsync(byEpisodeUrl).ConfigureAwait(false);
                    if (getResp.IsSuccessStatusCode)
                    {
                        var getBody = await getResp.Content.ReadAsStringAsync().ConfigureAwait(false);
                        if (!string.IsNullOrWhiteSpace(getBody) && !string.Equals(getBody, "null", StringComparison.OrdinalIgnoreCase))
                        {
                            var existingNode = JObject.Parse(getBody);
                            var existingData = existingNode["data"] as JObject;
                            var existingTranslations = existingData?["translation"] as JObject;
                            if (existingTranslations != null)
                                existingTranslationMap = (JObject)existingTranslations.DeepClone();
                        }
                    }
                }
                catch
                {
                    // best-effort merge, ignore GET failures
                }

                var meaning = (vocabularyDataMap?["meaning"]?.ToString() ?? string.Empty).Trim();
                existingTranslationMap[safeLang] = meaning;

                var vocabObjectData = (vocabularyDataMap ?? new JObject()).DeepClone() as JObject ?? new JObject();
                vocabObjectData.Remove("meaning");

                var byEpisodePayload = new JObject
                {
                    ["word"] = (word ?? string.Empty).Trim(),
                    ["wordHash"] = wordHash,
                    ["episodeId"] = episodeId.Trim(),
                    ["data"] = vocabObjectData,
                    ["translation"] = existingTranslationMap,
                    ["schemaVersion"] = 2,
                };
                var byEpisodeDto = GrammarAiCacheEntryDto.FromGrammarMap(
                    byEpisodePayload,
                    GrammarCacheConstants.AiCacheEntryVersion,
                    GrammarCacheConstants.VocabularyAiCacheTtlDays);
                var byEpisodeJson = JsonConvert.SerializeObject(byEpisodeDto);
                var idxResp = await Http.PutAsync(byEpisodeUrl, new StringContent(byEpisodeJson, Encoding.UTF8, "application/json")).ConfigureAwait(false);
                var idxBody = await idxResp.Content.ReadAsStringAsync().ConfigureAwait(false);
                if (!idxResp.IsSuccessStatusCode)
                    throw new InvalidOperationException("Firebase PUT " + (int)idxResp.StatusCode + " " + byEpisodeUrl + " " + idxBody);
            }
        }
    }
}
