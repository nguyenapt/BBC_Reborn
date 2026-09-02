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

        /// <summary>When true, EN row is included in batch Get Grammar Explaination/Passage.</summary>
        public bool GrammarSelected
        {
            get => _grammarSelected;
            set { if (value.Equals(_grammarSelected)) return; _grammarSelected = value; OnPropertyChanged(); }
        }

        public event PropertyChangedEventHandler PropertyChanged;

        private void OnPropertyChanged([CallerMemberName] string propertyName = null)
        {
            PropertyChanged?.Invoke(this, new PropertyChangedEventArgs(propertyName));
        }
    }
}
