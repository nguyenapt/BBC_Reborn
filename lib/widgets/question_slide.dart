import 'package:flutter/material.dart';
import '../models/episode.dart';
import '../models/question.dart';
import '../services/ai_question_service.dart';
import '../services/ai/ai_error_handler.dart';
import '../utils/category_colors.dart';

class QuestionSlide extends StatefulWidget {
  final Episode episode;

  const QuestionSlide({
    super.key,
    required this.episode,
  });

  @override
  State<QuestionSlide> createState() => _QuestionSlideState();
}

class _QuestionSlideState extends State<QuestionSlide> {
  final AIQuestionService _questionService = AIQuestionService();
  List<Question> _questions = [];
  bool _isLoading = false;
  bool _hasError = false;
  String? _errorMessage;
  final Map<int, String?> _selectedAnswers = {}; // question index -> selected answer
  bool _showResults = false;

  @override
  void initState() {
    super.initState();
    _loadQuestions();
  }

  Future<void> _loadQuestions() async {
    setState(() {
      _isLoading = true;
      _hasError = false;
      _errorMessage = null;
    });

    try {
      // Get transcript text
      String transcript = '';
      if (widget.episode.transcriptHtml != null && widget.episode.transcriptHtml!.isNotEmpty) {
        transcript = widget.episode.transcriptHtml!;
      } else if (widget.episode.transcript.isNotEmpty) {
        transcript = widget.episode.transcript;
      }

      if (transcript.isEmpty) {
        throw Exception('No transcript available for this episode');
      }

      final episodeId = widget.episode.id ?? '';
      final questions = await _questionService.generateQuestions(
        transcript,
        episodeId,
        count: 5,
      );

      if (mounted) {
        setState(() {
          _questions = questions;
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('Error loading questions: $e');
      if (mounted) {
        setState(() {
          _isLoading = false;
          _hasError = true;
          _errorMessage = AIErrorHandler.getErrorMessage(e);
        });
      }
    }
  }

  void _selectAnswer(int questionIndex, String answer) {
    setState(() {
      _selectedAnswers[questionIndex] = answer;
    });
  }

  void _checkAnswers() {
    setState(() {
      _showResults = true;
    });
  }

  void _resetQuiz() {
    setState(() {
      _selectedAnswers.clear();
      _showResults = false;
    });
  }

  int _getScore() {
    int correct = 0;
    for (int i = 0; i < _questions.length; i++) {
      final selected = _selectedAnswers[i];
      if (selected != null && selected == _questions[i].correctAnswer) {
        correct++;
      }
    }
    return correct;
  }

  @override
  Widget build(BuildContext context) {
    final categoryColor = CategoryColors.getCategoryColor(widget.episode.category);

    return Container(
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Row(
            children: [
              Icon(
                Icons.quiz,
                color: categoryColor,
                size: 20,
              ),
              const SizedBox(width: 8),
              Text(
                'Practice Questions',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: categoryColor,
                ),
              ),
              const Spacer(),
              if (_questions.isNotEmpty && !_showResults)
                TextButton.icon(
                  onPressed: _checkAnswers,
                  icon: const Icon(Icons.check_circle_outline),
                  label: const Text('Check Answers'),
                  style: TextButton.styleFrom(
                    foregroundColor: categoryColor,
                  ),
                ),
              if (_showResults)
                TextButton.icon(
                  onPressed: _resetQuiz,
                  icon: const Icon(Icons.refresh),
                  label: const Text('Reset'),
                  style: TextButton.styleFrom(
                    foregroundColor: categoryColor,
                  ),
                ),
            ],
          ),
          const SizedBox(height: 16),
          
          // Content
          Expanded(
            child: _isLoading
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        CircularProgressIndicator(
                          valueColor: AlwaysStoppedAnimation<Color>(categoryColor),
                        ),
                        const SizedBox(height: 16),
                        const Text('Generating questions...'),
                      ],
                    ),
                  )
                : _hasError
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.error_outline,
                              size: 64,
                              color: Theme.of(context).colorScheme.error,
                            ),
                            const SizedBox(height: 16),
                            Text(
                              _errorMessage ?? 'Failed to load questions',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                color: Theme.of(context).colorScheme.error,
                              ),
                            ),
                            const SizedBox(height: 16),
                            ElevatedButton.icon(
                              onPressed: _loadQuestions,
                              icon: const Icon(Icons.refresh),
                              label: const Text('Retry'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: categoryColor,
                                foregroundColor: Colors.white,
                              ),
                            ),
                          ],
                        ),
                      )
                    : _questions.isEmpty
                        ? Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  Icons.quiz_outlined,
                                  size: 64,
                                  color: Theme.of(context).colorScheme.onSurface.withOpacity(0.4),
                                ),
                                const SizedBox(height: 16),
                                Text(
                                  'No questions available',
                                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                                    color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
                                  ),
                                ),
                              ],
                            ),
                          )
                        : ListView.builder(
                            itemCount: _questions.length,
                            itemBuilder: (context, index) {
                              return _buildQuestionCard(context, _questions[index], index, categoryColor);
                            },
                          ),
          ),
          
          // Score (if results shown)
          if (_showResults && _questions.isNotEmpty)
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: categoryColor.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: categoryColor.withOpacity(0.3),
                  width: 1,
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.emoji_events,
                    color: categoryColor,
                    size: 24,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'Score: ${_getScore()} / ${_questions.length}',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: categoryColor,
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildQuestionCard(
    BuildContext context,
    Question question,
    int index,
    Color categoryColor,
  ) {
    final selectedAnswer = _selectedAnswers[index];
    final isCorrect = selectedAnswer == question.correctAnswer;
    final showAnswer = _showResults;

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: showAnswer
              ? (isCorrect ? Colors.green : Colors.red)
              : Theme.of(context).colorScheme.outline.withOpacity(0.3),
          width: showAnswer ? 2 : 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Question number and text
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: categoryColor,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  '${index + 1}',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  question.question,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Theme.of(context).colorScheme.onSurface,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          
          // Options
          ...question.options.asMap().entries.map((entry) {
            final optionIndex = entry.key;
            final option = entry.value;
            final isSelected = selectedAnswer == option;
            final isCorrectOption = option == question.correctAnswer;

            return Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: InkWell(
                onTap: showAnswer ? null : () => _selectAnswer(index, option),
                borderRadius: BorderRadius.circular(8),
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: showAnswer
                        ? (isCorrectOption
                            ? Colors.green.withOpacity(0.1)
                            : isSelected && !isCorrectOption
                                ? Colors.red.withOpacity(0.1)
                                : Colors.transparent)
                        : isSelected
                            ? categoryColor.withOpacity(0.1)
                            : Colors.transparent,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: showAnswer
                          ? (isCorrectOption
                              ? Colors.green
                              : isSelected && !isCorrectOption
                                  ? Colors.red
                                  : Colors.transparent)
                          : isSelected
                              ? categoryColor
                              : Theme.of(context).colorScheme.outline.withOpacity(0.3),
                      width: isSelected || (showAnswer && isCorrectOption) ? 2 : 1,
                    ),
                  ),
                  child: Row(
                    children: [
                      Radio<String>(
                        value: option,
                        groupValue: selectedAnswer,
                        onChanged: showAnswer ? null : (value) => _selectAnswer(index, value!),
                        activeColor: categoryColor,
                      ),
                      Expanded(
                        child: Text(
                          option,
                          style: TextStyle(
                            fontSize: 15,
                            color: Theme.of(context).colorScheme.onSurface,
                          ),
                        ),
                      ),
                      if (showAnswer && isCorrectOption)
                        Icon(
                          Icons.check_circle,
                          color: Colors.green,
                          size: 20,
                        ),
                      if (showAnswer && isSelected && !isCorrectOption)
                        Icon(
                          Icons.cancel,
                          color: Colors.red,
                          size: 20,
                        ),
                    ],
                  ),
                ),
              ),
            );
          }),
          
          // Explanation (if results shown)
          if (showAnswer && question.explanation.isNotEmpty) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: categoryColor.withOpacity(0.05),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    Icons.lightbulb_outline,
                    color: categoryColor,
                    size: 20,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      question.explanation,
                      style: TextStyle(
                        fontSize: 14,
                        color: Theme.of(context).colorScheme.onSurface.withOpacity(0.8),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

