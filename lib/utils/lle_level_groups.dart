import '../models/episode.dart';

class LleLevelGroups {
  static const String otherKey = 'OTHER';
  static const String allFilterKey = 'ALL';
  static const String prefsKey = 'lle_selected_level';

  static String asSubPrefsKey(String subCode) => 'as_level_$subCode';

  static const List<String> cefrOrder = ['A1', 'A2', 'B1', 'B2'];

  static int _byDateDesc(Episode a, Episode b) =>
      b.publishedDate.compareTo(a.publishedDate);

  static String normalizeLevel(String? raw) {
    if (raw == null) return otherKey;
    final trimmed = raw.trim();
    if (trimmed.isEmpty || trimmed == '--Select--') return otherKey;
    final upper = trimmed.toUpperCase();
    if (cefrOrder.contains(upper)) return upper;
    return otherKey;
  }

  static Map<String, List<Episode>> groupByLevel(List<Episode> episodes) {
    final map = <String, List<Episode>>{
      for (final level in cefrOrder) level: <Episode>[],
      otherKey: <Episode>[],
    };

    for (final episode in episodes) {
      map[normalizeLevel(episode.level)]!.add(episode);
    }

    for (final list in map.values) {
      list.sort(_byDateDesc);
    }
    return map;
  }

  static List<String> availableLevels(Map<String, List<Episode>> groups) {
    return cefrOrder.where((level) => groups[level]?.isNotEmpty ?? false).toList();
  }

  static List<String> sectionsForAllView(Map<String, List<Episode>> groups) {
    final sections = availableLevels(groups);
    if (groups[otherKey]?.isNotEmpty ?? false) {
      sections.add(otherKey);
    }
    return sections;
  }

  static List<Episode> episodesForPlaylist(
    Episode episode,
    List<Episode> allEpisodes,
  ) {
    if (!episode.hasLevel) {
      final sorted = List<Episode>.from(allEpisodes)..sort(_byDateDesc);
      return sorted;
    }

    final key = normalizeLevel(episode.level);
    if (!cefrOrder.contains(key)) {
      final sorted = List<Episode>.from(allEpisodes)..sort(_byDateDesc);
      return sorted;
    }

    return List<Episode>.from(groupByLevel(allEpisodes)[key] ?? []);
  }
}
