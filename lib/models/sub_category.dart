import 'episode.dart';

/// One item under RTDB `{level}/sub-categories/{index}`.
class SubCategory {
  final int index;
  final String text;
  final List<Episode> episodes;

  const SubCategory({
    required this.index,
    required this.text,
    this.episodes = const [],
  });

  bool get isGrammar => text.toLowerCase().contains('grammar');

  SubCategory copyWith({
    int? index,
    String? text,
    List<Episode>? episodes,
  }) {
    return SubCategory(
      index: index ?? this.index,
      text: text ?? this.text,
      episodes: episodes ?? this.episodes,
    );
  }
}
