const {callGemini} = require("./providers/gemini");
const {callOpenAI} = require("./providers/openai");
const {buildPromptForAction} = require("./prompts");
const {parseJsonObject, parseJsonArray} = require("./jsonParser");

const JSON_ARRAY_ACTIONS = new Set(["generateQuestions"]);
const JSON_OBJECT_ACTIONS = new Set([
  "translateVocabularyBatch",
  "explainGrammar",
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
    return callGemini(apiKey, model, prompt);
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
  if (action === "translate") {
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

  if (JSON_OBJECT_ACTIONS.has(action)) {
    return parseJsonObject(rawResponse);
  }

  return rawResponse.trim();
}

/**
 * @param {string} action
 * @param {Record<string, unknown>} payload
 * @param {Record<string, unknown>} config
 * @param {{openai: string, gemini: string}} keys
 * @returns {Promise<{data: unknown, provider: string}>}
 */
async function routeAiRequest(action, payload, config, keys) {
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
