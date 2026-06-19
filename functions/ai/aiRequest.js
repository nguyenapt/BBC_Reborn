const {onCall, HttpsError} = require("firebase-functions/v2/https");
const {
  AI_SECRETS,
  ALLOWED_ACTIONS,
  loadServerConfig,
  isPackageAllowed,
  getApiKeys,
  checkRateLimit,
} = require("./config");
const {routeAiRequest} = require("./router");

/** firebase-functions/logger có thể undefined trên một số bản deploy → dùng console. */
function logWarn(msg) {
  try {
    const {logger} = require("firebase-functions/logger");
    if (logger && typeof logger.warn === "function") {
      logger.warn(msg);
      return;
    }
  } catch (_) { /* ignore */ }
  console.warn(msg);
}

function logError(msg) {
  try {
    const {logger} = require("firebase-functions/logger");
    if (logger && typeof logger.error === "function") {
      logger.error(msg);
      return;
    }
  } catch (_) { /* ignore */ }
  console.error(msg);
}

/**
 * Callable AI proxy — keys from Secret Manager, routing from RTDB ai_server_config.
 */
const aiRequest = onCall(
    {
      region: "us-central1",
      secrets: AI_SECRETS,
      enforceAppCheck: true,
      timeoutSeconds: 120,
      memory: "512MiB",
    },
    async (request) => {
      const body = request.data ?? {};
      const packageName = typeof body.packageName === "string" ?
        body.packageName.trim() :
        "";
      const action = typeof body.action === "string" ? body.action.trim() : "";
      const payload = body.payload && typeof body.payload === "object" ?
        body.payload :
        {};

      if (!packageName) {
        throw new HttpsError("invalid-argument", "packageName is required");
      }
      if (!action || !ALLOWED_ACTIONS.has(action)) {
        throw new HttpsError("invalid-argument", `Invalid action: ${action}`);
      }

      const config = await loadServerConfig();

      if (config.enabled === false) {
        throw new HttpsError("failed-precondition", "AI proxy is disabled");
      }

      if (!isPackageAllowed(packageName, config)) {
        logWarn(`Package not allowed package=${packageName} action=${action}`);
        throw new HttpsError("permission-denied", "Package not allowed");
      }

      if (!checkRateLimit(packageName, config)) {
        throw new HttpsError("resource-exhausted", "Rate limit exceeded");
      }

      const keys = getApiKeys();

      try {
        const {data, provider} = await routeAiRequest(action, payload, config, keys);
        return {
          success: true,
          action,
          provider,
          data,
        };
      } catch (err) {
        const message = err instanceof Error ? err.message : String(err);
        const code = err && typeof err === "object" && "code" in err ?
          String(err.code) :
          "AI_ERROR";
        logError(
            `AI request failed action=${action} package=${packageName} ` +
            `code=${code} message=${message}`,
        );

        if (code === "RATE_LIMIT") {
          throw new HttpsError("resource-exhausted", message);
        }
        throw new HttpsError("internal", message);
      }
    },
);

module.exports = {aiRequest};
