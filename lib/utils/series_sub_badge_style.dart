import 'package:flutter/material.dart';
import 'category_names.dart';

class SeriesSubBadgeStyle {
  final IconData icon;
  final String label;
  final Color color;

  const SeriesSubBadgeStyle({
    required this.icon,
    required this.label,
    required this.color,
  });

  static SeriesSubBadgeStyle forCode(String code, ColorScheme colorScheme) {
    final strongAccent =
        Color.lerp(colorScheme.primary, colorScheme.onSurface, 0.22)!;

    switch (code) {
      case 'AMS':
        return SeriesSubBadgeStyle(
          icon: Icons.auto_stories_outlined,
          label: CategoryNames.getDisplayName(code),
          color: strongAccent,
        );
      case 'LLE':
        return SeriesSubBadgeStyle(
          icon: Icons.school_outlined,
          label: CategoryNames.getDisplayName(code),
          color: strongAccent,
        );
      case 'NC':
        return SeriesSubBadgeStyle(
          icon: Icons.forum_outlined,
          label: CategoryNames.getDisplayName(code),
          color: strongAccent,
        );
      case 'SC':
        return SeriesSubBadgeStyle(
          icon: Icons.chat_outlined,
          label: CategoryNames.getDisplayName(code),
          color: colorScheme.tertiary,
        );
      default:
        return SeriesSubBadgeStyle(
          icon: Icons.category_outlined,
          label: CategoryNames.getDisplayName(code),
          color: strongAccent,
        );
    }
  }
}
