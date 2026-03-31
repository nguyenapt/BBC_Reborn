import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import '../services/navigation_service.dart';

/// Chỉ khi **debug** (`flutter run` debug): hiện SnackBar để tester thấy nguồn dữ liệu (không dùng console).
void debugLogDataSource(String tag, String message) {
  if (!kDebugMode) return;

  final full = '[$tag] $message';
  final display = full.length > 220 ? '${full.substring(0, 220)}…' : full;

  WidgetsBinding.instance.addPostFrameCallback((_) {
    final ctx = NavigationService.navigatorKey.currentContext;
    if (ctx == null) return;
    final messenger = ScaffoldMessenger.maybeOf(ctx);
    if (messenger == null) return;

    messenger.hideCurrentSnackBar();
    messenger.showSnackBar(
      SnackBar(
        content: Text(
          display,
          style: const TextStyle(fontSize: 13, height: 1.25),
        ),
        duration: const Duration(milliseconds: 2800),
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        showCloseIcon: true,
        closeIconColor: Colors.white70,
      ),
    );
  });
}
