import 'package:flutter/foundation.dart';

import 'ai_cache_service.dart';
import 'episode_download_service.dart';
import 'image_cache_service.dart';
import 'local_database_service.dart';
import 'storage_service.dart';

enum AppCacheCategory {
  images,
  audioStream,
  downloads,
  aiLocal,
}

class CacheCategoryInfo {
  final AppCacheCategory id;
  final int sizeBytes;
  final bool selectedByDefault;
  final bool destructive;

  const CacheCategoryInfo({
    required this.id,
    required this.sizeBytes,
    required this.selectedByDefault,
    required this.destructive,
  });
}

/// Facade gom size/clear cache theo category cho Settings.
class AppCacheManager {
  static final AppCacheManager _instance = AppCacheManager._internal();
  factory AppCacheManager() => _instance;
  AppCacheManager._internal();

  final ImageCacheService _imageCache = ImageCacheService();
  final EpisodeDownloadService _downloads = EpisodeDownloadService();
  final StorageService _storage = StorageService();
  final AICacheService _aiCache = AICacheService();

  Future<Map<AppCacheCategory, int>> getSizes() async {
    final results = await Future.wait([
      _imageCache.getCacheSize(),
      kIsWeb ? Future.value(0) : _downloads.getStreamCacheSize(),
      kIsWeb ? Future.value(0) : _downloads.getDownloadsSize(),
      _storage.getAICacheSize(),
    ]);

    return {
      AppCacheCategory.images: results[0],
      AppCacheCategory.audioStream: results[1],
      AppCacheCategory.downloads: results[2],
      AppCacheCategory.aiLocal: results[3],
    };
  }

  Future<int> getTotalSize() async {
    final sizes = await getSizes();
    return sizes.values.fold<int>(0, (sum, size) => sum + size);
  }

  Future<List<CacheCategoryInfo>> getCategoryInfos() async {
    final sizes = await getSizes();
    return [
      CacheCategoryInfo(
        id: AppCacheCategory.images,
        sizeBytes: sizes[AppCacheCategory.images] ?? 0,
        selectedByDefault: true,
        destructive: false,
      ),
      CacheCategoryInfo(
        id: AppCacheCategory.audioStream,
        sizeBytes: sizes[AppCacheCategory.audioStream] ?? 0,
        selectedByDefault: true,
        destructive: false,
      ),
      CacheCategoryInfo(
        id: AppCacheCategory.downloads,
        sizeBytes: sizes[AppCacheCategory.downloads] ?? 0,
        selectedByDefault: false,
        destructive: true,
      ),
      CacheCategoryInfo(
        id: AppCacheCategory.aiLocal,
        sizeBytes: sizes[AppCacheCategory.aiLocal] ?? 0,
        selectedByDefault: false,
        destructive: false,
      ),
    ];
  }

  Future<void> clear(Set<AppCacheCategory> selected) async {
    if (selected.isEmpty) return;

    final futures = <Future<void>>[];

    if (selected.contains(AppCacheCategory.images)) {
      futures.add(_imageCache.clearCache());
    }
    if (selected.contains(AppCacheCategory.audioStream) && !kIsWeb) {
      futures.add(_downloads.clearStreamCache());
    }
    if (selected.contains(AppCacheCategory.downloads) && !kIsWeb) {
      futures.add(_downloads.clearAllDownloads());
    }
    if (selected.contains(AppCacheCategory.aiLocal)) {
      futures.add(_aiCache.clearAllCache());
    }

    await Future.wait(futures);

    // File local đã xóa nhưng SQLite còn path cũ → khôi phục URL remote để còn phát stream.
    final clearedLocalAudio = selected.contains(AppCacheCategory.downloads) ||
        selected.contains(AppCacheCategory.audioStream);
    if (clearedLocalAudio && !kIsWeb) {
      await LocalDatabaseService().restoreRemoteAudioUrlsAfterLocalFilesRemoved();
    }
  }

  String formatSize(int bytes) => _imageCache.formatCacheSize(bytes);
}
