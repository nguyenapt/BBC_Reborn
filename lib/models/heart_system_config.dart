/// Payload từ RTDB `config/app_client_config/heart_system`.
class HeartSystemConfig {
  final bool enabled;
  final int maxHearts;
  final int regenMinutes;

  const HeartSystemConfig({
    this.enabled = false,
    this.maxHearts = 5,
    this.regenMinutes = 30,
  });

  factory HeartSystemConfig.fromJson(Map<String, dynamic> json) {
    return HeartSystemConfig(
      enabled: json['enabled'] == true,
      maxHearts: _asInt(json['maxHearts']) ?? 5,
      regenMinutes: _asInt(json['regenMinutes']) ?? 30,
    );
  }

  static int? _asInt(dynamic v) {
    if (v is int) return v;
    if (v is num) return v.toInt();
    if (v is String) return int.tryParse(v);
    return null;
  }
}
