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

/**
 * Các category có cấu trúc {cat}/{year}/{index} (như 6M/2026/0) — khớp getCategoryData trong app.
 * Không dùng HomePage/* vì thường là cập nhật nguyên list → ít khi chỉ onCreate từng tập.
 */
const EPISODE_CATEGORIES = new Set(["6M", "TEWS", "REE","EG"]);

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
 * DISABLED: FCM is sent directly from playMP3 (EpisodeFcmSender.cs) after RTDB upload.
 * Keeping handler commented to avoid double notifications if this file is redeployed.
 *
 * Khi thêm node mới tại <category>/<year>/<episodeKey> (vd: 6M/2026/8), gửi FCM tới topic "episodes".
 */
/*
exports.onEpisodeCreated = onValueCreated(
  {
    ref: "{category}/{year}/{episodeKey}",
    region: "us-central1",
  },
  async (event) => {
    const category = event.params.category;
    const year = event.params.year;
    const episodeKey = event.params.episodeKey;

    if (!EPISODE_CATEGORIES.has(category)) {
      return null;
    }

    const snapshot = event.data;
    if (!snapshot) {
      return null;
    }

    const val = snapshot.val();
    if (val == null || typeof val !== "object") {
      return null;
    }

    const episodeName =
      val.EpisodeName || val.episodeName || val.Title || val.title || "New episode";
    const safeName = String(episodeName).slice(0, 120);
    const idFromDoc = val.Id != null ? String(val.Id) : String(episodeKey);

    const payload = {
      topic: FCM_TOPIC,
      notification: {
        title: "6 Mins Learning English Online — new episode",
        body: `${safeName} (${category} · ${year})`,
      },
      data: {
        category: String(category),
        year: String(year),
        episodeKey: String(episodeKey),
        episodeId: idFromDoc,
        click_action: "FLUTTER_NOTIFICATION_CLICK",
      },
      android: {
        priority: "high",
        notification: {
          channelId: "bbc_episode_push",
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
        year,
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
  },
);
*/

exports.aiRequest = aiRequest;
