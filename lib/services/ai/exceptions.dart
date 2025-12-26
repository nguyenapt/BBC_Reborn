/// Base exception for AI-related errors
class AIException implements Exception {
  final String message;
  final dynamic originalError;
  
  AIException(this.message, [this.originalError]);
  
  @override
  String toString() => message;
}

/// Rate limit exception
class RateLimitException extends AIException {
  RateLimitException([String? message, dynamic originalError])
      : super(message ?? 'Rate limit exceeded. Please wait a moment.', originalError);
}

/// Network exception
class NetworkException extends AIException {
  NetworkException([String? message, dynamic originalError])
      : super(message ?? 'Network error. Please check your connection.', originalError);
}

/// API exception
class APIException extends AIException {
  final int? statusCode;
  
  APIException(String message, [this.statusCode, dynamic originalError])
      : super(message, originalError);
}

/// Invalid response exception
class InvalidResponseException extends AIException {
  InvalidResponseException([String? message, dynamic originalError])
      : super(message ?? 'Invalid response from AI service.', originalError);
}

