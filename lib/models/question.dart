/// Question type enum
enum QuestionType {
  multipleChoice,
  trueFalse,
  fillBlank,
}

/// Model for AI-generated question
class Question {
  final String id;
  final String question;
  final QuestionType type;
  final List<String> options; // For multiple choice
  final String correctAnswer;
  final String explanation;
  final int? relatedLineIndex; // Link to transcript line (optional)

  Question({
    required this.id,
    required this.question,
    required this.type,
    required this.options,
    required this.correctAnswer,
    required this.explanation,
    this.relatedLineIndex,
  });

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'question': question,
      'type': type.name,
      'options': options,
      'correctAnswer': correctAnswer,
      'explanation': explanation,
      'relatedLineIndex': relatedLineIndex,
    };
  }

  factory Question.fromJson(Map<String, dynamic> json) {
    QuestionType questionType;
    try {
      questionType = QuestionType.values.firstWhere(
        (e) => e.name == json['type'],
        orElse: () => QuestionType.multipleChoice,
      );
    } catch (e) {
      questionType = QuestionType.multipleChoice;
    }

    return Question(
      id: json['id']?.toString() ?? '',
      question: json['question']?.toString() ?? '',
      type: questionType,
      options: (json['options'] as List<dynamic>?)
          ?.map((e) => e.toString())
          .toList() ?? [],
      correctAnswer: json['correctAnswer']?.toString() ?? '',
      explanation: json['explanation']?.toString() ?? '',
      relatedLineIndex: json['relatedLineIndex'],
    );
  }

  /// Create question from AI response
  factory Question.fromAIResponse(Map<String, dynamic> json, int index) {
    QuestionType questionType;
    final typeStr = json['type']?.toString().toLowerCase() ?? 'multiplechoice';
    
    if (typeStr.contains('true') || typeStr.contains('false')) {
      questionType = QuestionType.trueFalse;
    } else if (typeStr.contains('fill') || typeStr.contains('blank')) {
      questionType = QuestionType.fillBlank;
    } else {
      questionType = QuestionType.multipleChoice;
    }

    // Get options
    List<String> options = [];
    if (json['options'] != null) {
      options = (json['options'] as List<dynamic>)
          .map((e) => e.toString())
          .toList();
    } else if (questionType == QuestionType.trueFalse) {
      options = ['True', 'False'];
    }

    return Question(
      id: 'question_$index',
      question: json['question']?.toString() ?? '',
      type: questionType,
      options: options,
      correctAnswer: json['correctAnswer']?.toString() ?? '',
      explanation: json['explanation']?.toString() ?? '',
    );
  }
}

