import 'episode.dart';

class FavouriteEpisode {
  final String? id;
  final String actor;
  final String category;
  final String duration;
  final DateTime publishedDate;
  final String episodeName;
  final String transcript;
  final String thumbImage;
  final String? fileUrl;
  final String? secondFileUrl;
  final String? summary;
  final String? year;
  final String? transcriptHtml;
  final String? vocabulary;
  final List<dynamic>? vocabularies;
  final DateTime savedAt;

  FavouriteEpisode({
    this.id,
    required this.actor,
    required this.category,
    required this.duration,
    required this.publishedDate,
    required this.episodeName,
    required this.transcript,
    required this.thumbImage,
    this.fileUrl,
    this.secondFileUrl,
    this.summary,
    this.year,
    this.transcriptHtml,
    this.vocabulary,
    this.vocabularies,
    required this.savedAt,
  });

  // Tạo từ Episode object
  factory FavouriteEpisode.fromEpisode(Episode episode) {
    return FavouriteEpisode(
      id: episode.id,
      actor: episode.actor,
      category: episode.category,
      duration: episode.duration,
      publishedDate: episode.publishedDate,
      episodeName: episode.episodeName,
      transcript: episode.transcript,
      thumbImage: episode.thumbImage,
      fileUrl: episode.fileUrl,
      secondFileUrl: episode.secondFileUrl,
      summary: episode.summary,
      year: episode.year,
      transcriptHtml: episode.transcriptHtml,
      vocabulary: episode.vocabulary,
      vocabularies: episode.vocabularies,
      savedAt: DateTime.now(),
    );
  }

  // Convert từ JSON
  factory FavouriteEpisode.fromJson(Map<String, dynamic> json) {
    return FavouriteEpisode(
      id: json['id'],
      actor: json['actor'] ?? '',
      category: json['category'] ?? '',
      duration: json['duration'] ?? '',
      publishedDate: DateTime.parse(json['publishedDate'] ?? DateTime.now().toIso8601String()),
      episodeName: json['episodeName'] ?? '',
      transcript: json['transcript'] ?? '',
      thumbImage: json['thumbImage'] ?? '',
      fileUrl: json['fileUrl'],
      secondFileUrl: json['secondFileUrl'],
      summary: json['summary'],
      year: json['year'],
      transcriptHtml: json['transcriptHtml'],
      vocabulary: json['vocabulary'],
      vocabularies: json['vocabularies'],
      savedAt: DateTime.parse(json['savedAt'] ?? DateTime.now().toIso8601String()),
    );
  }

  // Convert sang JSON
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'actor': actor,
      'category': category,
      'duration': duration,
      'publishedDate': publishedDate.toIso8601String(),
      'episodeName': episodeName,
      'transcript': transcript,
      'thumbImage': thumbImage,
      'fileUrl': fileUrl,
      'secondFileUrl': secondFileUrl,
      'summary': summary,
      'year': year,
      'transcriptHtml': transcriptHtml,
      'vocabulary': vocabulary,
      'vocabularies': vocabularies,
      'savedAt': savedAt.toIso8601String(),
    };
  }

  // Convert sang Episode object để sử dụng trong app
  Episode toEpisode() {
    return Episode(
      id: id,
      actor: actor,
      category: category,
      duration: duration,
      publishedDate: publishedDate,
      episodeName: episodeName,
      transcript: transcript,
      thumbImage: thumbImage,
      fileUrl: fileUrl,
      secondFileUrl: secondFileUrl,
      summary: summary,
      year: year,
      transcriptHtml: transcriptHtml,
      vocabulary: vocabulary,
      vocabularies: vocabularies,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is FavouriteEpisode && other.id == id;
  }

  @override
  int get hashCode => id.hashCode;
}
