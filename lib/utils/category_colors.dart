import 'package:flutter/material.dart';

class CategoryColors {
  static const Map<String, Color> _categoryColorMap = {
    '6M': Colors.red,
    '6MGB': Colors.blue,
    '6MGI': Colors.green,
    'NewsReview': Colors.orange,
    'REE': Colors.purple,
    'TEWS': Colors.amber,
    '6Minute': Colors.teal,
    'Grammar': Colors.indigo,
    'Vocabulary': Colors.pink,
    'Pronunciation': Colors.cyan,
  };

  static const Map<String, Color> _categoryBackgroundMap = {
    '6M': Color(0xFFFFEBEE), // Light red
    '6MGB': Color(0xFFE3F2FD), // Light blue
    '6MGI': Color(0xFFE8F5E8), // Light green
    'NewsReview': Color(0xFFFFF3E0), // Light orange
    'REE': Color(0xFFF3E5F5), // Light purple
    'TEWS': Color(0xFFFFFDE7), // Light amber
    '6Minute': Color(0xFFE0F2F1), // Light teal
    'Grammar': Color(0xFFE8EAF6), // Light indigo
    'Vocabulary': Color(0xFFFCE4EC), // Light pink
    'Pronunciation': Color(0xFFE0F7FA), // Light cyan
  };

  static const Map<String, Color> _categoryBorderMap = {
    '6M': Colors.redAccent,
    '6MGB': Colors.blueAccent,
    '6MGI': Colors.greenAccent,
    'NewsReview': Colors.orangeAccent,
    'REE': Colors.purpleAccent,
    'TEWS': Colors.amberAccent,
    '6Minute': Colors.tealAccent,
    'Grammar': Colors.indigoAccent,
    'Vocabulary': Colors.pinkAccent,
    'Pronunciation': Colors.cyanAccent,
  };

  /// Lấy màu chính của category
  static Color getCategoryColor(String categoryName) {
    return _categoryColorMap[categoryName] ?? Colors.grey;
  }

  /// Lấy màu nền nhạt của category
  static Color getCategoryBackgroundColor(String categoryName) {
    return _categoryBackgroundMap[categoryName] ?? Colors.grey[100]!;
  }

  /// Lấy màu viền của category
  static Color getCategoryBorderColor(String categoryName) {
    return _categoryBorderMap[categoryName] ?? Colors.grey[400]!;
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
    return _categoryColorMap.keys.toList();
  }

  /// Kiểm tra xem category có màu được định nghĩa không
  static bool hasColorDefinition(String categoryName) {
    return _categoryColorMap.containsKey(categoryName);
  }
}

