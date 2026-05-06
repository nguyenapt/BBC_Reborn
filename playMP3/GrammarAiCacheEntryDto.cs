using System;
using Newtonsoft.Json;

namespace playMP3
{
    /// <summary>Matches Flutter lib/models/ai_cache_entry.dart for RTDB PUT.</summary>
    public class GrammarAiCacheEntryDto
    {
        [JsonProperty("data")]
        public Newtonsoft.Json.Linq.JObject Data { get; set; }

        [JsonProperty("createdAt")]
        public string CreatedAt { get; set; }

        [JsonProperty("version")]
        public int Version { get; set; }

        [JsonProperty("ttlDays")]
        public int? TtlDays { get; set; }

        public static GrammarAiCacheEntryDto FromGrammarMap(Newtonsoft.Json.Linq.JObject grammarData, int version, int ttlDays)
        {
            return new GrammarAiCacheEntryDto
            {
                Data = grammarData,
                CreatedAt = DateTime.UtcNow.ToString("o"),
                Version = version,
                TtlDays = ttlDays,
            };
        }
    }
}
