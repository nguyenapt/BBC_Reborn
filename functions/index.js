const {onValueCreated} = require("firebase-functions/v2/database");
const {logger} = require("firebase-functions/logger");
const admin = require("firebase-admin");
const {aiRequest} = require("./ai/aiRequest");

/** Gọi trong handler, không gọi khi nạp file — tránh timeout khi CLI deploy phân tích code trên Windows. */
function ensureAdmin() {
  if (admin.apps.length === 0) {
    admin.initializeApp();
  }
}

/** Trùng với lib/services/push_notification_service.dart — fcmTopicNewEpisodes */
const FCM_TOPIC = "episodes";

const NOTIFICATION_TITLE = "VOA Learning English — new episode";
const ANDROID_CHANNEL_ID = "voa_episode_push";

/** Root nodes that must never trigger episode push. */
const IGNORED_ROOT_CATEGORIES = new Set([
  "HomePage",
  "List",
  "ai_cache",
  "ai_server_config",
]);

/**
 * BBC-style categories: {cat}/{year}/{index} (6M/2026/0).
 * Kept for legacy data if present on RTDB.
 */
const EPISODE_CATEGORIES_WITH_YEAR = new Set(["6M", "TEWS", "REE", "EG"]);

/** VOA primary tabs: {cat}/{index} (AMS/5). */
const EPISODE_CATEGORIES_FLAT = new Set(["AMS", "ON", "NC", "SC"]);

/**
 * Ghi log lỗi an toàn — tránh truyền Error thẳng vào logger (có thể gây TypeError trong firebase-functions/logger).
 * @param {unknown} err
 * @returns {{ message: string, code?: string, stack?: string }}
 */
function serializeErrorForLog(err) {
  if (err == null) {
    return {message: "unknown_error"};
  }
  if (typeof err === "string") {
    return {message: err};
  }
  if (err instanceof Error) {
    return {
      message: err.message,
      code: err.code,
      stack: err.stack,
    };
  }
  if (typeof err !== "object") {
    return {message: String(err)};
  }
  const msg = typeof err.message === "string" ? err.message : String(err);
  const code = err.code || err.errorInfo?.code || err.status;
  return {
    message: msg,
    ...(code != null ? {code: String(code)} : {}),
    ...(typeof err.stack === "string" ? {stack: err.stack} : {}),
  };
}

/** Tránh throw khi err là object lạ / vòng tham chiếu. */
function safeSerializeErrorForLog(err) {
  try {
    return serializeErrorForLog(err);
  } catch {
    return {message: String(err)};
  }
}

/**
 * @param {string} category
 * @param {string|undefined|null} year
 * @param {string} episodeKey
 * @param {unknown} val
 * @returns {Promise<null>}
 */
async function handleEpisodeCreated(category, year, episodeKey, val) {
  if (IGNORED_ROOT_CATEGORIES.has(category)) {
    return null;
  }

  const hasYear = year != null && String(year).trim() !== "";
  const allowed = hasYear ?
    EPISODE_CATEGORIES_WITH_YEAR.has(category) :
    EPISODE_CATEGORIES_FLAT.has(category);

  if (!allowed) {
    return null;
  }

  if (val == null || typeof val !== "object") {
    return null;
  }

  const episodeName =
    val.EpisodeName || val.episodeName || val.Title || val.title || "New episode";
  const safeName = String(episodeName).slice(0, 120);
  const idFromDoc = val.Id != null ? String(val.Id) : String(episodeKey);
  const yearLabel = hasYear ? String(year) : "";
  const bodySuffix = hasYear ?
    `${category} · ${yearLabel}` :
    category;

  const payload = {
    topic: FCM_TOPIC,
    notification: {
      title: NOTIFICATION_TITLE,
      body: `${safeName} (${bodySuffix})`,
    },
    data: {
      category: String(category),
      year: yearLabel,
      episodeKey: String(episodeKey),
      episodeId: idFromDoc,
      click_action: "FLUTTER_NOTIFICATION_CLICK",
    },
    android: {
      priority: "high",
      notification: {
        channelId: ANDROID_CHANNEL_ID,
        sound: "default",
      },
    },
    apns: {
      payload: {
        aps: {
          sound: "default",
          badge: 1,
        },
      },
    },
  };

  try {
    ensureAdmin();
    const messageId = await admin.messaging().send(payload);
    logger.info("FCM sent for new episode", {
      category,
      year: yearLabel || undefined,
      episodeKey,
      messageId,
    });
  } catch (e) {
    const details = safeSerializeErrorForLog(e);
    let line;
    try {
      line = `FCM send failed: ${JSON.stringify(details)}`;
    } catch {
      line = `FCM send failed: ${details.message || "unknown"}`;
    }
    logger.error(line);
    console.error(line);
  }
  return null;
}

/**
 * BBC-style / year-based: {category}/{year}/{episodeKey} (vd: 6M/2026/8).
 */
exports.onEpisodeCreatedWithYear = onValueCreated(
  {
    ref: "{category}/{year}/{episodeKey}",
    region: "us-central1",
  },
  async (event) => {
    const snapshot = event.data;
    if (!snapshot) {
      return null;
    }
    return handleEpisodeCreated(
      event.params.category,
      event.params.year,
      event.params.episodeKey,
      snapshot.val(),
    );
  },
);

/**
 * VOA primary tabs: {category}/{episodeKey} (vd: AMS/5).
 */
exports.onEpisodeCreatedFlat = onValueCreated(
  {
    ref: "{category}/{episodeKey}",
    region: "us-central1",
  },
  async (event) => {
    const snapshot = event.data;
    if (!snapshot) {
      return null;
    }
    return handleEpisodeCreated(
      event.params.category,
      null,
      event.params.episodeKey,
      snapshot.val(),
    );
  },
);

exports.aiRequest = aiRequest;
