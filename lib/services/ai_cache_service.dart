import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'storage_service.dart';

/// Service for caching AI responses
class AICacheService {
  static final AICacheService _instance = AICacheService._internal();
  factory AICacheService() => _instance;
  AICacheService._internal();

  final StorageService _storage = StorageService();

  /// Get cached data
  Future<T?> getCached<T>(
    String key,
    T Function(Map<String, dynamic>) fromJson,
  ) async {
    try {
      final cached = await _storage.getCachedData(key);
      if (cached != null) {
        final Map<String, dynamic> decoded = json.decode(cached);
        return fromJson(decoded);
      }
      return null;
    } catch (e) {
      debugPrint('Error getting cached data: $e');
      return null;
    }
  }

  /// Cache data
  Future<void> cacheData<T>(
    String key,
    T data,
    Map<String, dynamic> Function(T) toJson,
  ) async {
    try {
      final jsonData = toJson(data);
      final encoded = json.encode(jsonData);
      await _storage.saveCachedData(key, encoded);
    } catch (e) {
      debugPrint('Error caching data: $e');
    }
  }

  /// Get cached string (for simple translations)
  Future<String?> getCachedString(String key) async {
    try {
      return await _storage.getCachedData(key);
    } catch (e) {
      debugPrint('Error getting cached string: $e');
      return null;
    }
  }

  /// Cache string (for simple translations)
  Future<void> cacheString(String key, String value) async {
    try {
      await _storage.saveCachedData(key, value);
    } catch (e) {
      debugPrint('Error caching string: $e');
    }
  }

  /// Get cached map (for translations map)
  Future<Map<String, String>?> getCachedMap(String key) async {
    try {
      final cached = await _storage.getCachedData(key);
      if (cached != null) {
        final Map<String, dynamic> decoded = json.decode(cached);
        return decoded.map((k, v) => MapEntry(k.toString(), v.toString()));
      }
      return null;
    } catch (e) {
      debugPrint('Error getting cached map: $e');
      return null;
    }
  }

  /// Cache map (for translations map)
  Future<void> cacheMap(String key, Map<String, String> value) async {
    try {
      final encoded = json.encode(value);
      await _storage.saveCachedData(key, encoded);
    } catch (e) {
      debugPrint('Error caching map: $e');
    }
  }

  /// Remove cached data
  Future<void> removeCached(String key) async {
    try {
      await _storage.removeCachedData(key);
    } catch (e) {
      debugPrint('Error removing cached data: $e');
    }
  }

  /// Clear all AI cache
  Future<void> clearAllCache() async {
    try {
      await _storage.clearAICache();
    } catch (e) {
      debugPrint('Error clearing AI cache: $e');
    }
  }
}

