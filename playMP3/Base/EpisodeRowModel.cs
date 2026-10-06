using System.ComponentModel;
using System.Runtime.CompilerServices;

namespace playMP3.Base
{
    /// <summary>
    /// One transcript segment row for DataGridView binding.
    /// MUST_SYNC cache strings: see GrammarCacheConstants (Flutter ai_config / AIGrammarService).
    /// </summary>
    public class EpisodeRowModel : INotifyPropertyChanged
    {
        private int _rowNumber;
        private double _firstDuration;
        private string _rowContent;
        private double _lastDuration;
        private int _group;
        private string _grammarExplanationSummary;
        private string _grammarExplanationJson;
        private bool _grammarSelected = true;
        private string _paraphraseJson;
        private string _chunksJson;
        private string _simplifyJson;
        private string _nuanceJson;
        private string _deepenSummary;

        /// <summary>0-based transcript line index (matches Firebase lineNumber).</summary>
        public int RowNumber
        {
            get => _rowNumber;
            set { if (value.Equals(_rowNumber)) return; _rowNumber = value; OnPropertyChanged(); }
        }

        public double FirstDuration
        {
            get => _firstDuration;
            set { if (value.Equals(_firstDuration)) return; _firstDuration = value; OnPropertyChanged(); }
        }

        public string RowContent
        {
            get => _rowContent;
            set { if (value == _rowContent) return; _rowContent = value; OnPropertyChanged(); }
        }

        public double LastDuration
        {
            get => _lastDuration;
            set { if (value.Equals(_lastDuration)) return; _lastDuration = value; OnPropertyChanged(); }
        }

        public int Group
        {
            get => _group;
            set { if (value.Equals(_group)) return; _group = value; OnPropertyChanged(); }
        }

        /// <summary>Short text for grid grammar column (DataPropertyName).</summary>
        public string GrammarExplanationSummary
        {
            get => _grammarExplanationSummary;
            set { if (value == _grammarExplanationSummary) return; _grammarExplanationSummary = value; OnPropertyChanged(); }
        }

        /// <summary>Full JSON for Flutter GrammarExplanation / Firebase ai_cache data map.</summary>
        public string GrammarExplanationJson
        {
            get => _grammarExplanationJson;
            set { if (value == _grammarExplanationJson) return; _grammarExplanationJson = value; OnPropertyChanged(); }
        }

        /// <summary>When true, EN row is included in batch Get Grammar / Get Deepen.</summary>
        public bool GrammarSelected
        {
            get => _grammarSelected;
            set { if (value.Equals(_grammarSelected)) return; _grammarSelected = value; OnPropertyChanged(); }
        }

        public string ParaphraseJson
        {
            get => _paraphraseJson;
            set { if (value == _paraphraseJson) return; _paraphraseJson = value; OnPropertyChanged(); RefreshDeepenSummary(); }
        }

        public string ChunksJson
        {
            get => _chunksJson;
            set { if (value == _chunksJson) return; _chunksJson = value; OnPropertyChanged(); RefreshDeepenSummary(); }
        }

        public string SimplifyJson
        {
            get => _simplifyJson;
            set { if (value == _simplifyJson) return; _simplifyJson = value; OnPropertyChanged(); RefreshDeepenSummary(); }
        }

        public string NuanceJson
        {
            get => _nuanceJson;
            set { if (value == _nuanceJson) return; _nuanceJson = value; OnPropertyChanged(); RefreshDeepenSummary(); }
        }

        /// <summary>Compact status of filled deepen features (grid column).</summary>
        public string DeepenSummary
        {
            get => _deepenSummary;
            set { if (value == _deepenSummary) return; _deepenSummary = value; OnPropertyChanged(); }
        }

        public string GetDeepenJson(string featureKey)
        {
            switch ((featureKey ?? "").Trim().ToLowerInvariant())
            {
                case "paraphrase": return ParaphraseJson;
                case "chunks": return ChunksJson;
                case "simplify": return SimplifyJson;
                case "nuance": return NuanceJson;
                default: return null;
            }
        }

        public void SetDeepenJson(string featureKey, string json)
        {
            switch ((featureKey ?? "").Trim().ToLowerInvariant())
            {
                case "paraphrase":
                    ParaphraseJson = json;
                    break;
                case "chunks":
                    ChunksJson = json;
                    break;
                case "simplify":
                    SimplifyJson = json;
                    break;
                case "nuance":
                    NuanceJson = json;
                    break;
            }
        }

        public void RefreshDeepenSummary()
        {
            var parts = new System.Collections.Generic.List<string>(4);
            if (!string.IsNullOrWhiteSpace(ParaphraseJson) && !ParaphraseJson.StartsWith("Lỗi:"))
                parts.Add("P");
            else if (!string.IsNullOrWhiteSpace(ParaphraseJson))
                parts.Add("P!");
            if (!string.IsNullOrWhiteSpace(ChunksJson) && !ChunksJson.StartsWith("Lỗi:"))
                parts.Add("C");
            else if (!string.IsNullOrWhiteSpace(ChunksJson))
                parts.Add("C!");
            if (!string.IsNullOrWhiteSpace(SimplifyJson) && !SimplifyJson.StartsWith("Lỗi:"))
                parts.Add("S");
            else if (!string.IsNullOrWhiteSpace(SimplifyJson))
                parts.Add("S!");
            if (!string.IsNullOrWhiteSpace(NuanceJson) && !NuanceJson.StartsWith("Lỗi:"))
                parts.Add("N");
            else if (!string.IsNullOrWhiteSpace(NuanceJson))
                parts.Add("N!");
            DeepenSummary = parts.Count == 0 ? "" : string.Join(",", parts);
        }

        public event PropertyChangedEventHandler PropertyChanged;

        private void OnPropertyChanged([CallerMemberName] string propertyName = null)
        {
            PropertyChanged?.Invoke(this, new PropertyChangedEventArgs(propertyName));
        }
    }
}
