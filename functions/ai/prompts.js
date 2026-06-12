/**
 * Prompt builders — port of gemini_provider.dart / openai_provider.dart
 */

/**
 * @param {string|undefined} context
 * @param {string} word
 * @param {number} maxLen
 * @returns {string|undefined}
 */
function trimContextForWord(context, word, maxLen = 200) {
  if (!context || !String(context).trim()) return undefined;
  const text = String(context);
  const wordLower = word.toLowerCase();
  const sentences = text.split(/[.!?]\s+/);
  const relevant = sentences
      .filter((sentence) => sentence.toLowerCase().includes(wordLower))
      .slice(0, 2)
      .join(". ");
  if (!relevant) return undefined;
  return relevant.length > maxLen ? `${relevant.slice(0, maxLen)}...` : relevant;
}

/**
 * @param {string} text
 * @param {string} targetLanguage
 * @param {string|undefined} context
 * @returns {{prompt: string, systemPrompt?: string}}
 */
function buildTranslatePrompt(text, targetLanguage, context) {
  const isVocabulary = context != null && context.includes("Meaning:");

  if (isVocabulary) {
    const contextPart = `\n\n${context}`;
    return {
      prompt: `Translate ONLY the English word below to ${targetLanguage}.
The word is: "${text}"
${contextPart}

IMPORTANT: Return ONLY the translation of the word "${text}" in ${targetLanguage}.
Do NOT translate the context or meaning. Do NOT include explanations.
Return only the translated word.`,
    };
  }

  const contextPart = context ? `\n\nContext: ${context}` : "";
  return {
    prompt: `Translate the following English text to ${targetLanguage}.
Provide only the translation, no explanations, no original text.

Text: ${text}${contextPart}

Translation:`,
  };
}

/**
 * @param {Array<{word?: string, meaning?: string, context?: string}>} vocabularyList
 * @param {string} targetLanguage
 * @returns {{prompt: string, systemPrompt: string}}
 */
function buildTranslateVocabularyBatchPrompt(vocabularyList, targetLanguage) {
  const vocabItems = vocabularyList
      .map((vocab, index) => {
        const word = vocab.word ?? "";
        const meaning = vocab.meaning ?? "";
        const ctx = vocab.context;
        let itemText = `${index + 1}. Word: "${word}"\n   Meaning: ${meaning}`;
        if (ctx) itemText += `\n   Context: ${ctx}`;
        return itemText;
      })
      .join("\n\n");

  return {
    prompt: `Translate the following English vocabulary words to ${targetLanguage}.
You MUST return ONLY a valid JSON object, no markdown, no explanations, no other text.

Vocabulary list:
${vocabItems}

Return format (JSON object only):
{
  "word1": "translation1",
  "word2": "translation2"
}

IMPORTANT:
- Return ONLY the JSON object with word as key and translation as value
- Do NOT translate the context or meaning
- Do NOT include explanations
- Return only the translated words in ${targetLanguage}`,
    systemPrompt:
      "You are a translation assistant. Always return valid JSON only with word translations.",
  };
}

/**
 * @param {string} sentence
 * @param {string} targetLanguage
 * @returns {{prompt: string, systemPrompt: string}}
 */
function buildExplainGrammarPrompt(sentence, targetLanguage) {
  return {
    prompt: `Analyze this English sentence for learning purposes.
You MUST return ONLY a valid JSON object, no markdown, no explanations, no other text.

Sentence: "${sentence}"

Return format (JSON object only):
{
  "grammarPoint": "name of grammar rule (short)",
  "rulePattern": "concise pattern, e.g. Subject + have/has + V3",
  "whyThisForm": "why this form is used in this sentence, in ${targetLanguage}",
  "explanation": "clear explanation in ${targetLanguage}",
  "highlightedWords": ["word_or_phrase_1", "word_or_phrase_2"],
  "commonMistakes": ["mistake 1 in ${targetLanguage}", "mistake 2 in ${targetLanguage}"]
}

Rules:
- Keep explanations practical and concise.
- "highlightedWords" must be exact fragments from the input sentence.
- Do NOT include quizzes, exercises, or multiple-choice questions.
- If uncertain, still return best-effort pedagogical output.
Important: Return ONLY the JSON object, nothing else.`,
    systemPrompt:
      "You are an English grammar coach for language learners. Always return strict JSON only.",
  };
}

/**
 * @param {string} passage
 * @param {string} targetLanguage
 * @returns {{prompt: string, systemPrompt: string}}
 */
function buildExplainGrammarPassageOverallPrompt(passage, targetLanguage) {
  return {
    prompt: `Analyze this English passage for grammar learning.
You MUST return ONLY a valid JSON object, no markdown, no explanations, no other text.

Passage: "${passage}"

Return format (JSON object only):
{
  "overall": {
    "grammarTheme": "main grammar theme in this passage",
    "usageSummary": "concise summary in ${targetLanguage}",
    "keyStructures": ["structure1", "structure2"]
  }
}

Rules:
- Keep it short.
Important: Return ONLY the JSON object, nothing else.`,
    systemPrompt:
      "You are a multilingual English grammar coach. Always return strict JSON only and write explanations in the requested target language.",
  };
}

/**
 * @param {string} passage
 * @param {string} targetLanguage
 * @returns {{prompt: string, systemPrompt: string}}
 */
function buildExplainGrammarPassageSentencesPrompt(passage, targetLanguage) {
  return {
    prompt: `Analyze this English passage for grammar learning.
You MUST return ONLY a valid JSON object, no markdown, no explanations, no other text.

Passage: "${passage}"

Return format (JSON object only):
{
  "sentenceAnalyses": [
    {
      "sentenceText": "exact sentence from passage",
      "mainStructure": "main grammar structure",
      "usageInContext": "contextual usage in ${targetLanguage}",
      "phraseBreakdown": [
        {
          "phrase": "exact phrase from sentence",
          "structure": "phrase structure",
          "usage": "phrase usage in ${targetLanguage}"
        }
      ],
      "examples": ["example 1", "example 2"],
      "commonMistakes": ["mistake 1", "mistake 2"]
    }
  ]
}

Rules:
- Cover each meaningful sentence.
- Keep output concise and learner-friendly in ${targetLanguage}.
- phraseBreakdown is optional; include only important grammar-bearing phrases.
Important: Return ONLY the JSON object, nothing else.`,
    systemPrompt:
      "You are a multilingual English grammar coach. Always return strict JSON only and write explanations in the requested target language.",
  };
}

/**
 * @param {string} transcript
 * @param {number} count
 * @returns {{prompt: string, systemPrompt: string}}
 */
function buildGenerateQuestionsPrompt(transcript, count) {
  return {
    prompt: `Generate exactly ${count} English learning questions from this transcript.
You MUST return ONLY a valid JSON array, no markdown, no explanations, no other text.

Transcript: "${transcript}"

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

Important: Return ONLY the JSON array, nothing else.`,
    systemPrompt:
      "You are a helpful English teacher. Always return valid JSON arrays only.",
  };
}

/**
 * @param {string} word
 * @param {string} meaning
 * @param {string|undefined} context
 * @returns {{prompt: string, systemPrompt: string}}
 */
function buildEnhanceVocabularyPrompt(word, meaning, context) {
  const trimmedContext = trimContextForWord(context, word);
  const contextPart = trimmedContext ? `\n\nContext: ${trimmedContext}` : "";
  return {
    prompt: `Enhance this English vocabulary with additional information.
You MUST return ONLY a valid JSON object, no markdown, no explanations, no other text.

Word: "${word}"
Meaning: "${meaning}"${contextPart}

Return format (JSON object only):
{
  "synonyms": ["word1", "word2"],
  "antonyms": ["word3"],
  "exampleSentences": ["sentence1", "sentence2"],
  "collocations": ["collocation1", "collocation2"],
  "pronunciation": "/pronunciation/",
  "wordForm": "noun"
}

Important: Return ONLY the JSON object, nothing else.`,
    systemPrompt:
      "You are a helpful English vocabulary teacher. Always return valid JSON only.",
  };
}

/**
 * @param {string} referenceText
 * @param {string} spokenText
 * @param {string|undefined} language
 * @returns {{prompt: string}}
 */
function buildEvaluateSpeechPrompt(referenceText, spokenText, language) {
  const languagePart = language ? `\nLanguage: ${language}` : "";
  return {
    prompt: `You are a speaking coach focused on pronunciation and clarity. Compare the reference and spoken transcripts.
Return ONLY a valid JSON object with scoring and feedback. No markdown.

Reference: "${referenceText}"
Spoken: "${spokenText}"${languagePart}

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
}`,
  };
}

/**
 * @param {string} action
 * @param {Record<string, unknown>} payload
 * @returns {{prompt: string, systemPrompt?: string}}
 */
function buildPromptForAction(action, payload) {
  switch (action) {
    case "translate":
      return buildTranslatePrompt(
          String(payload.text ?? ""),
          String(payload.targetLanguage ?? "English"),
          payload.context != null ? String(payload.context) : undefined,
      );
    case "translateVocabularyBatch":
      return buildTranslateVocabularyBatchPrompt(
          /** @type {Array<{word?: string, meaning?: string, context?: string}>} */ (
            payload.vocabularyList ?? []
          ),
          String(payload.targetLanguage ?? "English"),
      );
    case "explainGrammar":
      return buildExplainGrammarPrompt(
          String(payload.sentence ?? ""),
          String(payload.targetLanguage ?? "English"),
      );
    case "explainGrammarPassageOverall":
      return buildExplainGrammarPassageOverallPrompt(
          String(payload.passage ?? ""),
          String(payload.targetLanguage ?? "English"),
      );
    case "explainGrammarPassageSentences":
      return buildExplainGrammarPassageSentencesPrompt(
          String(payload.passage ?? ""),
          String(payload.targetLanguage ?? "English"),
      );
    case "generateQuestions":
      return buildGenerateQuestionsPrompt(
          String(payload.transcript ?? ""),
          Number(payload.count ?? 5),
      );
    case "enhanceVocabulary":
      return buildEnhanceVocabularyPrompt(
          String(payload.word ?? ""),
          String(payload.meaning ?? ""),
          payload.context != null ? String(payload.context) : undefined,
      );
    case "evaluateSpeech":
      return buildEvaluateSpeechPrompt(
          String(payload.referenceText ?? ""),
          String(payload.spokenText ?? ""),
          payload.language != null ? String(payload.language) : undefined,
      );
    default:
      throw new Error(`Unknown action: ${action}`);
  }
}

module.exports = {
  buildPromptForAction,
  buildTranslatePrompt,
};
