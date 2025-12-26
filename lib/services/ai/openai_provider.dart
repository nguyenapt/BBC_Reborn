import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'ai_provider.dart';
import 'exceptions.dart';
import 'json_parser_helper.dart';
import '../../config/ai_config.dart';

/// OpenAI Provider (Backup) - Using HTTP directly
class OpenAIProvider implements AIProvider {
  bool _initialized = false;
  final String? _apiKey;
  
  OpenAIProvider() : _apiKey = AIConfig.getOpenAIApiKey() {
    _initialize();
  }
  
  void _initialize() {
    if (_apiKey == null || _apiKey!.isEmpty || _apiKey == 'YOUR_OPENAI_API_KEY') {
      debugPrint('Warning: OpenAI API key not configured');
      _initialized = false;
      return;
    }
    _initialized = true;
  }
  
  @override
  Future<bool> isAvailable() async {
    return _initialized;
  }
  
  Future<String> _callOpenAI(String prompt, {String? systemPrompt}) async {
    if (!_initialized || _apiKey == null) {
      throw APIException('OpenAI not initialized. Please check API key.');
    }
    
    try {
      final messages = <Map<String, String>>[];
      
      if (systemPrompt != null) {
        messages.add({
          'role': 'system',
          'content': systemPrompt,
        });
      }
      
      messages.add({
        'role': 'user',
        'content': prompt,
      });
      
      final response = await http.post(
        Uri.parse('https://api.openai.com/v1/chat/completions'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $_apiKey',
        },
        body: json.encode({
          'model': AIConfig.openaiModel,
          'messages': messages,
          'temperature': 0.7,
        }),
      );
      
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final content = data['choices']?[0]?['message']?['content'];
        
        if (content == null || content.isEmpty) {
          throw InvalidResponseException('Empty response from OpenAI');
        }
        
        return content.toString();
      } else if (response.statusCode == 429) {
        throw RateLimitException('OpenAI rate limit exceeded');
      } else {
        throw APIException(
          'OpenAI API error: ${response.statusCode} - ${response.body}',
          response.statusCode,
        );
      }
    } catch (e) {
      if (e is AIException) rethrow;
      
      // Check for network errors
      if (e.toString().contains('network') || e.toString().contains('connection')) {
        throw NetworkException('Network error connecting to OpenAI', e);
      }
      
      throw APIException('OpenAI API error: ${e.toString()}', null, e);
    }
  }
  
  @override
  Future<String> translate(
    String text,
    String targetLanguage, {
    String? context,
  }) async {
    final contextPart = context != null ? '\n\nContext: $context' : '';
    final prompt = '''
Translate the following English text to $targetLanguage. 
Provide only the translation, no explanations.

Text: $text$contextPart

Translation:''';
    
    final response = await _callOpenAI(prompt);
    return response.trim();
  }
  
  @override
  Future<Map<String, dynamic>> explainGrammar(
    String sentence,
    String targetLanguage,
  ) async {
    final prompt = '''
Analyze this English sentence and explain the grammar.
Return ONLY a valid JSON object, no other text.

Sentence: "$sentence"

Return JSON format:
{
  "grammarPoint": "name of grammar rule",
  "explanation": "simple explanation in $targetLanguage",
  "highlightedWords": ["word1", "word2"]
}

JSON:''';
    
    final response = await _callOpenAI(
      prompt,
      systemPrompt: 'You are a helpful English grammar teacher. Always return valid JSON only.',
    );
    
    try {
      return JsonParserHelper.parseJsonObject(response);
    } catch (e) {
      throw InvalidResponseException('Failed to parse grammar explanation JSON: $e');
    }
  }
  
  @override
  Future<List<Map<String, dynamic>>> generateQuestions(
    String transcript,
    {int count = 5}
  ) async {
    final prompt = '''
Generate $count English learning questions from this transcript.
Return ONLY a valid JSON array, no other text.

Transcript: "$transcript"

Return JSON array format:
[
  {
    "type": "multipleChoice",
    "question": "question text",
    "options": ["option A", "option B", "option C", "option D"],
    "correctAnswer": "option A",
    "explanation": "why this is correct"
  }
]

JSON:''';
    
    final response = await _callOpenAI(
      prompt,
      systemPrompt: 'You are a helpful English teacher. Always return valid JSON arrays only.',
    );
    
    try {
      return JsonParserHelper.parseJsonArray(response);
    } catch (e) {
      throw InvalidResponseException('Failed to parse questions JSON: $e');
    }
  }
  
  @override
  Future<Map<String, dynamic>> enhanceVocabulary(
    String word,
    String meaning, {
    String? context,
  }) async {
    final contextPart = context != null ? '\n\nContext: $context' : '';
    final prompt = '''
Enhance this English vocabulary with additional information.
Return ONLY a valid JSON object, no other text.

Word: "$word"
Meaning: "$meaning"$contextPart

Return JSON format:
{
  "synonyms": ["word1", "word2"],
  "antonyms": ["word3"],
  "exampleSentences": ["sentence1", "sentence2"],
  "collocations": ["collocation1", "collocation2"],
  "pronunciation": "/pronunciation/",
  "wordForm": "noun"
}

JSON:''';
    
    final response = await _callOpenAI(
      prompt,
      systemPrompt: 'You are a helpful English vocabulary teacher. Always return valid JSON only.',
    );
    
    try {
      return JsonParserHelper.parseJsonObject(response);
    } catch (e) {
      throw InvalidResponseException('Failed to parse vocabulary enhancement JSON: $e');
    }
  }
}
