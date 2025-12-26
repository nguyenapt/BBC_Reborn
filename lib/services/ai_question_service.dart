import 'package:flutter/foundation.dart';
import '../models/question.dart';
import 'ai/ai_provider_factory.dart';
import 'ai/ai_error_handler.dart';
import 'ai/exceptions.dart';
import 'ai_cache_service.dart';

/// Service for AI-powered question generation
class AIQuestionService {
  static final AIQuestionService _instance = AIQuestionService._internal();
  factory AIQuestionService() => _instance;
  AIQuestionService._internal();

  final AICacheService _cache = AICacheService();

  /// Generate questions from transcript
  Future<List<Question>> generateQuestions(
    String transcript,
    String episodeId, {
    int count = 5,
  }) async {
    // Check cache with priority: Local → Firebase → null
    final cachedData = await _cache.getQuestionsFromCache(episodeId, count);

    if (cachedData != null && cachedData.isNotEmpty) {
      debugPrint('Using cached questions for episode $episodeId');
      // Convert cached data to Question objects
      final questions = <Question>[];
      for (int i = 0; i < cachedData.length; i++) {
        try {
          final question = Question.fromAIResponse(cachedData[i], i);
          questions.add(question);
        } catch (e) {
          debugPrint('Error parsing cached question $i: $e');
        }
      }
      if (questions.isNotEmpty) {
        return questions;
      }
    }

    // Get provider with fallback
    final provider = await AIProviderFactory.createProviderWithFallback();

    try {
      final response = await AIErrorHandler.withRetry(
        () => provider.generateQuestions(transcript, count: count),
      );

      // Parse questions from response
      final questions = <Question>[];
      for (int i = 0; i < response.length; i++) {
        try {
          final question = Question.fromAIResponse(response[i], i);
          questions.add(question);
        } catch (e) {
          debugPrint('Error parsing question $i: $e');
          // Continue with other questions
        }
      }

      // Save to both local and Firebase cache
      if (questions.isNotEmpty) {
        final questionsData = questions.map((q) => q.toJson()).toList();
        await _cache.saveQuestionsToCache(episodeId, count, questionsData);
      }

      return questions;
    } catch (e) {
      debugPrint('Error generating questions: $e');
      throw AIException('Failed to generate questions: ${AIErrorHandler.getErrorMessage(e)}', e);
    }
  }

  /// Generate questions from transcript lines
  Future<List<Question>> generateQuestionsFromLines(
    List<String> transcriptLines,
    String episodeId, {
    int count = 5,
  }) async {
    // Combine lines into transcript text
    final transcript = transcriptLines.join(' ');
    return generateQuestions(transcript, episodeId, count: count);
  }
}

