import 'package:flutter/foundation.dart';
import '../models/speaking_feedback.dart';
import 'ai/ai_provider_factory.dart';
import 'ai/ai_error_handler.dart';
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
    debugPrint('Speaking[evaluate] start referenceLen=${referenceText.length}');

    final primaryProvider = AIProviderFactory.getPrimaryProvider();
    final backupProvider = AIProviderFactory.getBackupProvider();

    try {
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

      await HeartService().consumeForAIFeature();

      debugPrint('Speaking[evaluate] ok score=${resultMap['overallScore']}');
      return SpeakingFeedback.fromMap(resultMap);
    } catch (e) {
      debugPrint('Speaking[evaluate] failed: $e');
      rethrow;
    }
  }
}
