class CategoryNames {
  static const Map<String, String> _categoryMapping = {
    'AAE': 'Accent & British English',
    '6M': '6 Minutes Conversation',
    'TEWS': 'The English We Speak',
    'REE': 'Real Easy English',
    'BSA': 'Beating Speaking Anxiety',
    '6MGB': '6 Minutes Grammar Basic',
    '6MGI': '6 Minutes Grammar Intermediate',
    '6MVB': '6 Minutes Vocabulary Basic',
    '6MVI': '6 Minutes Vocabulary Intermediate',
    'DRM': 'Drama',
    'EAW': 'English at Work',
    'EG': 'English Grammar',
    'OF': 'Office English',
    'EIM': 'English In Minute',
  };

  /// Sub-category codes under RTDB `AS` (Another Series). Thêm mã mới khi có series mới.
  static const Set<String> anotherSeriesSubcategoryCodes = {'OF', 'EIM'};

  /// Top-level programme codes trong UI Another Series (sau subs AS, trước [6MGB…]).
  /// **BSA** lưu theo năm `BSA/{year}`; các mã khác thường là `/CAT.json` phẳng.
  static const List<String> anotherSeriesFixedProgramCodes = [
    'BSA',
    '6MGB',
    '6MGI',
    '6MVB',
    '6MVI',
    'DRM',
    'EAW',
  ];

  /// Opening these categories from Home should select the Another Series tab (`AS`).
  static bool opensAnotherSeriesTab(String categoryCode) {
    return anotherSeriesSubcategoryCodes.contains(categoryCode) ||
        anotherSeriesFixedProgramCodes.contains(categoryCode);
  }

  /// Lấy tên hiển thị đầy đủ của category từ mã category
  /// Nếu không tìm thấy mapping, trả về mã category gốc
  static String getDisplayName(String categoryCode) {
    return _categoryMapping[categoryCode] ?? categoryCode;
  }

  static bool isAnotherSeriesSubcategory(String categoryCode) {
    return anotherSeriesSubcategoryCodes.contains(categoryCode);
  }

  /// Kiểm tra xem category có mapping hay không
  static bool hasMapping(String categoryCode) {
    return _categoryMapping.containsKey(categoryCode);
  }

  /// Lấy tất cả các mã category có mapping
  static List<String> getAllCategoryCodes() {
    return _categoryMapping.keys.toList();
  }

  /// Lấy tất cả các tên hiển thị
  static List<String> getAllDisplayNames() {
    return _categoryMapping.values.toList();
  }
}
