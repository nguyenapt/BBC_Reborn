import '../models/cefr_level.dart';

class CategoryNames {
  static const Map<String, String> _levelDisplayNames = {
    'A1': 'A1',
    'A2': 'A2',
    'B1': 'B1',
    'B2': 'B2',
    'C1': 'C1',
    'C2': 'C2',
  };

  /// Lấy tên hiển thị của level / subcategory text từ mã.
  /// Nếu không tìm thấy mapping, trả về mã gốc.
  static String getDisplayName(String categoryCode) {
    final level = CefrLevel.tryParse(categoryCode);
    if (level != null) {
      return _levelDisplayNames[level.code] ?? level.code;
    }
    return categoryCode;
  }

  static bool hasMapping(String categoryCode) {
    return CefrLevel.tryParse(categoryCode) != null;
  }

  static List<String> getAllCategoryCodes() => List<String>.from(CefrLevel.codes);

  static List<String> getAllDisplayNames() =>
      CefrLevel.codes.map(getDisplayName).toList();
}
