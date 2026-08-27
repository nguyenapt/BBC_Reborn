using System;
using System.Net.Http;
using System.Text;
using System.Threading.Tasks;
using Newtonsoft.Json;
using Newtonsoft.Json.Linq;

namespace playMP3
{
    public static class GrammarFirebaseCacheWriter
    {
        private static readonly HttpClient Http = new HttpClient { Timeout = TimeSpan.FromSeconds(30) };

        public static async Task PutGrammarCacheAsync(
            string sentence,
            string languageCode,
            string episodeId,
            JObject grammarDataMap,
            int lineNumber = -1)
        {
            if (string.IsNullOrWhiteSpace(episodeId))
                throw new ArgumentException("episodeId required.", nameof(episodeId));

            var safeEpisodeId = GrammarCacheKeyHelper.SanitizeFirebaseKey(episodeId.Trim());
            var modelVersion = GrammarCacheConstants.GrammarModelVersion;
            var promptVersion = GrammarCacheConstants.GrammarPromptVersion;
            var sentenceHash = GrammarCacheKeyHelper.GrammarSentenceHashPathSegment(
                sentence, languageCode, episodeId, modelVersion, promptVersion);
            var sentenceLineKey = GrammarCacheKeyHelper.GrammarEpisodeLineKey(sentence, lineNumber);
            var safeLang = GrammarCacheKeyHelper.SanitizeFirebaseKey(languageCode);
            var legacyUrl = ActiveRtdbContext.BaseUrl + "/" + GrammarCacheConstants.AiCachePath
                            + "/grammar/" + sentenceHash + "/" + safeLang + ".json";
            var byEpisodeUrl = ActiveRtdbContext.BaseUrl + "/" + GrammarCacheConstants.AiCachePath
                               + "/" + GrammarCacheConstants.GrammarByEpisodePath + "/" + safeEpisodeId + "/" + sentenceLineKey + "/" + safeLang + ".json";

            var normalizedData = (grammarDataMap ?? new JObject()).DeepClone() as JObject ?? new JObject();
            normalizedData["episodeId"] = episodeId.Trim();
            normalizedData["lineKey"] = sentenceLineKey;
            normalizedData["sourceSentence"] = (sentence ?? string.Empty).Trim();
            if (lineNumber >= 0)
                normalizedData["lineNumber"] = lineNumber;
            normalizedData["schemaVersion"] = GrammarCacheConstants.GrammarByEpisodeSchemaVersion;

            var dto = GrammarAiCacheEntryDto.FromGrammarMap(
                normalizedData,
                GrammarCacheConstants.AiCacheEntryVersion,
                GrammarCacheConstants.AiCacheTtlDays);
            var json = JsonConvert.SerializeObject(dto);

            var legacyResp = await Http.PutAsync(legacyUrl, new StringContent(json, Encoding.UTF8, "application/json")).ConfigureAwait(false);
            var legacyBody = await legacyResp.Content.ReadAsStringAsync().ConfigureAwait(false);
            if (!legacyResp.IsSuccessStatusCode)
                throw new InvalidOperationException("Firebase PUT " + (int)legacyResp.StatusCode + " " + legacyUrl + " " + legacyBody);

            var byEpisodeResp = await Http.PutAsync(byEpisodeUrl, new StringContent(json, Encoding.UTF8, "application/json")).ConfigureAwait(false);
            var byEpisodeBody = await byEpisodeResp.Content.ReadAsStringAsync().ConfigureAwait(false);
            if (!byEpisodeResp.IsSuccessStatusCode)
                throw new InvalidOperationException("Firebase PUT " + (int)byEpisodeResp.StatusCode + " " + byEpisodeUrl + " " + byEpisodeBody);
        }

        /// <summary>
        /// PUT <c>ai_cache/grammar_passage/{hash}/{lang}.json</c> only.
        /// Prefer dual-map via <see cref="PutGrammarCacheAsync"/> for playMP3 passage fill
        /// (grammar_by_episode) to avoid duplicate caches; this method kept for optional tools.
        /// </summary>
        public static async Task PutGrammarPassageCacheAsync(
            string passage,
            string languageCode,
            string episodeId,
            JObject grammarPassageDataMap)
        {
            if (string.IsNullOrWhiteSpace(episodeId))
                throw new ArgumentException("episodeId required.", nameof(episodeId));

            var modelVersion = GrammarCacheConstants.GrammarModelVersion;
            var promptVersion = GrammarCacheConstants.GrammarPassagePromptVersion;
            var schemaVersion = GrammarCacheConstants.GrammarPassageSchemaVersion;
            var passageHash = GrammarCacheKeyHelper.GrammarPassageHashPathSegment(
                passage, languageCode, episodeId, modelVersion, promptVersion, schemaVersion);
            var safeLang = GrammarCacheKeyHelper.SanitizeFirebaseKey(languageCode);
            var url = ActiveRtdbContext.BaseUrl + "/" + GrammarCacheConstants.AiCachePath
                      + "/" + GrammarCacheConstants.GrammarPassagePath + "/" + passageHash + "/" + safeLang + ".json";

            var normalizedData = (grammarPassageDataMap ?? new JObject()).DeepClone() as JObject ?? new JObject();
            normalizedData["episodeId"] = episodeId.Trim();
            normalizedData["sourceSentence"] = (passage ?? string.Empty).Trim();
            normalizedData["passageText"] = (passage ?? string.Empty).Trim();
            normalizedData["schemaVersion"] = schemaVersion;

            var dto = GrammarAiCacheEntryDto.FromGrammarMap(
                normalizedData,
                GrammarCacheConstants.AiCacheEntryVersion,
                GrammarCacheConstants.AiCacheTtlDays);
            var json = JsonConvert.SerializeObject(dto);

            var resp = await Http.PutAsync(url, new StringContent(json, Encoding.UTF8, "application/json")).ConfigureAwait(false);
            var body = await resp.Content.ReadAsStringAsync().ConfigureAwait(false);
            if (!resp.IsSuccessStatusCode)
                throw new InvalidOperationException("Firebase PUT " + (int)resp.StatusCode + " " + url + " " + body);
        }
    }
}
