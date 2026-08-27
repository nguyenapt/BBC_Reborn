namespace playMP3
{
    /// <summary>
    /// Runtime RTDB target for the currently selected cloud service.
    /// Defaults to BBC; overridden via <see cref="Set"/> when the user switches cloud.
    /// </summary>
    public static class ActiveRtdbContext
    {
        public static string BaseUrl { get; private set; } = GrammarCacheConstants.FirebaseRtdbBaseUrl;

        public static string AuthToken { get; private set; }

        public static void Set(string baseUrl, string authToken = null)
        {
            var url = (baseUrl ?? string.Empty).Trim().TrimEnd('/');
            if (url.EndsWith(".json", System.StringComparison.OrdinalIgnoreCase))
                url = url.Substring(0, url.Length - 5).TrimEnd('/');

            BaseUrl = string.IsNullOrEmpty(url)
                ? GrammarCacheConstants.FirebaseRtdbBaseUrl
                : url;

            AuthToken = string.IsNullOrWhiteSpace(authToken) ? null : authToken.Trim();
        }
    }
}
