/// RTDB endpoint cho cấu hình nhắc cập nhật app.
///
/// Tạo node **`AppUpdate`** trong Firebase Realtime Database (cùng project `bbc-listening-english`)
/// với JSON tối thiểu. Mỗi lần release: tăng `latest_build` (và `latest_version` nếu đổi semver);
/// khi cần chặn bản cũ: đặt `min_build` / `min_supported_version`.
///
/// Ví dụ:
/// ```json
/// {
///   "min_build": 0,
///   "latest_build": 29,
///   "min_supported_version": "1.0.0",
///   "latest_version": "1.0.0",
///   "store_ios_url": "https://apps.apple.com/app/id1234567890",
///   "update_title": "Update available",
///   "update_message": "Please update for the best experience."
/// }
/// ```
///
/// - `store_android_url`: **tuỳ chọn** — nếu bỏ qua, app tự dựng link Play
///   `...?id=<packageName>` từ `package_info`.
/// - `store_ios_url`: **bắt buộc cho iOS** (rate / update). Đặt Apple ID thật
///   từ App Store Connect; placeholder kiểu `idYOUR_APP_STORE_ID` bị bỏ qua.
/// - Hoặc điền `kIosAppStoreId` trong `lib/config/store_links.dart`.
/// - Bỏ trống hoặc `null`: trường tương ứng không dùng.
/// - Ưu tiên so sánh **số build** (`min_build`, `latest_build`) nếu có; bổ sung semver nếu không đủ.
const String kAppUpdateRtdbUrl =
    'https://bbc-listening-english.firebaseio.com/AppUpdate.json';
