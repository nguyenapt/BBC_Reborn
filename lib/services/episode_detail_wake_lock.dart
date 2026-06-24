import 'package:flutter/foundation.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

/// Giữ màn hình sáng khi có ít nhất một [EpisodeDetailScreen] trên stack.
///
/// Dùng ref-count vì `WakelockPlus` là toggle (không đếm ref): khi đổi episode
/// bằng `pushReplacement`, màn mới `enable` trước khi màn cũ `dispose` — gọi
/// `disable` trực tiếp trong `dispose` sẽ tắt nhầm wakelock.
class EpisodeDetailWakeLock {
  EpisodeDetailWakeLock._();

  static int _holders = 0;

  static Future<void> acquire() async {
    _holders++;
    if (_holders == 1) {
      try {
        await WakelockPlus.enable();
        debugPrint('EpisodeDetailWakeLock: enabled');
      } catch (e) {
        debugPrint('EpisodeDetailWakeLock: enable failed: $e');
      }
    }
  }

  static Future<void> release() async {
    if (_holders <= 0) return;
    _holders--;
    if (_holders == 0) {
      try {
        await WakelockPlus.disable();
        debugPrint('EpisodeDetailWakeLock: disabled');
      } catch (e) {
        debugPrint('EpisodeDetailWakeLock: disable failed: $e');
      }
    }
  }
}
