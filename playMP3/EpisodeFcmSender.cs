using System;
using System.Collections.Generic;
using System.IO;
using System.Threading;
using System.Threading.Tasks;
using FirebaseAdmin;
using FirebaseAdmin.Messaging;
using Google.Apis.Auth.OAuth2;
using playMP3.Base;

namespace playMP3
{
    /// <summary>
    /// Gửi FCM topic "episodes" sau khi playMP3 upload episode — khớp app Flutter.
    /// Hỗ trợ nhiều Firebase project (BBC / VOA) qua named <see cref="FirebaseApp"/>.
    /// </summary>
    public static class EpisodeFcmSender
    {
        public const string FcmTopicNewEpisodes = "episodes";
        public const string AndroidChannelId = "bbc_episode_push";

        public const string ProfileBbc = "bbc";
        public const string ProfileVoa = "voa";
        public const string ProfileBritish = "british";

        private static readonly object InitLock = new object();
        private static readonly HashSet<string> ConfiguredProfiles =
            new HashSet<string>(StringComparer.OrdinalIgnoreCase);

        public static bool IsProfileConfigured(string profileName)
        {
            if (string.IsNullOrWhiteSpace(profileName))
                return false;
            lock (InitLock)
                return ConfiguredProfiles.Contains(profileName.Trim());
        }

        public static void Configure(string profileName, string serviceAccountPath)
        {
            if (string.IsNullOrWhiteSpace(profileName))
                throw new ArgumentException("profileName is required.", nameof(profileName));
            if (string.IsNullOrWhiteSpace(serviceAccountPath))
                throw new InvalidOperationException(
                    "FCM service account path is not set in service.config for profile " + profileName + ".");

            var name = profileName.Trim();
            var path = ResolvePath(serviceAccountPath);
            if (!File.Exists(path))
                throw new FileNotFoundException("FCM service account not found: " + path);

            lock (InitLock)
            {
                if (ConfiguredProfiles.Contains(name))
                    return;

                FirebaseApp existing = null;
                try
                {
                    existing = FirebaseApp.GetInstance(name);
                }
                catch (InvalidOperationException)
                {
                    existing = null;
                }

                if (existing == null)
                {
                    FirebaseApp.Create(new AppOptions
                    {
                        Credential = GoogleCredential.FromFile(path),
                    }, name);
                }

                ConfiguredProfiles.Add(name);
            }
        }

        /// <summary>
        /// Configure FCM for a profile. Env <c>GOOGLE_APPLICATION_CREDENTIALS</c> is only used for BBC.
        /// </summary>
        public static bool TryConfigure(string profileName, string serviceAccountPath)
        {
            var name = (profileName ?? "").Trim();
            if (name.Length == 0)
                return false;

            if (string.Equals(name, ProfileBbc, StringComparison.OrdinalIgnoreCase))
            {
                var env = Environment.GetEnvironmentVariable("GOOGLE_APPLICATION_CREDENTIALS");
                if (!string.IsNullOrWhiteSpace(env) && File.Exists(env))
                {
                    try
                    {
                        Configure(name, env);
                        return true;
                    }
                    catch
                    {
                        // fall through to config path
                    }
                }
            }

            if (string.IsNullOrWhiteSpace(serviceAccountPath))
                return false;

            try
            {
                Configure(name, serviceAccountPath);
                return true;
            }
            catch
            {
                return false;
            }
        }

        public static async Task<string> SendNewEpisodeAsync(
            string profileName,
            Episode episode,
            string episodeKey,
            CancellationToken cancellationToken = default(CancellationToken))
        {
            var name = (profileName ?? "").Trim();
            if (name.Length == 0)
                throw new ArgumentException("profileName is required.", nameof(profileName));

            if (!IsProfileConfigured(name))
                throw new InvalidOperationException(
                    "FCM not configured for profile \"" + name + "\". "
                    + "Set FcmServiceAccountPath / FcmServiceAccountPathVOA / FcmServiceAccountPathBritish in service.config.");

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
    }
}
