import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'ai_provider.dart';
import 'exceptions.dart';
import 'json_parser_helper.dart';
import '../../config/ai_config.dart';

/// OpenAI Provider (Backup) - Using HTTP directly
/// Deprecated: use [CloudAIProvider] when [AIConfig.useCloudAI] is true.
@Deprecated('Use CloudAIProvider via AIProviderFactory when useCloudAI is true')
class OpenAIProvider implements AIProvider {
  static String _resolveLocalOpenAIKey() {
    const envKey = String.fromEnvironment('OPENAI_API_KEY');
    if (envKey.isNotEmpty && envKey != 'YOUR_OPENAI_API_KEY') {
      return envKey;
    }
    return '';
  }

  bool _initialized = false;
  final String? _apiKey;

  OpenAIProvider() : _apiKey = _resolveLocalOpenAIKey() {
    debugPrint('🔑 OpenAI Provider: API key length=${_apiKey?.length ?? 0}');
    _initialize();
  }
  
  void _initialize() {
    try {
      if (_apiKey == null || _apiKey.isEmpty || _apiKey == 'YOUR_OPENAI_API_KEY') {
        debugPrint('❌ Warning: OpenAI API key not configured');
        _initialized = false;
        return;
      }
      _initialized = true;
      debugPrint('✅ OpenAI provider initialized successfully');
    } catch (e, stackTrace) {
      debugPrint('❌ Error initializing OpenAI: $e');
      debugPrint('   Stack trace: $stackTrace');
      _initialized = false;
    }
  }
  
  @override
  Future<bool> isAvailable() async {
    debugPrint('🔍 Checking OpenAI availability: initialized=$_initialized');
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
        debugPrint(
          'OpenAI API error: ${response.statusCode} - ${response.body}',
        );
        throw APIException(
          'OpenAI API error',
          response.statusCode,
        );
      }
    } catch (e) {
      if (e is AIException) rethrow;
      
      // Check for network errors
      if (e.toString().contains('network') || e.toString().contains('connection')) {
        throw NetworkException('Network error connecting to OpenAI', e);
      }
      
      debugPrint('OpenAI API error: $e');
      throw APIException('OpenAI API error', null, e);
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
      contextPart = '\n\n$context';
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
    
    debugPrint('🔤 OpenAI translate prompt:');
    debugPrint('   Source: English');
    debugPrint('   Target: $targetLanguage');
    debugPrint('   Text: "$text"');
    
    final response = await _callOpenAI(prompt);
    final trimmed = response.trim();
    
    debugPrint('📥 OpenAI translation response: "$trimmed"');
    
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
    
    debugPrint('🔤 OpenAI batch translate vocabulary: ${vocabularyList.length} words');
    
    final response = await _callOpenAI(
      prompt,
      systemPrompt: 'You are a translation assistant. Always return valid JSON only with word translations.',
    );
    
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
      
      debugPrint('✅ OpenAI batch translation completed: ${translations.length} words');
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
Analyze this English sentence for learning purposes.
Return ONLY a valid JSON object, no markdown, no comments.

Sentence: "$sentence"

Return JSON format:
{
  "grammarPoint": "name of grammar rule (short)",
  "rulePattern": "concise pattern, e.g. Subject + have/has + V3",
  "whyThisForm": "why this form is used in this sentence, in $targetLanguage",
  "explanation": "clear explanation in $targetLanguage",
  "highlightedWords": ["word_or_phrase_1", "word_or_phrase_2"],
  "commonMistakes": ["mistake 1 in $targetLanguage", "mistake 2 in $targetLanguage"]
}

Rules:
- Keep explanations practical and short.
- "highlightedWords" must be exact fragments from the input sentence.
- Do NOT include quizzes, exercises, or multiple-choice questions.
- If unsure, still provide best-effort pedagogical output.
JSON:''';
    
    final response = await _callOpenAI(
      prompt,
      systemPrompt:
          'You are an English grammar coach for language learners. Always return strict JSON only.',
    );
    
    try {
      return JsonParserHelper.parseJsonObject(response);
    } catch (e) {
      throw InvalidResponseException('Failed to parse grammar explanation JSON: $e');
    }
  }

  @override
  Future<Map<String, dynamic>> explainGrammarPassage(
    String passage,
    String targetLanguage,
  ) async {
    // Backward compatibility: keep this method, but use the slim schema.
    final prompt = '''
Analyze this English passage for grammar learning.
Return ONLY a valid JSON object, no markdown, no additional text.

Passage: "$passage"

Return JSON format (slim):
{
  "overall": {
    "grammarTheme": "main grammar theme in this passage",
    "usageSummary": "concise summary in $targetLanguage",
    "keyStructures": ["structure1", "structure2"]
  },
  "sentenceAnalyses": [
    {
      "sentenceText": "exact sentence from passage",
      "mainStructure": "main grammar structure",
      "usageInContext": "contextual usage in $targetLanguage",
      "phraseBreakdown": [
        {
          "phrase": "exact phrase from sentence",
          "structure": "phrase structure",
          "usage": "phrase usage in $targetLanguage"
        }
      ],
      "examples": ["example 1", "example 2"],
      "commonMistakes": ["mistake 1", "mistake 2"]
    }
  ]
}

Rules:
- Keep output concise and learner-friendly in $targetLanguage.
- phraseBreakdown is optional; include only important grammar-bearing phrases.
JSON:''';

    final response = await _callOpenAI(
      prompt,
      systemPrompt:
          'You are a multilingual English grammar coach. Always return strict JSON only and write explanations in the requested target language.',
    );

    try {
      return JsonParserHelper.parseJsonObject(response);
    } catch (e) {
      throw InvalidResponseException('Failed to parse passage grammar JSON: $e');
    }
  }

  @override
  Future<Map<String, dynamic>> explainGrammarPassageOverall(
    String passage,
    String targetLanguage,
  ) async {
    final prompt = '''
Analyze this English passage for grammar learning.
Return ONLY a valid JSON object, no markdown, no additional text.

Passage: "$passage"

Return JSON format:
{
  "overall": {
    "grammarTheme": "main grammar theme in this passage",
    "usageSummary": "concise summary in $targetLanguage",
    "keyStructures": ["structure1", "structure2"]
  }
}

Rules:
- Keep it short.
JSON:''';

    final response = await _callOpenAI(
      prompt,
      systemPrompt:
          'You are a multilingual English grammar coach. Always return strict JSON only and write explanations in the requested target language.',
    );
    try {
      return JsonParserHelper.parseJsonObject(response);
    } catch (e) {
      throw InvalidResponseException('Failed to parse passage overall JSON: $e');
    }
  }

  @override
  Future<Map<String, dynamic>> explainGrammarPassageSentences(
    String passage,
    String targetLanguage,
  ) async {
    final prompt = '''
Analyze this English passage for grammar learning.
Return ONLY a valid JSON object, no markdown, no additional text.

Passage: "$passage"

Return JSON format:
{
  "sentenceAnalyses": [
    {
      "sentenceText": "exact sentence from passage",
      "mainStructure": "main grammar structure",
      "usageInContext": "contextual usage in $targetLanguage",
      "phraseBreakdown": [
        {
          "phrase": "exact phrase from sentence",
          "structure": "phrase structure",
          "usage": "phrase usage in $targetLanguage"
        }
      ],
      "examples": ["example 1", "example 2"],
      "commonMistakes": ["mistake 1", "mistake 2"]
    }
  ]
}

Rules:
- Cover each meaningful sentence.
- Keep output concise and learner-friendly in $targetLanguage.
- phraseBreakdown is optional; include only important grammar-bearing phrases.
JSON:''';

    final response = await _callOpenAI(
      prompt,
      systemPrompt:
          'You are a multilingual English grammar coach. Always return strict JSON only and write explanations in the requested target language.',
    );
    try {
      return JsonParserHelper.parseJsonObject(response);
    } catch (e) {
      throw InvalidResponseException('Failed to parse passage sentences JSON: $e');
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
  "synonymDetails": [{"word": "word1", "meaning": "short gloss"}],
  "antonymDetails": [{"word": "word3", "meaning": "short gloss"}],
  "collocationDetails": [{"word": "collocation1", "meaning": "short gloss"}],
  "pronunciation": "/pronunciation/",
  "wordForm": "noun"
}

Rules:
- Keep synonyms/antonyms/collocations as plain string arrays (legacy).
- Always also fill *Details with the same terms plus a concise English meaning/gloss.

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

    final response = await _callOpenAI(prompt);
    try {
      return JsonParserHelper.parseJsonObject(response);
    } catch (e) {
      throw InvalidResponseException('Failed to parse speaking feedback JSON: $e');
    }
  }
}
