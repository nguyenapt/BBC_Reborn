import 'package:flutter/material.dart';
import '../services/audio_player_service.dart';
import '../utils/category_colors.dart';

class AudioPlayerWidget extends StatelessWidget {
  final AudioPlayerService audioService;

  const AudioPlayerWidget({
    super.key,
    required this.audioService,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        boxShadow: [
          BoxShadow(
            color: Theme.of(context).colorScheme.shadow.withOpacity(0.3),
            spreadRadius: 1,
            blurRadius: 8,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Progress bar
              _buildProgressBar(),
              const SizedBox(height: 16),
              // Control buttons
              _buildControlButtons(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildProgressBar() {
    return ListenableBuilder(
      listenable: audioService,
      builder: (context, child) {
        final progress = audioService.totalDuration.inMilliseconds > 0
            ? audioService.currentPosition.inMilliseconds / audioService.totalDuration.inMilliseconds
            : 0.0;

        return Column(
          children: [
            SliderTheme(
              data: SliderTheme.of(context).copyWith(
                activeTrackColor: audioService.currentEpisode != null
                    ? CategoryColors.getCategoryColor(audioService.currentEpisode!.category)
                    : Colors.blue,
                inactiveTrackColor: Theme.of(context).colorScheme.onSurface.withOpacity(0.3),
                thumbColor: audioService.currentEpisode != null
                    ? CategoryColors.getCategoryColor(audioService.currentEpisode!.category)
                    : Colors.blue,
                overlayColor: audioService.currentEpisode != null
                    ? CategoryColors.getCategoryColor(audioService.currentEpisode!.category).withOpacity(0.2)
                    : Colors.blue.withOpacity(0.2),
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
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  _formatDuration(audioService.currentPosition),
                  style: TextStyle(
                    fontSize: 12, 
                    color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
                  ),
                ),
                Text(
                  _formatDuration(audioService.totalDuration),
                  style: TextStyle(
                    fontSize: 12, 
                    color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
                  ),
                ),
              ],
            ),
          ],
        );
      },
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

        final categoryColor = CategoryColors.getCategoryColor(episode.category);

        return Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            // Previous button
            IconButton(
              onPressed: audioService.currentEpisodeIndex > 0
                  ? () => audioService.previousEpisode()
                  : null,
              icon: Icon(
                Icons.skip_previous,
                color: audioService.currentEpisodeIndex > 0 
                    ? categoryColor 
                    : Theme.of(context).colorScheme.onSurface.withOpacity(0.3),
                size: 32,
              ),
            ),
            // Skip backward button
            IconButton(
              onPressed: () async => await audioService.skipBackward(),
              icon: Icon(
                Icons.replay_10,
                color: categoryColor,
                size: 28,
              ),
            ),
            // Play/Pause button
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
                  size: 32,
                ),
              ),
            ),
            // Skip forward button
            IconButton(
              onPressed: () async => await audioService.skipForward(),
              icon: Icon(
                Icons.forward_10,
                color: categoryColor,
                size: 28,
              ),
            ),
            // Next button
            IconButton(
              onPressed: audioService.currentEpisodeIndex < audioService.currentCategoryEpisodes.length - 1
                  ? () => audioService.nextEpisode()
                  : null,
              icon: Icon(
                Icons.skip_next,
                color: audioService.currentEpisodeIndex < audioService.currentCategoryEpisodes.length - 1
                    ? categoryColor
                    : Theme.of(context).colorScheme.onSurface.withOpacity(0.3),
                size: 32,
              ),
            ),
          ],
        );
      },
    );
  }

  String _formatDuration(Duration duration) {
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    final minutes = twoDigits(duration.inMinutes.remainder(60));
    final seconds = twoDigits(duration.inSeconds.remainder(60));
    return '$minutes:$seconds';
  }
}
