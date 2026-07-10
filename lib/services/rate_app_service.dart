import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';

import '../config/store_links.dart';
import '../models/app_update_remote_config.dart';
import 'app_update_service.dart';
import 'language_manager.dart';

class RateAppService {
  static const String _hasRatedKey = 'has_rated_app';
  static const String _ratePromptCountKey = 'rate_prompt_count';
  static const String _lastRatePromptDateKey = 'last_rate_prompt_date';
  static const String _appInstallDateKey = 'app_install_date';
  static const String _appUsageCountKey = 'app_usage_count';
  
  // Số lần tối đa hiển thị popup rate (sau đó sẽ không hiển thị nữa)
  static const int _maxPromptCount = 3;
  
  // Khoảng thời gian tối thiểu giữa các lần hiển thị popup (ngày)
  static const int _minDaysBetweenPrompts = 7;
  
  // Số ngày tối thiểu sau khi cài đặt để hiển thị popup rate
  static const int _minDaysAfterInstall = 3;
  
  // Số lần mở app tối thiểu để hiển thị popup rate
  static const int _minAppUsageCount = 5;

  /// Khởi tạo dữ liệu cho user mới (gọi khi app khởi động lần đầu)
  static Future<void> initializeForNewUser() async {
    final prefs = await SharedPreferences.getInstance();
    
    // Lưu ngày cài đặt nếu chưa có
    if (!prefs.containsKey(_appInstallDateKey)) {
      await prefs.setString(_appInstallDateKey, DateTime.now().toIso8601String());
    }
    
    // Tăng số lần sử dụng app
    final currentCount = prefs.getInt(_appUsageCountKey) ?? 0;
    await prefs.setInt(_appUsageCountKey, currentCount + 1);
  }

  /// Kiểm tra xem user đã rate app chưa
  static Future<bool> hasRatedApp() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_hasRatedKey) ?? false;
  }

  /// Đánh dấu user đã rate app
  static Future<void> markAsRated() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_hasRatedKey, true);
  }

  /// Kiểm tra xem có nên hiển thị popup rate không
  static Future<bool> shouldShowRatePrompt() async {
    // Nếu đã rate rồi thì không hiển thị
    if (await hasRatedApp()) {
      return false;
    }

    final prefs = await SharedPreferences.getInstance();
    final promptCount = prefs.getInt(_ratePromptCountKey) ?? 0;
    
    // Nếu đã hiển thị quá số lần tối đa thì không hiển thị nữa
    if (promptCount >= _maxPromptCount) {
      return false;
    }

    // Kiểm tra ngày cài đặt
    final installDateStr = prefs.getString(_appInstallDateKey);
    if (installDateStr != null) {
      final installDate = DateTime.parse(installDateStr);
      final daysSinceInstall = DateTime.now().difference(installDate).inDays;
      
      // Nếu chưa đủ số ngày sau khi cài đặt thì không hiển thị
      if (daysSinceInstall < _minDaysAfterInstall) {
        return false;
      }
    }

    // Kiểm tra số lần sử dụng app
    final usageCount = prefs.getInt(_appUsageCountKey) ?? 0;
    if (usageCount < _minAppUsageCount) {
      return false;
    }

    // Kiểm tra khoảng thời gian giữa các lần hiển thị
    final lastPromptDateStr = prefs.getString(_lastRatePromptDateKey);
    if (lastPromptDateStr != null) {
      final lastPromptDate = DateTime.parse(lastPromptDateStr);
      final daysSinceLastPrompt = DateTime.now().difference(lastPromptDate).inDays;
      
      if (daysSinceLastPrompt < _minDaysBetweenPrompts) {
        return false;
      }
    }

    return true;
  }

  /// Tăng số lần hiển thị popup và cập nhật ngày cuối cùng
  static Future<void> incrementPromptCount() async {
    final prefs = await SharedPreferences.getInstance();
    final currentCount = prefs.getInt(_ratePromptCountKey) ?? 0;
    await prefs.setInt(_ratePromptCountKey, currentCount + 1);
    await prefs.setString(_lastRatePromptDateKey, DateTime.now().toIso8601String());
  }

  /// Mở đúng store theo nền tảng (App Store trên iOS, Play Store trên Android).
  static Future<void> openStore() async {
    final uri = await _resolveStoreUri();
    try {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (e) {
      debugPrint('Error opening store ($uri): $e');
    }
  }

  /// Giữ tên cũ để tương thích call site cũ.
  @Deprecated('Use openStore()')
  static Future<void> openPlayStore() => openStore();

  static Future<Uri> _resolveStoreUri() async {
    final platform = defaultTargetPlatform;
    AppUpdateRemoteConfig? remote;
    try {
      remote = await AppUpdateService.instance.fetchConfig();
    } catch (e) {
      debugPrint('RateApp: fetch store config failed: $e');
    }
    remote ??= const AppUpdateRemoteConfig();

    if (platform == TargetPlatform.iOS) {
      if (isUsableStoreUrl(remote.storeIosUrl)) {
        final base = Uri.parse(remote.storeIosUrl!.trim());
        return base.replace(
          queryParameters: {
            ...base.queryParameters,
            'action': 'write-review',
          },
        );
      }
      final fromId = iosAppStoreUri();
      if (fromId != null) return fromId;
      debugPrint(
        'RateApp: thiếu App Store ID — đặt kIosAppStoreId hoặc store_ios_url trên RTDB',
      );
      return Uri.parse('https://apps.apple.com');
    }

    if (isUsableStoreUrl(remote.storeAndroidUrl)) {
      return Uri.parse(remote.storeAndroidUrl!.trim());
    }
    try {
      final pkg = await PackageInfo.fromPlatform();
      return androidPlayStoreUri(pkg.packageName);
    } catch (_) {
      return androidPlayStoreUri();
    }
  }

  /// Hiển thị dialog rate app
  static Future<void> showRateDialog(BuildContext context) async {
    final languageManager = LanguageManager();
    
    return showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: Row(
            children: [
              Icon(
                Icons.star,
                color: Colors.amber,
                size: 28,
              ),
              const SizedBox(width: 8),
              Text(
                languageManager.getText('rateApp'),
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                languageManager.getText('rateAppMessage'),
                style: const TextStyle(fontSize: 16),
              ),
              const SizedBox(height: 16),
              Row(
                children: List.generate(5, (index) {
                  return Icon(
                    Icons.star,
                    color: Colors.amber,
                    size: 32,
                  );
                }),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
                incrementPromptCount();
              },
              child: Text(
                languageManager.getText('later'),
                style: TextStyle(
                  color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
                ),
              ),
            ),
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
                markAsRated();
                openStore();
              },

              child: Text(
                languageManager.getText('rateNow'),
                style: TextStyle(
                  color: Theme.of(context).colorScheme.primary,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  /// Reset trạng thái rate (chỉ dùng cho testing)
  static Future<void> resetRateStatus() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_hasRatedKey);
    await prefs.remove(_ratePromptCountKey);
    await prefs.remove(_lastRatePromptDateKey);
    await prefs.remove(_appInstallDateKey);
    await prefs.remove(_appUsageCountKey);
  }
}
