import 'package:flutter/material.dart';
import '../models/episode_learning_progress.dart';
import '../services/language_manager.dart';

class LearningChecklistBar extends StatelessWidget {
  static const double iconSize = 34;
  static const double laneOuterPadding = 6;
  static const double reservedLaneWidth = iconSize + laneOuterPadding;
  /// Khoảng trống phải cho native/banner ad — tránh chồng checklist (AdMob).
  static const double adClearanceGap = 8;
  static const double adRightClearance = reservedLaneWidth + adClearanceGap;

  final EpisodeLearningProgress? progress;
  final Color accentColor;
  final void Function(int tabIndex)? onStepTap;
  final Axis direction;
  /// Đường kính icon; mặc định [iconSize]. Toolbar ngang nên ~28–30 cho khớp switch/Aa.
  final double diameter;

  const LearningChecklistBar({
    super.key,
    this.progress,
    required this.accentColor,
    this.onStepTap,
    this.direction = Axis.vertical,
    this.diameter = iconSize,
  });

  @override
  Widget build(BuildContext context) {
    final lm = LanguageManager();
    final p = progress;
    final steps = [
      _Step(
        done: p?.listenedComplete == true ||
            (p?.listenProgressRatio ?? 0) >= 0.85,
        icon: Icons.headphones_rounded,
        label: lm.getText('checklistListen'),
        tabIndex: 0,
      ),
      _Step(
        done: p?.transcriptViewed == true,
        icon: Icons.description_rounded,
        label: lm.getText('checklistTranscript'),
        tabIndex: 0,
      ),
      _Step(
        done: p?.vocabViewed == true,
        icon: Icons.translate_rounded,
        label: lm.getText('checklistVocab'),
        tabIndex: 2,
      ),
      _Step(
        done: p?.questionsViewed == true || p?.speakingDone == true,
        icon: Icons.quiz_outlined,
        label: lm.getText('checklistPractice'),
        tabIndex: 3,
      ),
    ];

    final gap = direction == Axis.horizontal
        ? (diameter <= 30 ? 4.0 : 8.0)
        : 8.0;

    final children = <Widget>[
      for (int i = 0; i < steps.length; i++) ...[
        if (i > 0)
          SizedBox(
            width: direction == Axis.horizontal ? gap : 0,
            height: direction == Axis.vertical ? gap : 0,
          ),
        _ChecklistIcon(
          step: steps[i],
          accentColor: accentColor,
          diameter: diameter,
          onTap: onStepTap == null
              ? null
              : () => onStepTap!(steps[i].tabIndex),
        ),
      ],
    ];

    return Material(
      color: Colors.transparent,
      child: direction == Axis.horizontal
          ? Row(mainAxisSize: MainAxisSize.min, children: children)
          : Column(mainAxisSize: MainAxisSize.min, children: children),
    );
  }
}

class _Step {
  final bool done;
  final IconData icon;
  final String label;
  final int tabIndex;

  const _Step({
    required this.done,
    required this.icon,
    required this.label,
    required this.tabIndex,
  });
}

class _ChecklistIcon extends StatelessWidget {
  /// Xanh lá hoàn thành — tương phản tốt trên nền sáng/tối.
  static const Color _completedGreen = Color(0xFF22A06B);

  final _Step step;
  final Color accentColor;
  final double diameter;
  final VoidCallback? onTap;

  const _ChecklistIcon({
    required this.step,
    required this.accentColor,
    required this.diameter,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final inactiveColor = colorScheme.brightness == Brightness.dark
        ? Colors.white.withOpacity(0.42)
        : colorScheme.onSurface.withOpacity(0.34);
    final scale = diameter / LearningChecklistBar.iconSize;
    final glyphSize = (17 * scale).clamp(12.0, 17.0);
    final badgeSize = (13 * scale).clamp(10.0, 13.0);
    final badgeIconSize = (8 * scale).clamp(6.0, 8.0);

    return Tooltip(
      message: step.label,
      child: InkWell(
        onTap: onTap,
        customBorder: const CircleBorder(),
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            Container(
              width: diameter,
              height: diameter,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: step.done
                    ? accentColor.withOpacity(0.1)
                    : colorScheme.surface.withOpacity(0.5),
                border: Border.all(
                  color: step.done
                      ? accentColor.withOpacity(0.55)
                      : colorScheme.outlineVariant.withOpacity(0.5),
                  width: 1.2,
                ),
                boxShadow: [
                  BoxShadow(
                    color: colorScheme.shadow.withOpacity(0.12),
                    blurRadius: 8 * scale,
                    offset: Offset(0, 2 * scale),
                  ),
                ],
              ),
              child: Icon(
                step.icon,
                size: glyphSize,
                color: step.done ? accentColor : inactiveColor,
              ),
            ),
            Positioned(
              right: -2 * scale,
              bottom: -2 * scale,
              child: Container(
                width: badgeSize,
                height: badgeSize,
                decoration: BoxDecoration(
                  color: colorScheme.surface,
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: step.done
                        ? _completedGreen.withOpacity(0.75)
                        : Colors.red.withOpacity(0.75),
                    width: 1.1,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: colorScheme.shadow.withOpacity(0.1),
                      blurRadius: 3,
                      offset: const Offset(0, 1),
                    ),
                  ],
                ),
                child: Icon(
                  step.done ? Icons.check_rounded : Icons.close_rounded,
                  size: badgeIconSize,
                  color: step.done ? _completedGreen : Colors.red.shade600,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
