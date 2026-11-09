import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../config/heart_system_rtdb.dart';
import '../models/heart_system_config.dart';

/// Fetches [HeartSystemConfig] from RTDB with TTL cache + local defaults fallback.
class HeartRemoteConfigService {
  HeartRemoteConfigService._();
  static final HeartRemoteConfigService instance = HeartRemoteConfigService._();

  HeartSystemConfig _config = HeartSystemConfig.defaults;
  DateTime? _cacheAt;
  static const _cacheTtl = Duration(hours: 5);

  HeartSystemConfig get config => _config;

  Future<HeartSystemConfig> ensureLoaded({bool bypassCache = false}) async {
    if (!bypassCache &&
        _cacheAt != null &&
        DateTime.now().difference(_cacheAt!) < _cacheTtl) {
      return _config;
    }
    await refresh(bypassCache: bypassCache);
    return _config;
  }

  Future<HeartSystemConfig> refresh({bool bypassCache = false}) async {
    if (!bypassCache &&
        _cacheAt != null &&
        DateTime.now().difference(_cacheAt!) < _cacheTtl) {
      return _config;
    }
    try {
      final response = await http.get(
        Uri.parse(kHeartSystemRtdbUrl),
        headers: {'Accept': 'application/json'},
      );
      if (response.statusCode != 200) {
        debugPrint('HeartRemoteConfig: HTTP ${response.statusCode}');
        return _config;
      }
      final body = response.body.trim();
      if (body.isEmpty || body == 'null') {
        debugPrint('HeartRemoteConfig: empty — using defaults');
        _config = HeartSystemConfig.defaults;
        _cacheAt = DateTime.now();
        return _config;
      }
      final decoded = json.decode(body);
      if (decoded is! Map) {
        return _config;
      }
      _config = HeartSystemConfig.fromJson(
        Map<String, dynamic>.from(decoded),
      );
      _cacheAt = DateTime.now();
      debugPrint(
        'HeartRemoteConfig: allow_credit=${_config.allowCredit} '
        'ep_pass=${_config.allowCreditEpisodePass} '
        'speaking=${_config.allowCreditSpeaking} '
        'hearts=${_config.heartNumber} credits=${_config.creditNumber}',
      );
      return _config;
    } catch (e) {
      debugPrint('HeartRemoteConfig: fetch failed $e — using cached/defaults');
      return _config;
    }
  }
}
