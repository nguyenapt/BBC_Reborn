class CategoryNames {
  /// Tab Categories + thứ tự Home category cards.
  static const List<String> primaryTabCodes = ['CD', 'EK', 'ON', 'AS'];

  /// Section episode ưu tiên trên Home (không gồm AS — AS là multi-category).
  static const List<String> homePrioritySectionCodes = ['CD', 'EK', 'ON'];

  /// Nội dung tab Another Series (AMS, LLE, NC, SC).
  static const List<String> anotherSeriesSubCodes = ['AMS', 'LLE', 'NC', 'SC'];

  static const bool showAnotherSeries = true;

  static const Map<String, String> _categoryMapping = {
    'CD': 'Civil Discourse',
    'EK': 'Endless Knot',
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

  /// TabBar line-1 / line-2 — derived from English [getDisplayName], not l10n.
  static List<String> primaryTabDisplayLines(String categoryCode) {
    return displayNameLines(categoryCode);
  }

  /// Split English programme name for two-line UI (tabs, home cards). Never localized.
  static List<String> displayNameLines(String categoryCode) {
    if (categoryCode == 'AS') {
      return ['Another', 'Series'];
    }
    final name = getDisplayName(categoryCode);
    final lastSpace = name.lastIndexOf(' ');
    if (lastSpace <= 0) {
      return [name, ''];
    }
    return [name.substring(0, lastSpace), name.substring(lastSpace + 1)];
  }

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
    if (categoryCode == 'AS') return true;
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
