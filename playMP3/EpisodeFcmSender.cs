using System;
using System.Collections.Generic;
using System.IO;
using System.Threading;
using System.Threading.Tasks;
using FirebaseAdmin;
using FirebaseAdmin.Messaging;
using Google.Apis.Auth.OAuth2;
using Newtonsoft.Json.Linq;
using playMP3.Base;

namespace playMP3
{
    /// <summary>
    /// Gửi FCM topic "episodes" sau khi playMP3 upload episode — khớp app Flutter.
    /// Mỗi CloudService một named <see cref="FirebaseApp"/> (tên cloud, ví dụ bbc / voa / british).
    /// </summary>
    public static class EpisodeFcmSender
    {
        public const string FcmTopicNewEpisodes = "episodes";
        public const string AndroidChannelId = "bbc_episode_push";

        /// <summary>Profile id của cloud BBC. Chỉ profile này được fallback <c>GOOGLE_APPLICATION_CREDENTIALS</c>.</summary>
        public const string ProfileBbc = "bbc";

        private static readonly object InitLock = new object();
        private static readonly Dictionary<string, string> ConfiguredPaths =
            new Dictionary<string, string>(StringComparer.OrdinalIgnoreCase);

        public static bool IsProfileConfigured(string profileName)
        {
            if (string.IsNullOrWhiteSpace(profileName))
                return false;
            lock (InitLock)
                return ConfiguredPaths.ContainsKey(profileName.Trim());
        }

        /// <summary>
        /// Path trên CloudService thắng. <c>GOOGLE_APPLICATION_CREDENTIALS</c> chỉ dùng khi
        /// cloud BBC không khai báo <c>FcmServiceAccountPath</c>.
        /// </summary>
        public static string ResolveServiceAccountPath(string profileName, string serviceAccountPath)
        {
            var path = (serviceAccountPath ?? string.Empty).Trim();
            if (path.Length > 0)
                return path;

            var name = (profileName ?? string.Empty).Trim();
            if (!string.Equals(name, ProfileBbc, StringComparison.OrdinalIgnoreCase))
                return string.Empty;

            var env = Environment.GetEnvironmentVariable("GOOGLE_APPLICATION_CREDENTIALS");
            return string.IsNullOrWhiteSpace(env) ? string.Empty : env.Trim();
        }

        public static void Configure(string profileName, string serviceAccountPath)
        {
            if (string.IsNullOrWhiteSpace(profileName))
                throw new ArgumentException("profileName is required.", nameof(profileName));
            if (string.IsNullOrWhiteSpace(serviceAccountPath))
                throw new InvalidOperationException(
                    "FCM service account path is not set in service.config for profile " + profileName + ".");

            var name = profileName.Trim().ToLowerInvariant();
            var path = ResolvePath(serviceAccountPath);
            if (!File.Exists(path))
                throw new FileNotFoundException("Không thấy file service account: " + path);

            lock (InitLock)
            {
                string existingPath;
                if (ConfiguredPaths.TryGetValue(name, out existingPath))
                {
                    if (!string.Equals(existingPath, path, StringComparison.OrdinalIgnoreCase))
                    {
                        throw new InvalidOperationException(
                            "FCM \"" + name + "\" đã dùng file " + existingPath
                            + ". Khởi động lại playMP3 trước khi đổi key.");
                    }
                    return;
                }

                FirebaseApp existing = null;
                try
                {
                    existing = FirebaseApp.GetInstance(name);
                }
                catch (InvalidOperationException)
                {
                    existing = null;
                }

                if (existing != null)
                {
                    throw new InvalidOperationException(
                        "FirebaseApp \"" + name + "\" đã được tạo trước đó. Khởi động lại playMP3.");
                }

                FirebaseApp.Create(new AppOptions
                {
                    Credential = GoogleCredential.FromFile(path),
                }, name);

                ConfiguredPaths[name] = path;
            }
        }

        /// <summary>
        /// Khởi tạo FCM bằng key của cloud đang chọn. Từ chối gửi nếu <c>project_id</c>
        /// trong JSON không khớp Realtime Database vừa ghi.
        /// </summary>
        public static bool TryConfigure(
            string profileName,
            string serviceAccountPath,
            string databaseUrl,
            out string error)
        {
            error = null;
            var name = (profileName ?? string.Empty).Trim().ToLowerInvariant();
            if (name.Length == 0)
            {
                error = "Chưa chọn CloudService.";
                return false;
            }

            var path = ResolveServiceAccountPath(name, serviceAccountPath);
            if (string.IsNullOrWhiteSpace(path))
            {
                error = "CloudService \"" + name + "\" chưa có FcmServiceAccountPath.";
                return false;
            }

            string fullPath;
            try
            {
                fullPath = ResolvePath(path);
            }
            catch (Exception ex)
            {
                error = ex.Message;
                return false;
            }

            if (!File.Exists(fullPath))
            {
                error = "Không thấy file service account: " + fullPath;
                return false;
            }

            string projectId;
            try
            {
                projectId = ReadProjectId(fullPath);
            }
            catch (Exception ex)
            {
                error = "Không đọc được project_id trong " + Path.GetFileName(fullPath) + ": " + ex.Message;
                return false;
            }

            if (string.IsNullOrWhiteSpace(projectId))
            {
                error = "File service account không có project_id: " + fullPath;
                return false;
            }

            string databaseHost;
            if (!ServiceAccountMatchesDatabase(projectId, databaseUrl, out databaseHost))
            {
                error = "Key FCM thuộc project \"" + projectId.Trim()
                    + "\" nhưng Realtime Database đang ghi là \"" + (databaseHost ?? databaseUrl)
                    + "\". Không gửi để tránh push nhầm app.";
                return false;
            }

            try
            {
                Configure(name, fullPath);
                return true;
            }
            catch (Exception ex)
            {
                error = ex.Message;
                return false;
            }
        }

        public static async Task<string> SendNewEpisodeAsync(
            string profileName,
            Episode episode,
            string episodeKey,
            CancellationToken cancellationToken = default(CancellationToken))
        {
            var name = (profileName ?? "").Trim().ToLowerInvariant();
            if (name.Length == 0)
                throw new ArgumentException("profileName is required.", nameof(profileName));

            if (!IsProfileConfigured(name))
                throw new InvalidOperationException(
                    "FCM not configured for profile \"" + name + "\". "
                    + "Set FcmServiceAccountPath on the selected CloudService in service.config.");

            if (episode == null)
                throw new ArgumentNullException(nameof(episode));
            if (string.IsNullOrWhiteSpace(episodeKey))
                throw new ArgumentException("episodeKey is required.", nameof(episodeKey));

            var episodeName = (episode.EpisodeName ?? "New episode").Trim();
            if (episodeName.Length > 120)
                episodeName = episodeName.Substring(0, 120);

            var category = episode.Category ?? string.Empty;
            var year = episode.Year ?? string.Empty;

            var message = new Message
            {
                Topic = FcmTopicNewEpisodes,
                Notification = new Notification
                {
                    Title = "Learning English — new episode",
                    Body = string.Format("{0} ({1} · {2})", episodeName, category, year),
                },
                Data = new Dictionary<string, string>
                {
                    ["category"] = category,
                    ["year"] = year,
                    ["episodeKey"] = episodeKey,
                    ["episodeId"] = episode.Id.ToString(),
                    ["rtdbPath"] = episode.RtdbPath ?? string.Empty,
                    ["click_action"] = "FLUTTER_NOTIFICATION_CLICK",
                },
                Android = new AndroidConfig
                {
                    Priority = Priority.High,
                    Notification = new AndroidNotification
                    {
                        ChannelId = AndroidChannelId,
                        Sound = "default",
                    },
                },
                Apns = new ApnsConfig
                {
                    Headers = new Dictionary<string, string>
                    {
                        { "apns-priority", "10" },
                    },
                    Aps = new Aps
                    {
                        Sound = "default",
                        Badge = 1,
                    },
                },
            };

            var app = FirebaseApp.GetInstance(name);
            return await FirebaseMessaging.GetMessaging(app)
                .SendAsync(message, cancellationToken)
                .ConfigureAwait(false);
        }

        private static string ResolvePath(string path)
        {
            if (Path.IsPathRooted(path))
                return path;

            var baseDir = AppDomain.CurrentDomain.BaseDirectory ?? string.Empty;
            return Path.GetFullPath(Path.Combine(baseDir, path));
        }

        private static string ReadProjectId(string serviceAccountPath)
        {
            var json = JObject.Parse(File.ReadAllText(serviceAccountPath));
            return (json["project_id"] ?? string.Empty).ToString().Trim();
        }

        /// <summary>
        /// Khớp <c>project_id</c> với host RTDB:
        /// <c>{id}.firebaseio.com</c> hoặc <c>{id}-default-rtdb.firebaseio.com</c>
        /// (và dạng <c>firebasedatabase.app</c>).
        /// </summary>
        internal static bool ServiceAccountMatchesDatabase(string projectId, string databaseUrl, out string databaseHost)
        {
            databaseHost = null;
            var id = (projectId ?? string.Empty).Trim();
            var raw = (databaseUrl ?? string.Empty).Trim();
            if (id.Length == 0 || raw.Length == 0)
                return false;

            if (raw.IndexOf("://", StringComparison.Ordinal) < 0)
                raw = "https://" + raw;

            Uri uri;
            if (!Uri.TryCreate(raw, UriKind.Absolute, out uri) || string.IsNullOrWhiteSpace(uri.Host))
                return false;

            databaseHost = uri.Host;
            var host = uri.Host;
            if (host.Equals(id + ".firebaseio.com", StringComparison.OrdinalIgnoreCase)
                || host.Equals(id + ".firebasedatabase.app", StringComparison.OrdinalIgnoreCase))
                return true;

            if (host.EndsWith(".firebasedatabase.app", StringComparison.OrdinalIgnoreCase)
                && host.StartsWith(id + ".", StringComparison.OrdinalIgnoreCase))
                return true;

            if (host.StartsWith(id + "-default-rtdb.", StringComparison.OrdinalIgnoreCase)
                && (host.EndsWith(".firebaseio.com", StringComparison.OrdinalIgnoreCase)
                    || host.EndsWith(".firebasedatabase.app", StringComparison.OrdinalIgnoreCase)))
                return true;

            return false;
        }
    }
}
