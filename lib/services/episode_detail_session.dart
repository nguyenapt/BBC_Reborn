import 'audio_player_service.dart';

/// Ref-count phiên Episode Detail — chỉ reset auto-play khi rời hẳn khỏi detail.
///
/// Tránh `resetAutoPlayNext()` trong `initState`/`dispose` khi `pushReplacement`
/// đổi episode (màn mới vào trước khi màn cũ dispose).
class EpisodeDetailSession {
  EpisodeDetailSession._();

  static int _holders = 0;

  static void acquire() {
    _holders++;
  }

  static void release() {
    if (_holders <= 0) return;
    _holders--;
    if (_holders == 0) {
      AudioPlayerService().resetAutoPlayNext();
    }
  }
}
