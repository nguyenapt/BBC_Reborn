// Lưu file sau khi tải giúp tránh lặp egress Firebase Storage cho cùng một episode.
import 'dart:io';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:http/http.dart' as http;

class EpisodeDownloadService {
  static const String _downloadsSubdir = 'downloads';
  static const String _streamCacheSubdir = 'audio_stream_cache';

  Future<Directory> _downloadsDir() async {
    final directory = await getApplicationDocumentsDirectory();
    final dir = Directory(p.join(directory.path, _downloadsSubdir));
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }
    return dir;
  }

  Future<Directory> _streamCacheDir() async {
    final directory = await getApplicationDocumentsDirectory();
    final dir = Directory(p.join(directory.path, _streamCacheSubdir));
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }
    return dir;
  }

  /// Tải thủ công → `downloads/{fileName}` (thường `{episodeId}.mp3`).
  Future<String?> downloadAudio({
    required String url,
    required String fileName,
  }) async {
    try {
      final downloadsDir = await _downloadsDir();
      final filePath = p.join(downloadsDir.path, fileName);
      final response = await http.get(Uri.parse(url));
      if (response.statusCode != 200) {
        return null;
      }

      final file = File(filePath);
      await file.writeAsBytes(response.bodyBytes, flush: true);
      return filePath;
    } catch (_) {
      return null;
    }
  }

  /// Đường dẫn file download thủ công nếu đã tồn tại.
  Future<String?> downloadedEpisodePathIfExists(String episodeId) async {
    if (episodeId.isEmpty) return null;
    try {
      final downloadsDir = await _downloadsDir();
      final filePath = p.join(downloadsDir.path, '$episodeId.mp3');
      if (await File(filePath).exists()) return filePath;
    } catch (_) {}
    return null;
  }

  /// Cache ngầm sau khi phát stream → `audio_stream_cache/{episodeId}.mp3`.
  Future<String?> streamCachedEpisodePathIfExists(String episodeId) async {
    if (episodeId.isEmpty) return null;
    try {
      final dir = await _streamCacheDir();
      final filePath = p.join(dir.path, '$episodeId.mp3');
      if (await File(filePath).exists()) return filePath;
    } catch (_) {}
    return null;
  }

  /// Chuyển file từ stream cache sang `downloads/` (không tải lại từ mạng).
  /// Dùng khi user bấm Download nhưng đã có `audio_stream_cache/{episodeId}.mp3`.
  Future<String?> promoteStreamCacheToDownload(String episodeId) async {
    if (episodeId.isEmpty) return null;
    try {
      final already = await downloadedEpisodePathIfExists(episodeId);
      if (already != null) return already;

      final streamPath = await streamCachedEpisodePathIfExists(episodeId);
      if (streamPath == null) return null;

      final downloadsDir = await _downloadsDir();
      final destPath = p.join(downloadsDir.path, '$episodeId.mp3');
      final src = File(streamPath);
      try {
        await src.rename(destPath);
      } on FileSystemException {
        await src.copy(destPath);
        await src.delete();
      }
      return destPath;
    } catch (_) {
      return null;
    }
  }

  /// Tải nền một lần; bỏ qua nếu file đã có.
  Future<String?> downloadToStreamCache({
    required String url,
    required String episodeId,
  }) async {
    if (episodeId.isEmpty) return null;
    try {
      final existing = await streamCachedEpisodePathIfExists(episodeId);
      if (existing != null) return existing;

      final dir = await _streamCacheDir();
      final filePath = p.join(dir.path, '$episodeId.mp3');
      final response = await http.get(Uri.parse(url));
      if (response.statusCode != 200) {
        return null;
      }
      final file = File(filePath);
      await file.writeAsBytes(response.bodyBytes, flush: true);
      return filePath;
    } catch (_) {
      return null;
    }
  }

  Future<bool> fileExists(String path) async {
    return File(path).exists();
  }
}
