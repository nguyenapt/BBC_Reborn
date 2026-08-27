/// RTDB paths cho app Learn Speak British English
/// (`speak-british-english-default-rtdb`).
///
/// Cấu trúc gom node: `category/`, `config/`, `ai_cache/`.
class RtdbPaths {
  RtdbPaths._();

  static const String baseUrl =
      'https://speak-british-english-default-rtdb.firebaseio.com';

  static const String categoryRoot = 'category';
  static const String listRoot = 'category/List';
  static const String homeList = 'category/List/HomePage';
  static const String grammarList = 'category/List/HomePage/Grammar';

  static const String appUpdate = 'config/app_client_config/app_update';
  static const String heartSystem = 'config/app_client_config/heart_system';
  static const String aiServerConfig = 'config/ai_server_config';

  static const String aiCache = 'ai_cache';
  static const String users = 'users';

  static String jsonUrl(String path) {
    final cleaned = path.replaceAll(RegExp(r'^/+'), '').replaceAll(RegExp(r'/+$'), '');
    return '$baseUrl/$cleaned.json';
  }

  /// Full episode tree: `category/{cat}` hoặc `category/{cat}/{year}`.
  static String categoryFull(String cat, [String? year]) {
    final c = cat.trim().replaceAll(RegExp(r'^/+|/+$'), '');
    if (year == null || year.trim().isEmpty) {
      return '$categoryRoot/$c';
    }
    return '$categoryRoot/$c/${year.trim()}';
  }

  /// Slim list mirror: `category/List/{cat}` hoặc `category/List/{cat}/{year}`.
  static String categoryList(String cat, [String? year]) {
    final c = cat.trim().replaceAll(RegExp(r'^/+|/+$'), '');
    if (year == null || year.trim().isEmpty) {
      return '$listRoot/$c';
    }
    return '$listRoot/$c/${year.trim()}';
  }

  /// Another Series full: `category/AS/{sub}` (+ optional year).
  static String asFull(String sub, [String? year]) {
    final s = sub.trim().replaceAll(RegExp(r'^/+|/+$'), '');
    if (year == null || year.trim().isEmpty) {
      return '$categoryRoot/AS/$s';
    }
    return '$categoryRoot/AS/$s/${year.trim()}';
  }

  /// Another Series slim: `category/List/AS/{sub}`.
  static String asList(String sub, [String? year]) {
    final s = sub.trim().replaceAll(RegExp(r'^/+|/+$'), '');
    if (year == null || year.trim().isEmpty) {
      return '$listRoot/AS/$s';
    }
    return '$listRoot/AS/$s/${year.trim()}';
  }

  /// HomePage AS slim: `category/List/HomePage/AS/{sub}`.
  static String homeAsList(String sub) {
    final s = sub.trim().replaceAll(RegExp(r'^/+|/+$'), '');
    return '$homeList/AS/$s';
  }

  /// Ensure [rtdbPath] is under `category/` when it is a relative episode path.
  static String normalizeEpisodePath(String rtdbPath) {
    final p = rtdbPath.trim().replaceAll(RegExp(r'^/+|/+$'), '');
    if (p.isEmpty) return p;
    if (p.startsWith('$categoryRoot/')) return p;
    if (p.startsWith('List/') ||
        p.startsWith('HomePage/') ||
        p.startsWith('config/') ||
        p.startsWith('ai_cache/') ||
        p.startsWith('users/')) {
      return p;
    }
    return '$categoryRoot/$p';
  }
}
