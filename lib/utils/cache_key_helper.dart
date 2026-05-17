import 'dart:convert';
import 'package:crypto/crypto.dart';

/// Helper class for generating cache keys and hashing
class CacheKeyHelper {
  /// Generate translation cache key
  static String translationKey(String episodeId, String languageCode) {
    return 'translation_${episodeId}_$languageCode';
  }

  /// 0-based transcript index → RTDB path `grammar_by_episode/.../line_0/...`.
  /// MUST_SYNC playMP3 upload tools when present.
  static String grammarByEpisodeLineKey(int transcriptLineIndex) =>
      'line_$transcriptLineIndex';

  /// Local / auxiliary key: prefer [lineNumber] when set, else sentence hash.
  static String grammarEpisodeLineKey(String sentence, {int? lineNumber}) {
    if (lineNumber != null && lineNumber >= 0) {
      return grammarByEpisodeLineKey(lineNumber);
    }
    return 's_${hashString(sentence.trim())}';
  }

  /// Generate grammar cache key from sentence hash and language code
  static String grammarKey(
    String sentence,
    String languageCode, {
    String? episodeId,
    String? modelVersion,
    String? promptVersion,
  }) {
    final scopedPayload = [
      sentence.trim(),
      episodeId?.trim() ?? '',
      modelVersion?.trim() ?? '',
      promptVersion?.trim() ?? '',
    ].join('|');
    final hash = hashString(scopedPayload);
    return 'grammar_${hash}_$languageCode';
  }

  /// Generate passage grammar cache key with isolated namespace
  static String grammarPassageKey(
    String passage,
    String languageCode, {
    String? episodeId,
    String? modelVersion,
    String? promptVersion,
    String? schemaVersion,
  }) {
    final scopedPayload = [
      passage.trim(),
      episodeId?.trim() ?? '',
      modelVersion?.trim() ?? '',
      promptVersion?.trim() ?? '',
      schemaVersion?.trim() ?? '',
    ].join('|');
    final hash = hashString(scopedPayload);
    return 'grammar_passage_${hash}_$languageCode';
  }

  /// Generate questions cache key
  static String questionsKey(String episodeId, int count) {
    return 'questions_${episodeId}_$count';
  }

  /// Generate vocabulary cache key from word hash and language code
  static String vocabularyKey(String word, String languageCode) {
    final hash = hashString(word.toLowerCase().trim());
    return 'vocab_${hash}_$languageCode';
  }

  /// playMP3 RTDB segment: SHA256(lowercase word), first 16 hex chars.
  static String vocabularyWordHashKey(String word) =>
      hashString(word.toLowerCase().trim());

  /// RTDB key under `vocabulary_by_episode/{episodeId}/{key}` (legacy Flutter: item id).
  static String vocabularyByEpisodeItemKey(String word, {String? itemId}) {
    if (itemId != null && itemId.trim().isNotEmpty) {
      return sanitizeFirebaseKey(itemId.trim());
    }
    return vocabularyWordHashKey(word);
  }

  /// Keys to try when reading vocabulary_by_episode (playMP3 wordHash first).
  static List<String> vocabularyByEpisodeLookupKeys(
    String word, {
    String? itemId,
  }) {
    final wordHash = vocabularyWordHashKey(word);
    final keys = <String>[wordHash];
    final legacyKey = vocabularyByEpisodeItemKey(word, itemId: itemId);
    if (legacyKey != wordHash) {
      keys.add(legacyKey);
    }
    return keys;
  }

  /// Unwrap playMP3 by-episode payload → flat map for [EnhancedVocabulary.fromAIResponse].
  static Map<String, dynamic> normalizeVocabularyByEpisodePayload(
    Map<String, dynamic> raw,
  ) {
    if (raw['schemaVersion'] == 2 || raw.containsKey('wordHash')) {
      final enhancement = raw['data'];
      if (enhancement is Map) {
        return Map<String, dynamic>.from(enhancement);
      }
    }
    return raw;
  }

  /// Hash a string to create unique identifier
  static String hashString(String input) {
    final bytes = utf8.encode(input);
    final digest = sha256.convert(bytes);
    return digest.toString().substring(0, 16); // Use first 16 chars for shorter key
  }

  /// Sanitize key for Firebase (remove invalid characters)
  /// Firebase doesn't allow: $ # [ ] / . or empty keys
  static String sanitizeFirebaseKey(String key) {
    if (key.isEmpty) {
      return 'empty';
    }
    // Replace invalid characters with underscore
    return key
        .replaceAll('\$', '_dollar_')
        .replaceAll('#', '_hash_')
        .replaceAll('[', '_lbracket_')
        .replaceAll(']', '_rbracket_')
        .replaceAll('/', '_slash_')
        .replaceAll('.', '_dot_');
  }

  /// Convert translations map to Firebase-safe format
  /// Store as array of {original, translated, lineNumber} objects instead of map
  static List<Map<String, dynamic>> translationsToFirebaseFormat(
    Map<String, String> translations, {
    List<String>? originalLines,
  }) {
    return translations.entries.toList().asMap().entries.map((entry) {
      final index = entry.key;
      final mapEntry = entry.value;
      final result = <String, dynamic>{
        'original': mapEntry.key,
        'translated': mapEntry.value,
      };
      // Add lineNumber if originalLines is provided
      if (originalLines != null && index < originalLines.length) {
        // Find the index of this line in originalLines
        final lineIndex = originalLines.indexOf(mapEntry.key);
        if (lineIndex >= 0) {
          result['lineNumber'] = lineIndex;
        } else {
          result['lineNumber'] = index; // Fallback to map index
        }
      }
      return result;
    }).toList();
  }

  /// Convert Firebase format back to translations map
  static Map<String, String> translationsFromFirebaseFormat(List<dynamic> firebaseData) {
    final translations = <String, String>{};
    for (final item in firebaseData) {
      if (item is Map<String, dynamic>) {
        final original = item['original']?.toString() ?? '';
        final translated = item['translated']?.toString() ?? '';
        if (original.isNotEmpty) {
          translations[original] = translated;
        }
      }
    }
    return translations;
  }

  static int? _lineNumberFromJson(dynamic value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    return int.tryParse(value?.toString() ?? '');
  }

  /// Find translation by [lineNumber] only (transcript text may vary).
  static String? findLineTranslation(
    List<dynamic> firebaseData,
    int? lineNumber,
  ) {
    if (lineNumber == null || lineNumber < 0) return null;

    String? match;
    for (final item in firebaseData) {
      if (item is! Map<String, dynamic>) continue;

      final translated = item['translated']?.toString() ?? '';
      if (translated.isEmpty) continue;

      final itemLineNumber = _lineNumberFromJson(item['lineNumber']);
      if (itemLineNumber == lineNumber) {
        match = translated;
      }
    }
    return match;
  }

  /// Generate episode-specific cache key
  static String episodeKey(String episodeId, String suffix) {
    return '${episodeId}_$suffix';
  }
}

