import 'dart:convert';

import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'ai_provider.dart';
import 'exceptions.dart';
import 'grammar_passage_dual_map.dart';

/// AI provider that proxies all LLM calls through Firebase Callable `aiRequest`.
class CloudAIProvider implements AIProvider {
  static const String _callableName = 'aiRequest';
  static const String _region = 'us-central1';

  final FirebaseFunctions _functions;
  String? _packageName;

  CloudAIProvider({FirebaseFunctions? functions})
      : _functions = functions ??
            FirebaseFunctions.instanceFor(region: _region);

  Future<String> _getPackageName() async {
    if (_packageName != null && _packageName!.isNotEmpty) {
      return _packageName!;
    }
    final info = await PackageInfo.fromPlatform();
    _packageName = info.packageName;
    return _packageName!;
  }

  Future<dynamic> _callAction(
    String action,
    Map<String, dynamic> payload,
  ) async {
    try {
      final callable = _functions.httpsCallable(_callableName);
      // Avoid .call<Map<...>> on web — causes JSObject cast TypeError.
      final result = await callable.call({
        'packageName': await _getPackageName(),
        'action': action,
        'payload': payload,
      });

      final raw = result.data;
      if (raw is! Map) {
        throw APIException('Invalid response from Cloud AI');
      }
      final data = Map<String, dynamic>.from(raw);
      if (data['success'] == true) {
        final provider = data['provider']?.toString() ?? 'unknown';
        debugPrint('CloudAIProvider [$action] → provider: $provider');
        return data['data'];
      }

      final message = data['message']?.toString() ?? 'AI request failed';
      throw APIException(message);
    } on FirebaseFunctionsException catch (e) {
      debugPrint(
        'CloudAIProvider error [$action]: code=${e.code} message=${e.message} '
        'details=${e.details}',
      );
      final detailMsg = e.details?.toString();
      final userMessage = (e.message != null && e.message!.isNotEmpty && e.message != 'INTERNAL')
          ? e.message!
          : (detailMsg?.isNotEmpty == true ? detailMsg! : 'Cloud AI error (${e.code})');
      throw _mapFirebaseError(e.code, userMessage, e);
    } on FirebaseException catch (e) {
      debugPrint('CloudAIProvider FirebaseException [$action]: ${e.code} ${e.message}');
      throw _mapFirebaseError(e.code, e.message, e);
    } catch (e) {
      if (e is AIException) rethrow;
      debugPrint('CloudAIProvider unexpected error [$action]: $e');
      throw APIException('Cloud AI error', null, e);
    }
  }

  Never _mapFirebaseError(String? code, String? message, Object? original) {
    if (code == 'resource-exhausted') {
      throw RateLimitException(message);
    }
    if (code == 'unavailable' || code == 'deadline-exceeded') {
      throw NetworkException(message, original);
    }
    throw APIException(message ?? 'Cloud AI error', null, original);
  }

  @override
  Future<bool> isAvailable() async => true;

  @override
  Future<String> translate(
    String text,
    String targetLanguage, {
    String? context,
  }) async {
    final data = await _callAction('translate', {
      'text': text,
      'targetLanguage': targetLanguage,
      if (context != null) 'context': context,
    });
    return data.toString().trim();
  }

  @override
  Future<Map<String, String>> translateVocabularyBatch(
    List<Map<String, String>> vocabularyList,
    String targetLanguage,
  ) async {
    final data = await _callAction('translateVocabularyBatch', {
      'vocabularyList': vocabularyList,
      'targetLanguage': targetLanguage,
    });
    if (data is! Map) {
      throw InvalidResponseException('Invalid batch translation response');
    }
    return data.map((key, value) => MapEntry(key.toString(), value.toString()));
  }

  @override
  Future<Map<String, dynamic>> explainGrammar(
    String sentence,
    String targetLanguage,
  ) async {
    final data = await _callAction('explainGrammar', {
      'sentence': sentence,
      'targetLanguage': targetLanguage,
    });
    return Map<String, dynamic>.from(data as Map);
  }

  @override
  Future<Map<String, dynamic>> explainGrammarPassageSingle(
    String passage,
    String targetLanguage,
  ) async {
    final data = await _callAction('explainGrammarPassageSingle', {
      'passage': passage,
      'sentence': passage,
      'targetLanguage': targetLanguage,
    });
    // CF already dual-maps; re-apply idempotently for safety.
    return toFlutterGrammarPassageData(
      Map<String, dynamic>.from(data as Map),
      passage,
    );
  }

  @override
  Future<Map<String, dynamic>> explainGrammarPassage(
    String passage,
    String targetLanguage,
  ) async {
    final overall = await explainGrammarPassageOverall(passage, targetLanguage);
    final sentences =
        await explainGrammarPassageSentences(passage, targetLanguage);
    return {
      ...overall,
      ...sentences,
    };
  }

  @override
  Future<Map<String, dynamic>> explainGrammarPassageOverall(
    String passage,
    String targetLanguage,
  ) async {
    final data = await _callAction('explainGrammarPassageOverall', {
      'passage': passage,
      'targetLanguage': targetLanguage,
    });
    return Map<String, dynamic>.from(data as Map);
  }

  @override
  Future<Map<String, dynamic>> explainGrammarPassageSentences(
    String passage,
    String targetLanguage,
  ) async {
    final data = await _callAction('explainGrammarPassageSentences', {
      'passage': passage,
      'targetLanguage': targetLanguage,
    });
    return Map<String, dynamic>.from(data as Map);
  }

  @override
  Future<List<Map<String, dynamic>>> generateQuestions(
    String transcript, {
    int count = 5,
  }) async {
    final data = await _callAction('generateQuestions', {
      'transcript': transcript,
      'count': count,
    });
    if (data is! List) {
      throw InvalidResponseException('Invalid questions response');
    }
    return data
        .map((item) => Map<String, dynamic>.from(item as Map))
        .toList();
  }

  @override
  Future<Map<String, dynamic>> enhanceVocabulary(
    String word,
    String meaning, {
    String? context,
  }) async {
    final data = await _callAction('enhanceVocabulary', {
      'word': word,
      'meaning': meaning,
      if (context != null) 'context': context,
    });
    return Map<String, dynamic>.from(data as Map);
  }

  /// Speech-to-text via Cloud Function `transcribeSpeech` (Azure / Whisper on server).
  Future<String> transcribeSpeech(
    Uint8List audioBytes, {
    String language = 'en-US',
  }) async {
    final data = await _callAction('transcribeSpeech', {
      'audioBase64': base64Encode(audioBytes),
      'language': language,
    });
    final text = data.toString().trim();
    if (text.isEmpty) {
      throw InvalidResponseException('Empty transcription from Cloud STT');
    }
    return text;
  }

  @override
  Future<Map<String, dynamic>> evaluateSpeech({
    required String referenceText,
    required String spokenText,
    String? language,
  }) async {
    final data = await _callAction('evaluateSpeech', {
      'referenceText': referenceText,
      'spokenText': spokenText,
      if (language != null) 'language': language,
    });
    return Map<String, dynamic>.from(data as Map);
  }
}
