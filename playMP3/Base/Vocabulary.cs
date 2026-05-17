using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading.Tasks;

namespace playMP3.Base
{
    /// <summary>
    /// Episode vocabulary row for Firebase. Enhancement JSON (synonyms, etc.) per locale may be added later to align with Flutter/tool grids.
    /// </summary>
    public class Vocabulary
    {
        public Guid Id { get; set; }

        public Nullable<Guid> EpisodeId { get; set; }

        public Nullable<Guid> BBCEpisodeId { get; set; }

        public string Vocab { get; set; }
        public string Mean { get; set; }
        public string Description { get; set; }
        public string Examples { get; set; }

        public virtual Episode Episode { get; set; }

    }
}
