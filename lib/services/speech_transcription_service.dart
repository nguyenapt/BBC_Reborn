import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../config/ai_config.dart';
import 'ai/ai_provider_factory.dart';
import 'ai/exceptions.dart';
import 'azure_stt_service.dart';

/// STT: Cloud Function (production) or local Azure/Whisper (dev when useCloudAI=false).
class SpeechTranscriptionService {
  final AzureSttService _azure = AzureSttService();

  static String _whisperLanguageCode(String bcp47) {
    final parts = bcp47.split(RegExp(r'[-_]'));
    if (parts.isEmpty) return 'en';
    final code = parts.first.toLowerCase();
    if (code.length == 2 || code.length == 3) return code;
    return 'en';
  }

  Future<String> transcribeWavFile(
    String filePath, {
    String language = 'en-US',
  }) async {
    if (AIConfig.effectiveUseCloudAI) {
      throw APIException(
        'Cloud STT requires audio bytes; use transcribeWavBytes on mobile.',
      );
    }

    final azureKey = AIConfig.getAzureSpeechKey();
    if (azureKey.isNotEmpty) {
      return _azure.transcribeWavFile(filePath, language: language);
    }

    return _transcribeWithWhisper(filePath, language: language);
  }

  /// Dùng cho Flutter Web: âm thanh ở dạng bytes (blob WAV), không có đường dẫn file thật.
  Future<String> transcribeWavBytes(
    Uint8List audioBytes, {
    String language = 'en-US',
  }) async {
    if (AIConfig.effectiveUseCloudAI) {
      debugPrint(
        'Speaking[stt] cloud transcribeSpeech bytes=${audioBytes.length}',
      );
      try {
        final text = await AIProviderFactory.getCloudProvider().transcribeSpeech(
          audioBytes,
          language: language,
        );
        debugPrint('Speaking[stt] cloud ok length=${text.length}');
        return text;
      } catch (e) {
        debugPrint('Speaking[stt] cloud failed: $e');
        rethrow;
      }
    }

    final azureKey = AIConfig.getAzureSpeechKey();
    if (azureKey.isNotEmpty) {
      return _azure.transcribeWavBytes(audioBytes, language: language);
    }

    return _transcribeWithWhisperBytes(audioBytes, language: language);
  }

  Future<String> _transcribeWithWhisper(
    String filePath, {
    required String language,
  }) async {
    final key = AIConfig.getWhisperApiKey();
    if (key.isEmpty) {
      throw SpeechNotConfiguredException();
    }

    final lang = _whisperLanguageCode(language);
    final uri = Uri.parse('https://api.openai.com/v1/audio/transcriptions');
    final request = http.MultipartRequest('POST', uri)
      ..headers['Authorization'] = 'Bearer $key'
      ..fields['model'] = 'whisper-1'
      ..fields['language'] = lang;

    request.files.add(await http.MultipartFile.fromPath('file', filePath));

    return _sendWhisperRequest(request);
  }

  Future<String> _transcribeWithWhisperBytes(
    Uint8List audioBytes, {
    required String language,
  }) async {
    final key = AIConfig.getWhisperApiKey();
    if (key.isEmpty) {
      throw SpeechNotConfiguredException();
    }

    final lang = _whisperLanguageCode(language);
    final uri = Uri.parse('https://api.openai.com/v1/audio/transcriptions');
    final request = http.MultipartRequest('POST', uri)
      ..headers['Authorization'] = 'Bearer $key'
      ..fields['model'] = 'whisper-1'
      ..fields['language'] = lang;

    request.files.add(
      http.MultipartFile.fromBytes(
        'file',
        audioBytes,
        filename: 'speech.wav',
      ),
    );

    return _sendWhisperRequest(request);
  }

  Future<String> _sendWhisperRequest(http.MultipartRequest request) async {
    try {
      final streamed = await request.send();
      final response = await http.Response.fromStream(streamed);

      if (response.statusCode == 200) {
        final data = json.decode(response.body) as Map<String, dynamic>;
        final text = data['text']?.toString().trim() ?? '';
        if (text.isEmpty) {
          throw InvalidResponseException('Whisper returned empty text');
        }
        return text;
      }

      if (response.statusCode == 429) {
        throw RateLimitException('OpenAI Whisper rate limit exceeded');
      }

      throw APIException(
        'Whisper API error: ${response.statusCode} - ${response.body}',
        response.statusCode,
      );
    } catch (e) {
      if (e is AIException) rethrow;
      final s = e.toString();
      if (s.contains('network') || s.contains('connection')) {
        throw NetworkException('Network error connecting to Whisper', e);
      }
      throw APIException('Whisper error: $s', null, e);
    }
  }

  /// Chỉ dùng khi [kIsWeb] và [blobOrPath] là URL `blob:` từ package record.
  static Future<Uint8List> readWebBlobBytes(String blobUrl) async {
    final r = await http.get(Uri.parse(blobUrl));
    if (r.statusCode != 200) {
      throw StateError('Cannot read recording (HTTP ${r.statusCode})');
    }
    return r.bodyBytes;
  }
}
