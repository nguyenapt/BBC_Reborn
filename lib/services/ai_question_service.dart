import 'package:flutter/foundation.dart';
import '../models/question.dart';
import 'ai/ai_provider_factory.dart';
import 'ai/ai_error_handler.dart';
import 'ai/exceptions.dart';
import 'ai_cache_lookup.dart';
import 'ai_cache_service.dart';
import 'heart_service.dart';

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

    if (cachedData != null && cachedData.value.isNotEmpty) {
      debugPrint('Using cached questions for episode $episodeId');
      final rows = cachedData.value;
      final questions = <Question>[];
      for (int i = 0; i < rows.length; i++) {
        try {
          final question = Question.fromAIResponse(rows[i], i);
          questions.add(question);
        } catch (e) {
          debugPrint('Error parsing cached question $i: $e');
        }
      }
      if (questions.isNotEmpty) {
        if (cachedData.source == AiCacheSource.firebase) {
          await HeartService().consumeHeartOrThrow();
        }
        return questions;
      }
    }

    await HeartService().consumeHeartOrThrow();

    // Get providers (primary and backup)
    final primaryProvider = AIProviderFactory.getPrimaryProvider();
    final backupProvider = AIProviderFactory.getBackupProvider();

    try {
      // Try primary provider first with retry
      List<Map<String, dynamic>>? response;
      try {
        response = await AIErrorHandler.withRetry(
          () => primaryProvider.generateQuestions(transcript, count: count),
          maxRetries: 1, // Only 1 retry, then fallback
        );
        debugPrint('✅ Primary provider (Gemini) question generation successful');
      } catch (e) {
        debugPrint('⚠️ Primary provider failed: $e');
        
        // If rate limit with long retry time (>30s), try backup provider immediately
        if (e is RateLimitException && e.retryAfter != null && e.retryAfter!.inSeconds > 30) {
          debugPrint('⚠️ Rate limit retry time too long (${e.retryAfter!.inSeconds}s), falling back to OpenAI...');
          try {
            if (await backupProvider.isAvailable()) {
              response = await backupProvider.generateQuestions(transcript, count: count);
              debugPrint('✅ Backup provider (OpenAI) question generation successful');
            } else {
              rethrow;
            }
          } catch (backupError) {
            debugPrint('❌ Backup provider also failed: $backupError');
            rethrow;
          }
        } else if (e is APIException || e is RateLimitException) {
          // For other API errors or short retry times, try backup
          debugPrint('⚠️ Trying backup provider due to API error...');
          try {
            if (await backupProvider.isAvailable()) {
              response = await backupProvider.generateQuestions(transcript, count: count);
              debugPrint('✅ Backup provider (OpenAI) question generation successful');
            } else {
              rethrow;
            }
          } catch (backupError) {
            debugPrint('❌ Backup provider also failed: $backupError');
            rethrow;
          }
        } else {
          rethrow;
        }
      }

      if (response == null) {
        throw Exception('Question generation failed: no result');
      }

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

