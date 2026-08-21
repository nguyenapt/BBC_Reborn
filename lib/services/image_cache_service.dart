// CachedNetworkImage + disk cache giảm số lần tải ảnh từ Firebase Storage (egress).
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';
import 'package:path_provider/path_provider.dart';
import 'navigation_service.dart';

class ImageCacheService {
  static final ImageCacheService _instance = ImageCacheService._internal();
  factory ImageCacheService() => _instance;
  ImageCacheService._internal();

  // Cấu hình cache
  static const int _maxCacheSize = 100; // Số lượng ảnh tối đa trong cache
  static const Duration _cacheDuration = Duration(days: 7); // Thời gian cache

  /// Widget để hiển thị ảnh với cache
  Widget buildCachedImage({
    required String imageUrl,
    required double width,
    required double height,
    BoxFit fit = BoxFit.cover,
    BorderRadius? borderRadius,
    Widget? placeholder,
    Widget? errorWidget,
    Color? placeholderColor,
    Color? errorColor,
    bool showWatermark = false,
    IconData watermarkIcon = Icons.copyright_rounded,
    double watermarkOpacity = 0.32,
    String? watermarkAssetPath = 'assets/images/logo.png',
  }) {
    final image = CachedNetworkImage(
      imageUrl: imageUrl,
      width: width,
      height: height,
      fit: fit,
      placeholder: (context, url) => placeholder ?? _buildPlaceholder(
        width: width,
        height: height,
        color: placeholderColor,
      ),
      errorWidget: (context, url, error) => errorWidget ?? _buildErrorWidget(
        width: width,
        height: height,
        color: errorColor,
      ),
      memCacheWidth: width.toInt(),
      memCacheHeight: height.toInt(),
      maxWidthDiskCache: (width * 2).toInt(), // Cache với độ phân giải cao hơn
      maxHeightDiskCache: (height * 2).toInt(),
    );

    final clippedRadius = borderRadius ?? BorderRadius.circular(8);
    return ClipRRect(
      borderRadius: clippedRadius,
      child: SizedBox(
        width: width,
        height: height,
        child: showWatermark
            ? _buildWatermarkedImage(
                image: image,
                width: width,
                height: height,
                watermarkIcon: watermarkIcon,
                watermarkOpacity: watermarkOpacity,
                watermarkAssetPath: watermarkAssetPath,
              )
            : image,
      ),
    );
  }

  Widget _buildWatermarkedImage({
    required Widget image,
    required double width,
    required double height,
    required IconData watermarkIcon,
    required double watermarkOpacity,
    String? watermarkAssetPath,
  }) {
    final iconSize = (height * 0.22).clamp(11.0, 16.0);
    final logoWidth = (height * 0.38).clamp(15.0, 24.0);
    final badgePadding = (height * 0.04).clamp(2.0, 4.0);
    final inset = (height * 0.04).clamp(2.0, 4.0);
    return Stack(
      fit: StackFit.expand,
      children: [
        image,
        Positioned(
          right: inset,
          bottom: inset,
          child: IgnorePointer(
            child: Opacity(
              opacity: watermarkOpacity.clamp(0.0, 1.0),
              child: Container(
                padding: EdgeInsets.all(badgePadding),
                decoration: BoxDecoration(
                  color: const Color(0xAA000000),
                  shape: BoxShape.circle,
                ),
                child: watermarkAssetPath != null
                    ? Image.asset(
                        watermarkAssetPath,
                        width: logoWidth,
                        fit: BoxFit.contain,
                        errorBuilder: (context, error, stackTrace) {
                          return Icon(
                            watermarkIcon,
                            size: iconSize,
                            color: Colors.white,
                          );
                        },
                      )
                    : Icon(
                        watermarkIcon,
                        size: iconSize,
                        color: Colors.white,
                      ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  /// Widget placeholder mặc định
  Widget _buildPlaceholder({
    required double width,
    required double height,
    Color? color,
  }) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: color ?? Colors.grey[300],
        borderRadius: BorderRadius.circular(8),
      ),
      child: const Center(
        child: CircularProgressIndicator(
          strokeWidth: 2,
        ),
      ),
    );
  }

  /// Widget error mặc định
  Widget _buildErrorWidget({
    required double width,
    required double height,
    Color? color,
  }) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: color ?? Colors.grey[300],
        borderRadius: BorderRadius.circular(8),
      ),
      child: Icon(
        Icons.image_not_supported,
        color: color ?? Colors.grey,
        size: (width * 0.4).clamp(20.0, 40.0),
      ),
    );
  }

  /// Đường dẫn file thumbnail đã cache (dùng cho media notification).
  Future<String?> cachedImageLocalPath(String imageUrl) async {
    if (imageUrl.isEmpty) return null;
    try {
      final cached = await DefaultCacheManager().getFileFromCache(imageUrl);
      if (cached != null && await cached.file.exists()) {
        return cached.file.path;
      }
    } catch (e) {
      debugPrint('cachedImageLocalPath failed: $e');
    }
    return null;
  }

  /// Preload ảnh vào cache
  Future<void> preloadImage(String imageUrl) async {
    try {
      await precacheImage(
        CachedNetworkImageProvider(imageUrl),
        NavigationService.navigatorKey.currentContext!,
      );
    } catch (e) {
      debugPrint('Error preloading image: $e');
    }
  }

  /// Preload nhiều ảnh cùng lúc
  Future<void> preloadImages(List<String> imageUrls) async {
    final futures = imageUrls.map((url) => preloadImage(url));
    await Future.wait(futures);
  }

  /// Xóa cache disk (DefaultCacheManager) + memory image cache.
  Future<void> clearCache() async {
    try {
      await DefaultCacheManager().emptyCache();
      PaintingBinding.instance.imageCache.clear();
      PaintingBinding.instance.imageCache.clearLiveImages();
      debugPrint('Image cache cleared');
    } catch (e) {
      debugPrint('Error clearing cache: $e');
    }
  }

  /// Lấy kích thước cache disk của DefaultCacheManager (`libCachedImageData`).
  Future<int> getCacheSize() async {
    try {
      final directory = await getTemporaryDirectory();
      final cacheDir = Directory('${directory.path}/${DefaultCacheManager.key}');

      if (!await cacheDir.exists()) {
        return 0;
      }

      int totalSize = 0;
      await for (final entity in cacheDir.list(recursive: true)) {
        if (entity is File) {
          totalSize += await entity.length();
        }
      }

      return totalSize;
    } catch (e) {
      debugPrint('Error getting cache size: $e');
      return 0;
    }
  }

  /// Format kích thước cache thành string dễ đọc
  String formatCacheSize(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    if (bytes < 1024 * 1024 * 1024) {
      return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    }
    return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(1)} GB';
  }

  /// Xóa cache cũ (older than cache duration)
  Future<void> clearOldCache() async {
    try {
      final directory = await getTemporaryDirectory();
      final cacheDir = Directory('${directory.path}/${DefaultCacheManager.key}');

      if (!await cacheDir.exists()) return;

      final now = DateTime.now();
      await for (final entity in cacheDir.list(recursive: true)) {
        if (entity is File) {
          final stat = await entity.stat();
          if (now.difference(stat.modified).compareTo(_cacheDuration) > 0) {
            await entity.delete();
          }
        }
      }
    } catch (e) {
      debugPrint('Error clearing old cache: $e');
    }
  }
}
