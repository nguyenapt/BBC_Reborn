import 'package:flutter/material.dart';

import '../services/language_manager.dart';
import '../services/learning_progress_service.dart';
import 'streak_slide_panel.dart';

class StreakWidget extends StatelessWidget {
  const StreakWidget({super.key, this.panelTop});

  /// Offset từ đỉnh màn hình tới điểm bắt đầu vùng dim + panel (giống [HeartWidget]).
  final double? panelTop;

  void _showSlidePanelFromTop(BuildContext context) {
    final safeAreaTop = MediaQuery.of(context).padding.top;
    const headerTopPadding = 16.0;
    const rowHeight = 48.0;
    const headerBottomPadding = 16.0;
    final resolvedPanelTop = panelTop ??
        (safeAreaTop + headerTopPadding + rowHeight + headerBottomPadding);

    showGeneralDialog(
      context: context,
      barrierDismissible: true,
      barrierLabel: MaterialLocalizations.of(context).modalBarrierDismissLabel,
      barrierColor: Colors.transparent,
      transitionDuration: const Duration(milliseconds: 300),
      pageBuilder: (context, animation, secondaryAnimation) {
        return const SizedBox.shrink();
      },
      transitionBuilder: (context, animation, secondaryAnimation, child) {
        final heightAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
          CurvedAnimation(parent: animation, curve: Curves.easeOut),
        );

        return Stack(
          children: [
            Positioned.fill(
              child: FadeTransition(
                opacity: animation,
                child: GestureDetector(
                  onTap: () => Navigator.of(context).pop(),
                  child: Container(
                    color: Colors.black.withOpacity(0.3),
                    margin: EdgeInsets.only(top: resolvedPanelTop),
                  ),
                ),
              ),
            ),
            Positioned(
              top: resolvedPanelTop + 4,
              left: 0,
              right: 0,
              child: SizedBox(
                width: double.infinity,
                child: SizeTransition(
                  sizeFactor: heightAnimation,
                  axisAlignment: -1.0,
                  child: Material(
                    color: Colors.transparent,
                    child: Container(
                      width: double.infinity,
                      constraints: BoxConstraints(
                        maxHeight: MediaQuery.of(context).size.height * 0.52,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.2),
                            blurRadius: 10,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: const StreakSlidePanel(),
                    ),
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final languageManager = LanguageManager();
    return ListenableBuilder(
      listenable: LearningProgressService(),
      builder: (context, child) {
        final streak = LearningProgressService().currentStreak;
        final colorScheme = Theme.of(context).colorScheme;
        return Tooltip(
          message: languageManager.getText('dayStreak'),
          child: GestureDetector(
            onTap: () => _showSlidePanelFromTop(context),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: colorScheme.primaryContainer.withOpacity(0.65),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: colorScheme.outlineVariant.withOpacity(0.5),
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.local_fire_department_rounded,
                    size: 18,
                    color: streak > 0
                        ? Colors.deepOrange
                        : colorScheme.onSurface.withOpacity(0.45),
                  ),
                  const SizedBox(width: 4),
                  Text(
                    '$streak',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w800,
                      color: colorScheme.onSurface,
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
