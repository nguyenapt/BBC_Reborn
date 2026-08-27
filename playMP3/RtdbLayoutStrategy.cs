using System;

namespace playMP3
{
    public enum RtdbLayoutKind
    {
        BbcLegacy,
        VoaLegacy,
        BritishGrouped,
    }

    /// <summary>
    /// RTDB path builders theo cloud: BBC/VOA legacy vs British grouped under <c>category/</c>.
    /// </summary>
    public static class RtdbLayoutStrategy
    {
        public static RtdbLayoutKind ResolveFromCloudName(string cloudName)
        {
            var name = (cloudName ?? string.Empty).Trim();
            if (string.Equals(name, "British", StringComparison.OrdinalIgnoreCase))
                return RtdbLayoutKind.BritishGrouped;
            if (string.Equals(name, "VOA", StringComparison.OrdinalIgnoreCase))
                return RtdbLayoutKind.VoaLegacy;
            return RtdbLayoutKind.BbcLegacy;
        }

        public static string BuildFullEpisodePath(RtdbLayoutKind layout, string categoryPath, string episodeKey)
        {
            var cat = NormalizeSegment(categoryPath);
            var key = NormalizeSegment(episodeKey);
            if (layout == RtdbLayoutKind.BritishGrouped)
                return Join("category", cat, key);
            return Join(cat, key);
        }

        public static string BuildListEpisodePath(RtdbLayoutKind layout, string categoryPath, string episodeKey)
        {
            var cat = NormalizeSegment(categoryPath);
            var key = NormalizeSegment(episodeKey);
            if (layout == RtdbLayoutKind.BritishGrouped)
                return Join("category", "List", cat, key);
            return Join("List", cat, key);
        }

        /// <summary>Same as full episode path — value stored in episode <c>RtdbPath</c>.</summary>
        public static string BuildRtdbPathField(RtdbLayoutKind layout, string categoryPath, string episodeKey)
        {
            return BuildFullEpisodePath(layout, categoryPath, episodeKey);
        }

        /// <summary>
        /// BBC: <c>HomePage/{slot}</c>; VOA: <c>NewHomePage/{slot}</c>; British: no full home tree.
        /// </summary>
        public static bool TryGetHomeFullPath(RtdbLayoutKind layout, string homeSlot, out string path)
        {
            path = null;
            var slot = NormalizeSegment(homeSlot);
            if (string.IsNullOrEmpty(slot))
                return false;

            switch (layout)
            {
                case RtdbLayoutKind.BbcLegacy:
                    path = Join("HomePage", slot);
                    return true;
                case RtdbLayoutKind.VoaLegacy:
                    path = Join("NewHomePage", slot);
                    return true;
                default:
                    return false;
            }
        }

        /// <summary>
        /// BBC: <c>List/HomePage/{slot}</c>; British: <c>category/List/HomePage/{slot}</c>; VOA: none.
        /// </summary>
        public static bool TryGetHomeListPath(RtdbLayoutKind layout, string homeSlot, out string path)
        {
            path = null;
            var slot = NormalizeSegment(homeSlot);
            if (string.IsNullOrEmpty(slot))
                return false;

            switch (layout)
            {
                case RtdbLayoutKind.BbcLegacy:
                    path = Join("List", "HomePage", slot);
                    return true;
                case RtdbLayoutKind.BritishGrouped:
                    path = Join("category", "List", "HomePage", slot);
                    return true;
                default:
                    return false;
            }
        }

        /// <summary>List mirror path for a full-tree episode path (migrator / patch helpers).</summary>
        public static string BuildListMirrorPath(RtdbLayoutKind layout, string fullEpisodePath)
        {
            var full = NormalizeSegment(fullEpisodePath);
            if (string.IsNullOrEmpty(full))
                return layout == RtdbLayoutKind.BritishGrouped ? "category/List" : "List";

            if (layout == RtdbLayoutKind.BritishGrouped)
            {
                if (full.StartsWith("category/", StringComparison.OrdinalIgnoreCase))
                    return "category/List/" + full.Substring("category/".Length);
                return "category/List/" + full;
            }

            return "List/" + full;
        }

        private static string NormalizeSegment(string value)
        {
            return (value ?? string.Empty).Trim().Trim('/').Replace('\\', '/');
        }

        private static string Join(params string[] parts)
        {
            var sb = new System.Text.StringBuilder();
            foreach (var part in parts)
            {
                var p = NormalizeSegment(part);
                if (string.IsNullOrEmpty(p)) continue;
                if (sb.Length > 0) sb.Append('/');
                sb.Append(p);
            }
            return sb.ToString();
        }
    }
}
