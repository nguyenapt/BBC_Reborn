import 'dart:async';
import 'package:flutter/foundation.dart';
import '../language_manager.dart';
import 'exceptions.dart';
import 'ai_provider.dart';

/// Error handler for AI operations
class AIErrorHandler {
  static final LanguageManager _languageManager = LanguageManager();

  /// Thông báo chung cho người dùng (không lộ chi tiết API/JSON).
  static String get genericUserMessage =>
      _languageManager.getText('aiGenericError');

  static String _rawMessage(dynamic error) {
    if (error is AIException) return error.message;
    return error?.toString() ?? '';
  }

  /// Ẩn JSON, status code, tên provider, API key, stack trace, v.v.
  static bool _looksTechnical(String message) {
    final m = message.trim();
    if (m.isEmpty) return true;
    if (m.length > 180) return true;

    final lower = m.toLowerCase();
    const markers = [
      '{',
      '"error"',
      '"message"',
      'api error',
      'openai',
      'gemini',
      'azure stt',
      'invalid_api',
      'incorrect api key',
      'backup:',
      'translation failed',
      'failed to generate',
      'not initialized',
      'api key',
      'sk-proj',
      'sk-',
      'aiza',
      'exception',
      'stacktrace',
      'dart:',
      'http://',
      'https://',
      'statuscode',
      'status code',
    ];
    for (final marker in markers) {
      if (lower.contains(marker)) return true;
    }
    if (RegExp(r'\b(401|403|404|429|500|502|503)\b').hasMatch(m)) {
      return true;
    }
    return false;
  }

  /// Get user-friendly error message (never expose raw API responses).
  static String getErrorMessage(dynamic error) {
    final raw = _rawMessage(error);
    if (kDebugMode && raw.isNotEmpty) {
      debugPrint('AI error (hidden from user): $raw');
    }

    if (error is NoHeartsException) {
      return _languageManager.getText('noHeartsAvailable');
    }
    if (error is RateLimitException) {
      return _languageManager.getText('aiRateLimitError');
    }
    if (error is NetworkException) {
      return _languageManager.getText('aiNetworkError');
    }
    if (error is APIException || error is InvalidResponseException) {
      return genericUserMessage;
    }
    if (error is AIException) {
      return _looksTechnical(raw) ? genericUserMessage : raw;
    }
    if (_looksTechnical(raw)) {
      return genericUserMessage;
    }
    return _languageManager.getText('errorOccurred');
  }
  
  /// Execute action with retry logic
  static Future<T> withRetry<T>(
    Future<T> Function() action, {
    int maxRetries = 2,
    Duration delay = const Duration(seconds: 2),
  }) async {
    int attempts = 0;
    
    while (attempts < maxRetries) {
      try {
        return await action();
      } catch (e) {
        attempts++;
        
        if (attempts >= maxRetries) {
          rethrow;
        }
        
        // If it's a RateLimitException with retryAfter, use that duration
        Duration retryDelay = delay;
        if (e is RateLimitException && e.retryAfter != null) {
          retryDelay = e.retryAfter!;
          // Add a small buffer (1 second) to the retry time
          retryDelay = Duration(seconds: retryDelay.inSeconds + 1);
          debugPrint('⏳ Waiting ${retryDelay.inSeconds}s before retry due to quota limit...');
        } else if (e is RateLimitException) {
          // Exponential backoff for rate limits without specific retry time
          retryDelay = Duration(seconds: delay.inSeconds * attempts);
          debugPrint('⏳ Waiting ${retryDelay.inSeconds}s before retry (attempt $attempts)...');
        }
        
        // Wait before retry
        await Future.delayed(retryDelay);
      }
    }
    
    throw Exception('Max retries exceeded');
  }
  
  /// Execute action with provider fallback
  static Future<T> withProviderFallback<T>(
    Future<T> Function(AIProvider) action,
    AIProvider primaryProvider,
    AIProvider backupProvider,
  ) async {
    // Try primary provider first
    try {
      return await action(primaryProvider);
    } catch (e) {
      // If rate limit with long retry time (>30s) or quota exceeded, try backup immediately
      if (e is RateLimitException) {
        final shouldFallback = e.retryAfter != null && e.retryAfter!.inSeconds > 30;
        if (shouldFallback) {
          debugPrint('⚠️ Rate limit retry time too long (${e.retryAfter!.inSeconds}s), falling back to backup provider');
          try {
            return await action(backupProvider);
          } catch (backupError) {
            // If backup also fails, throw original error
            throw e;
          }
        }
        // For shorter retry times, rethrow to let retry logic handle it
        rethrow;
      }
      
      // If API error, try backup
      if (e is APIException) {
        try {
          return await action(backupProvider);
        } catch (backupError) {
          if (kDebugMode) {
            debugPrint(
              'AI provider fallback failed. primary=$e backup=$backupError',
            );
          }
          throw AIException(genericUserMessage, backupError);
        }
      }

      // Primary returned unusable JSON/text — backup model may still succeed
      if (e is InvalidResponseException) {
        debugPrint('⚠️ Invalid response from primary AI, trying backup provider...');
        try {
          return await action(backupProvider);
        } catch (backupError) {
          rethrow;
        }
      }

      // For other errors, rethrow
      rethrow;
    }
  }
}

