import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../config/rtdb_paths.dart';
import '../models/heart_system_config.dart';

/// Đọc remote config heart system từ RTDB (chưa gắn UI gameplay).
class HeartSystemService {
  HeartSystemService._();
  static final HeartSystemService instance = HeartSystemService._();

  HeartSystemConfig? _cache;

  Future<HeartSystemConfig> fetch({bool bypassCache = false}) async {
    if (!bypassCache && _cache != null) return _cache!;

    try {
      final response = await http.get(
        Uri.parse(RtdbPaths.jsonUrl(RtdbPaths.heartSystem)),
        headers: {'Accept': 'application/json'},
      );
      if (response.statusCode != 200 ||
          response.body.isEmpty ||
          response.body == 'null') {
        debugPrint('HeartSystem: HTTP ${response.statusCode}');
        return _cache = const HeartSystemConfig();
      }
      final decoded = json.decode(response.body);
      if (decoded is! Map<String, dynamic>) {
        return _cache = const HeartSystemConfig();
      }
      return _cache = HeartSystemConfig.fromJson(decoded);
    } catch (e) {
      debugPrint('HeartSystem: fetch failed $e');
      return _cache = const HeartSystemConfig();
    }
  }

  void clearCache() => _cache = null;
}
