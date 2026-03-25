import 'dart:async';
import 'package:flutter/foundation.dart';
import 'exceptions.dart';
import 'ai_provider.dart';

/// Error handler for AI operations
class AIErrorHandler {
  /// Get user-friendly error message
  static String getErrorMessage(dynamic error) {
    if (error is RateLimitException) {
      return 'Too many requests. Please wait a moment.';
    } else if (error is NetworkException) {
      return 'Network error. Please check your connection.';
    } else if (error is APIException) {
      return error.message;
    } else if (error is InvalidResponseException) {
      return 'Invalid response from AI service. Please try again.';
    } else if (error is NoHeartsException) {
      return 'No hearts available. Watch an ad to earn more hearts.';
    } else if (error is AIException) {
      return error.message;
    }
    return 'An error occurred. Please try again.';
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
          final backupMsg = backupError is AIException
              ? backupError.message
              : backupError.toString();
          throw AIException(
            '${e.message} · Backup: $backupMsg',
            backupError,
          );
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

