using System;
using System.Collections.Generic;
using System.Globalization;
using System.Net.Http;
using System.Threading;
using System.Threading.Tasks;
using Newtonsoft.Json.Linq;

namespace playMP3
{
    /// <summary>
    /// Scan / delete expired leaf entries under <c>ai_cache/{node}</c>.
    /// Leaf shape matches Flutter <c>AICacheEntry</c>: data, createdAt, version, ttlDays.
    /// </summary>
    public static class AiCacheExpiryCleaner
    {
        private static readonly HttpClient Http = new HttpClient { Timeout = TimeSpan.FromMinutes(5) };

        public static readonly string[] CacheNodeNames = GrammarCacheConstants.AiCacheNodeNames;

        public static int DefaultTtlDaysForNode(string nodeName)
        {
            if (string.Equals(nodeName, "vocabulary", StringComparison.OrdinalIgnoreCase)
                || string.Equals(nodeName, "vocabulary_by_episode", StringComparison.OrdinalIgnoreCase))
                return GrammarCacheConstants.VocabularyAiCacheTtlDays;
            return GrammarCacheConstants.AiCacheTtlDays;
        }

        public sealed class ScanProgress
        {
            public string Node { get; set; }
            public string CurrentPath { get; set; }
            public int ScannedLeaves { get; set; }
            public int ExpiredLeaves { get; set; }
            public int InvalidLeaves { get; set; }
        }

        public sealed class ScanResult
        {
            public int ScannedLeaves { get; set; }
            public int ExpiredLeaves { get; set; }
            public int InvalidLeaves { get; set; }
            public List<string> ExpiredPaths { get; } = new List<string>();
            public Dictionary<string, int> ExpiredByNode { get; } = new Dictionary<string, int>(StringComparer.Ordinal);
            public Dictionary<string, int> ScannedByNode { get; } = new Dictionary<string, int>(StringComparer.Ordinal);
        }

        public sealed class DeleteResult
        {
            public int Deleted { get; set; }
            public int Failed { get; set; }
            public List<string> Errors { get; } = new List<string>();
        }

        public static async Task<ScanResult> ScanAsync(
            string firebaseRtdbBaseUrl,
            IEnumerable<string> nodeNames,
            string authToken,
            IProgress<ScanProgress> progress = null,
            CancellationToken cancellationToken = default(CancellationToken))
        {
            if (string.IsNullOrWhiteSpace(authToken))
                throw new ArgumentException("Firebase auth secret is required.", nameof(authToken));

            var baseUrl = GrammarCacheKeyHelper.NormalizeRtdbBaseUrl(firebaseRtdbBaseUrl);
            var result = new ScanResult();
            var now = DateTime.UtcNow;

            foreach (var rawNode in nodeNames)
            {
                cancellationToken.ThrowIfCancellationRequested();
                var node = (rawNode ?? string.Empty).Trim();
                if (string.IsNullOrEmpty(node))
                    continue;

                if (!result.ScannedByNode.ContainsKey(node))
                    result.ScannedByNode[node] = 0;
                if (!result.ExpiredByNode.ContainsKey(node))
                    result.ExpiredByNode[node] = 0;

                var defaultTtl = DefaultTtlDaysForNode(node);
                var rootRelative = GrammarCacheConstants.AiCachePath + "/" + node;

                await WalkAsync(
                    baseUrl,
                    rootRelative,
                    node,
                    defaultTtl,
                    now,
                    authToken.Trim(),
                    result,
                    progress,
                    cancellationToken).ConfigureAwait(false);
            }

            return result;
        }

        public static async Task<DeleteResult> DeleteAsync(
            string firebaseRtdbBaseUrl,
            IReadOnlyList<string> relativePaths,
            string authToken,
            IProgress<ScanProgress> progress = null,
            CancellationToken cancellationToken = default(CancellationToken))
        {
            if (string.IsNullOrWhiteSpace(authToken))
                throw new ArgumentException("Firebase auth secret is required.", nameof(authToken));

            var baseUrl = GrammarCacheKeyHelper.NormalizeRtdbBaseUrl(firebaseRtdbBaseUrl);
            var result = new DeleteResult();
            var auth = authToken.Trim();
            var parentsToPrune = new HashSet<string>(StringComparer.Ordinal);

            for (var i = 0; i < relativePaths.Count; i++)
            {
                cancellationToken.ThrowIfCancellationRequested();
                var path = (relativePaths[i] ?? string.Empty).Trim().Trim('/');
                if (string.IsNullOrEmpty(path))
                    continue;

                if (progress != null)
                {
                    progress.Report(new ScanProgress
                    {
                        CurrentPath = path,
                        ExpiredLeaves = i + 1,
                        ScannedLeaves = relativePaths.Count,
                    });
                }

                try
                {
                    await DeletePathAsync(baseUrl, path, auth, cancellationToken).ConfigureAwait(false);
                    result.Deleted++;
                    var parent = ParentPath(path);
                    if (!string.IsNullOrEmpty(parent))
                        parentsToPrune.Add(parent);
                }
                catch (Exception ex)
                {
                    result.Failed++;
                    result.Errors.Add(path + ": " + ex.Message);
                }
            }

            // Best-effort prune empty parents (deepest first).
            var orderedParents = new List<string>(parentsToPrune);
            orderedParents.Sort((a, b) => b.Length.CompareTo(a.Length));
            foreach (var parent in orderedParents)
            {
                cancellationToken.ThrowIfCancellationRequested();
                try
                {
                    await TryPruneEmptyAncestorsAsync(baseUrl, parent, auth, cancellationToken).ConfigureAwait(false);
                }
                catch
                {
                    // ignore prune failures
                }
            }

            return result;
        }

        private static async Task WalkAsync(
            string baseUrl,
            string relativePath,
            string rootNode,
            int defaultTtl,
            DateTime nowUtc,
            string authToken,
            ScanResult result,
            IProgress<ScanProgress> progress,
            CancellationToken cancellationToken)
        {
            cancellationToken.ThrowIfCancellationRequested();

            var shallow = await GetJsonAsync(baseUrl, relativePath, authToken, shallow: true, cancellationToken).ConfigureAwait(false);
            if (shallow == null || shallow.Type == JTokenType.Null)
                return;

            if (shallow.Type != JTokenType.Object)
                return;

            var shallowObj = (JObject)shallow;

            // On a leaf, shallow=true yields { data:true, createdAt:true, ttlDays:true, version:true }.
            if (shallowObj["createdAt"] != null)
            {
                var full = await GetJsonAsync(baseUrl, relativePath, authToken, shallow: false, cancellationToken).ConfigureAwait(false);
                if (full is JObject leaf && IsCacheLeaf(leaf))
                {
                    await EvaluateLeafAsync(relativePath, rootNode, defaultTtl, nowUtc, leaf, result, progress)
                        .ConfigureAwait(false);
                }
                return;
            }

            foreach (var prop in shallowObj.Properties())
            {
                cancellationToken.ThrowIfCancellationRequested();
                var childPath = relativePath + "/" + EncodePathSegment(prop.Name);
                await WalkAsync(baseUrl, childPath, rootNode, defaultTtl, nowUtc, authToken, result, progress, cancellationToken)
                    .ConfigureAwait(false);
            }
        }

        private static Task EvaluateLeafAsync(
            string relativePath,
            string rootNode,
            int defaultTtl,
            DateTime nowUtc,
            JObject leaf,
            ScanResult result,
            IProgress<ScanProgress> progress)
        {
            result.ScannedLeaves++;
            result.ScannedByNode[rootNode] = result.ScannedByNode[rootNode] + 1;

            DateTime createdAt;
            if (!TryParseCreatedAt(leaf["createdAt"], out createdAt))
            {
                result.InvalidLeaves++;
                Report(progress, rootNode, relativePath, result);
                return Task.CompletedTask;
            }

            int? ttlDays = null;
            var ttlToken = leaf["ttlDays"];
            if (ttlToken != null && ttlToken.Type != JTokenType.Null)
            {
                int parsed;
                if (ttlToken.Type == JTokenType.Integer)
                    ttlDays = ttlToken.Value<int>();
                else if (int.TryParse(ttlToken.ToString(), NumberStyles.Integer, CultureInfo.InvariantCulture, out parsed))
                    ttlDays = parsed;
            }

            var ttl = ttlDays ?? defaultTtl;
            var expiry = createdAt.ToUniversalTime().AddDays(ttl);
            // Match Flutter isValid: valid while now.isBefore(expiry) → expired when now >= expiry
            var expired = nowUtc >= expiry;

            if (expired)
            {
                result.ExpiredLeaves++;
                result.ExpiredByNode[rootNode] = result.ExpiredByNode[rootNode] + 1;
                result.ExpiredPaths.Add(relativePath);
            }

            Report(progress, rootNode, relativePath, result);
            return Task.CompletedTask;
        }

        private static void Report(IProgress<ScanProgress> progress, string node, string path, ScanResult result)
        {
            if (progress == null)
                return;
            progress.Report(new ScanProgress
            {
                Node = node,
                CurrentPath = path,
                ScannedLeaves = result.ScannedLeaves,
                ExpiredLeaves = result.ExpiredLeaves,
                InvalidLeaves = result.InvalidLeaves,
            });
        }

        internal static bool IsCacheLeaf(JObject obj)
        {
            if (obj == null)
                return false;
            return obj["createdAt"] != null && obj["createdAt"].Type != JTokenType.Null;
        }

        internal static bool TryParseCreatedAt(JToken token, out DateTime createdAt)
        {
            createdAt = default(DateTime);
            if (token == null || token.Type == JTokenType.Null)
                return false;
            var s = token.ToString();
            if (string.IsNullOrWhiteSpace(s))
                return false;
            return DateTime.TryParse(
                s,
                CultureInfo.InvariantCulture,
                DateTimeStyles.RoundtripKind,
                out createdAt);
        }

        private static async Task<JToken> GetJsonAsync(
            string baseUrl,
            string relativePath,
            string authToken,
            bool shallow,
            CancellationToken cancellationToken)
        {
            var url = BuildUrl(baseUrl, relativePath, authToken, shallow);
            using (var resp = await Http.GetAsync(url, cancellationToken).ConfigureAwait(false))
            {
                var body = await resp.Content.ReadAsStringAsync().ConfigureAwait(false);
                if (!resp.IsSuccessStatusCode)
                    throw new InvalidOperationException(
                        "Firebase GET " + (int)resp.StatusCode + " " + relativePath + " " + Truncate(body, 200));

                if (string.IsNullOrWhiteSpace(body) || body == "null")
                    return null;

                return JToken.Parse(body);
            }
        }

        private static async Task DeletePathAsync(string baseUrl, string relativePath, string authToken, CancellationToken cancellationToken)
        {
            var url = BuildUrl(baseUrl, relativePath, authToken, shallow: false);
            using (var resp = await Http.DeleteAsync(url, cancellationToken).ConfigureAwait(false))
            {
                var body = await resp.Content.ReadAsStringAsync().ConfigureAwait(false);
                if (!resp.IsSuccessStatusCode)
                    throw new InvalidOperationException(
                        "Firebase DELETE " + (int)resp.StatusCode + " " + Truncate(body, 200));
            }
        }

        private static async Task TryPruneEmptyAncestorsAsync(
            string baseUrl,
            string relativePath,
            string authToken,
            CancellationToken cancellationToken)
        {
            var path = relativePath;
            // Stop at ai_cache root — never delete the ai_cache node itself.
            var stopAt = GrammarCacheConstants.AiCachePath;

            while (!string.IsNullOrEmpty(path)
                   && !string.Equals(path, stopAt, StringComparison.Ordinal)
                   && path.StartsWith(stopAt + "/", StringComparison.Ordinal))
            {
                cancellationToken.ThrowIfCancellationRequested();
                var token = await GetJsonAsync(baseUrl, path, authToken, shallow: false, cancellationToken).ConfigureAwait(false);
                if (token == null || token.Type == JTokenType.Null)
                {
                    path = ParentPath(path);
                    continue;
                }

                if (token.Type == JTokenType.Object && !((JObject)token).HasValues)
                {
                    await DeletePathAsync(baseUrl, path, authToken, cancellationToken).ConfigureAwait(false);
                    path = ParentPath(path);
                    continue;
                }

                break;
            }
        }

        private static string ParentPath(string relativePath)
        {
            if (string.IsNullOrEmpty(relativePath))
                return null;
            var i = relativePath.LastIndexOf('/');
            if (i <= 0)
                return null;
            return relativePath.Substring(0, i);
        }

        private static string BuildUrl(string baseUrl, string relativePath, string authToken, bool shallow)
        {
            var path = (relativePath ?? string.Empty).Trim().Trim('/');
            var root = GrammarCacheKeyHelper.NormalizeRtdbBaseUrl(baseUrl);
            var url = root + "/" + path + ".json?auth="
                      + Uri.EscapeDataString(authToken ?? string.Empty);
            if (shallow)
                url += "&shallow=true";
            return url;
        }

        /// <summary>RTDB path segments must not contain . # $ [ ] / — keys are already sanitized when written.</summary>
        private static string EncodePathSegment(string segment)
        {
            return segment ?? string.Empty;
        }

        private static string Truncate(string s, int max)
        {
            if (string.IsNullOrEmpty(s) || s.Length <= max)
                return s ?? string.Empty;
            return s.Substring(0, max) + "...";
        }
    }
}
