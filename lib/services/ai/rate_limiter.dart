import 'dart:async';

/// Rate limiter to control API requests
class RateLimiter {
  final int maxRequestsPerMinute;
  final List<DateTime> requestTimes = [];
  
  RateLimiter({required this.maxRequestsPerMinute});
  
  /// Check if a request can be made
  Future<bool> canMakeRequest() async {
    final now = DateTime.now();
    // Remove requests older than 1 minute
    requestTimes.removeWhere((time) => 
      now.difference(time).inMinutes >= 1
    );
    
    if (requestTimes.length >= maxRequestsPerMinute) {
      return false; // Rate limited
    }
    
    requestTimes.add(now);
    return true;
  }
  
  /// Wait until a request can be made
  Future<void> waitUntilAvailable() async {
    while (!await canMakeRequest()) {
      // Calculate wait time
      if (requestTimes.isNotEmpty) {
        final oldestRequest = requestTimes.first;
        final waitSeconds = 60 - DateTime.now().difference(oldestRequest).inSeconds;
        if (waitSeconds > 0) {
          await Future.delayed(Duration(seconds: waitSeconds));
        }
      } else {
        await Future.delayed(const Duration(seconds: 1));
      }
    }
  }
  
  /// Reset rate limiter
  void reset() {
    requestTimes.clear();
  }
  
  /// Get remaining requests in current window
  int getRemainingRequests() {
    final now = DateTime.now();
    requestTimes.removeWhere((time) => 
      now.difference(time).inMinutes >= 1
    );
    return maxRequestsPerMinute - requestTimes.length;
  }
}

