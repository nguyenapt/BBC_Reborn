/// CEFR proficiency levels used as top-level RTDB nodes (A1…C2).
enum CefrLevel {
  a1('A1'),
  a2('A2'),
  b1('B1'),
  b2('B2'),
  c1('C1'),
  c2('C2');

  const CefrLevel(this.code);
  final String code;

  static const List<CefrLevel> all = CefrLevel.values;

  static const List<String> codes = ['A1', 'A2', 'B1', 'B2', 'C1', 'C2'];

  static CefrLevel? tryParse(String? raw) {
    if (raw == null || raw.isEmpty) return null;
    final normalized = raw.trim().toUpperCase();
    for (final level in CefrLevel.values) {
      if (level.code == normalized) return level;
    }
    return null;
  }

  static CefrLevel parse(String raw, {CefrLevel fallback = CefrLevel.a1}) {
    return tryParse(raw) ?? fallback;
  }
}
