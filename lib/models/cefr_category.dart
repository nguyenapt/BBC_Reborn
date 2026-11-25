import 'cefr_level.dart';
import 'episode.dart';
import 'sub_category.dart';

/// RTDB level node: `{level}/metadata` + `{level}/sub-categories`.
class CefrCategory {
  final CefrLevel level;
  /// Reserved for later (e.g. description). Not used in UI yet.
  final String? metadata;
  final List<SubCategory> subCategories;

  const CefrCategory({
    required this.level,
    this.metadata,
    this.subCategories = const [],
  });

  String get code => level.code;

  /// Episodes concatenated in subcategory index order (0 → 1 → 2 …).
  List<Episode> get allEpisodesInSubOrder {
    final out = <Episode>[];
    for (final sub in subCategories) {
      out.addAll(sub.episodes);
    }
    return out;
  }

  SubCategory? subAt(int index) {
    for (final sub in subCategories) {
      if (sub.index == index) return sub;
    }
    if (index >= 0 && index < subCategories.length) {
      return subCategories[index];
    }
    return null;
  }
}
