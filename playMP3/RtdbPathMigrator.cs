using System;
using System.Collections.Generic;
using System.Linq;
using System.Net.Http;
using System.Text;
using System.Threading;
using System.Threading.Tasks;
using Newtonsoft.Json;
using Newtonsoft.Json.Linq;

namespace playMP3
{
    /// <summary>
    /// Backfill field <c>RtdbPath</c> lên RTDB full + List từ file JSON export full DB.
    /// HomePage / List/HomePage (BBC) hoặc <c>category/List/HomePage</c> (British):
    /// resolve path full tree theo Id (2 năm gần nhất nếu category có year).
    /// </summary>
    public static class RtdbPathMigrator
    {
        private const int RecentYearLookupCount = 2;

        private static readonly HashSet<string> ExcludedTopLevelBbc = new HashSet<string>(StringComparer.OrdinalIgnoreCase)
        {
            "ai_cache",
            "users",
            "AppUpdate",
            "List",
            "app_client_config",
            "ai_server_config",
            "user_favourites",
        };

        private static readonly HashSet<string> ExcludedTopLevelBritish = new HashSet<string>(StringComparer.OrdinalIgnoreCase)
        {
            "ai_cache",
            "users",
            "config",
        };

        private static readonly HashSet<string> HomePageRootsBbc = new HashSet<string>(StringComparer.OrdinalIgnoreCase)
        {
            "HomePage",
            "NewHomePage",
        };

        public sealed class EpisodeLeaf
        {
            /// <summary>Path full tree (6M/2026/11 hoặc category/AAE/…) — giá trị ghi vào field RtdbPath.</summary>
            public string RtdbPath { get; set; }

            /// <summary>Slot HomePage/NewHomePage. Null với British (chỉ list home).</summary>
            public string HomePageSlotPath { get; set; }

            /// <summary>Slot List/HomePage/… hoặc category/List/HomePage/…</summary>
            public string ListHomePageSlotPath { get; set; }

            public JObject Episode { get; set; }

            public bool IsHomePageSlot { get; set; }

            public bool Unresolved { get; set; }

            public bool AlreadyHasCorrectPath { get; set; }
        }

        public sealed class MigrateResult
        {
            public int PatchedFull { get; set; }
            public int PatchedList { get; set; }
            public int PatchedHomeSlots { get; set; }
            public int Skipped { get; set; }
            public int ListMissing { get; set; }
            public int Unresolved { get; set; }
            public int Failed { get; set; }
        }

        private static HashSet<string> GetExcludedTopLevel(RtdbLayoutKind layout)
        {
            return layout == RtdbLayoutKind.BritishGrouped
                ? ExcludedTopLevelBritish
                : ExcludedTopLevelBbc;
        }

        /// <summary>
        /// Paths chọn được: category/year, AS/sub, HomePage/…, List/HomePage/…
        /// (British: <c>category/*</c>, <c>category/List/HomePage</c>).
        /// </summary>
        public static List<string> LoadSelectableNodes(JObject root)
        {
            return LoadSelectableNodes(root, RtdbLayoutKind.BbcLegacy);
        }

        public static List<string> LoadSelectableNodes(JObject root, RtdbLayoutKind layout)
        {
            var nodes = new List<string>();
            if (root == null) return nodes;

            if (layout == RtdbLayoutKind.BritishGrouped)
            {
                var categoryRoot = root["category"] as JObject;
                if (categoryRoot != null)
                {
                    foreach (var prop in categoryRoot.Properties())
                    {
                        if (string.Equals(prop.Name, "List", StringComparison.OrdinalIgnoreCase))
                            continue;
                        if (prop.Value == null || prop.Value.Type == JTokenType.Null) continue;
                        AddSelectableFromTree(nodes, "category/" + prop.Name, prop.Value);
                    }

                    if (categoryRoot["List"]?["HomePage"] is JObject listHomePage)
                        AddSelectableFromTree(nodes, "category/List/HomePage", listHomePage);
                }
            }
            else
            {
                var excluded = GetExcludedTopLevel(layout);
                foreach (var prop in root.Properties())
                {
                    if (excluded.Contains(prop.Name)) continue;
                    if (string.Equals(prop.Name, "List", StringComparison.OrdinalIgnoreCase)) continue;
                    if (prop.Value == null || prop.Value.Type == JTokenType.Null) continue;

                    AddSelectableFromTree(nodes, prop.Name, prop.Value);
                }

                var listNode = root["List"] as JObject;
                if (listNode?["HomePage"] is JObject listHomePage)
                    AddSelectableFromTree(nodes, "List/HomePage", listHomePage);
            }

            nodes.Sort(StringComparer.OrdinalIgnoreCase);
            return nodes.Distinct(StringComparer.OrdinalIgnoreCase).ToList();
        }

        private static bool IsHomePageSelectablePrefix(string prefix)
        {
            if (string.IsNullOrEmpty(prefix)) return false;
            return string.Equals(prefix, "List/HomePage", StringComparison.OrdinalIgnoreCase)
                || prefix.StartsWith("List/HomePage/", StringComparison.OrdinalIgnoreCase)
                || string.Equals(prefix, "category/List/HomePage", StringComparison.OrdinalIgnoreCase)
                || prefix.StartsWith("category/List/HomePage/", StringComparison.OrdinalIgnoreCase)
                || string.Equals(prefix, "HomePage", StringComparison.OrdinalIgnoreCase)
                || prefix.StartsWith("HomePage/", StringComparison.OrdinalIgnoreCase)
                || string.Equals(prefix, "NewHomePage", StringComparison.OrdinalIgnoreCase)
                || prefix.StartsWith("NewHomePage/", StringComparison.OrdinalIgnoreCase);
        }

        private static void AddSelectableFromTree(List<string> nodes, string prefix, JToken token)
        {
            if (token == null || token.Type == JTokenType.Null) return;

            nodes.Add(prefix);

            if (!(token is JObject obj)) return;

            if (IsYearKeyedObject(obj))
            {
                foreach (var year in obj.Properties())
                    nodes.Add(prefix + "/" + year.Name);
                return;
            }

            if (IsHomePageSelectablePrefix(prefix))
            {
                if (LooksLikeEpisode(obj)) return;
                foreach (var child in obj.Properties())
                {
                    if (string.Equals(child.Name, "Grammar", StringComparison.OrdinalIgnoreCase)) continue;
                    AddSelectableFromTree(nodes, prefix + "/" + child.Name, child.Value);
                }
                return;
            }

            if (LooksLikeEpisode(obj)) return;

            foreach (var child in obj.Properties())
            {
                if (string.Equals(child.Name, "Grammar", StringComparison.OrdinalIgnoreCase)) continue;
                AddSelectableFromTree(nodes, prefix + "/" + child.Name, child.Value);
            }
        }

        public static List<EpisodeLeaf> EnumerateEpisodeLeaves(
            JObject root,
            IEnumerable<string> selectedPaths)
        {
            return EnumerateEpisodeLeaves(root, selectedPaths, RtdbLayoutKind.BbcLegacy);
        }

        public static List<EpisodeLeaf> EnumerateEpisodeLeaves(
            JObject root,
            IEnumerable<string> selectedPaths,
            RtdbLayoutKind layout)
        {
            var selected = new HashSet<string>(
                (selectedPaths ?? Enumerable.Empty<string>())
                    .Where(p => !string.IsNullOrWhiteSpace(p))
                    .Select(p => p.Trim().Trim('/')),
                StringComparer.OrdinalIgnoreCase);

            var leaves = new List<EpisodeLeaf>();
            if (root == null || selected.Count == 0) return leaves;

            var idIndex = BuildEpisodeIdIndex(root, layout);

            if (layout == RtdbLayoutKind.BritishGrouped)
            {
                var categoryRoot = root["category"] as JObject;
                if (categoryRoot != null)
                {
                    foreach (var prop in categoryRoot.Properties())
                    {
                        if (string.Equals(prop.Name, "List", StringComparison.OrdinalIgnoreCase))
                            continue;
                        WalkToken(prop.Value, "category/" + prop.Name, selected, leaves, root, idIndex, layout);
                    }
                }

                var walkListHome = selected.Any(s =>
                    s.StartsWith("category/List/HomePage", StringComparison.OrdinalIgnoreCase));
                if (walkListHome && root["category"]?["List"]?["HomePage"] != null)
                {
                    WalkToken(root["category"]["List"]["HomePage"], "category/List/HomePage",
                        selected, leaves, root, idIndex, layout);
                }
            }
            else
            {
                var excluded = GetExcludedTopLevel(layout);
                var walkListHome = selected.Any(s =>
                    s.StartsWith("List/HomePage", StringComparison.OrdinalIgnoreCase));

                foreach (var prop in root.Properties())
                {
                    if (excluded.Contains(prop.Name)) continue;
                    if (string.Equals(prop.Name, "List", StringComparison.OrdinalIgnoreCase)) continue;
                    WalkToken(prop.Value, prop.Name, selected, leaves, root, idIndex, layout);
                }

                if (walkListHome && root["List"]?["HomePage"] != null)
                {
                    WalkToken(root["List"]["HomePage"], "List/HomePage", selected, leaves, root, idIndex, layout);
                }
            }

            return leaves
                .GroupBy(l => (l.IsHomePageSlot ? l.HomePageSlotPath ?? l.ListHomePageSlotPath : l.RtdbPath) ?? "",
                    StringComparer.OrdinalIgnoreCase)
                .Select(g => g.First())
                .OrderBy(l => l.RtdbPath ?? l.HomePageSlotPath ?? l.ListHomePageSlotPath, StringComparer.OrdinalIgnoreCase)
                .ToList();
        }

        public static JObject BuildSlimRtdbPathPatch(string rtdbPath)
        {
            return new JObject { ["RtdbPath"] = rtdbPath };
        }

        public static async Task<MigrateResult> MigrateAsync(
            string baseUrl,
            string authSecret,
            IList<EpisodeLeaf> leaves,
            IProgress<string> log,
            IProgress<int> progressPercent,
            CancellationToken cancellationToken)
        {
            return await MigrateAsync(
                baseUrl, authSecret, leaves, log, progressPercent, cancellationToken,
                RtdbLayoutKind.BbcLegacy).ConfigureAwait(false);
        }

        public static async Task<MigrateResult> MigrateAsync(
            string baseUrl,
            string authSecret,
            IList<EpisodeLeaf> leaves,
            IProgress<string> log,
            IProgress<int> progressPercent,
            CancellationToken cancellationToken,
            RtdbLayoutKind layout)
        {
            var result = new MigrateResult();
            if (leaves == null || leaves.Count == 0) return result;

            var baseTrim = (baseUrl ?? string.Empty).Trim().TrimEnd('/');
            if (baseTrim.EndsWith(".json", StringComparison.OrdinalIgnoreCase))
                baseTrim = baseTrim.Substring(0, baseTrim.Length - 5).TrimEnd('/');

            using (var http = new HttpClient())
            {
                http.Timeout = TimeSpan.FromSeconds(30);
                for (var i = 0; i < leaves.Count; i++)
                {
                    cancellationToken.ThrowIfCancellationRequested();
                    var leaf = leaves[i];

                    try
                    {
                        if (leaf.Unresolved || string.IsNullOrWhiteSpace(leaf.RtdbPath))
                        {
                            result.Unresolved++;
                            log?.Report("UNRESOLVED "
                                + (leaf.HomePageSlotPath ?? leaf.ListHomePageSlotPath ?? "?")
                                + " — không tìm thấy full tree theo Id");
                            continue;
                        }

                        var path = leaf.RtdbPath;
                        var patchJson = BuildSlimRtdbPathPatch(path).ToString(Formatting.None);

                        if (leaf.IsHomePageSlot)
                        {
                            await PatchHomePageSlotsAsync(
                                http, baseTrim, authSecret, leaf, path, patchJson,
                                result, log, cancellationToken, layout).ConfigureAwait(false);
                        }
                        else
                        {
                            await PatchCategoryLeafAsync(
                                http, baseTrim, authSecret, leaf, path, patchJson,
                                result, log, cancellationToken, layout).ConfigureAwait(false);
                        }
                    }
                    catch (OperationCanceledException)
                    {
                        throw;
                    }
                    catch (Exception ex)
                    {
                        result.Failed++;
                        log?.Report("FAIL "
                            + (leaf.RtdbPath ?? leaf.HomePageSlotPath ?? leaf.ListHomePageSlotPath ?? "?")
                            + " — " + ex.Message);
                    }

                    progressPercent?.Report((int)((i + 1) * 100.0 / leaves.Count));
                    await Task.Delay(40, cancellationToken).ConfigureAwait(false);
                }
            }

            return result;
        }

        private static async Task PatchCategoryLeafAsync(
            HttpClient http,
            string baseTrim,
            string authSecret,
            EpisodeLeaf leaf,
            string path,
            string patchJson,
            MigrateResult result,
            IProgress<string> log,
            CancellationToken ct,
            RtdbLayoutKind layout)
        {
            if (leaf.AlreadyHasCorrectPath)
            {
                result.Skipped++;
                log?.Report("SKIP (already) " + path);
            }
            else
            {
                await PatchAsync(http, baseTrim, path, authSecret, patchJson, ct).ConfigureAwait(false);
                result.PatchedFull++;
                log?.Report("PATCH full " + path);
            }

            var listPath = RtdbLayoutStrategy.BuildListMirrorPath(layout, path);
            await PatchListMirrorAsync(http, baseTrim, authSecret, listPath, path, patchJson, result, log, ct)
                .ConfigureAwait(false);
        }

        private static async Task PatchHomePageSlotsAsync(
            HttpClient http,
            string baseTrim,
            string authSecret,
            EpisodeLeaf leaf,
            string resolvedFullPath,
            string patchJson,
            MigrateResult result,
            IProgress<string> log,
            CancellationToken ct,
            RtdbLayoutKind layout)
        {
            var slotPaths = new List<string>();
            if (!string.IsNullOrWhiteSpace(leaf.HomePageSlotPath))
                slotPaths.Add(NormalizeSlotPath(leaf.HomePageSlotPath));
            if (!string.IsNullOrWhiteSpace(leaf.ListHomePageSlotPath))
            {
                var listSlot = NormalizeSlotPath(leaf.ListHomePageSlotPath);
                if (!slotPaths.Any(s => string.Equals(s, listSlot, StringComparison.OrdinalIgnoreCase)))
                    slotPaths.Add(listSlot);
            }

            foreach (var slot in slotPaths)
            {
                if (leaf.AlreadyHasCorrectPath)
                {
                    result.Skipped++;
                    log?.Report("SKIP (already) " + slot + " → " + resolvedFullPath);
                }
                else
                {
                    await PatchAsync(http, baseTrim, slot, authSecret, patchJson, ct).ConfigureAwait(false);
                    result.PatchedHomeSlots++;
                    log?.Report("PATCH Home slot " + slot + " → RtdbPath=" + resolvedFullPath);
                }
            }

            var fullExists = await NodeExistsAsync(http, baseTrim, resolvedFullPath, authSecret, ct)
                .ConfigureAwait(false);
            if (fullExists)
            {
                var existingFull = await ReadRtdbPathFieldAsync(
                    http, baseTrim, resolvedFullPath, authSecret, ct).ConfigureAwait(false);
                if (!string.Equals(existingFull, resolvedFullPath, StringComparison.OrdinalIgnoreCase))
                {
                    await PatchAsync(http, baseTrim, resolvedFullPath, authSecret, patchJson, ct)
                        .ConfigureAwait(false);
                    result.PatchedFull++;
                    log?.Report("PATCH full (from Home lookup) " + resolvedFullPath);
                }

                var listPath = RtdbLayoutStrategy.BuildListMirrorPath(layout, resolvedFullPath);
                await PatchListMirrorAsync(
                    http, baseTrim, authSecret, listPath, resolvedFullPath,
                    patchJson, result, log, ct).ConfigureAwait(false);
            }
            else
            {
                log?.Report("INFO full tree missing " + resolvedFullPath + " (chỉ patch Home slot)");
            }
        }

        private static async Task PatchListMirrorAsync(
            HttpClient http,
            string baseTrim,
            string authSecret,
            string listPath,
            string expectedRtdbPath,
            string patchJson,
            MigrateResult result,
            IProgress<string> log,
            CancellationToken ct)
        {
            var listExists = await NodeExistsAsync(http, baseTrim, listPath, authSecret, ct).ConfigureAwait(false);
            if (!listExists)
            {
                result.ListMissing++;
                log?.Report("WARN List missing " + listPath);
                return;
            }

            var existingListPath = await ReadRtdbPathFieldAsync(
                http, baseTrim, listPath, authSecret, ct).ConfigureAwait(false);
            if (string.Equals(existingListPath, expectedRtdbPath, StringComparison.OrdinalIgnoreCase))
            {
                log?.Report("SKIP List (already) " + listPath);
                return;
            }

            await PatchAsync(http, baseTrim, listPath, authSecret, patchJson, ct).ConfigureAwait(false);
            result.PatchedList++;
            log?.Report("PATCH " + listPath);
        }

        private static string NormalizeSlotPath(string path)
        {
            return (path ?? string.Empty).Trim().Trim('/').Replace('\\', '/');
        }

        private static Dictionary<string, string> BuildEpisodeIdIndex(JObject root, RtdbLayoutKind layout)
        {
            var index = new Dictionary<string, string>(StringComparer.OrdinalIgnoreCase);
            if (root == null) return index;

            if (layout == RtdbLayoutKind.BritishGrouped)
            {
                var categoryRoot = root["category"] as JObject;
                if (categoryRoot == null) return index;
                foreach (var prop in categoryRoot.Properties())
                {
                    if (string.Equals(prop.Name, "List", StringComparison.OrdinalIgnoreCase))
                        continue;
                    IndexToken(prop.Value, "category/" + prop.Name, index);
                }
                return index;
            }

            var excluded = GetExcludedTopLevel(layout);
            foreach (var prop in root.Properties())
            {
                if (excluded.Contains(prop.Name)) continue;
                if (HomePageRootsBbc.Contains(prop.Name)) continue;
                if (string.Equals(prop.Name, "List", StringComparison.OrdinalIgnoreCase)) continue;
                IndexToken(prop.Value, prop.Name, index);
            }

            return index;
        }

        private static void IndexToken(JToken token, string path, Dictionary<string, string> index)
        {
            if (token == null || token.Type == JTokenType.Null) return;

            if (token is JObject obj)
            {
                if (LooksLikeEpisode(obj))
                {
                    RegisterEpisodeId(index, obj, path);
                    return;
                }

                if (IsYearKeyedObject(obj))
                {
                    foreach (var yearProp in obj.Properties())
                        IndexToken(yearProp.Value, path + "/" + yearProp.Name, index);
                    return;
                }

                foreach (var child in obj.Properties())
                    IndexToken(child.Value, path + "/" + child.Name, index);
                return;
            }

            if (token is JArray arr)
            {
                for (var i = 0; i < arr.Count; i++)
                {
                    if (arr[i] is JObject item && LooksLikeEpisode(item))
                        RegisterEpisodeId(index, item, path + "/" + i);
                }
            }
        }

        private static void RegisterEpisodeId(
            Dictionary<string, string> index,
            JObject episode,
            string path)
        {
            var id = episode["Id"]?.ToString()?.Trim();
            if (string.IsNullOrEmpty(id)) return;
            if (!index.ContainsKey(id))
                index[id] = path;
        }

        /// <summary>
        /// Tìm path full tree theo Id — index trước, rồi lookup category (2 năm gần nhất nếu có year).
        /// </summary>
        public static string ResolveFullRtdbPath(
            JObject root,
            JObject episode,
            Dictionary<string, string> idIndex)
        {
            return ResolveFullRtdbPath(root, episode, idIndex, RtdbLayoutKind.BbcLegacy);
        }

        public static string ResolveFullRtdbPath(
            JObject root,
            JObject episode,
            Dictionary<string, string> idIndex,
            RtdbLayoutKind layout)
        {
            if (episode == null || root == null) return null;

            var id = episode["Id"]?.ToString()?.Trim();
            if (string.IsNullOrEmpty(id)) return null;

            if (idIndex != null && idIndex.TryGetValue(id, out var indexed))
                return indexed;

            var category = episode["Category"]?.ToString()?.Trim();
            if (string.IsNullOrEmpty(category)) return null;

            JToken searchRoot = layout == RtdbLayoutKind.BritishGrouped
                ? root["category"]
                : root;
            if (searchRoot == null) return null;

            var pathPrefix = layout == RtdbLayoutKind.BritishGrouped ? "category/" : "";

            var asNode = searchRoot["AS"]?[category];
            if (asNode != null)
            {
                var asPath = FindEpisodeIdInTree(asNode, id, pathPrefix + "AS/" + category, RecentYearLookupCount);
                if (asPath != null) return asPath;
            }

            var catNode = searchRoot[category];
            if (catNode != null)
            {
                var catPath = FindEpisodeIdInTree(catNode, id, pathPrefix + category, RecentYearLookupCount);
                if (catPath != null) return catPath;
            }

            return null;
        }

        private static string FindEpisodeIdInTree(
            JToken node,
            string episodeId,
            string basePath,
            int maxRecentYears)
        {
            if (node == null) return null;

            if (node is JObject obj)
            {
                if (IsYearKeyedObject(obj))
                {
                    var years = obj.Properties()
                        .Select(p => p.Name)
                        .Where(y => y.Length == 4 && int.TryParse(y, out _))
                        .OrderByDescending(y => y, StringComparer.Ordinal)
                        .Take(Math.Max(1, maxRecentYears));

                    foreach (var year in years)
                    {
                        var found = FindEpisodeIdInContainer(obj[year], episodeId, basePath + "/" + year);
                        if (found != null) return found;
                    }

                    return null;
                }

                return FindEpisodeIdInContainer(obj, episodeId, basePath);
            }

            if (node is JArray arr)
                return FindEpisodeIdInContainer(arr, episodeId, basePath);

            return null;
        }

        private static string FindEpisodeIdInContainer(JToken container, string episodeId, string basePath)
        {
            if (container is JObject map)
            {
                foreach (var ep in map.Properties())
                {
                    if (ep.Value is JObject epObj && LooksLikeEpisode(epObj))
                    {
                        if (EpisodeIdMatches(epObj, episodeId))
                            return basePath + "/" + ep.Name;
                    }
                    else
                    {
                        var nested = FindEpisodeIdInTree(
                            ep.Value, episodeId, basePath + "/" + ep.Name, RecentYearLookupCount);
                        if (nested != null) return nested;
                    }
                }
            }
            else if (container is JArray arr)
            {
                for (var i = 0; i < arr.Count; i++)
                {
                    if (arr[i] is JObject epObj && LooksLikeEpisode(epObj))
                    {
                        if (EpisodeIdMatches(epObj, episodeId))
                            return basePath + "/" + i;
                    }
                }
            }

            return null;
        }

        private static bool EpisodeIdMatches(JObject episode, string episodeId)
        {
            var id = episode["Id"]?.ToString();
            if (string.IsNullOrEmpty(id) || string.IsNullOrEmpty(episodeId)) return false;
            return string.Equals(id, episodeId, StringComparison.OrdinalIgnoreCase);
        }

        private static void WalkToken(
            JToken token,
            string path,
            HashSet<string> selected,
            List<EpisodeLeaf> leaves,
            JObject root,
            Dictionary<string, string> idIndex,
            RtdbLayoutKind layout)
        {
            if (token == null || token.Type == JTokenType.Null) return;

            var normalizedPath = NormalizeSlotPath(path);

            if (token is JObject obj)
            {
                if (LooksLikeEpisode(obj))
                {
                    if (IsHomePageSlotPath(normalizedPath))
                        AddHomePageLeaf(leaves, normalizedPath, obj, root, idIndex, selected, layout);
                    else if (IsPathSelected(normalizedPath, selected))
                        AddCategoryLeaf(leaves, normalizedPath, obj);
                    return;
                }

                if (IsYearKeyedObject(obj))
                {
                    foreach (var yearProp in obj.Properties())
                    {
                        var yearPath = normalizedPath + "/" + yearProp.Name;
                        WalkEpisodesUnderContainer(yearProp.Value, yearPath, selected, leaves, root, idIndex, layout);
                    }
                    return;
                }

                foreach (var child in obj.Properties())
                {
                    if (string.Equals(child.Name, "Grammar", StringComparison.OrdinalIgnoreCase)
                        && (normalizedPath.StartsWith("HomePage", StringComparison.OrdinalIgnoreCase)
                            || normalizedPath.StartsWith("category/List/HomePage", StringComparison.OrdinalIgnoreCase)
                            || normalizedPath.StartsWith("List/HomePage", StringComparison.OrdinalIgnoreCase)))
                        continue;

                    var childPath = normalizedPath + "/" + child.Name;
                    if (child.Value is JObject childObj && LooksLikeEpisode(childObj))
                    {
                        if (IsHomePageSlotPath(childPath))
                            AddHomePageLeaf(leaves, childPath, childObj, root, idIndex, selected, layout);
                        else if (IsPathSelected(childPath, selected) || IsPathSelected(normalizedPath, selected))
                            AddCategoryLeaf(leaves, childPath, childObj);
                    }
                    else
                    {
                        WalkToken(child.Value, childPath, selected, leaves, root, idIndex, layout);
                    }
                }
                return;
            }

            if (token is JArray arr)
            {
                for (var i = 0; i < arr.Count; i++)
                {
                    var item = arr[i] as JObject;
                    if (item == null || !LooksLikeEpisode(item)) continue;
                    var itemPath = normalizedPath + "/" + i;
                    if (IsHomePageSlotPath(itemPath))
                        AddHomePageLeaf(leaves, itemPath, item, root, idIndex, selected, layout);
                    else if (IsPathSelected(itemPath, selected) || IsPathSelected(normalizedPath, selected))
                        AddCategoryLeaf(leaves, itemPath, item);
                }
            }
        }

        private static void WalkEpisodesUnderContainer(
            JToken token,
            string path,
            HashSet<string> selected,
            List<EpisodeLeaf> leaves,
            JObject root,
            Dictionary<string, string> idIndex,
            RtdbLayoutKind layout)
        {
            if (token is JObject map)
            {
                foreach (var ep in map.Properties())
                {
                    if (ep.Value is JObject epObj && LooksLikeEpisode(epObj))
                    {
                        var epPath = path + "/" + ep.Name;
                        if (IsHomePageSlotPath(epPath))
                            AddHomePageLeaf(leaves, epPath, epObj, root, idIndex, selected, layout);
                        else if (IsPathSelected(epPath, selected) || IsPathSelected(path, selected))
                            AddCategoryLeaf(leaves, epPath, epObj);
                    }
                    else
                    {
                        WalkToken(ep.Value, path + "/" + ep.Name, selected, leaves, root, idIndex, layout);
                    }
                }
            }
            else if (token is JArray arr)
            {
                for (var i = 0; i < arr.Count; i++)
                {
                    var item = arr[i] as JObject;
                    if (item == null || !LooksLikeEpisode(item)) continue;
                    var itemPath = path + "/" + i;
                    if (IsHomePageSlotPath(itemPath))
                        AddHomePageLeaf(leaves, itemPath, item, root, idIndex, selected, layout);
                    else if (IsPathSelected(itemPath, selected) || IsPathSelected(path, selected))
                        AddCategoryLeaf(leaves, itemPath, item);
                }
            }
        }

        private static bool IsHomePageSlotPath(string path)
        {
            if (string.IsNullOrEmpty(path)) return false;
            return path.StartsWith("HomePage/", StringComparison.OrdinalIgnoreCase)
                || path.StartsWith("List/HomePage/", StringComparison.OrdinalIgnoreCase)
                || path.StartsWith("category/List/HomePage/", StringComparison.OrdinalIgnoreCase)
                || path.StartsWith("NewHomePage/", StringComparison.OrdinalIgnoreCase);
        }

        private static void AddHomePageLeaf(
            List<EpisodeLeaf> leaves,
            string slotPath,
            JObject episode,
            JObject root,
            Dictionary<string, string> idIndex,
            HashSet<string> selected,
            RtdbLayoutKind layout)
        {
            if (!IsPathSelected(slotPath, selected)
                && !IsPathSelected(ParentPath(slotPath), selected))
                return;

            var resolved = ResolveFullRtdbPath(root, episode, idIndex, layout);
            var existing = episode["RtdbPath"]?.ToString();

            string homeSlot;
            string listHomeSlot;

            if (slotPath.StartsWith("category/List/HomePage/", StringComparison.OrdinalIgnoreCase))
            {
                listHomeSlot = slotPath;
                homeSlot = null;
            }
            else if (slotPath.StartsWith("List/HomePage/", StringComparison.OrdinalIgnoreCase))
            {
                listHomeSlot = slotPath;
                homeSlot = "HomePage/" + slotPath.Substring("List/HomePage/".Length);
            }
            else if (slotPath.StartsWith("HomePage/", StringComparison.OrdinalIgnoreCase))
            {
                homeSlot = slotPath;
                listHomeSlot = "List/" + slotPath;
            }
            else
            {
                homeSlot = slotPath;
                listHomeSlot = null;
            }

            leaves.Add(new EpisodeLeaf
            {
                RtdbPath = resolved,
                HomePageSlotPath = homeSlot,
                ListHomePageSlotPath = listHomeSlot,
                Episode = episode,
                IsHomePageSlot = true,
                Unresolved = string.IsNullOrEmpty(resolved),
                AlreadyHasCorrectPath = !string.IsNullOrEmpty(resolved)
                    && string.Equals(existing, resolved, StringComparison.OrdinalIgnoreCase),
            });
        }

        private static void AddCategoryLeaf(List<EpisodeLeaf> leaves, string path, JObject episode)
        {
            var existing = episode["RtdbPath"]?.ToString();
            leaves.Add(new EpisodeLeaf
            {
                RtdbPath = path,
                Episode = episode,
                IsHomePageSlot = false,
                AlreadyHasCorrectPath = string.Equals(existing, path, StringComparison.OrdinalIgnoreCase),
            });
        }

        private static string ParentPath(string path)
        {
            var idx = path.LastIndexOf('/');
            return idx > 0 ? path.Substring(0, idx) : path;
        }

        private static bool IsPathSelected(string path, HashSet<string> selected)
        {
            if (selected.Contains(path)) return true;
            foreach (var sel in selected)
            {
                if (path.StartsWith(sel + "/", StringComparison.OrdinalIgnoreCase))
                    return true;
            }
            return false;
        }

        private static bool LooksLikeEpisode(JObject obj)
        {
            if (obj == null) return false;
            return obj["Id"] != null
                || obj["EpisodeName"] != null
                || obj["Transcript"] != null
                || obj["TranscriptHtml"] != null
                || obj["FileUrl"] != null;
        }

        private static bool IsYearKeyedObject(JObject obj)
        {
            if (obj == null || !obj.HasValues) return false;
            return obj.Properties().All(p =>
            {
                int y;
                return p.Name.Length == 4 && int.TryParse(p.Name, out y) && y >= 1900 && y <= 2100;
            });
        }

        private static async Task PatchAsync(
            HttpClient http,
            string baseUrl,
            string path,
            string authSecret,
            string jsonBody,
            CancellationToken ct)
        {
            var url = BuildUrl(baseUrl, path, authSecret);
            var content = new StringContent(jsonBody, Encoding.UTF8, "application/json");
            var req = new HttpRequestMessage(new HttpMethod("PATCH"), url) { Content = content };
            var resp = await http.SendAsync(req, ct).ConfigureAwait(false);
            var body = await resp.Content.ReadAsStringAsync().ConfigureAwait(false);
            if (!resp.IsSuccessStatusCode)
                throw new InvalidOperationException((int)resp.StatusCode + " " + Truncate(body, 200));
        }

        private static async Task<bool> NodeExistsAsync(
            HttpClient http,
            string baseUrl,
            string path,
            string authSecret,
            CancellationToken ct)
        {
            var url = BuildUrl(baseUrl, path, authSecret);
            url += url.Contains("?") ? "&shallow=true" : "?shallow=true";

            var resp = await http.GetAsync(url, ct).ConfigureAwait(false);
            if (!resp.IsSuccessStatusCode) return false;
            var body = (await resp.Content.ReadAsStringAsync().ConfigureAwait(false) ?? "").Trim();
            return !string.IsNullOrEmpty(body) && body != "null";
        }

        private static async Task<string> ReadRtdbPathFieldAsync(
            HttpClient http,
            string baseUrl,
            string path,
            string authSecret,
            CancellationToken ct)
        {
            var url = BuildUrl(baseUrl, path + "/RtdbPath", authSecret);
            var resp = await http.GetAsync(url, ct).ConfigureAwait(false);
            if (!resp.IsSuccessStatusCode) return null;
            var body = (await resp.Content.ReadAsStringAsync().ConfigureAwait(false) ?? "").Trim();
            if (string.IsNullOrEmpty(body) || body == "null") return null;
            try
            {
                return JsonConvert.DeserializeObject<string>(body);
            }
            catch
            {
                return body.Trim('"');
            }
        }

        private static string BuildUrl(string baseUrl, string path, string authSecret)
        {
            var p = (path ?? string.Empty).Trim().Trim('/');
            var url = baseUrl + "/" + p + ".json";
            if (!string.IsNullOrEmpty(authSecret))
                url += "?auth=" + Uri.EscapeDataString(authSecret);
            return url;
        }

        private static string Truncate(string s, int max)
        {
            if (string.IsNullOrEmpty(s)) return string.Empty;
            return s.Length <= max ? s : s.Substring(0, max) + "…";
        }
    }
}
