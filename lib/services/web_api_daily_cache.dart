import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

/// Daily API cache for web (no SQLite) — tối đa 1 lần fetch RTDB mỗi ngày mỗi key.
class WebApiDailyCache {
  WebApiDailyCache._();

  static String _payloadKey(String cacheKey) => 'web_api_daily_payload_$cacheKey';
  static String _dateKey(String cacheKey) => 'web_api_daily_date_$cacheKey';

  static String _today() {
    final now = DateTime.now();
    return '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
  }

  static Future<bool> _isFresh(String cacheKey) async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_dateKey(cacheKey)) == _today();
  }

  static Future<String?> getPayload(String cacheKey) async {
    if (!await _isFresh(cacheKey)) return null;
    final prefs = await SharedPreferences.getInstance();
    final payload = prefs.getString(_payloadKey(cacheKey));
    if (payload == null || payload.isEmpty) return null;
    return payload;
  }

  static Future<void> putPayload(String cacheKey, String payload) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_payloadKey(cacheKey), payload);
    await prefs.setString(_dateKey(cacheKey), _today());
  }

  static Future<List<String>?> getStringList(String cacheKey) async {
    final payload = await getPayload(cacheKey);
    if (payload == null) return null;
    try {
      final decoded = json.decode(payload);
      if (decoded is List) {
        return decoded.map((e) => e.toString()).toList();
      }
    } catch (_) {}
    return null;
  }

  static Future<void> putStringList(String cacheKey, List<String> values) async {
    await putPayload(cacheKey, json.encode(values));
  }
}
