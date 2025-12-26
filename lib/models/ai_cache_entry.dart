/// Model for AI cache entry in Firebase
class AICacheEntry {
  final Map<String, dynamic> data;
  final DateTime createdAt;
  final int version;
  final int? ttlDays; // Time to live in days

  AICacheEntry({
    required this.data,
    required this.createdAt,
    this.version = 1,
    this.ttlDays,
  });

  Map<String, dynamic> toJson() {
    return {
      'data': data,
      'createdAt': createdAt.toIso8601String(),
      'version': version,
      'ttlDays': ttlDays,
    };
  }

  factory AICacheEntry.fromJson(Map<String, dynamic> json) {
    return AICacheEntry(
      data: json['data'] as Map<String, dynamic>,
      createdAt: DateTime.parse(json['createdAt'] as String),
      version: json['version'] as int? ?? 1,
      ttlDays: json['ttlDays'] as int?,
    );
  }

  /// Check if cache entry is still valid
  bool isValid({int? defaultTtlDays}) {
    final ttl = ttlDays ?? defaultTtlDays ?? 90;
    final expiryDate = createdAt.add(Duration(days: ttl));
    return DateTime.now().isBefore(expiryDate);
  }

  /// Get remaining days until expiry
  int getRemainingDays({int? defaultTtlDays}) {
    final ttl = ttlDays ?? defaultTtlDays ?? 90;
    final expiryDate = createdAt.add(Duration(days: ttl));
    final remaining = expiryDate.difference(DateTime.now()).inDays;
    return remaining > 0 ? remaining : 0;
  }
}

