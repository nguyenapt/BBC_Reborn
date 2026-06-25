import 'package:flutter/material.dart';

/// Episode detail tab chrome: horizontal inset only (no panel fill color).
class EpisodeDetailTabPanel extends StatelessWidget {
  final Widget child;

  const EpisodeDetailTabPanel({
    super.key,
    required this.child,
  });

  /// Horizontal inset of tab content on episode detail (and aligned screens).
  static const EdgeInsets panelOuterPadding = EdgeInsets.fromLTRB(6, 0, 6, 4);

  static const double panelBorderRadius = 12;

  /// Horizontal inset aligned with tab list content (panel 6 + scroll 12).
  static const double contentHorizontalInset = 18;

  /// List / scroll padding: base insets + clearance for floating player.
  static EdgeInsets scrollPadding(
    double scrollBottomInset, {
    double left = 12,
    double top = 12,
    double right = 12,
    double bottom = 16,
  }) {
    return EdgeInsets.fromLTRB(
      left,
      top,
      right,
      bottom + scrollBottomInset,
    );
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox.expand(
      child: Padding(
        padding: panelOuterPadding,
        child: child,
      ),
    );
  }

  /// Inset panel block (e.g. speaking history stats) — optional white/elevated card.
  static Widget insetPanel({
    required BuildContext context,
    required Widget child,
    Color? tintColor,
    Color? backgroundColor,
    EdgeInsets? outerPadding,
    EdgeInsets? contentPadding,
    bool elevated = false,
  }) {
    final scheme = Theme.of(context).colorScheme;
    final panelBg = backgroundColor ??
        (tintColor ?? scheme.primary).withValues(alpha: 0.12);
    return Padding(
      padding: outerPadding ?? panelOuterPadding.copyWith(top: 8, bottom: 8),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: panelBg,
          borderRadius: BorderRadius.circular(panelBorderRadius),
          border: elevated
              ? Border.all(
                  color: scheme.outline.withValues(alpha: 0.18),
                  width: 1,
                )
              : null,
          boxShadow: elevated
              ? [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.06),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ]
              : null,
        ),
        child: Padding(
          padding: contentPadding ?? scrollPadding(0),
          child: child,
        ),
      ),
    );
  }
}
