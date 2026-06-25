import 'package:flutter/material.dart';

/// Màu dùng cho tab Vocabulary trong Library (My Learning).
abstract final class VocabularyTheme {
  static const Color backgroundTop = Color(0xFF0D5D85);
  static const Color backgroundBottom = Color(0xFF0A4B6B);
  static const Color accentGreen = Color(0xFF66C95B);

  static const LinearGradient cardGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [backgroundTop, backgroundBottom],
  );
}
