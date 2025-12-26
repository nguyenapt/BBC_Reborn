import 'package:google_generative_ai/google_generative_ai.dart';
import 'package:flutter/foundation.dart';
import 'dart:convert';
import 'ai_provider.dart';
import 'exceptions.dart';
import 'rate_limiter.dart';
import 'json_parser_helper.dart';
import '../../config/ai_config.dart';

/// Google Gemini AI Provider (Free tier)
class GeminiProvider implements AIProvider {
  late final GenerativeModel _model;
  final RateLimiter _rateLimiter;
  bool _initialized = false;
  
  GeminiProvider() : _rateLimiter = RateLimiter(maxRequestsPerMinute: AIConfig.geminiRateLimit) {
    _initialize();
  }
  
  void _initialize() {
    try {
      // Skip initialization on web during hot reload to avoid errors
      if (kIsWeb) {
        // On web, initialize lazily on first use to avoid hot reload issues
        debugPrint('Gemini provider: Web platform detected, will initialize on first use');
        return;
      }
      
      final apiKey = AIConfig.getGeminiApiKey();
      debugPrint('🔑 Gemini API Key check: isEmpty=${apiKey.isEmpty}, length=${apiKey.length}');
      
      if (apiKey.isEmpty || apiKey == 'YOUR_GEMINI_API_KEY') {
        debugPrint('❌ Warning: Gemini API key not configured');
        return;
      }
      
      debugPrint('✅ Gemini API key found, initializing model...');
      _initializeModel(apiKey);
      
      if (_initialized) {
        debugPrint('✅ Gemini provider initialized successfully');
      } else {
        debugPrint('❌ Gemini provider initialization failed');
      }
    } catch (e, stackTrace) {
      debugPrint('❌ Error initializing Gemini: $e');
      debugPrint('   Stack trace: $stackTrace');
      _initialized = false;
    }
  }
  
  void _initializeModel(String apiKey) {
      // Try different model names in order of preference
      // Reference: https://ai.google.dev/gemini-api/docs/api-key
      final modelNames = [
        AIConfig.geminiModel, // Try configured model first (gemini-2.5-flash)
        'gemini-2.5-flash',   // Official latest model
        'gemini-1.5-flash',   // Fallback to previous version
        'gemini-pro',         // Legacy fallback
      ];
    
    GenerativeModel? model;
    String? lastError;
    
    for (final modelName in modelNames) {
      try {
        model = GenerativeModel(
          model: modelName,
          apiKey: apiKey,
        );
        debugPrint('Successfully initialized Gemini with model: $modelName');
        break;
      } catch (e) {
        lastError = e.toString();
        debugPrint('Failed to initialize with model $modelName: $e');
        continue;
      }
    }
    
    if (model == null) {
      debugPrint('Error initializing Gemini with any model. Last error: $lastError');
      _initialized = false;
      return;
    }
    
    _model = model;
    _initialized = true;
  }
  
  @override
  Future<bool> isAvailable() async {
    debugPrint('🔍 Checking Gemini availability: initialized=$_initialized');
    if (!_initialized) {
      // Try to initialize if not already done
      final apiKey = AIConfig.getGeminiApiKey();
      if (apiKey.isNotEmpty && apiKey != 'YOUR_GEMINI_API_KEY') {
        debugPrint('🔄 Attempting late initialization...');
        _initializeModel(apiKey);
      }
    }
    
    if (!_initialized) {
      debugPrint('❌ Gemini not available: not initialized');
      return false;
    }
    
    final canRequest = await _rateLimiter.canMakeRequest();
    debugPrint('✅ Gemini available: canMakeRequest=$canRequest');
    return canRequest;
  }
  
  Future<String> _callGemini(String prompt) async {
    // Lazy initialization for web platform
    if (!_initialized) {
      if (kIsWeb) {
        final apiKey = AIConfig.getGeminiApiKey();
        if (apiKey.isEmpty || apiKey == 'YOUR_GEMINI_API_KEY') {
          throw APIException('Gemini API key not configured');
        }
        _initializeModel(apiKey);
        if (!_initialized) {
          throw APIException('Gemini not initialized. Please check API key.');
        }
      } else {
        throw APIException('Gemini not initialized. Please check API key.');
      }
    }
    
    // Wait if rate limited
    await _rateLimiter.waitUntilAvailable();
    
    try {
      final response = await _model.generateContent([Content.text(prompt)]);
      final text = response.text;
      
      if (text == null || text.isEmpty) {
        throw InvalidResponseException('Empty response from Gemini');
      }
      
      return text;
    } catch (e) {
      if (e is AIException) rethrow;
      
      // Check for rate limit
      if (e.toString().contains('429') || e.toString().contains('rate limit')) {
        throw RateLimitException('Gemini rate limit exceeded', e);
      }
      
      // Check for network errors
      if (e.toString().contains('network') || e.toString().contains('connection')) {
        throw NetworkException('Network error connecting to Gemini', e);
      }
      
      throw APIException('Gemini API error: ${e.toString()}', null, e);
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
    
    final response = await _callGemini(prompt);
    return response.trim();
  }
  
  @override
  Future<Map<String, dynamic>> explainGrammar(
    String sentence,
    String targetLanguage,
  ) async {
    final prompt = '''
Analyze this English sentence and explain the grammar.
You MUST return ONLY a valid JSON object, no markdown, no explanations, no other text.

Sentence: "$sentence"

Return format (JSON object only):
{
  "grammarPoint": "name of grammar rule",
  "explanation": "simple explanation in $targetLanguage",
  "highlightedWords": ["word1", "word2"]
}

Important: Return ONLY the JSON object, nothing else.''';
    
    final response = await _callGemini(prompt);
    
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
Generate exactly $count English learning questions from this transcript.
You MUST return ONLY a valid JSON array, no markdown, no explanations, no other text.

Transcript: "$transcript"

Return format (JSON array only):
[
  {
    "type": "multipleChoice",
    "question": "question text",
    "options": ["option A", "option B", "option C", "option D"],
    "correctAnswer": "option A",
    "explanation": "why this is correct"
  }
]

Important: Return ONLY the JSON array, nothing else.''';
    
    final response = await _callGemini(prompt);
    
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
You MUST return ONLY a valid JSON object, no markdown, no explanations, no other text.

Word: "$word"
Meaning: "$meaning"$contextPart

Return format (JSON object only):
{
  "synonyms": ["word1", "word2"],
  "antonyms": ["word3"],
  "exampleSentences": ["sentence1", "sentence2"],
  "collocations": ["collocation1", "collocation2"],
  "pronunciation": "/pronunciation/",
  "wordForm": "noun"
}

Important: Return ONLY the JSON object, nothing else.''';
    
    final response = await _callGemini(prompt);
    
    try {
      return JsonParserHelper.parseJsonObject(response);
    } catch (e) {
      throw InvalidResponseException('Failed to parse vocabulary enhancement JSON: $e');
    }
  }
}

