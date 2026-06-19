import 'package:flutter/material.dart';

/// Icon + label without background — matches transcript action chips (Listen / Translate).
class CompactGhostBadge extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final double iconSize;
  final double fontSize;
  final FontWeight fontWeight;

  const CompactGhostBadge({
    super.key,
    required this.icon,
    required this.label,
    required this.color,
    this.iconSize = 14,
    this.fontSize = 11,
    this.fontWeight = FontWeight.w600,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, color: color, size: iconSize),
        const SizedBox(width: 4),
        Text(
          label,
          style: TextStyle(
            fontSize: fontSize,
            fontWeight: fontWeight,
            color: color,
          ),
        ),
      ],
    );
  }
}
