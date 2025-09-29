class Episode {
  final String actor;
  final String category;
  final String duration;
  final DateTime publishedDate;
  final String episodeName;
  final String transcript;
  final String thumbImage;
  final String? id; // ID của episode trong Firebase
  final String? fileUrl;
  final String? summary;
  final String? year;

  Episode({
    required this.actor,
    required this.category,
    required this.duration,
    required this.publishedDate,
    required this.episodeName,
    required this.transcript,
    required this.thumbImage,
    this.id,
    this.fileUrl,
    this.summary,
    this.year,
  });

  factory Episode.fromJson(Map<String, dynamic> json, String episodeId) {
    return Episode(
      id: episodeId,
      actor: json['Actor'] ?? '',
      category: json['Category'] ?? '',
      duration: _formatDuration(json['Duration']),
      publishedDate: DateTime.parse(json['PublishedDate'] ?? DateTime.now().toIso8601String()),
      episodeName: json['EpisodeName'] ?? '',
      transcript: json['Transcript'] ?? '',
      thumbImage: json['ThumbImage'] ?? '',
      fileUrl: json['FileUrl'],
      summary: json['Summary'],
      year: json['Year'],
    );
  }

  // Chuyển đổi duration từ số (giây) sang định dạng mm:ss
  static String _formatDuration(dynamic duration) {
    if (duration == null) return '0:00';
    
    int seconds;
    if (duration is int) {
      seconds = duration;
    } else if (duration is String) {
      seconds = int.tryParse(duration) ?? 0;
    } else {
      return '0:00';
    }
    
    final minutes = seconds ~/ 60;
    final remainingSeconds = seconds % 60;
    return '$minutes:${remainingSeconds.toString().padLeft(2, '0')}';
  }

  Map<String, dynamic> toJson() {
    return {
      'actor': actor,
      'category': category,
      'duration': duration,
      'publishedDate': publishedDate.toIso8601String(),
      'episodeName': episodeName,
      'transcript': transcript,
      'thumbImage': thumbImage,
    };
  }

  // Lấy transcript ngắn (200 ký tự)
  String get shortTranscript {
    if (transcript.length <= 200) {
      return transcript;
    }
    return '${transcript.substring(0, 200)}...';
  }
}
