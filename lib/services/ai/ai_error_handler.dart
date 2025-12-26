import 'dart:async';
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
      return 'AI service error. Trying backup...';
    } else if (error is InvalidResponseException) {
      return 'Invalid response from AI service. Please try again.';
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
        
        // Wait before retry
        await Future.delayed(delay);
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
      // If rate limit or API error, try backup
      if (e is RateLimitException || e is APIException) {
        try {
          return await action(backupProvider);
        } catch (backupError) {
          // If backup also fails, throw original error
          throw e;
        }
      }
      // For other errors, rethrow
      rethrow;
    }
  }
}

