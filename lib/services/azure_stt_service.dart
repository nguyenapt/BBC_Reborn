import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../config/ai_config.dart';
import 'ai/exceptions.dart';

class AzureSttService {
  /// Đọc sample rate từ WAV PCM linear; null nếu không phải PCM chuẩn.
  static int? _readPcmWavSampleRate(Uint8List bytes) {
    if (bytes.length < 36) return null;
    if (bytes[0] != 0x52 ||
        bytes[1] != 0x49 ||
        bytes[2] != 0x46 ||
        bytes[3] != 0x46) {
      return null;
    }
    var i = 12;
    while (i + 8 < bytes.length) {
      final chunkId = String.fromCharCodes(bytes.sublist(i, i + 4));
      final chunkSize = bytes[i + 4] |
          (bytes[i + 5] << 8) |
          (bytes[i + 6] << 16) |
          (bytes[i + 7] << 24);
      if (chunkId == 'fmt ') {
        if (i + 16 > bytes.length) return null;
        final audioFormat = bytes[i + 8] | (bytes[i + 9] << 8);
        if (audioFormat != 1) return null;
        return bytes[i + 12] |
            (bytes[i + 13] << 8) |
            (bytes[i + 14] << 16) |
            (bytes[i + 15] << 24);
      }
      i += 8 + chunkSize;
      if (chunkSize % 2 == 1) i++;
    }
    return null;
  }

  static int _effectiveSampleRate(Uint8List audioBytes) {
    final fromFile = _readPcmWavSampleRate(audioBytes);
    if (fromFile != null && fromFile > 0) {
      final r = fromFile;
      if (r == 8000 || r == 16000 || r == 24000 || r == 48000) return r;
      return r;
    }
    return 16000;
  }

  /// Azure chấp nhận một vài biến thể Content-Type; 415 thường do sai codec/samplerate.
  static List<String> _contentTypeCandidates(int sampleRate) {
    final sr = sampleRate.toString();
    return [
      'audio/wav; codecs=audio/pcm; samplerate=$sr',
      'audio/wav; codec=audio/pcm; samplerate=$sr',
      'audio/wav; codecs=audio/pcm;samplerate=$sr',
      'audio/wav',
    ];
  }

  Uri _sttUriFromRegion(String language) {
    final region = AIConfig.getAzureSpeechRegion();
    if (region.isEmpty || region == 'YOUR_AZURE_SPEECH_REGION') {
      throw APIException('Azure Speech region not configured');
    }
    return Uri.parse(
      'https://$region.stt.speech.microsoft.com/speech/recognition/conversation/cognitiveservices/v1',
    ).replace(queryParameters: {'language': language});
  }

  Uri _buildEndpoint(String language) {
    final configured = AIConfig.getAzureSpeechEndpoint().trim();
    if (configured.isNotEmpty) {
      final lower = configured.toLowerCase();
      if (lower.contains('.tts.speech.microsoft.com')) {
        if (kDebugMode) {
          debugPrint(
            'Azure STT: azureSpeechEndpoint is TTS (tts.speech…), not STT. '
            'Using stt.speech URL from region instead.',
          );
        }
        return _sttUriFromRegion(language);
      }
      final base = Uri.parse(configured);
      final q = Map<String, String>.from(base.queryParameters);
      q['language'] = language;
      return base.replace(queryParameters: q);
    }

    return _sttUriFromRegion(language);
  }

  Future<String> transcribeWavFile(
    String filePath, {
    String language = 'en-US',
  }) async {
    final key = AIConfig.getAzureSpeechKey();
    if (key.isEmpty) {
      throw APIException('Azure Speech key not configured');
    }

    final endpoint = _buildEndpoint(language);
    final file = File(filePath);
    if (!await file.exists()) {
      throw APIException('Audio file not found');
    }

    final audioBytes = await file.readAsBytes();
    if (audioBytes.isEmpty) {
      throw APIException('Audio file is empty');
    }

    final sampleRate = _effectiveSampleRate(Uint8List.sublistView(audioBytes));
    final headersBase = {
      'Ocp-Apim-Subscription-Key': key,
      'Accept': 'application/json',
    };

    Object? lastBody;
    int? lastCode;

    for (final contentType in _contentTypeCandidates(sampleRate)) {
      try {
        final response = await http.post(
          endpoint,
          headers: {...headersBase, 'Content-Type': contentType},
          body: audioBytes,
        );
        lastCode = response.statusCode;
        lastBody = response.body;

        if (response.statusCode == 200) {
          final data = json.decode(response.body);
          final displayText = data['DisplayText']?.toString() ??
              data['NBest']?[0]?['Display']?.toString() ??
              data['NBest']?[0]?['Lexical']?.toString();

          if (displayText == null || displayText.trim().isEmpty) {
            throw InvalidResponseException('Empty transcription result');
          }

          return displayText.toString().trim();
        }

        if (response.statusCode == 415) {
          continue;
        }

        if (response.statusCode == 429) {
          throw RateLimitException('Azure STT rate limit exceeded');
        }

        throw APIException(
          'Azure STT error: ${response.statusCode} - ${response.body}',
          response.statusCode,
        );
      } catch (e) {
        if (e is AIException) rethrow;
        if (e.toString().contains('network') ||
            e.toString().contains('connection')) {
          throw NetworkException('Network error connecting to Azure STT', e);
        }
        throw APIException('Azure STT error: ${e.toString()}', null, e);
      }
    }

    final detail = lastBody is String ? lastBody : '';
    throw APIException(
      'Azure STT rejected audio (415 Unsupported Media Type). '
      'Try: set a full regional URL in azureSpeechEndpoint, or record 16 kHz mono PCM WAV. '
      'Detail: ${lastCode ?? '?'} ${detail.length > 200 ? '${detail.substring(0, 200)}...' : detail}',
      lastCode,
    );
  }
}
