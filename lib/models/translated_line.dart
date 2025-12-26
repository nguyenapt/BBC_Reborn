import 'transcript_line.dart';

/// Model for translated transcript line
class TranslatedLine {
  final TranscriptLine original;
  final String translatedText;
  final String? translatedSpeaker;
  final String targetLanguage;

  TranslatedLine({
    required this.original,
    required this.translatedText,
    this.translatedSpeaker,
    required this.targetLanguage,
  });

  Map<String, dynamic> toJson() {
    return {
      'original': {
        'startTime': original.startTime,
        'endTime': original.endTime,
        'speaker': original.speaker,
        'text': original.text,
      },
      'translatedText': translatedText,
      'translatedSpeaker': translatedSpeaker,
      'targetLanguage': targetLanguage,
    };
  }

  factory TranslatedLine.fromJson(Map<String, dynamic> json) {
    return TranslatedLine(
      original: TranscriptLine(
        startTime: json['original']['startTime'] ?? 0,
        endTime: json['original']['endTime'] ?? 0,
        speaker: json['original']['speaker'] ?? '',
        text: json['original']['text'] ?? '',
      ),
      translatedText: json['translatedText'] ?? '',
      translatedSpeaker: json['translatedSpeaker'],
      targetLanguage: json['targetLanguage'] ?? '',
    );
  }
}

