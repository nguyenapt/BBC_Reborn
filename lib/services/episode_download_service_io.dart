import 'dart:io';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:http/http.dart' as http;

class EpisodeDownloadService {
  Future<String?> downloadAudio({
    required String url,
    required String fileName,
  }) async {
    try {
      final directory = await getApplicationDocumentsDirectory();
      final downloadsDir = Directory(p.join(directory.path, 'downloads'));
      if (!await downloadsDir.exists()) {
        await downloadsDir.create(recursive: true);
      }

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

  Future<bool> fileExists(String path) async {
    return File(path).exists();
  }
}
