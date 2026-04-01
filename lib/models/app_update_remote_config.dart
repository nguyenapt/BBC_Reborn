/// Payload từ RTDB `AppUpdate.json`.
class AppUpdateRemoteConfig {
  final int? minBuild;
  final int? latestBuild;
  final String? minSupportedVersion;
  final String? latestVersion;
  final String? storeAndroidUrl;
  final String? storeIosUrl;
  final String? updateTitle;
  final String? updateMessage;

  const AppUpdateRemoteConfig({
    this.minBuild,
    this.latestBuild,
    this.minSupportedVersion,
    this.latestVersion,
    this.storeAndroidUrl,
    this.storeIosUrl,
    this.updateTitle,
    this.updateMessage,
  });

  static int? _parseInt(dynamic v) {
    if (v == null) return null;
    if (v is int) return v;
    if (v is double) return v.toInt();
    return int.tryParse(v.toString());
  }

  factory AppUpdateRemoteConfig.fromJson(Map<String, dynamic> json) {
    return AppUpdateRemoteConfig(
      minBuild: _parseInt(json['min_build'] ?? json['minBuild']),
      latestBuild: _parseInt(json['latest_build'] ?? json['latestBuild']),
      minSupportedVersion: json['min_supported_version']?.toString() ??
          json['minSupportedVersion']?.toString(),
      latestVersion:
          json['latest_version']?.toString() ?? json['latestVersion']?.toString(),
      storeAndroidUrl: json['store_android_url']?.toString() ??
          json['storeAndroidUrl']?.toString(),
      storeIosUrl:
          json['store_ios_url']?.toString() ?? json['storeIosUrl']?.toString(),
      updateTitle: json['update_title']?.toString() ?? json['updateTitle']?.toString(),
      updateMessage:
          json['update_message']?.toString() ?? json['updateMessage']?.toString(),
    );
  }
}

enum AppUpdateUrgency { none, optional, forced }

class AppUpdateCheckOutcome {
  final AppUpdateUrgency urgency;
  final AppUpdateRemoteConfig config;

  const AppUpdateCheckOutcome({
    required this.urgency,
    required this.config,
  });

  static const AppUpdateCheckOutcome none = AppUpdateCheckOutcome(
    urgency: AppUpdateUrgency.none,
    config: AppUpdateRemoteConfig(),
  );
}
