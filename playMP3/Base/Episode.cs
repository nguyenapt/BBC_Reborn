using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading.Tasks;

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
        public string ThumbImage { get; set; }
        public string SecondFileUrl { get; set; }
        public string Actor { get; set; }
        public int Duration { get; set; }
    }
}
