using System.ComponentModel;
using System.Runtime.CompilerServices;

namespace playMP3.Base
{
    /// <summary>
    /// One vocabulary row per language grid. EnglishLemma aligns rows across tabs (from txtVocab).
    /// Firebase/app sync for enhancement JSON is a future step — see tool workflow.
    /// </summary>
    public class VocabularyGridRowModel : INotifyPropertyChanged
    {
        private string _englishLemma = "";
        private string _displayText = "";
        private string _meaning = "";
        private string _enhancementJson = "";

        /// <summary>Headword from source line (before ':'), stable row key.</summary>
        public string EnglishLemma
        {
            get => _englishLemma;
            set { if (value == _englishLemma) return; _englishLemma = value ?? ""; OnPropertyChanged(); }
        }

        /// <summary>Binds to grid column "Text".</summary>
        public string DisplayText
        {
            get => _displayText;
            set { if (value == _displayText) return; _displayText = value ?? ""; OnPropertyChanged(); }
        }

        public string Meaning
        {
            get => _meaning;
            set { if (value == _meaning) return; _meaning = value ?? ""; OnPropertyChanged(); }
        }

        /// <summary>Compact JSON: synonyms, antonyms, etc. (Flutter enhanceVocabulary shape). On locale grids, same string as English row.</summary>
        public string EnhancementJson
        {
            get => _enhancementJson;
            set { if (value == _enhancementJson) return; _enhancementJson = value ?? ""; OnPropertyChanged(); }
        }

        public event PropertyChangedEventHandler PropertyChanged;

        private void OnPropertyChanged([CallerMemberName] string propertyName = null)
        {
            PropertyChanged?.Invoke(this, new PropertyChangedEventArgs(propertyName));
        }
    }
}
