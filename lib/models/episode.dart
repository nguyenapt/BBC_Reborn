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
  final String? secondFileUrl;
  final String? summary;
  final String? year;
  final String? transcriptHtml;
  final String? vocabulary;
  final List<dynamic>? vocabularies;

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
    this.secondFileUrl,
    this.summary,
    this.year,
    this.transcriptHtml,
    this.vocabulary,
    this.vocabularies,
  });

  factory Episode.fromJson(Map<String, dynamic> json, String episodeId) {
    return Episode(
      id: episodeId,
      actor: json['Actor']?.toString() ?? '',
      category: json['Category']?.toString() ?? '',
      duration: _formatDuration(json['Duration']),
      publishedDate: _parseDate(json['PublishedDate']),
      episodeName: json['EpisodeName']?.toString() ?? '',
      transcript: json['Transcript']?.toString() ?? '',
      thumbImage: json['ThumbImage']?.toString() ?? '',
      fileUrl: json['FileUrl']?.toString(),
      secondFileUrl: json['SecondFileUrl']?.toString(),
      summary: json['Summary']?.toString(),
      year: json['Year']?.toString(),
      transcriptHtml: json['TranscriptHtml']?.toString(),
      vocabulary: json['Vocabulary']?.toString(),
      vocabularies: json['Vocabularies'] as List<dynamic>?,
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

  // Parse date an toàn với fallback
  static DateTime _parseDate(dynamic dateValue) {
    if (dateValue == null) return DateTime.now();
    
    try {
      if (dateValue is String) {
        return DateTime.parse(dateValue);
      } else if (dateValue is int) {
        // Nếu là timestamp
        return DateTime.fromMillisecondsSinceEpoch(dateValue);
      } else {
        return DateTime.now();
      }
    } catch (e) {
      print('Error parsing date: $dateValue, error: $e');
      return DateTime.now();
    }
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
      'transcriptHtml': transcriptHtml,
      'vocabulary': vocabulary,
      'vocabularies': vocabularies,
      'summary': summary,
      'year': year,
      'fileUrl': fileUrl,
      'secondFileUrl': secondFileUrl,
      'id': id,
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
