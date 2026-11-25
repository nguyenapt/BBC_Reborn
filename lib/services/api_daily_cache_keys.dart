/// Khóa cache SQLite cho [LocalDatabaseService.api_daily_cache] — tối đa một lần fetch RTDB mỗi ngày mỗi key.
class ApiDailyCacheKeys {
  ApiDailyCacheKeys._();

  static const String grammarList = 'GrammarList';

  static String cefrLevel(String levelCode) => 'CEFR_$levelCode';
}
