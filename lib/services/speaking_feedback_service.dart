import 'package:flutter/foundation.dart';
import '../models/speaking_feedback.dart';
import 'ai/ai_provider_factory.dart';
import 'ai/ai_error_handler.dart';
import 'ai/exceptions.dart';
import 'heart_service.dart';

class SpeakingFeedbackService {
  static final SpeakingFeedbackService _instance =
      SpeakingFeedbackService._internal();
  factory SpeakingFeedbackService() => _instance;
  SpeakingFeedbackService._internal();

  Future<SpeakingFeedback> evaluateSpeech({
    required String referenceText,
    required String spokenText,
    String? language,
  }) async {
    final heartService = HeartService();
    if (!heartService.hasHearts) {
      throw NoHeartsException();
    }

    final heartUsed = await heartService.useHeart();
    if (!heartUsed) {
      throw NoHeartsException();
    }

    final primaryProvider = AIProviderFactory.getPrimaryProvider();
    final backupProvider = AIProviderFactory.getBackupProvider();

    final resultMap = await AIErrorHandler.withRetry(() async {
      return AIErrorHandler.withProviderFallback(
        (provider) => provider.evaluateSpeech(
          referenceText: referenceText,
          spokenText: spokenText,
          language: language,
        ),
        primaryProvider,
        backupProvider,
      );
    });

    debugPrint('✅ Speaking feedback result: $resultMap');
    return SpeakingFeedback.fromMap(resultMap);
  }
}
