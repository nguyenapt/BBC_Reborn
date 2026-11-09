/// Nguồn cache khi phục vụ tính năng AI.
enum AICacheTier {
  /// SharedPreferences / storage local — không trừ heart/credit.
  local,

  /// Firebase ai_cache — trừ heart (legacy) hoặc 1 credit (allow_credit).
  firebase,
}
