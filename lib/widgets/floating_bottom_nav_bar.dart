import 'package:flutter/material.dart';

/// Destination for [FloatingBottomNavBar].
class FloatingNavDestination {
  final IconData icon;
  final IconData selectedIcon;
  final String label;

  const FloatingNavDestination({
    required this.icon,
    required this.selectedIcon,
    required this.label,
  });
}

/// Floating bottom nav — bo góc 20, margin 16/12, shadow nhẹ (ClassicPuzzle style).
class FloatingBottomNavBar extends StatelessWidget {
  static const double _barRadius = 20;
  static const double _itemRadius = 12;
  static const double _outerMarginBottom = 12;
  static const double _barVerticalPadding = 10;
  static const double _itemVerticalPadding = 4;
  static const double _iconPadding = 8;
  static const double _iconSize = 22;
  static const double _labelGap = 2;
  static const double _labelHeight = 12;

  /// Chiều cao vùng navbar overlay (để pad nội dung scroll nếu cần).
  static double bottomInset(BuildContext context) {
    final safeBottom = MediaQuery.viewPaddingOf(context).bottom;
    return _outerMarginBottom +
        _barVerticalPadding * 2 +
        _itemVerticalPadding * 2 +
        _iconPadding * 2 +
        _iconSize +
        _labelGap +
        _labelHeight +
        safeBottom;
  }

  /// Padding scroll — cùng pattern [EpisodeDetailTabPanel.scrollPadding].
  static EdgeInsets scrollPadding(
    BuildContext context, {
    double left = 12,
    double top = 12,
    double right = 12,
    double bottom = 16,
    double extraBottom = 0,
  }) {
    return EdgeInsets.fromLTRB(
      left,
      top,
      right,
      bottom + bottomInset(context) + extraBottom,
    );
  }

  final int selectedIndex;
  final ValueChanged<int> onDestinationSelected;
  final List<FloatingNavDestination> destinations;

  const FloatingBottomNavBar({
    super.key,
    required this.selectedIndex,
    required this.onDestinationSelected,
    required this.destinations,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 0, 16, _outerMarginBottom),
      padding: const EdgeInsets.symmetric(
        vertical: _barVerticalPadding,
        horizontal: 8,
      ),
      decoration: BoxDecoration(
        color: colorScheme.surface,
        borderRadius: BorderRadius.circular(_barRadius),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.28 : 0.06),
            blurRadius: 12,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: List.generate(destinations.length, (index) {
          final dest = destinations[index];
          final active = index == selectedIndex;
          return _NavItem(
            icon: active ? dest.selectedIcon : dest.icon,
            label: dest.label,
            active: active,
            activeBackground: colorScheme.primary.withValues(
              alpha: isDark ? 0.22 : 0.14,
            ),
            activeColor: colorScheme.onSurface,
            inactiveColor: colorScheme.onSurface.withValues(alpha: 0.55),
            onTap: () => onDestinationSelected(index),
          );
        }),
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  const _NavItem({
    required this.icon,
    required this.label,
    required this.active,
    required this.activeBackground,
    required this.activeColor,
    required this.inactiveColor,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final bool active;
  final Color activeBackground;
  final Color activeColor;
  final Color inactiveColor;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(FloatingBottomNavBar._itemRadius),
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: 6,
          vertical: FloatingBottomNavBar._itemVerticalPadding,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              padding: const EdgeInsets.all(FloatingBottomNavBar._iconPadding),
              decoration: BoxDecoration(
                color: active ? activeBackground : Colors.transparent,
                borderRadius: BorderRadius.circular(
                  FloatingBottomNavBar._itemRadius,
                ),
              ),
              child: Icon(
                icon,
                size: FloatingBottomNavBar._iconSize,
                color: active ? activeColor : inactiveColor,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 10,
                fontWeight: active ? FontWeight.w700 : FontWeight.w500,
                color: active ? activeColor : inactiveColor,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
