import 'package:flutter/foundation.dart';

/// Service để quản lý back navigation timer reset
/// Cho phép reset double back timer từ bất kỳ đâu trong app
class BackNavigationService {
  static final BackNavigationService _instance = BackNavigationService._internal();
  factory BackNavigationService() => _instance;
  BackNavigationService._internal();

  /// Callback function để reset back timer
  /// Được set từ main.dart state
  VoidCallback? _resetBackTimerCallback;

  /// Set callback để reset back timer
  void setResetBackTimerCallback(VoidCallback? callback) {
    _resetBackTimerCallback = callback;
  }

  /// Reset back timer nếu callback đã được set
  void resetBackTimer() {
    if (_resetBackTimerCallback != null) {
      _resetBackTimerCallback!();
      debugPrint('🔄 Back timer reset');
    } else {
      debugPrint('⚠️ Reset back timer callback not set');
    }
  }
}

