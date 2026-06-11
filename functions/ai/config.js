const {defineSecret} = require("firebase-functions/params");
const admin = require("firebase-admin");

const openaiKeySecret = defineSecret("AI_OPENAI_API_KEY");
const geminiKeySecret = defineSecret("AI_GEMINI_API_KEY");

const AI_SECRETS = [openaiKeySecret, geminiKeySecret];

/** @type {Record<string, unknown>|null} */
let cachedServerConfig = null;
/** @type {number} */
let configLoadedAt = 0;
const CONFIG_TTL_MS = 60_000;

/** Cached API keys per function instance (cold start read once). */
let cachedOpenaiKey = null;
let cachedGeminiKey = null;

const DEFAULT_SERVER_CONFIG = {
  allowedPackages:
    "com.learningenglish.studyingbbc.bbc_reborn;com.bbclearningenglish.listeningskills",
  enabled: true,
  routes: {
    translate: "gemini",
    translateVocabularyBatch: "gemini",
    explainGrammar: "gemini",
    explainGrammarPassageOverall: "gemini",
    explainGrammarPassageSentences: "gemini",
    enhanceVocabulary: "gemini",
    generateQuestions: "gemini",
    evaluateSpeech: "openai",
  },
  fallback: {
    translate: "openai",
    explainGrammar: "openai",
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
  "explainGrammarPassageOverall",
  "explainGrammarPassageSentences",
  "enhanceVocabulary",
  "generateQuestions",
  "evaluateSpeech",
]);

function ensureAdmin() {
  if (admin.apps.length === 0) {
    admin.initializeApp();
  }
}

/**
 * @returns {Promise<Record<string, unknown>>}
 */
async function loadServerConfig() {
  const now = Date.now();
  if (cachedServerConfig && now - configLoadedAt < CONFIG_TTL_MS) {
    return cachedServerConfig;
  }

  ensureAdmin();
  try {
    const snap = await admin.database().ref("ai_server_config").once("value");
    const val = snap.val();
    cachedServerConfig = val && typeof val === "object" ?
      {...DEFAULT_SERVER_CONFIG, ...val} :
      {...DEFAULT_SERVER_CONFIG};
  } catch {
    cachedServerConfig = {...DEFAULT_SERVER_CONFIG};
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
  const raw = String(config.allowedPackages ?? "");
  const packages = raw.split(";").map((p) => p.trim()).filter(Boolean);
  return packages.includes(packageName);
}

/**
 * @returns {{openai: string, gemini: string}}
 */
function getApiKeys() {
  if (!cachedOpenaiKey) {
    cachedOpenaiKey = openaiKeySecret.value();
  }
  if (!cachedGeminiKey) {
    cachedGeminiKey = geminiKeySecret.value();
  }
  return {
    openai: cachedOpenaiKey ? String(cachedOpenaiKey).trim() : "",
    gemini: cachedGeminiKey ? String(cachedGeminiKey).trim() : "",
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
  ALLOWED_ACTIONS,
  DEFAULT_SERVER_CONFIG,
  loadServerConfig,
  isPackageAllowed,
  getApiKeys,
  checkRateLimit,
};
