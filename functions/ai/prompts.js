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
 * Single-shot passage prompt (overall + sentenceAnalyses) — aligned with playMP3 BuildPassagePrompt.
 * @param {string} passage
 * @param {string} targetLanguage
 * @returns {{prompt: string, systemPrompt: string}}
 */
function buildExplainGrammarPassageSinglePrompt(passage, targetLanguage) {
  return {
    prompt: `Analyze this English passage for grammar learning.
You MUST return ONLY a valid JSON object, no markdown, no explanations, no other text.

Passage: "${passage}"

Return format (JSON object only, slim):
{
  "overall": {
    "grammarTheme": "main grammar theme in this passage",
    "usageSummary": "concise summary in ${targetLanguage}",
    "keyStructures": ["structure1", "structure2"]
  },
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
- Keep output concise and learner-friendly in ${targetLanguage}.
- phraseBreakdown is optional; include only important grammar-bearing phrases.
- Cover each meaningful sentence (a single-line passage may have one analysis).
Important: Return ONLY the JSON object, nothing else.`,
    systemPrompt:
      "You are a multilingual English grammar coach. Always return strict JSON only and write explanations in the requested target language.",
  };
}

/**
 * Translate learner-facing grammar JSON fields from English canonical JSON.
 * @param {Record<string, unknown>} englishJson
 * @param {string} targetLanguage
 * @returns {{prompt: string, systemPrompt: string}}
 */
function buildTranslateGrammarPassageJsonPrompt(englishJson, targetLanguage) {
  const json = JSON.stringify(englishJson ?? {});
  return {
    prompt: `Translate the LEARNER-FACING fields of this English grammar JSON into ${targetLanguage}.
You MUST return ONLY a valid JSON object with the SAME schema and the SAME array lengths.

KEEP these fields EXACTLY as in the input (English quotes from the transcript):
- sentence, passageText, sentenceText
- highlightedWords (array of exact fragments)
- phrase (inside each phraseBreakdown item)
- examples (keep English example sentences)

TRANSLATE into ${targetLanguage}:
- grammarPoint, explanation, whyThisForm, rulePattern
- overall.grammarTheme, overall.usageSummary, overall.keyStructures
- mainStructure, usageInContext, structure, usage
- commonMistakes, rewriteExercise

Do not add or remove sentenceAnalyses or phraseBreakdown items.
Do not invent new quotes from the transcript.

English JSON:
${json}

JSON object only:`,
    systemPrompt:
      "You translate English grammar-teaching JSON into another language. Return strict JSON only. Never change transcript quotes or English examples.",
  };
}

/**
 * Copy transcript quotes from canonical English JSON onto a translation.
 * @param {Record<string, unknown>} english
 * @param {Record<string, unknown>} translated
 * @returns {Record<string, unknown>}
 */
function preserveGrammarQuotesFromEnglish(english, translated) {
  const src = english && typeof english === "object" ? english : {};
  const result = {
    ...(translated && typeof translated === "object" ? translated : {}),
  };
  for (const key of ["sentence", "passageText", "highlightedWords"]) {
    if (src[key] !== undefined) result[key] = src[key];
  }

  const enAnalyses = Array.isArray(src.sentenceAnalyses) ? src.sentenceAnalyses : null;
  if (!enAnalyses) return result;

  const trAnalyses = Array.isArray(result.sentenceAnalyses) ?
    [...result.sentenceAnalyses] :
    [];
  while (trAnalyses.length < enAnalyses.length) {
    trAnalyses.push(enAnalyses[trAnalyses.length]);
  }
  if (trAnalyses.length > enAnalyses.length) {
    trAnalyses.length = enAnalyses.length;
  }

  for (let i = 0; i < enAnalyses.length; i++) {
    const enA = enAnalyses[i] && typeof enAnalyses[i] === "object" &&
      !Array.isArray(enAnalyses[i]) ?
      /** @type {Record<string, unknown>} */ (enAnalyses[i]) :
      null;
    if (!enA) continue;
    const trItem = trAnalyses[i] && typeof trAnalyses[i] === "object" &&
      !Array.isArray(trAnalyses[i]) ?
      /** @type {Record<string, unknown>} */ (trAnalyses[i]) :
      {};
    const trA = {...trItem};
    if (enA.sentenceText !== undefined) trA.sentenceText = enA.sentenceText;
    if (enA.examples !== undefined) trA.examples = enA.examples;
    const enPhrases = Array.isArray(enA.phraseBreakdown) ? enA.phraseBreakdown : null;
    if (enPhrases) {
      const trPhrases = Array.isArray(trA.phraseBreakdown) ?
        [...trA.phraseBreakdown] :
        [];
      while (trPhrases.length < enPhrases.length) {
        trPhrases.push(enPhrases[trPhrases.length]);
      }
      if (trPhrases.length > enPhrases.length) {
        trPhrases.length = enPhrases.length;
      }
      for (let j = 0; j < enPhrases.length; j++) {
        const enPh = enPhrases[j] && typeof enPhrases[j] === "object" &&
          !Array.isArray(enPhrases[j]) ?
          /** @type {Record<string, unknown>} */ (enPhrases[j]) :
          null;
        if (!enPh) continue;
        const trPhItem = trPhrases[j] && typeof trPhrases[j] === "object" &&
          !Array.isArray(trPhrases[j]) ?
          /** @type {Record<string, unknown>} */ (trPhrases[j]) :
          {};
        trPhrases[j] = {...trPhItem, phrase: enPh.phrase};
      }
      trA.phraseBreakdown = trPhrases;
    }
    trAnalyses[i] = trA;
  }
  result.sentenceAnalyses = trAnalyses;
  return result;
}

/**
 * Dual-map for Flutter / old apps — matches playMP3 ToFlutterGrammarPassageData.
 * Keeps overall + sentenceAnalyses and synthesizes grammarPoint/explanation (non-empty).
 * @param {Record<string, unknown>} apiResponse
 * @param {string} passage
 * @returns {Record<string, unknown>}
 */
function toFlutterGrammarPassageData(apiResponse, passage) {
  const src = apiResponse && typeof apiResponse === "object" ? apiResponse : {};
  const overallSrc =
    src.overall && typeof src.overall === "object" && !Array.isArray(src.overall) ?
      /** @type {Record<string, unknown>} */ (src.overall) :
      {};
  /** @type {Record<string, unknown>} */
  const overall = {...overallSrc};
  const analyses = Array.isArray(src.sentenceAnalyses) ? src.sentenceAnalyses : [];

  let theme = String(overall.grammarTheme ?? "").trim();
  if (!theme) theme = "Grammar Overview";
  let usage = String(overall.usageSummary ?? "").trim();
  if (!usage) usage = theme; // old apps require non-empty explanation
  overall.grammarTheme = theme;
  overall.usageSummary = usage;
  if (!Array.isArray(overall.keyStructures)) {
    overall.keyStructures = [];
  }

  const first =
    analyses.length > 0 && analyses[0] && typeof analyses[0] === "object" ?
      /** @type {Record<string, unknown>} */ (analyses[0]) :
      null;
  /** @type {string[]} */
  const highlighted = [];
  /** @type {string[]} */
  const commonMistakes = [];
  if (first) {
    const phrases = Array.isArray(first.phraseBreakdown) ? first.phraseBreakdown : [];
    for (const p of phrases) {
      if (!p || typeof p !== "object") continue;
      const phrase = String(
          /** @type {Record<string, unknown>} */ (p).phrase ?? "",
      ).trim();
      if (phrase) highlighted.push(phrase);
    }
    const mistakes = Array.isArray(first.commonMistakes) ? first.commonMistakes : [];
    for (const m of mistakes) {
      const s = String(m ?? "").trim();
      if (s) commonMistakes.push(s);
    }
  }

  return {
    sentence: passage ?? "",
    passageText: passage ?? "",
    grammarPoint: theme,
    explanation: usage,
    highlightedWords: highlighted,
    overall,
    sentenceAnalyses: analyses,
    rulePattern: first ? String(first.mainStructure ?? "") : "",
    whyThisForm: first ? String(first.usageInContext ?? "") : "",
    commonMistakes,
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
  "synonymDetails": [{"word": "word1", "meaning": "short gloss"}],
  "antonymDetails": [{"word": "word3", "meaning": "short gloss"}],
  "collocationDetails": [{"word": "collocation1", "meaning": "short gloss"}],
  "pronunciation": "/pronunciation/",
  "wordForm": "noun"
}

Rules:
- Keep synonyms/antonyms/collocations as plain string arrays (legacy).
- Always also fill *Details with the same terms plus a concise English meaning/gloss.
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
    case "explainGrammarPassageSingle": {
      const passageText = String(
          payload.passage ?? payload.sentence ?? "",
      );
      return buildExplainGrammarPassageSinglePrompt(
          passageText,
          String(payload.targetLanguage ?? "English"),
      );
    }
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
    case "translateGrammarPassageJson": {
      const englishJson = payload.englishJson && typeof payload.englishJson === "object" ?
        /** @type {Record<string, unknown>} */ (payload.englishJson) :
        {};
      return buildTranslateGrammarPassageJsonPrompt(
          englishJson,
          String(payload.targetLanguage ?? "English"),
      );
    }
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
  toFlutterGrammarPassageData,
  preserveGrammarQuotesFromEnglish,
};
