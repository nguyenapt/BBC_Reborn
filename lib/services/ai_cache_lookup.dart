/// Phân biệt nguồn hit cache để áp dụng chính sách tim (local miễn phí; Firebase ai_cache có trừ tim).
enum AiCacheSource {
  local,
  firebase,
}

class AiCached<T> {
  final T value;
  final AiCacheSource source;

  const AiCached(this.value, this.source);
}
