import 'package:flutter/material.dart';
import '../services/audio_player_service.dart';

class AudioPlayerWidget extends StatefulWidget {
  final AudioPlayerService audioService;
  final Future<void> Function()? onPlayPressed;
  final String currentSpeaker;
  final String currentLineText;
  final bool showCurrentPanel;
  final VoidCallback? onCurrentPanelTap;

  const AudioPlayerWidget({
    super.key,
    required this.audioService,
    this.onPlayPressed,
    required this.currentSpeaker,
    required this.currentLineText,
    required this.showCurrentPanel,
    this.onCurrentPanelTap,
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
        constraints: const BoxConstraints(maxWidth: 350),
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
            padding: const EdgeInsets.fromLTRB(10, 6, 10, 4),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                AnimatedSwitcher(
                  duration: const Duration(milliseconds: 280),
                  switchInCurve: Curves.easeOutCubic,
                  switchOutCurve: Curves.easeInCubic,
                  transitionBuilder: (child, animation) {
                    final offsetAnimation = Tween<Offset>(
                      begin: const Offset(0, 0.18),
                      end: Offset.zero,
                    ).animate(animation);
                    return FadeTransition(
                      opacity: animation,
                      child: SlideTransition(
                        position: offsetAnimation,
                        child: child,
                      ),
                    );
                  },
                  child: widget.showCurrentPanel
                      ? _buildCurrentTranscriptPanel(context)
                      : const SizedBox.shrink(key: ValueKey('current-panel-hidden')),
                ),
                if (widget.showCurrentPanel) const SizedBox(height: 4),
                _buildSeekBarRow(),
                const SizedBox(height: 3),
                _buildCenterControls(context),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildCurrentTranscriptPanel(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return GestureDetector(
      onTap: widget.onCurrentPanelTap,
      behavior: HitTestBehavior.opaque,
      child: Padding(
      key: const ValueKey('current-panel-shown'),
      padding: const EdgeInsets.only(top: 8),
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Container(
            width: double.infinity,
            constraints: const BoxConstraints(minHeight: 84, maxHeight: 90),
            padding: const EdgeInsets.fromLTRB(8, 10, 8, 6),
            decoration: BoxDecoration(
              color: colorScheme.surfaceContainerHighest.withOpacity(0.5),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: colorScheme.outlineVariant.withOpacity(0.65),
              ),
            ),
            child: SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              child: Text(
                widget.currentLineText,
                style: TextStyle(
                  fontSize: 13,
                  height: 1.25,
                  color: colorScheme.onSurface.withOpacity(0.92),
                ),
              ),
            ),
          ),
          Positioned(
            top: -8,
            left: 0,
            right: 0,
            child: Center(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 1),
                decoration: BoxDecoration(
                  color: colorScheme.surface,
                  borderRadius: BorderRadius.circular(999),
                  border: Border.all(
                    color: colorScheme.outlineVariant.withOpacity(0.8),
                  ),
                ),
                child: Text(
                  widget.currentSpeaker,
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.35,
                    color: colorScheme.primary,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    ),
    );
  }

  Widget _buildSeekBarRow() {
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

        final primary = Theme.of(context).colorScheme.primary;

        return Row(
          children: [
            SizedBox(
              width: 36,
              child: Text(
                _formatDuration(effectivePosition),
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 10,
                  color: Theme.of(context).colorScheme.onSurface.withOpacity(0.65),
                ),
              ),
            ),
            Expanded(
              child: SliderTheme(
                data: SliderTheme.of(context).copyWith(
                  activeTrackColor: primary,
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
              width: 36,
              child: Text(
                '-${_formatDuration(remainingDuration.isNegative ? Duration.zero : remainingDuration)}',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 10,
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

        final primary = Theme.of(context).colorScheme.primary;

        return Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              onPressed: () async => await widget.audioService.skipBackward(),
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints.tightFor(width: 36, height: 36),
              icon: Icon(
                Icons.replay_10_rounded,
                color: primary,
                size: 22,
              ),
            ),
            Container(
              decoration: BoxDecoration(
                color: primary,
                shape: BoxShape.circle,
              ),
              child: IconButton(
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints.tightFor(width: 44, height: 44),
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
                  size: 28,
                ),
              ),
            ),
            IconButton(
              onPressed: () async => await widget.audioService.skipForward(),
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints.tightFor(width: 36, height: 36),
              icon: Icon(
                Icons.forward_10_rounded,
                color: primary,
                size: 22,
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

