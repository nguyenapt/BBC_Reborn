import 'package:flutter/material.dart';
import '../services/language_manager.dart';

class SeriesSubBadgeStyle {
  final IconData icon;
  final String label;
  final Color color;

  const SeriesSubBadgeStyle({
    required this.icon,
    required this.label,
    required this.color,
  });

  static SeriesSubBadgeStyle forCode(
    String code,
    ColorScheme colorScheme,
    LanguageManager languageManager,
  ) {
    final strongAccent =
        Color.lerp(colorScheme.primary, colorScheme.onSurface, 0.22)!;

    switch (code) {
      case 'NC':
        return SeriesSubBadgeStyle(
          icon: Icons.forum_outlined,
          label: languageManager.getText('categoryNatural'),
          color: strongAccent,
        );
      case 'SC':
        return SeriesSubBadgeStyle(
          icon: Icons.chat_outlined,
          label: languageManager.getText('categorySimple'),
          color: colorScheme.tertiary,
        );
      default:
        return SeriesSubBadgeStyle(
          icon: Icons.category_outlined,
          label: code,
          color: strongAccent,
        );
    }
  }
}
