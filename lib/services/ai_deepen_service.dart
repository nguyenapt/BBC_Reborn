import 'package:flutter/foundation.dart';
import '../config/ai_config.dart';
import '../models/deepen_feature.dart';
import 'ai/ai_provider_factory.dart';
import 'ai/ai_error_handler.dart';
import 'ai/exceptions.dart';
import 'ai_cache_service.dart';
import 'language_manager.dart';
import 'heart_service.dart';

/// Deepen a transcript line: paraphrase / chunks / simplify / nuance.
class AIDeepenService {
  static final AIDeepenService _instance = AIDeepenService._internal();
  factory AIDeepenService() => _instance;
  AIDeepenService._internal();

  final AICacheService _cache = AICacheService();
  final LanguageManager _languageManager = LanguageManager();

  String _getTargetLanguage([String? languageCode]) {
    final code = languageCode ?? _languageManager.currentLocale.languageCode;
    switch (code) {
      case 'vi':
        return 'Vietnamese';
      case 'zh':
        return 'Chinese';
      case 'ja':
        return 'Japanese';
      case 'ko':
        return 'Korean';
      case 'es':
        return 'Spanish';
      case 'pt':
        return 'Portuguese';
      case 'ar':
        return 'Arabic';
      case 'ru':
        return 'Russian';
      case 'fr':
        return 'French';
      case 'de':
        return 'German';
      case 'tr':
        return 'Turkish';
      case 'it':
        return 'Italian';
      case 'hi':
        return 'Hindi';
      default:
        return 'English';
    }
  }

  Future<Map<String, dynamic>> deepenLine({
    required DeepenFeature feature,
    required String text,
    required String episodeId,
    required int lineNumber,
    String? languageCode,
    String? context,
  }) async {
    if (!AIConfig.enableDeepen) {
      throw APIException('Deepen feature is temporarily disabled.');
    }

    final resolvedLanguageCode =
        languageCode ?? _languageManager.currentLocale.languageCode;
    final targetLanguage = _getTargetLanguage(resolvedLanguageCode);
    final featureKey = feature.featureKey;
    final action = feature.cloudAction;
    final normalized = text.trim();

    final cacheHit = await _cache.lookupDeepen(
      featureKey: featureKey,
      episodeId: episodeId,
      lineNumber: lineNumber,
      languageCode: resolvedLanguageCode,
    );

    if (cacheHit != null) {
      await AICacheService.consumeHeartIfFirebase(cacheHit.tier);
      debugPrint('Using cached deepen $featureKey for line_$lineNumber');
      return Map<String, dynamic>.from(cacheHit.data);
    }

    await HeartService().consumeForAIFeature();

    final primaryProvider = AIProviderFactory.getPrimaryProvider();
    final backupProvider = AIProviderFactory.getBackupProvider();

    Map<String, dynamic>? response;
    try {
      try {
        response = await AIErrorHandler.withRetry(
          () => primaryProvider.deepenLine(
            action,
            normalized,
            targetLanguage,
            context: context,
          ),
          maxRetries: 1,
        );
      } catch (e) {
        debugPrint('⚠️ Primary deepen failed: $e');
        if (e is APIException || e is RateLimitException) {
          if (await backupProvider.isAvailable()) {
            response = await backupProvider.deepenLine(
              action,
              normalized,
              targetLanguage,
              context: context,
            );
          } else {
            rethrow;
          }
        } else {
          rethrow;
        }
      }

      if (response == null) {
        throw APIException('Empty deepen response');
      }

      final enriched = Map<String, dynamic>.from(response);
      enriched['schemaVersion'] = deepenSchemaVersion;
      enriched['featureKey'] = featureKey;
      enriched['episodeId'] = episodeId;
      enriched['lineNumber'] = lineNumber;
      enriched['lineKey'] = 'line_$lineNumber';
      enriched['languageCode'] = resolvedLanguageCode;
      enriched['sourceSentence'] = normalized;

      await _cache.saveDeepenToCache(
        featureKey: featureKey,
        episodeId: episodeId,
        lineNumber: lineNumber,
        languageCode: resolvedLanguageCode,
        deepenData: enriched,
      );

      return enriched;
    } catch (e) {
      debugPrint('❌ deepenLine error: $e');
      rethrow;
    }
  }
}
