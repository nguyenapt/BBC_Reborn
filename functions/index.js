const {onValueCreated} = require("firebase-functions/v2/database");
const {logger} = require("firebase-functions/logger");
const admin = require("firebase-admin");

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
const EPISODE_CATEGORIES = new Set(["6M", "TEWS", "REE"]);

/**
 * Khi thêm node mới tại <category>/<year>/<episodeKey> (vd: 6M/2026/8), gửi FCM tới topic "episodes".
 */
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
        title: "BBC Learning English — new episode",
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
      await admin.messaging().send(payload);
      logger.info("FCM sent for new episode", {category, year, episodeKey});
    } catch (e) {
      logger.error("FCM send failed", e);
    }
    return null;
  },
);
