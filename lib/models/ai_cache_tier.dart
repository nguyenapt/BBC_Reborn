/// Nguồn cache khi phục vụ tính năng AI.
enum AICacheTier {
  /// SharedPreferences / storage local — không trừ heart.
  local,

  /// Firebase ai_cache (hoặc grammar/vocabulary_by_episode) — trừ heart.
  firebase,
}
