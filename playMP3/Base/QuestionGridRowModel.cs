using System.Collections.Generic;
using System.ComponentModel;
using System.Linq;
using System.Runtime.CompilerServices;
using Newtonsoft.Json.Linq;

namespace playMP3.Base
{
    /// <summary>One quiz row for grvQuestions; maps to Flutter Question model JSON for ai_cache.</summary>
    public class QuestionGridRowModel : INotifyPropertyChanged
    {
        private string _quizType = "multipleChoice";
        private string _questionText = "";
        private string _optionsText = "";
        private string _correctAnswer = "";
        private string _explanation = "";

        /// <summary>Flutter enum name: multipleChoice, trueFalse, fillBlank.</summary>
        public string QuizType
        {
            get => _quizType;
            set { if (value == _quizType) return; _quizType = value ?? ""; OnPropertyChanged(); }
        }

        public string QuestionText
        {
            get => _questionText;
            set { if (value == _questionText) return; _questionText = value ?? ""; OnPropertyChanged(); }
        }

        /// <summary>Display/edit: options separated by " | ".</summary>
        public string OptionsText
        {
            get => _optionsText;
            set { if (value == _optionsText) return; _optionsText = value ?? ""; OnPropertyChanged(); }
        }

        public string CorrectAnswer
        {
            get => _correctAnswer;
            set { if (value == _correctAnswer) return; _correctAnswer = value ?? ""; OnPropertyChanged(); }
        }

        public string Explanation
        {
            get => _explanation;
            set { if (value == _explanation) return; _explanation = value ?? ""; OnPropertyChanged(); }
        }

        public static QuestionGridRowModel FromAiObject(JToken token)
        {
            var jo = token as JObject ?? throw new System.ArgumentException("Question element must be object.");
            var typeRaw = jo["type"]?.ToString() ?? "";
            var kind = NormalizeQuizType(typeRaw);

            var optionsArr = jo["options"] as JArray;
            List<string> optionList;
            if (optionsArr != null && optionsArr.Count > 0)
                optionList = optionsArr.Select(x => x?.ToString() ?? "").Where(s => s.Length > 0).ToList();
            else if (kind == "trueFalse")
                optionList = new List<string> { "True", "False" };
            else
                optionList = new List<string>();

            return new QuestionGridRowModel
            {
                QuizType = kind,
                QuestionText = jo["question"]?.ToString() ?? "",
                OptionsText = string.Join(" | ", optionList),
                CorrectAnswer = jo["correctAnswer"]?.ToString() ?? "",
                Explanation = jo["explanation"]?.ToString() ?? "",
            };
        }

        /// <summary>Match Flutter <c>Question.fromAIResponse</c> inference.</summary>
        public static string NormalizeQuizType(string typeRaw)
        {
            var s = (typeRaw ?? "").ToLowerInvariant();
            if (s.Contains("true") || s.Contains("false"))
                return "trueFalse";
            if (s.Contains("fill") || s.Contains("blank"))
                return "fillBlank";
            return "multipleChoice";
        }

        public JObject ToFlutterQuestionObject(int index)
        {
            var options = ParseOptionsForExport();
            var jo = new JObject
            {
                ["id"] = "question_" + index,
                ["question"] = QuestionText ?? "",
                ["type"] = QuizType ?? "multipleChoice",
                ["correctAnswer"] = CorrectAnswer ?? "",
                ["explanation"] = Explanation ?? "",
                ["options"] = new JArray(options),
            };
            return jo;
        }

        private List<string> ParseOptionsForExport()
        {
            var kind = QuizType ?? "multipleChoice";
            var parts = (OptionsText ?? "")
                .Split('|')
                .Select(x => x.Trim())
                .Where(x => x.Length > 0)
                .ToList();

            if (parts.Count > 0)
                return parts;

            if (kind == "trueFalse")
                return new List<string> { "True", "False" };

            return new List<string>();
        }

        public event PropertyChangedEventHandler PropertyChanged;

        private void OnPropertyChanged([CallerMemberName] string propertyName = null)
        {
            PropertyChanged?.Invoke(this, new PropertyChangedEventArgs(propertyName));
        }
    }
}
