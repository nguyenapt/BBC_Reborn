import 'package:flutter/material.dart';

import '../models/episode_learning_progress.dart';
import '../services/image_cache_service.dart';

/// Thumbnail episode kèm progress ring (dùng cho layout ngang trên Home).
class EpisodeThumbnailWithProgress extends StatelessWidget {
  final String imageUrl;
  final double width;
  final double height;
  final EpisodeLearningProgress? learningProgress;

  const EpisodeThumbnailWithProgress({
    super.key,
    required this.imageUrl,
    required this.width,
    required this.height,
    this.learningProgress,
  });

  @override
  Widget build(BuildContext context) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        ImageCacheService().buildCachedImage(
          imageUrl: imageUrl,
          width: width,
          height: height,
          fit: BoxFit.cover,
          borderRadius: BorderRadius.circular(8),
          showWatermark: true,
        ),
        if (learningProgress != null && learningProgress!.shouldShowProgressRing)
          Positioned(
            right: -4,
            top: -4,
            child: EpisodeProgressRing(
              progress: learningProgress!.ringProgressValue,
              size: 18,
              strokeWidth: 2,
            ),
          ),
      ],
    );
  }
}

class EpisodeProgressRing extends StatelessWidget {
  final double progress;
  final double size;
  final double strokeWidth;

  const EpisodeProgressRing({
    super.key,
    required this.progress,
    this.size = 22,
    this.strokeWidth = 2.5,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final clamped = progress.clamp(0.0, 1.0);
    return SizedBox(
      width: size,
      height: size,
      child: CircularProgressIndicator(
        value: clamped <= 0 ? null : clamped,
        strokeWidth: strokeWidth,
        backgroundColor: colorScheme.outlineVariant.withOpacity(0.35),
        color: colorScheme.primary,
      ),
    );
  }
}
