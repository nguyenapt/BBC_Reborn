class CategoryNames {
  /// Tab Categories + thứ tự Home category cards.
  static const List<String> primaryTabCodes = ['AMS', 'LLE', 'ON', 'AS'];

  /// Section episode ưu tiên trên Home (không gồm AS — AS là multi-category).
  static const List<String> homePrioritySectionCodes = ['AMS', 'LLE', 'ON'];

  /// Nội dung tab Another Series (NC + SC).
  static const List<String> anotherSeriesSubCodes = ['NC', 'SC'];

  static const bool showAnotherSeries = true;

  static const Map<String, String> _categoryMapping = {
    'AMS': 'American Story',
    'LLE': "Let's Learn English",
    'ON': 'Our Narrative',
    'NC': 'Natural Conversation',
    'SC': 'Simple Conversation',
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

  /// TabBar line-1 / line-2 l10n keys for [primaryTabCodes].
  static const Map<String, List<String>> primaryTabLabelKeys = {
    'AMS': ['categoryAmerican', 'categoryStory'],
    'LLE': ['categoryLets', 'categoryLearnEnglish'],
    'ON': ['categoryOur', 'categoryNarrative'],
    'AS': ['categoryAnother', 'categorySeries'],
  };

  /// Sub-category codes under RTDB `AS` (legacy). Thêm mã mới khi có series mới.
  static const Set<String> anotherSeriesSubcategoryCodes = {'OF', 'EIM'};

  /// Top-level programme codes trong UI Another Series (legacy).
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
    if (!showAnotherSeries) return false;
    return anotherSeriesSubCodes.contains(categoryCode);
  }

  static bool isPrimaryTab(String categoryCode) {
    return primaryTabCodes.contains(categoryCode);
  }

  static bool isHomePrioritySection(String categoryCode) {
    return homePrioritySectionCodes.contains(categoryCode);
  }

  /// Categories loaded from flat `List/{CAT}.json` (no year sub-path).
  static bool usesFlatEpisodeList(String categoryCode) {
    return homePrioritySectionCodes.contains(categoryCode) ||
        anotherSeriesSubCodes.contains(categoryCode);
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
