import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:in_app_update/in_app_update.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:url_launcher/url_launcher.dart';

import '../config/app_update_rtdb.dart';
import '../config/store_links.dart';
import '../models/app_update_remote_config.dart';

/// Tải và đánh giá cấu hình cập nhật từ RTDB; mở store / Android in-app update.
class AppUpdateService {
  AppUpdateService._();
  static final AppUpdateService instance = AppUpdateService._();

  AppUpdateRemoteConfig? _cacheConfig;
  DateTime? _cacheAt;
  static const _cacheTtl = Duration(minutes: 5);

  int compareSemver(String a, String b) {
    final ap = a.split('.').map((s) => int.tryParse(s.trim()) ?? 0).toList();
    final bp = b.split('.').map((s) => int.tryParse(s.trim()) ?? 0).toList();
    final n = ap.length > bp.length ? ap.length : bp.length;
    for (var i = 0; i < n; i++) {
      final av = i < ap.length ? ap[i] : 0;
      final bv = i < bp.length ? bp[i] : 0;
      if (av != bv) return av.compareTo(bv);
    }
    return 0;
  }

  AppUpdateCheckOutcome evaluate(PackageInfo pkg, AppUpdateRemoteConfig c) {
    final build = int.tryParse(pkg.buildNumber) ?? 0;
    final ver = pkg.version;

    if (c.minBuild != null && c.minBuild! > 0 && build < c.minBuild!) {
      return AppUpdateCheckOutcome(urgency: AppUpdateUrgency.forced, config: c);
    }
    if (c.minSupportedVersion != null && c.minSupportedVersion!.isNotEmpty) {
      if (compareSemver(ver, c.minSupportedVersion!) < 0) {
        return AppUpdateCheckOutcome(urgency: AppUpdateUrgency.forced, config: c);
      }
    }
    if (c.latestBuild != null && c.latestBuild! > 0 && build < c.latestBuild!) {
      return AppUpdateCheckOutcome(urgency: AppUpdateUrgency.optional, config: c);
    }
    if (c.latestVersion != null && c.latestVersion!.isNotEmpty) {
      if (compareSemver(ver, c.latestVersion!) < 0) {
        return AppUpdateCheckOutcome(urgency: AppUpdateUrgency.optional, config: c);
      }
    }
    return AppUpdateCheckOutcome.none;
  }

  Future<AppUpdateRemoteConfig?> _fetchRemote({bool bypassCache = false}) async {
    if (!bypassCache &&
        _cacheConfig != null &&
        _cacheAt != null &&
        DateTime.now().difference(_cacheAt!) < _cacheTtl) {
      return _cacheConfig;
    }
    try {
      final response = await http.get(
        Uri.parse(kAppUpdateRtdbUrl),
        headers: {'Accept': 'application/json'},
      );
      if (response.statusCode != 200) {
        debugPrint('AppUpdate: HTTP ${response.statusCode}');
        return null;
      }
      final body = response.body.trim();
      if (body.isEmpty || body == 'null') {
        return null;
      }
      final decoded = json.decode(body);
      if (decoded is! Map<String, dynamic>) {
        return null;
      }
      final config = AppUpdateRemoteConfig.fromJson(decoded);
      _cacheConfig = config;
      _cacheAt = DateTime.now();
      return config;
    } catch (e) {
      debugPrint('AppUpdate: fetch failed $e');
      return null;
    }
  }

  Future<AppUpdateCheckOutcome> check({bool bypassCache = false}) async {
    if (kIsWeb) {
      return AppUpdateCheckOutcome.none;
    }
    final pkg = await PackageInfo.fromPlatform();
    final remote = await _fetchRemote(bypassCache: bypassCache);
    if (remote == null) {
      return AppUpdateCheckOutcome.none;
    }
    return evaluate(pkg, remote);
  }

  /// iOS: ưu tiên [AppUpdateRemoteConfig.storeIosUrl] (RTDB), rồi [kIosAppStoreId].
  /// Android: ưu tiên RTDB, không có thì dựng từ `packageName`.
  Future<Uri> resolveStoreUri(AppUpdateRemoteConfig c, TargetPlatform platform) async {
    final raw = platform == TargetPlatform.iOS ? c.storeIosUrl : c.storeAndroidUrl;
    if (isUsableStoreUrl(raw)) {
      return Uri.parse(raw!.trim());
    }
    if (platform == TargetPlatform.iOS) {
      return iosAppStoreUri() ?? Uri.parse('https://apps.apple.com');
    }
    final pkg = await PackageInfo.fromPlatform();
    return androidPlayStoreUri(pkg.packageName);
  }

  /// Lấy cấu hình RTDB (có cache) — dùng cho rate app / mở store.
  Future<AppUpdateRemoteConfig?> fetchConfig({bool bypassCache = false}) {
    return _fetchRemote(bypassCache: bypassCache);
  }

  Future<void> openStore(AppUpdateRemoteConfig c, TargetPlatform platform) async {
    final uri = await resolveStoreUri(c, platform);
    try {
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      }
    } catch (e) {
      debugPrint('AppUpdate: launchUrl $e');
    }
  }

  /// Android: cập nhật ngay (fullscreen). Trả về true nếu Play xử lý thành công.
  Future<bool> tryAndroidImmediateUpdate() async {
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) {
      return false;
    }
    try {
      final info = await InAppUpdate.checkForUpdate();
      if (info.updateAvailability == UpdateAvailability.updateAvailable) {
        final result = await InAppUpdate.performImmediateUpdate();
        return result == AppUpdateResult.success;
      }
    } catch (e) {
      debugPrint('AppUpdate: immediate update $e');
    }
    return false;
  }

  /// Android: cập nhật linh hoạt (fallback khi dialog “khuyến nghị”).
  Future<bool> tryAndroidFlexibleUpdate() async {
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) {
      return false;
    }
    try {
      final info = await InAppUpdate.checkForUpdate();
      if (info.updateAvailability == UpdateAvailability.updateAvailable) {
        await InAppUpdate.startFlexibleUpdate();
        return true;
      }
    } catch (e) {
      debugPrint('AppUpdate: flexible update $e');
    }
    return false;
  }
}
