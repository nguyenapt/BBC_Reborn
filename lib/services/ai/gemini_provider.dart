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
      
      final errorString = e.toString();
      
      // Check for quota exceeded with retry time
      if (errorString.contains('Quota exceeded') || errorString.contains('quota')) {
        // Try to extract retry time from error message
        // Format: "Please retry in 33.127665466s"
        Duration? retryAfter;
        final retryMatch = RegExp(r'retry in ([\d.]+)s', caseSensitive: false).firstMatch(errorString);
        if (retryMatch != null) {
          try {
            final seconds = double.parse(retryMatch.group(1)!);
            retryAfter = Duration(milliseconds: (seconds * 1000).round());
            debugPrint('⚠️ Gemini quota exceeded. Retry after: ${retryAfter.inSeconds}s');
          } catch (parseError) {
            debugPrint('Could not parse retry time: $parseError');
          }
        }
        throw RateLimitException('Gemini quota exceeded. Please wait a moment.', e, retryAfter);
      }
      
      // Check for rate limit (429)
      if (errorString.contains('429') || errorString.contains('rate limit')) {
        throw RateLimitException('Gemini rate limit exceeded', e);
      }
      
      // Check for network errors
      if (errorString.contains('network') || errorString.contains('connection')) {
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
    // Check if this is a vocabulary translation (context contains "Meaning:")
    final isVocabulary = context != null && context.contains('Meaning:');
    
    String contextPart;
    String instruction;
    
    if (isVocabulary) {
      // For vocabulary: only translate the word, ignore context examples
      contextPart = context != null ? '\n\n$context' : '';
      instruction = '''
Translate ONLY the English word below to $targetLanguage.
The word is: "$text"
$contextPart

IMPORTANT: Return ONLY the translation of the word "$text" in $targetLanguage. 
Do NOT translate the context or meaning. Do NOT include explanations.
Return only the translated word.''';
    } else {
      // For regular text translation
      contextPart = context != null ? '\n\nContext: $context' : '';
      instruction = '''
Translate the following English text to $targetLanguage. 
Provide only the translation, no explanations, no original text.

Text: $text$contextPart

Translation:''';
    }
    
    final prompt = instruction;
    
    debugPrint('🔤 Gemini translate prompt:');
    debugPrint('   Source: English');
    debugPrint('   Target: $targetLanguage');
    debugPrint('   Text: "$text"');
    
    final response = await _callGemini(prompt);
    final trimmed = response.trim();
    
    debugPrint('📥 Gemini translation response: "$trimmed"');
    
    // Check if response is same as original (AI might have returned original text)
    if (trimmed.toLowerCase() == text.toLowerCase()) {
      debugPrint('⚠️ WARNING: AI returned original text instead of translation!');
      debugPrint('   This might indicate the AI did not translate properly.');
    }
    
    return trimmed;
  }
  
  @override
  Future<Map<String, String>> translateVocabularyBatch(
    List<Map<String, String>> vocabularyList,
    String targetLanguage,
  ) async {
    // Build vocabulary list for prompt
    final vocabItems = vocabularyList.asMap().entries.map((entry) {
      final index = entry.key + 1;
      final vocab = entry.value;
      final word = vocab['word'] ?? '';
      final meaning = vocab['meaning'] ?? '';
      final context = vocab['context'];
      
      String itemText = '$index. Word: "$word"\n   Meaning: $meaning';
      if (context != null && context.isNotEmpty) {
        itemText += '\n   Context: $context';
      }
      return itemText;
    }).join('\n\n');
    
    final prompt = '''
Translate the following English vocabulary words to $targetLanguage.
You MUST return ONLY a valid JSON object, no markdown, no explanations, no other text.

Vocabulary list:
$vocabItems

Return format (JSON object only):
{
  "word1": "translation1",
  "word2": "translation2",
  ...
}

IMPORTANT: 
- Return ONLY the JSON object with word as key and translation as value
- Do NOT translate the context or meaning
- Do NOT include explanations
- Return only the translated words in $targetLanguage''';
    
    debugPrint('🔤 Gemini batch translate vocabulary: ${vocabularyList.length} words');
    
    final response = await _callGemini(prompt);
    
    try {
      final jsonResponse = JsonParserHelper.parseJsonObject(response);
      final translations = <String, String>{};
      
      // Extract translations from JSON
      for (final vocab in vocabularyList) {
        final word = vocab['word'] ?? '';
        if (jsonResponse.containsKey(word)) {
          translations[word] = jsonResponse[word].toString();
        } else {
          // Fallback: try lowercase
          final wordLower = word.toLowerCase();
          for (final key in jsonResponse.keys) {
            if (key.toString().toLowerCase() == wordLower) {
              translations[word] = jsonResponse[key].toString();
              break;
            }
          }
          // If still not found, use original word
          if (!translations.containsKey(word)) {
            debugPrint('⚠️ Translation not found for word: $word');
            translations[word] = word;
          }
        }
      }
      
      debugPrint('✅ Gemini batch translation completed: ${translations.length} words');
      return translations;
    } catch (e) {
      debugPrint('❌ Error parsing batch translation JSON: $e');
      throw InvalidResponseException('Failed to parse batch translation JSON: $e');
    }
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

  @override
  Future<Map<String, dynamic>> evaluateSpeech({
    required String referenceText,
    required String spokenText,
    String? language,
  }) async {
    final languagePart = language != null ? '\nLanguage: $language' : '';
    final prompt = '''
You are a speaking coach focused on pronunciation and clarity. Compare the reference and spoken transcripts.
Return ONLY a valid JSON object with scoring and feedback. No markdown.

Reference: "$referenceText"
Spoken: "$spokenText"$languagePart

Rules for "mistakes":
- Each "expected" MUST be copied exactly as a substring from Reference (same spelling; you may use a single word or short phrase).
- "spoken" is what the user actually said (from Spoken) for that slip.
- "note" is a concise pronunciation fix: how to shape the sound, stress, or mouth position (optional IPA in slashes if helpful).

Return format:
{
  "overallScore": 0-100,
  "pronunciationScore": 0-100,
  "fluencyScore": 0-100,
  "accuracyScore": 0-100,
  "feedback": "short actionable feedback",
  "mistakes": [
    {
      "expected": "word or phrase from Reference",
      "spoken": "what user said",
      "note": "how to fix pronunciation"
    }
  ]
}
''';

    final response = await _callGemini(prompt);
    try {
      return JsonParserHelper.parseJsonObject(response);
    } catch (e) {
      throw InvalidResponseException('Failed to parse speaking feedback JSON: $e');
    }
  }
}

