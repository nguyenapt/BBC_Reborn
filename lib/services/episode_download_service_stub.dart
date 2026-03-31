class EpisodeDownloadService {
  Future<String?> downloadAudio({
    required String url,
    required String fileName,
  }) async {
    return null;
  }

  Future<String?> downloadedEpisodePathIfExists(String episodeId) async => null;

  Future<String?> streamCachedEpisodePathIfExists(String episodeId) async => null;

  Future<String?> downloadToStreamCache({
    required String url,
    required String episodeId,
  }) async =>
      null;

  Future<String?> promoteStreamCacheToDownload(String episodeId) async => null;

  Future<bool> fileExists(String path) async {
    return false;
  }
}
