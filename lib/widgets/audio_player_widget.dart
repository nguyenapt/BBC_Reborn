import 'package:flutter/material.dart';
import '../services/audio_player_service.dart';
import '../utils/category_colors.dart';

class AudioPlayerWidget extends StatefulWidget {
  final AudioPlayerService audioService;
  final Future<void> Function()? onPlayPressed;

  const AudioPlayerWidget({
    super.key,
    required this.audioService,
    this.onPlayPressed,
  });

  @override
  State<AudioPlayerWidget> createState() => _AudioPlayerWidgetState();
}

class _AudioPlayerWidgetState extends State<AudioPlayerWidget> {
  bool _isDragging = false;
  double _dragProgress = 0;

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
      listenable: widget.audioService,
      builder: (context, child) {
        final episode = widget.audioService.currentEpisode;
        if (episode == null) {
          return const SizedBox.shrink();
        }

        final progress = widget.audioService.totalDuration.inMilliseconds > 0
            ? widget.audioService.currentPosition.inMilliseconds /
                widget.audioService.totalDuration.inMilliseconds
            : 0.0;
        final effectiveProgress = _isDragging ? _dragProgress : progress;
        final effectivePosition = Duration(
          milliseconds:
              (effectiveProgress * widget.audioService.totalDuration.inMilliseconds)
                  .round(),
        );
        final remainingDuration =
            widget.audioService.totalDuration - effectivePosition;

        final categoryColor = CategoryColors.getCategoryColor(episode.category);

        return Row(
          children: [
            SizedBox(
              width: 40,
              child: Text(
                _formatDuration(effectivePosition),
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 11,
                  color: Theme.of(context).colorScheme.onSurface.withOpacity(0.65),
                ),
              ),
            ),
            Expanded(
              child: SliderTheme(
                data: SliderTheme.of(context).copyWith(
                  activeTrackColor: categoryColor,
                  inactiveTrackColor:
                      Theme.of(context).colorScheme.onSurface.withOpacity(0.15),
                  thumbColor: Colors.transparent,
                  overlayColor: Colors.transparent,
                  thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 0),
                  overlayShape: const RoundSliderOverlayShape(overlayRadius: 0),
                  trackHeight: 3,
                ),
                child: Slider(
                  value: effectiveProgress.clamp(0.0, 1.0),
                  onChangeStart: (value) {
                    setState(() {
                      _isDragging = true;
                      _dragProgress = value;
                    });
                  },
                  onChanged: (value) {
                    setState(() {
                      _dragProgress = value;
                    });
                  },
                  onChangeEnd: (value) async {
                    setState(() {
                      _isDragging = false;
                    });
                    final newPosition = Duration(
                      milliseconds:
                          (value * widget.audioService.totalDuration.inMilliseconds)
                              .round(),
                    );
                    await widget.audioService.seekTo(newPosition);
                  },
                ),
              ),
            ),
            SizedBox(
              width: 40,
              child: Text(
                '-${_formatDuration(remainingDuration.isNegative ? Duration.zero : remainingDuration)}',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 11,
                  color: Theme.of(context).colorScheme.onSurface.withOpacity(0.65),
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildCenterControls(BuildContext context) {
    return ListenableBuilder(
      listenable: widget.audioService,
      builder: (context, child) {
        final episode = widget.audioService.currentEpisode;
        if (episode == null) {
          return const SizedBox.shrink();
        }

        final categoryColor = CategoryColors.getCategoryColor(episode.category);

        return Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              onPressed: () async => await widget.audioService.skipBackward(),
              icon: Icon(
                Icons.replay_10_rounded,
                color: categoryColor,
                size: 24,
              ),
            ),
            Container(
              decoration: BoxDecoration(
                color: categoryColor,
                shape: BoxShape.circle,
              ),
              child: IconButton(
                onPressed: () async {
                  if (widget.audioService.isPlaying) {
                    await widget.audioService.pause();
                  } else if (widget.audioService.isPaused) {
                    await widget.audioService.resume();
                  } else {
                    // Gọi callback trước khi play (để hiển thị interstitial ads nếu cần)
                    await widget.onPlayPressed?.call();
                    await widget.audioService.play();
                  }
                },
                icon: Icon(
                  widget.audioService.isLoading
                      ? Icons.hourglass_empty
                      : widget.audioService.isPlaying
                          ? Icons.pause
                          : Icons.play_arrow,
                  color: Theme.of(context).colorScheme.onPrimary,
                  size: 30,
                ),
              ),
            ),
            IconButton(
              onPressed: () async => await widget.audioService.skipForward(),
              icon: Icon(
                Icons.forward_10_rounded,
                color: categoryColor,
                size: 24,
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
