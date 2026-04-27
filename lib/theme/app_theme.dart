import 'package:flutter/material.dart';

class AppTheme {
  static const Color _lightPrimary = Color(0xFF0EA5C6);
  static const Color _lightSecondary = Color(0xFF8B5CF6);
  static const Color _lightSurface = Color(0xFFFFFFFF);
  static const Color _lightBackground = Color(0xFFF7FAFF);
  static const Color _lightOnSurface = Color(0xFF12172A);

  static const Color _darkPrimary = Color(0xFF4DE8FF);
  static const Color _darkSecondary = Color(0xFFC96BFF);
  static const Color _darkSurface = Color(0xFF12162A);
  static const Color _darkBackground = Color(0xFF0A0A1A);
  static const Color _darkOnSurface = Color(0xFFE9EDFF);

  static ThemeData light(double textScaleFactor) {
    final scheme = const ColorScheme(
      brightness: Brightness.light,
      primary: _lightPrimary,
      onPrimary: Colors.white,
      secondary: _lightSecondary,
      onSecondary: Colors.white,
      error: Color(0xFFDC2626),
      onError: Colors.white,
      surface: _lightSurface,
      onSurface: _lightOnSurface,
    );

    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      colorScheme: scheme.copyWith(
        surfaceContainerHighest: const Color(0xFFEEF3FF),
        outlineVariant: const Color(0xFFD7DDF0),
      ),
      scaffoldBackgroundColor: _lightBackground,
      textTheme: _textTheme(textScaleFactor),
      navigationBarTheme: NavigationBarThemeData(
        indicatorColor: _lightPrimary.withOpacity(0.16),
      ),
    );
  }

  static ThemeData dark(double textScaleFactor) {
    final scheme = const ColorScheme(
      brightness: Brightness.dark,
      primary: _darkPrimary,
      onPrimary: Color(0xFF00121A),
      secondary: _darkSecondary,
      onSecondary: Color(0xFF150029),
      error: Color(0xFFF87171),
      onError: Color(0xFF2D0000),
      surface: _darkSurface,
      onSurface: _darkOnSurface,
    );

    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      colorScheme: scheme.copyWith(
        surfaceContainerHighest: const Color(0xFF1A2038),
        outlineVariant: const Color(0xFF2A3254),
      ),
      scaffoldBackgroundColor: _darkBackground,
      textTheme: _textTheme(textScaleFactor),
      navigationBarTheme: NavigationBarThemeData(
        indicatorColor: _darkPrimary.withOpacity(0.22),
      ),
    );
  }

  static TextTheme _textTheme(double textScaleFactor) {
    return TextTheme(
      bodyLarge: TextStyle(
        fontSize: 16 * textScaleFactor,
        decoration: TextDecoration.none,
      ),
      bodyMedium: TextStyle(
        fontSize: 14 * textScaleFactor,
        decoration: TextDecoration.none,
      ),
      bodySmall: TextStyle(
        fontSize: 12 * textScaleFactor,
        decoration: TextDecoration.none,
      ),
    );
  }
}
