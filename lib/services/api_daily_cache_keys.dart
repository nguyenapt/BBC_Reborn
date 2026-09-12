/// Khóa cache SQLite cho [LocalDatabaseService.api_daily_cache] — tối đa một lần fetch RTDB mỗi ngày mỗi key.
class ApiDailyCacheKeys {
  ApiDailyCacheKeys._();

  static const String homePage = 'HomePage';
  static const String grammarList = 'GrammarList';
  static const String anotherSeriesSubKeysHome = 'AS_SubKeys_Home';
  static const String anotherSeriesSubKeysList = 'AS_SubKeys_List';
}
