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
    /// </summary>
    public static class EpisodeFcmSender
    {
        public const string FcmTopicNewEpisodes = "episodes";
        public const string AndroidChannelId = "bbc_episode_push";

        private static readonly object InitLock = new object();
        private static bool _initialized;

        public static bool IsConfigured => _initialized;

        public static void Configure(string serviceAccountPath)
        {
            if (string.IsNullOrWhiteSpace(serviceAccountPath))
                throw new InvalidOperationException("FcmServiceAccountPath is not set in service.config.");

            var path = ResolvePath(serviceAccountPath);
            if (!File.Exists(path))
                throw new FileNotFoundException("FCM service account not found: " + path);

            lock (InitLock)
            {
                if (_initialized)
                    return;

                if (FirebaseApp.DefaultInstance == null)
                {
                    FirebaseApp.Create(new AppOptions
                    {
                        Credential = GoogleCredential.FromFile(path),
                    });
                }

                _initialized = true;
            }
        }

        public static bool TryConfigure(string serviceAccountPath)
        {
            var env = Environment.GetEnvironmentVariable("GOOGLE_APPLICATION_CREDENTIALS");
            if (!string.IsNullOrWhiteSpace(env) && File.Exists(env))
            {
                try
                {
                    Configure(env);
                    return true;
                }
                catch
                {
                    // fall through to config path
                }
            }

            if (string.IsNullOrWhiteSpace(serviceAccountPath))
                return false;

            try
            {
                Configure(serviceAccountPath);
                return true;
            }
            catch
            {
                return false;
            }
        }

        public static async Task<string> SendNewEpisodeAsync(
            Episode episode,
            string episodeKey,
            CancellationToken cancellationToken = default(CancellationToken))
        {
            if (!_initialized)
                throw new InvalidOperationException(
                    "FCM not configured. Set FcmServiceAccountPath in service.config or GOOGLE_APPLICATION_CREDENTIALS.");

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
                    Title = "BBC Learning English — new episode",
                    Body = string.Format("{0} ({1} · {2})", episodeName, category, year),
                },
                Data = new Dictionary<string, string>
                {
                    ["category"] = category,
                    ["year"] = year,
                    ["episodeKey"] = episodeKey,
                    ["episodeId"] = episode.Id.ToString(),
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
            };

            return await FirebaseMessaging.DefaultInstance
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
