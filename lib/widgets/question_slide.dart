import 'package:flutter/material.dart';
import '../models/episode.dart';
import '../models/question.dart';
import '../services/ai_question_service.dart';
import '../services/ai/ai_error_handler.dart';
import '../services/ai/exceptions.dart';
import '../services/admob_service.dart';
import '../services/heart_service.dart';
import '../services/language_manager.dart';
import '../utils/category_colors.dart';
import 'episode_tab_skeleton.dart';

class QuestionSlide extends StatefulWidget {
  final Episode episode;
  /// Chờ transcript đầy đủ — tránh gọi AI / lỗi "no transcript" khi list RTDB mỏng.
  final bool isAwaitingFullEpisode;

  const QuestionSlide({
    super.key,
    required this.episode,
    this.isAwaitingFullEpisode = false,
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
  dynamic _lastError; // Store error object to check if it's NoHeartsException
  final Map<int, String?> _selectedAnswers = {}; // question index -> selected answer
  bool _showResults = false;

  @override
  void initState() {
    super.initState();
    if (!widget.isAwaitingFullEpisode) {
      _loadQuestions();
    }
  }

  @override
  void didUpdateWidget(QuestionSlide oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.episode.id != widget.episode.id) {
      setState(() {
        _questions = [];
        _hasError = false;
        _errorMessage = null;
        _selectedAnswers.clear();
        _showResults = false;
      });
      if (!widget.isAwaitingFullEpisode) {
        _loadQuestions();
      }
      return;
    }
    if (oldWidget.isAwaitingFullEpisode && !widget.isAwaitingFullEpisode) {
      _loadQuestions();
    }
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
          _lastError = e; // Store error to check if it's NoHeartsException
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

    if (widget.isAwaitingFullEpisode) {
      return Padding(
        padding: const EdgeInsets.all(12),
        child: EpisodeTabSkeleton(accentColor: categoryColor, lineCount: 12),
      );
    }

    return Container(
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if ((_questions.isNotEmpty && !_showResults) || _showResults)
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Row(
                children: [
                  const Spacer(),
                  if (_questions.isNotEmpty && !_showResults)
                    TextButton.icon(
                      onPressed: _checkAnswers,
                      icon: const Icon(Icons.check_circle_outline),
                      label: Text(LanguageManager().getText('checkAnswers')),
                      style: TextButton.styleFrom(
                        foregroundColor: categoryColor,
                      ),
                    ),
                  if (_showResults)
                    TextButton.icon(
                      onPressed: _resetQuiz,
                      icon: const Icon(Icons.refresh),
                      label: Text(LanguageManager().getText('reset')),
                      style: TextButton.styleFrom(
                        foregroundColor: categoryColor,
                      ),
                    ),
                ],
              ),
            ),
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
                        Text(LanguageManager().getText('generatingQuestions')),
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
                            _buildErrorActionButton(context, categoryColor),
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
                                  LanguageManager().getText('noQuestionsAvailable'),
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
                    '${LanguageManager().getText('score')}: ${_getScore()} / ${_questions.length}',
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
    final successColor = Theme.of(context).colorScheme.tertiary;
    final errorColor = Theme.of(context).colorScheme.error;
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
              ? (isCorrect ? successColor : errorColor)
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
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.onPrimary,
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
                            ? successColor.withOpacity(0.1)
                            : isSelected && !isCorrectOption
                                ? errorColor.withOpacity(0.1)
                                : Colors.transparent)
                        : isSelected
                            ? categoryColor.withOpacity(0.1)
                            : Colors.transparent,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: showAnswer
                          ? (isCorrectOption
                              ? successColor
                              : isSelected && !isCorrectOption
                                  ? errorColor
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
                          color: successColor,
                          size: 20,
                        ),
                      if (showAnswer && isSelected && !isCorrectOption)
                        Icon(
                          Icons.cancel,
                          color: errorColor,
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

  /// Build error action button - "Watch Ads Now" and "Retry" for NoHeartsException, "Retry" only for others
  Widget _buildErrorActionButton(BuildContext context, Color categoryColor) {
    final heartService = HeartService();
    final admobService = AdMobService();
    
    if (_lastError is NoHeartsException && heartService.canEarnMoreHearts) {
      // Show both "Watch Ads Now" and "Retry" buttons for NoHeartsException
      return Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          ElevatedButton.icon(
            onPressed: () {
              if (admobService.isRewardedAdReady()) {
                admobService.showRewardedAd(
                  onRewarded: () {
                    heartService.earnHeart();
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('❤️ You earned 1 heart!'),
                        backgroundColor: Color(0xFF7A5CFF),
                        duration: Duration(seconds: 2),
                      ),
                    );
                    // Retry after earning heart
                    Future.delayed(const Duration(milliseconds: 500), _loadQuestions);
                  },
                  onAdFailedToShow: (error) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('Failed to show ad: $error'),
                        backgroundColor: Theme.of(context).colorScheme.error,
                      ),
                    );
                  },
                );
              } else {
                admobService.createRewardedAd();
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Ad is loading, please try again in a moment'),
                    duration: Duration(seconds: 2),
                  ),
                );
              }
            },
            icon: const Icon(Icons.play_circle_outline),
            label: const Text('Watch Ads Now'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.error,
              foregroundColor: Theme.of(context).colorScheme.onError,
            ),
          ),
          const SizedBox(width: 12),
          ElevatedButton.icon(
            onPressed: _loadQuestions,
            icon: const Icon(Icons.refresh),
            label: const Text('Retry'),
            style: ElevatedButton.styleFrom(
              backgroundColor: categoryColor,
              foregroundColor: Theme.of(context).colorScheme.onPrimary,
            ),
          ),
        ],
      );
    } else {
      // Show "Retry" button only for other errors
      return ElevatedButton.icon(
        onPressed: _loadQuestions,
        icon: const Icon(Icons.refresh),
        label: const Text('Retry'),
        style: ElevatedButton.styleFrom(
          backgroundColor: categoryColor,
          foregroundColor: Theme.of(context).colorScheme.onPrimary,
        ),
      );
    }
  }
}

