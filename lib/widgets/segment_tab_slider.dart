import 'package:flutter/material.dart';

class SegmentTabItem {
  final IconData icon;
  final String label;

  const SegmentTabItem({
    required this.icon,
    required this.label,
  });
}

/// Pill-style horizontal tab slider (episode detail, My Hub saved sub-tabs).
class SegmentTabSlider extends StatelessWidget {
  final List<SegmentTabItem> tabs;
  final int selectedIndex;
  final ValueChanged<int> onSelected;
  final Color? accentColor;
  final EdgeInsets padding;

  const SegmentTabSlider({
    super.key,
    required this.tabs,
    required this.selectedIndex,
    required this.onSelected,
    this.accentColor,
    this.padding = const EdgeInsets.fromLTRB(12, 8, 12, 4),
  });

  static const double _tabRadius = 10;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final accent = accentColor ?? scheme.primary;
    final muted = scheme.onSurface.withOpacity(0.55);

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: padding,
      child: Row(
        children: [
          for (int i = 0; i < tabs.length; i++) ...[
            if (i > 0) const SizedBox(width: 4),
            Material(
              color: Colors.transparent,
              child: InkWell(
                borderRadius: BorderRadius.circular(_tabRadius),
                onTap: () => onSelected(i),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
                  decoration: BoxDecoration(
                    color: selectedIndex == i
                        ? accent.withOpacity(0.18)
                        : Colors.transparent,
                    borderRadius: BorderRadius.circular(_tabRadius),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        tabs[i].icon,
                        size: 18,
                        color: selectedIndex == i ? accent : muted,
                      ),
                      const SizedBox(width: 5),
                      Text(
                        tabs[i].label,
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: selectedIndex == i
                              ? FontWeight.w700
                              : FontWeight.w500,
                          color: selectedIndex == i ? accent : muted,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
