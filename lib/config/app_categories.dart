/// Danh mục nội dung được app Learn Speak British English hỗ trợ.
/// Bổ sung mã mới (6M, TEWS, …) khi seed thêm trên RTDB.
class AppCategories {
  AppCategories._();

  /// Mã category được hiển thị / mở từ Home và tab programmes.
  static const Set<String> enabledCategoryCodes = {
    'AAE',
    // '6M',
    // 'TEWS',
  };

  static bool isEnabled(String categoryCode) {
    final code = categoryCode.trim();
    if (code.isEmpty) return false;
    return enabledCategoryCodes.contains(code);
  }
}
