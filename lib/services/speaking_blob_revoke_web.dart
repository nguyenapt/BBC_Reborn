import 'package:web/web.dart' as web;

/// Gỡ blob URL sau khi đọc xong (chỉ build web).
void revokeSpeakingBlobUrl(String url) {
  if (!url.startsWith('blob:')) return;
  try {
    web.URL.revokeObjectURL(url);
  } catch (_) {}
}
