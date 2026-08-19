const {callGemini} = require("./providers/gemini");
const {callOpenAI} = require("./providers/openai");
const {callAzureStt} = require("./providers/azureStt");
const {callWhisperStt} = require("./providers/whisperStt");
const {buildPromptForAction, toFlutterGrammarPassageData, preserveGrammarQuotesFromEnglish} = require("./prompts");
const {parseJsonObject, parseJsonArray} = require("./jsonParser");

const JSON_ARRAY_ACTIONS = new Set(["generateQuestions"]);
const JSON_OBJECT_ACTIONS = new Set([
  "translateVocabularyBatch",
  "explainGrammar",
  "explainGrammarPassageSingle",
  "translateGrammarPassageJson",
  "explainGrammarPassageOverall",
  "explainGrammarPassageSentences",
  "enhanceVocabulary",
  "evaluateSpeech",
]);

/**
 * @param {"gemini"|"openai"} providerName
 * @param {string} prompt
 * @param {string|undefined} systemPrompt
 * @param {{openai: string, gemini: string}} keys
 * @param {Record<string, unknown>} config
 * @returns {Promise<string>}
 */
async function invokeProvider(providerName, prompt, systemPrompt, keys, config) {
  const models = /** @type {Record<string, string>} */ (config.models ?? {});
  if (providerName === "gemini") {
    const apiKey = keys.gemini;
    if (!apiKey) throw new Error("Gemini API key not configured");
    const model = models.gemini ?? "gemini-2.5-flash";
    return callGemini(apiKey, model, prompt, systemPrompt);
  }
  if (providerName === "openai") {
    const apiKey = keys.openai;
    if (!apiKey) throw new Error("OpenAI API key not configured");
    const model = models.openai ?? "gpt-4o-mini";
    return callOpenAI(apiKey, model, prompt, systemPrompt);
  }
  throw new Error(`Unknown provider: ${providerName}`);
}

/**
 * @param {string} action
 * @param {string} rawResponse
 * @param {Record<string, unknown>} payload
 * @returns {unknown}
 */
function parseActionResponse(action, rawResponse, payload) {
  if (action === "translate" || action === "transcribeSpeech") {
    return rawResponse.trim();
  }

  if (action === "translateVocabularyBatch") {
    const jsonResponse = parseJsonObject(rawResponse);
    const vocabularyList = /** @type {Array<{word?: string}>} */ (
      payload.vocabularyList ?? []
    );
    /** @type {Record<string, string>} */
    const translations = {};
    for (const vocab of vocabularyList) {
      const word = vocab.word ?? "";
      if (Object.prototype.hasOwnProperty.call(jsonResponse, word)) {
        translations[word] = String(jsonResponse[word]);
        continue;
      }
      const wordLower = word.toLowerCase();
      let found = false;
      for (const key of Object.keys(jsonResponse)) {
        if (key.toLowerCase() === wordLower) {
          translations[word] = String(jsonResponse[key]);
          found = true;
          break;
        }
      }
      if (!found) translations[word] = word;
    }
    return translations;
  }

  if (JSON_ARRAY_ACTIONS.has(action)) {
    return parseJsonArray(rawResponse);
  }

  if (action === "explainGrammarPassageSingle") {
    const json = parseJsonObject(rawResponse);
    const passage = String(payload.passage ?? payload.sentence ?? "");
    return toFlutterGrammarPassageData(
        /** @type {Record<string, unknown>} */ (json),
        passage,
    );
  }

  if (action === "translateGrammarPassageJson") {
    const json = parseJsonObject(rawResponse);
    const englishJson = payload.englishJson && typeof payload.englishJson === "object" ?
      /** @type {Record<string, unknown>} */ (payload.englishJson) :
      {};
    const merged = preserveGrammarQuotesFromEnglish(
        englishJson,
        /** @type {Record<string, unknown>} */ (json),
    );
    const passage = String(
        englishJson.sentence ?? englishJson.passageText ?? payload.passage ?? "",
    );
    return toFlutterGrammarPassageData(merged, passage);
  }

  if (JSON_OBJECT_ACTIONS.has(action)) {
    return parseJsonObject(rawResponse);
  }

  return rawResponse.trim();
}

/**
 * @param {Record<string, unknown>} payload
 * @param {Record<string, unknown>} config
 * @param {{openai: string, gemini: string, azure: string}} keys
 * @returns {Promise<{data: string, provider: string}>}
 */
async function routeTranscribeSpeech(payload, config, keys) {
  const routes = /** @type {Record<string, string>} */ (config.routes ?? {});
  const fallback = /** @type {Record<string, string>} */ (config.fallback ?? {});

  const audioBase64 = typeof payload.audioBase64 === "string" ?
    payload.audioBase64.trim() :
    "";
  if (!audioBase64) {
    throw new Error("audioBase64 is required for transcribeSpeech");
  }

  const language = typeof payload.language === "string" ?
    payload.language.trim() :
    "en-US";
  const audioBytes = Buffer.from(audioBase64, "base64");
  const region = String(config.azureSpeechRegion ?? "southeastasia").trim();

  const primary = routes.transcribeSpeech ?? "azure";
  const fallbackProvider = fallback.transcribeSpeech;
  const providersToTry = [primary];
  if (fallbackProvider && fallbackProvider !== primary) {
    providersToTry.push(fallbackProvider);
  }

  let lastError = null;
  for (const providerName of providersToTry) {
    try {
      let transcript;
      if (providerName === "azure") {
        transcript = await callAzureStt(
            keys.azure,
            region,
            audioBytes,
            language,
        );
      } else if (providerName === "whisper") {
        transcript = await callWhisperStt(keys.openai, audioBytes, language);
      } else {
        throw new Error(`Unknown STT provider: ${providerName}`);
      }
      return {data: transcript, provider: providerName};
    } catch (err) {
      lastError = err;
    }
  }

  const message = lastError instanceof Error ? lastError.message : String(lastError);
  const code = lastError && typeof lastError === "object" && "code" in lastError ?
    String(lastError.code) :
    "STT_ERROR";
  const err = new Error(`Speech transcription failed: ${message.slice(0, 240)}`);
  err.code = code;
  throw err;
}

/**
 * @param {string} action
 * @param {Record<string, unknown>} payload
 * @param {Record<string, unknown>} config
 * @param {{openai: string, gemini: string, azure: string}} keys
 * @returns {Promise<{data: unknown, provider: string}>}
 */
async function routeAiRequest(action, payload, config, keys) {
  if (action === "transcribeSpeech") {
    return routeTranscribeSpeech(payload, config, keys);
  }

  const routes = /** @type {Record<string, string>} */ (config.routes ?? {});
  const fallback = /** @type {Record<string, string>} */ (config.fallback ?? {});

  const primary = routes[action] ?? "gemini";
  const fallbackProvider = fallback[action];

  const {prompt, systemPrompt} = buildPromptForAction(action, payload);

  const providersToTry = [primary];
  if (fallbackProvider && fallbackProvider !== primary) {
    providersToTry.push(fallbackProvider);
  }

  let lastError = null;
  for (const providerName of providersToTry) {
    try {
      const raw = await invokeProvider(
          providerName,
          prompt,
          systemPrompt,
          keys,
          config,
      );
      const data = parseActionResponse(action, raw, payload);
      return {data, provider: providerName};
    } catch (err) {
      lastError = err;
    }
  }

  const message = lastError instanceof Error ? lastError.message : String(lastError);
  const code = lastError && typeof lastError === "object" && "code" in lastError ?
    String(lastError.code) :
    "AI_ERROR";
  const err = new Error(message);
  err.code = code;
  throw err;
}

module.exports = {routeAiRequest};
