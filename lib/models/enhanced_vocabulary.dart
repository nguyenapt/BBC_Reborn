import 'vocabulary_item.dart';

/// Enhanced vocabulary with additional AI-generated information
class EnhancedVocabulary {
  final VocabularyItem original;
  final List<String> synonyms;
  final List<String> antonyms;
  final List<String> exampleSentences;
  final List<String> collocations;
  final String? pronunciation; // IPA notation
  final String? wordForm; // noun, verb, etc.

  EnhancedVocabulary({
    required this.original,
    required this.synonyms,
    required this.antonyms,
    required this.exampleSentences,
    required this.collocations,
    this.pronunciation,
    this.wordForm,
  });

  Map<String, dynamic> toJson() {
    return {
      'original': {
        'id': original.id,
        'bbcEpisodeId': original.bbcEpisodeId,
        'vocab': original.vocab,
        'mean': original.mean,
      },
      'synonyms': synonyms,
      'antonyms': antonyms,
      'exampleSentences': exampleSentences,
      'collocations': collocations,
      'pronunciation': pronunciation,
      'wordForm': wordForm,
    };
  }

  factory EnhancedVocabulary.fromJson(Map<String, dynamic> json) {
    return EnhancedVocabulary(
      original: VocabularyItem(
        id: json['original']['id'] ?? '',
        bbcEpisodeId: json['original']['bbcEpisodeId'] ?? '',
        vocab: json['original']['vocab'] ?? '',
        mean: json['original']['mean'] ?? '',
      ),
      synonyms: (json['synonyms'] as List<dynamic>?)
          ?.map((e) => e.toString())
          .toList() ?? [],
      antonyms: (json['antonyms'] as List<dynamic>?)
          ?.map((e) => e.toString())
          .toList() ?? [],
      exampleSentences: (json['exampleSentences'] as List<dynamic>?)
          ?.map((e) => e.toString())
          .toList() ?? [],
      collocations: (json['collocations'] as List<dynamic>?)
          ?.map((e) => e.toString())
          .toList() ?? [],
      pronunciation: json['pronunciation']?.toString(),
      wordForm: json['wordForm']?.toString(),
    );
  }

  /// Create from AI response
  factory EnhancedVocabulary.fromAIResponse(
    VocabularyItem original,
    Map<String, dynamic> response,
  ) {
    return EnhancedVocabulary(
      original: original,
      synonyms: (response['synonyms'] as List<dynamic>?)
          ?.map((e) => e.toString())
          .toList() ?? [],
      antonyms: (response['antonyms'] as List<dynamic>?)
          ?.map((e) => e.toString())
          .toList() ?? [],
      exampleSentences: (response['exampleSentences'] as List<dynamic>?)
          ?.map((e) => e.toString())
          .toList() ?? [],
      collocations: (response['collocations'] as List<dynamic>?)
          ?.map((e) => e.toString())
          .toList() ?? [],
      pronunciation: response['pronunciation']?.toString(),
      wordForm: response['wordForm']?.toString(),
    );
  }
}

