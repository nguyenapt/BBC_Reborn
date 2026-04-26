import 'package:flutter/material.dart';
import '../services/audio_player_service.dart';
import '../utils/category_colors.dart';

class AudioPlayerWidget extends StatelessWidget {
  final AudioPlayerService audioService;
  final Future<void> Function()? onPlayPressed;

  const AudioPlayerWidget({
    super.key,
    required this.audioService,
    this.onPlayPressed,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 330),
        child: Container(
          clipBehavior: Clip.antiAlias,
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surface,
            borderRadius: BorderRadius.circular(22),
            boxShadow: [
              BoxShadow(
                color: Theme.of(context).colorScheme.shadow.withOpacity(0.25),
                blurRadius: 12,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 10, 12, 8),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _buildCenterControls(context),
                const SizedBox(height: 8),
                _buildControlButtons(),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildControlButtons() {
    return ListenableBuilder(
      listenable: audioService,
      builder: (context, child) {
        final episode = audioService.currentEpisode;
        if (episode == null) {
          return const SizedBox.shrink();
        }

        final progress = audioService.totalDuration.inMilliseconds > 0
            ? audioService.currentPosition.inMilliseconds / audioService.totalDuration.inMilliseconds
            : 0.0;

        final categoryColor = CategoryColors.getCategoryColor(episode.category);

        return SliderTheme(
          data: SliderTheme.of(context).copyWith(
            activeTrackColor: categoryColor,
            inactiveTrackColor: Theme.of(context).colorScheme.onSurface.withOpacity(0.15),
            thumbColor: Colors.transparent,
            overlayColor: Colors.transparent,
            thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 0),
            overlayShape: const RoundSliderOverlayShape(overlayRadius: 0),
            trackHeight: 3,
          ),
          child: Slider(
            value: progress.clamp(0.0, 1.0),
            onChanged: (value) async {
              final newPosition = Duration(
                milliseconds: (value * audioService.totalDuration.inMilliseconds).round(),
              );
              await audioService.seekTo(newPosition);
            },
          ),
        );
      },
    );
  }

  Widget _buildCenterControls(BuildContext context) {
    return ListenableBuilder(
      listenable: audioService,
      builder: (context, child) {
        final episode = audioService.currentEpisode;
        if (episode == null) {
          return const SizedBox.shrink();
        }

        final categoryColor = CategoryColors.getCategoryColor(episode.category);

        return Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              onPressed: () async => await audioService.skipBackward(),
              icon: Icon(
                Icons.skip_previous_rounded,
                color: categoryColor,
                size: 30,
              ),
            ),
            Container(
              decoration: BoxDecoration(
                color: categoryColor,
                shape: BoxShape.circle,
              ),
              child: IconButton(
                onPressed: () async {
                  if (audioService.isPlaying) {
                    await audioService.pause();
                  } else if (audioService.isPaused) {
                    await audioService.resume();
                  } else {
                    // Gọi callback trước khi play (để hiển thị interstitial ads nếu cần)
                    await onPlayPressed?.call();
                    await audioService.play();
                  }
                },
                icon: Icon(
                  audioService.isLoading
                      ? Icons.hourglass_empty
                      : audioService.isPlaying
                          ? Icons.pause
                          : Icons.play_arrow,
                  color: Colors.white,
                  size: 30,
                ),
              ),
            ),
            IconButton(
              onPressed: () async => await audioService.skipForward(),
              icon: Icon(
                Icons.skip_next_rounded,
                color: categoryColor,
                size: 30,
              ),
            ),
          ],
        );
      },
    );
  }
}
