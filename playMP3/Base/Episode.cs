using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading.Tasks;
using Newtonsoft.Json;

namespace playMP3.Base
{
    public class Episode
    {
        public Guid Id { get; set; }
        public string Category { get; set; }
        public string Year { get; set; }
        public string EpisodeName { get; set; }
        public string FileUrl { get; set; }
        public Nullable<DateTime> PublishedDate { get; set; }
        public string Transcript { get; set; }
        public string TranscriptHtml { get; set; }
        public string Vocabulary { get; set; }
        public string Question { get; set; }
        public string Summary { get; set; }
        public Nullable<DateTime> CreatedDate { get; set; }
        public Nullable<DateTime> UpdatedDate { get; set; }
        public bool IsNew { get; set; }
        public ICollection<Vocabulary> Vocabularies { get; set; }
        public string Grammar { get; set; }
        /// <summary>CSV g:,v: prefixes — grammar scoped hashes + vocabulary word hashes for ai_cache lookup/testing.</summary>
        public string GrammarVocabularyCacheKeys { get; set; }
        public string ThumbImage { get; set; }
        public string Actor { get; set; }
        public int Duration { get; set; }
        /// <summary>CEFR level (A1–C2) — chỉ export khi cloud service VOA.</summary>
        [JsonProperty(NullValueHandling = NullValueHandling.Ignore)]
        public string Level { get; set; }
    }
}
