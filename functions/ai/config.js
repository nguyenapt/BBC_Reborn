const {defineSecret} = require("firebase-functions/params");
const admin = require("firebase-admin");

const openaiKeySecret = defineSecret("AI_OPENAI_API_KEY");
const geminiKeySecret = defineSecret("AI_GEMINI_API_KEY");
const azureSpeechKeySecret = defineSecret("AI_AZURE_SPEECH_KEY");

const AI_SECRETS = [openaiKeySecret, geminiKeySecret, azureSpeechKeySecret];

/** @type {Record<string, unknown>|null} */
let cachedServerConfig = null;
/** @type {number} */
let configLoadedAt = 0;
const CONFIG_TTL_MS = 60_000;

/** Cached API keys per function instance (cold start read once). */
let cachedOpenaiKey = null;
let cachedGeminiKey = null;
let cachedAzureSpeechKey = null;

const DEFAULT_SERVER_CONFIG = {
  allowedPackages:
    "com.voalearningenglish.listeningskills;com.learningenglish.studyingbbc.bbc_reborn;com.bbclearningenglish.listeningskills;com.learning.esllearning;com.learning.eslenglish",
  enabled: true,
  azureSpeechRegion: "southeastasia",
  routes: {
    translate: "gemini",
    translateVocabularyBatch: "gemini",
    explainGrammar: "gemini",
    explainGrammarPassageSingle: "gemini",
    explainGrammarPassageOverall: "gemini",
    explainGrammarPassageSentences: "gemini",
    enhanceVocabulary: "gemini",
    generateQuestions: "gemini",
    evaluateSpeech: "openai",
    transcribeSpeech: "azure",
  },
  fallback: {
    translate: "openai",
    translateVocabularyBatch: "openai",
    explainGrammar: "openai",
    explainGrammarPassageSingle: "openai",
    enhanceVocabulary: "openai",
    generateQuestions: "openai",
    evaluateSpeech: "gemini",
    transcribeSpeech: "whisper",
  },
  models: {
    gemini: "gemini-2.5-flash",
    openai: "gpt-4o-mini",
  },
  grammarPromptVersion: "v2_detailed_learning_no_quiz",
  rateLimitPerMinute: 30,
};

const ALLOWED_ACTIONS = new Set([
  "translate",
  "translateVocabularyBatch",
  "explainGrammar",
  "explainGrammarPassageSingle",
  "explainGrammarPassageOverall",
  "explainGrammarPassageSentences",
  "enhanceVocabulary",
  "generateQuestions",
  "evaluateSpeech",
  "transcribeSpeech",
]);

function ensureAdmin() {
  if (admin.apps.length === 0) {
    admin.initializeApp();
  }
}

/**
 * @returns {Promise<Record<string, unknown>>}
 */
/**
 * Deep-merge RTDB config so partial `routes` / `fallback` updates do not drop defaults.
 * @param {Record<string, unknown>} val
 * @returns {Record<string, unknown>}
 */
function mergeServerConfig(val) {
  const defaults = DEFAULT_SERVER_CONFIG;
  if (!val || typeof val !== "object") {
    return {...defaults};
  }
  return {
    ...defaults,
    ...val,
    routes: {
      ...defaults.routes,
      ...(val.routes && typeof val.routes === "object" ? val.routes : {}),
    },
    fallback: {
      ...defaults.fallback,
      ...(val.fallback && typeof val.fallback === "object" ? val.fallback : {}),
    },
    models: {
      ...defaults.models,
      ...(val.models && typeof val.models === "object" ? val.models : {}),
    },
  };
}

async function loadServerConfig() {
  const now = Date.now();
  if (cachedServerConfig && now - configLoadedAt < CONFIG_TTL_MS) {
    return cachedServerConfig;
  }

  ensureAdmin();
  try {
    const snap = await admin.database().ref("ai_server_config").once("value");
    const val = snap.val();
    cachedServerConfig = mergeServerConfig(val);
  } catch {
    cachedServerConfig = mergeServerConfig(null);
  }
  configLoadedAt = now;
  return cachedServerConfig;
}

/**
 * @param {string} packageName
 * @param {Record<string, unknown>} config
 * @returns {boolean}
 */
function isPackageAllowed(packageName, config) {
  const normalized = String(packageName ?? "").trim();
  if (!normalized) return false;
  const raw = String(config.allowedPackages ?? "");
  const packages = raw.split(";").map((p) => p.trim()).filter(Boolean);
  return packages.includes(normalized);
}

/**
 * @returns {{openai: string, gemini: string, azure: string}}
 */
function getApiKeys() {
  if (!cachedOpenaiKey) {
    cachedOpenaiKey = openaiKeySecret.value();
  }
  if (!cachedGeminiKey) {
    cachedGeminiKey = geminiKeySecret.value();
  }
  if (!cachedAzureSpeechKey) {
    cachedAzureSpeechKey = azureSpeechKeySecret.value();
  }
  return {
    openai: cachedOpenaiKey ? String(cachedOpenaiKey).trim() : "",
    gemini: cachedGeminiKey ? String(cachedGeminiKey).trim() : "",
    azure: cachedAzureSpeechKey ? String(cachedAzureSpeechKey).trim() : "",
  };
}

/** In-memory rate limit: packageName -> timestamps[] */
const rateLimitBuckets = new Map();

/**
 * @param {string} packageName
 * @param {Record<string, unknown>} config
 * @returns {boolean}
 */
function checkRateLimit(packageName, config) {
  const limit = Number(config.rateLimitPerMinute ?? 30);
  const now = Date.now();
  const windowStart = now - 60_000;

  let bucket = rateLimitBuckets.get(packageName) ?? [];
  bucket = bucket.filter((t) => t > windowStart);

  if (bucket.length >= limit) {
    return false;
  }

  bucket.push(now);
  rateLimitBuckets.set(packageName, bucket);
  return true;
}

module.exports = {
  AI_SECRETS,
  openaiKeySecret,
  geminiKeySecret,
  azureSpeechKeySecret,
  ALLOWED_ACTIONS,
  DEFAULT_SERVER_CONFIG,
  loadServerConfig,
  isPackageAllowed,
  getApiKeys,
  checkRateLimit,
};
