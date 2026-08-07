import 'vocabulary_item.dart';

/// One synonym / antonym / collocation with optional meaning (additive schema).
class VocabTermDetail {
  final String word;
  final String meaning;

  const VocabTermDetail({
    required this.word,
    this.meaning = '',
  });

  Map<String, dynamic> toJson() => {
        'word': word,
        'meaning': meaning,
      };

  factory VocabTermDetail.fromJson(Map<String, dynamic> json) {
    return VocabTermDetail(
      word: (json['word'] ?? json['term'] ?? '').toString().trim(),
      meaning: (json['meaning'] ?? json['mean'] ?? '').toString().trim(),
    );
  }

  VocabularyItem toVocabularyItem({
    required String bbcEpisodeId,
    String id = '',
  }) {
    return VocabularyItem(
      id: id,
      bbcEpisodeId: bbcEpisodeId,
      vocab: word,
      mean: meaning,
    );
  }
}

/// Enhanced vocabulary with additional AI-generated information
class EnhancedVocabulary {
  final VocabularyItem original;
  final List<String> synonyms;
  final List<String> antonyms;
  final List<String> exampleSentences;
  final List<String> collocations;
  final List<VocabTermDetail> synonymDetails;
  final List<VocabTermDetail> antonymDetails;
  final List<VocabTermDetail> collocationDetails;
  final String? pronunciation; // IPA notation
  final String? wordForm; // noun, verb, etc.

  EnhancedVocabulary({
    required this.original,
    required this.synonyms,
    required this.antonyms,
    required this.exampleSentences,
    required this.collocations,
    this.synonymDetails = const [],
    this.antonymDetails = const [],
    this.collocationDetails = const [],
    this.pronunciation,
    this.wordForm,
  });

  /// Prefer details when present; else wrap legacy string lists.
  List<VocabTermDetail> get displaySynonyms =>
      synonymDetails.isNotEmpty ? synonymDetails : _wrapWords(synonyms);

  List<VocabTermDetail> get displayAntonyms =>
      antonymDetails.isNotEmpty ? antonymDetails : _wrapWords(antonyms);

  List<VocabTermDetail> get displayCollocations =>
      collocationDetails.isNotEmpty
          ? collocationDetails
          : _wrapWords(collocations);

  static List<VocabTermDetail> _wrapWords(List<String> words) =>
      words
          .map((w) => w.trim())
          .where((w) => w.isNotEmpty)
          .map((w) => VocabTermDetail(word: w))
          .toList();

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
      'synonymDetails': synonymDetails.map((e) => e.toJson()).toList(),
      'antonymDetails': antonymDetails.map((e) => e.toJson()).toList(),
      'collocationDetails': collocationDetails.map((e) => e.toJson()).toList(),
      'pronunciation': pronunciation,
      'wordForm': wordForm,
    };
  }

  factory EnhancedVocabulary.fromJson(Map<String, dynamic> json) {
    return EnhancedVocabulary.fromAIResponse(
      VocabularyItem(
        id: json['original']?['id'] ?? '',
        bbcEpisodeId: json['original']?['bbcEpisodeId'] ?? '',
        vocab: json['original']?['vocab'] ?? '',
        mean: json['original']?['mean'] ?? '',
      ),
      json,
    );
  }

  /// Create from AI / cache response. Accepts legacy string arrays and additive *Details.
  factory EnhancedVocabulary.fromAIResponse(
    VocabularyItem original,
    Map<String, dynamic> response,
  ) {
    final synonymDetails = _parseDetails(
      response['synonymDetails'],
      fallbackWords: response['synonyms'],
    );
    final antonymDetails = _parseDetails(
      response['antonymDetails'],
      fallbackWords: response['antonyms'],
    );
    final collocationDetails = _parseDetails(
      response['collocationDetails'],
      fallbackWords: response['collocations'],
    );

    final synonyms = _stringList(response['synonyms']);
    final antonyms = _stringList(response['antonyms']);
    final collocations = _stringList(response['collocations']);

    return EnhancedVocabulary(
      original: original,
      synonyms: synonyms.isNotEmpty
          ? synonyms
          : synonymDetails.map((e) => e.word).toList(),
      antonyms: antonyms.isNotEmpty
          ? antonyms
          : antonymDetails.map((e) => e.word).toList(),
      exampleSentences: _stringList(response['exampleSentences']),
      collocations: collocations.isNotEmpty
          ? collocations
          : collocationDetails.map((e) => e.word).toList(),
      synonymDetails: synonymDetails,
      antonymDetails: antonymDetails,
      collocationDetails: collocationDetails,
      pronunciation: response['pronunciation']?.toString(),
      wordForm: response['wordForm']?.toString(),
    );
  }

  static List<String> _stringList(dynamic raw) {
    if (raw is! List) return const [];
    return raw
        .map((e) {
          if (e is Map) {
            final word = (e['word'] ?? e['term'] ?? '').toString().trim();
            return word;
          }
          return e.toString().trim();
        })
        .where((e) => e.isNotEmpty)
        .toList();
  }

  /// Parse `*Details` arrays; if missing, optionally build from string word list (meaning empty).
  static List<VocabTermDetail> _parseDetails(
    dynamic detailsRaw, {
    dynamic fallbackWords,
  }) {
    if (detailsRaw is List && detailsRaw.isNotEmpty) {
      final out = <VocabTermDetail>[];
      for (final e in detailsRaw) {
        if (e is Map) {
          final d = VocabTermDetail.fromJson(Map<String, dynamic>.from(e));
          if (d.word.isNotEmpty) out.add(d);
        } else {
          final w = e.toString().trim();
          if (w.isNotEmpty) out.add(VocabTermDetail(word: w));
        }
      }
      if (out.isNotEmpty) return out;
    }
    return _wrapWords(_stringList(fallbackWords));
  }
}
