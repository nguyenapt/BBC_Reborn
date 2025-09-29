import 'episode.dart';

class Category {
  final String name;
  final List<Episode> episodes;

  Category({
    required this.name,
    required this.episodes,
  });

  // Lấy 3 episode mới nhất theo publishedDate
  List<Episode> get latestEpisodes {
    final sortedEpisodes = List<Episode>.from(episodes);
    sortedEpisodes.sort((a, b) => b.publishedDate.compareTo(a.publishedDate));
    return sortedEpisodes.take(3).toList();
  }

  // Constructor đơn giản vì chúng ta đã xử lý parsing trong FirebaseService

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> episodesJson = {};
    for (final episode in episodes) {
      if (episode.id != null) {
        episodesJson[episode.id!] = episode.toJson();
      }
    }
    return episodesJson;
  }
}
