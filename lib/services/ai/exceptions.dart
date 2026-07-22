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
  final Duration? retryAfter;
  
  RateLimitException([String? message, dynamic originalError, this.retryAfter])
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

/// Exception for when user has no hearts available
class NoHeartsException extends AIException {
  NoHeartsException([dynamic originalError])
      : super('No hearts available. Please watch an ad to earn more hearts.', originalError);
}

/// STT not configured (local dev only — production uses Cloud STT).
class SpeechNotConfiguredException extends AIException {
  SpeechNotConfiguredException([dynamic originalError])
      : super('Speech recognition is not configured for local dev.', originalError);
}

/// Speaking analysis (evaluateSpeech) failed after STT succeeded.
class SpeakingAnalysisException extends AIException {
  SpeakingAnalysisException([String? message, dynamic originalError])
      : super(message ?? 'Speaking analysis failed.', originalError);
}

/// Ghi âm luyện nói thất bại (file rỗng, stop recorder, v.v.).
class SpeakingRecordingException extends AIException {
  SpeakingRecordingException([String? message, dynamic originalError])
      : super(message ?? 'Recording failed.', originalError);
}

/// App Check không lấy được token (debug token chưa đăng ký, attestation fail, v.v.).
class AppCheckException extends AIException {
  AppCheckException([String? message, dynamic originalError])
      : super(
          message ?? 'App Check verification failed.',
          originalError,
        );
}

