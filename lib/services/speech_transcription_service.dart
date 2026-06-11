import 'dart:convert';
import 'dart:typed_data';
import 'package:http/http.dart' as http;
import '../config/ai_config.dart';
import 'ai/exceptions.dart';
import 'azure_stt_service.dart';

/// Azure STT ưu tiên; nếu chưa cấu hình Azure thì dùng OpenAI Whisper (cùng API key OpenAI).
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
      throw APIException(
        'Speech recognition is not configured. '
        'Set AZURE_SPEECH_KEY and AZURE_SPEECH_REGION (or AZURE_SPEECH_ENDPOINT) in '
        'environment variables or lib/config/ai_config.dart, '
        'or set OPENAI_API_KEY / openaiApiKey to use Whisper as fallback.',
      );
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
      throw APIException(
        'Speech recognition is not configured. '
        'Set AZURE_SPEECH_KEY and AZURE_SPEECH_REGION (or AZURE_SPEECH_ENDPOINT) in '
        'environment variables or lib/config/ai_config.dart, '
        'or set OPENAI_API_KEY / openaiApiKey to use Whisper as fallback.',
      );
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
