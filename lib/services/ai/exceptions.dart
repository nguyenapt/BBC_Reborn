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

/// Credit mode: need to open Episode Pass (spend 1 heart) before AI.
class NeedsEpisodePassException extends AIException {
  final String episodeId;
  NeedsEpisodePassException(this.episodeId, [dynamic originalError])
      : super('Open an episode AI pass to continue.', originalError);
}

/// Credit mode: pass open but credits exhausted.
class NoEpisodeCreditsException extends AIException {
  final String episodeId;
  NoEpisodeCreditsException(this.episodeId, [dynamic originalError])
      : super('No AI credits left for this episode.', originalError);
}

/// Credit mode: daily live API soft cap reached.
class DailyLiveAiCapException extends AIException {
  DailyLiveAiCapException([dynamic originalError])
      : super('Daily AI support limit reached.', originalError);
}

/// Credit mode: need speaking ticket (1 heart → N attempts).
class NeedsSpeakingTicketException extends AIException {
  NeedsSpeakingTicketException([dynamic originalError])
      : super('Open a speaking session to continue.', originalError);
}

/// Credit mode: speaking ticket attempts exhausted.
class NoSpeakingAttemptsException extends AIException {
  NoSpeakingAttemptsException([dynamic originalError])
      : super('No speaking attempts left.', originalError);
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

