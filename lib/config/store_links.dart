/// Link / ID cửa hàng dùng cho đánh giá & cập nhật app.

const String kAndroidPackageName = 'com.voalearningenglish.listeningskills';

/// Apple ID số trên App Store Connect (App Information → Apple ID).
/// Để trống cho đến khi đã tạo app trên Connect; điền trước khi ship TestFlight/rate.
const String kIosAppStoreId = '';

bool isUsableStoreUrl(String? raw) {
  if (raw == null) return false;
  final s = raw.trim();
  if (s.isEmpty) return false;
  final lower = s.toLowerCase();
  if (lower.contains('your_') ||
      lower.contains('your-app') ||
      lower.contains('placeholder') ||
      lower.contains('idyour')) {
    return false;
  }
  return Uri.tryParse(s) != null;
}

Uri androidPlayStoreUri([String? packageName]) {
  final id = (packageName != null && packageName.isNotEmpty)
      ? packageName
      : kAndroidPackageName;
  return Uri.parse('https://play.google.com/store/apps/details?id=$id');
}

Uri? iosAppStoreUri([String? appStoreId]) {
  final id = (appStoreId != null && appStoreId.trim().isNotEmpty)
      ? appStoreId.trim()
      : kIosAppStoreId.trim();
  if (id.isEmpty) return null;
  return Uri.parse('https://apps.apple.com/app/id$id?action=write-review');
}
