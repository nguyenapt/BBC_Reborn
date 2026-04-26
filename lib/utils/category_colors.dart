import 'package:flutter/material.dart';

class CategoryColors {
  // Unified brand palette: no per-category color mapping.
  static const Color _brandPrimary = Color(0xFF08789D);
  static const Color _brandBackground = Color(0x2608789D);
  static const Color _brandBorder = Color(0x8A08789D);

  /// Lấy màu chính của category
  static Color getCategoryColor(String categoryName) {
    return _brandPrimary;
  }

  /// Lấy màu nền nhạt của category
  static Color getCategoryBackgroundColor(String categoryName) {
    return _brandBackground;
  }

  /// Lấy màu viền của category
  static Color getCategoryBorderColor(String categoryName) {
    return _brandBorder;
  }

  /// Lấy màu chữ phù hợp với màu nền
  static Color getCategoryTextColor(String categoryName) {
    final backgroundColor = getCategoryBackgroundColor(categoryName);
    // Tính độ sáng để quyết định màu chữ
    final luminance = backgroundColor.computeLuminance();
    return luminance > 0.5 ? Colors.black87 : Colors.white;
  }

  /// Lấy tất cả categories có màu được định nghĩa
  static List<String> getDefinedCategories() {
    return const [];
  }

  /// Kiểm tra xem category có màu được định nghĩa không
  static bool hasColorDefinition(String categoryName) {
    return false;
  }
}

