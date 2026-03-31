import 'package:flutter/material.dart';

/// Global navigator key (MaterialApp) — dùng cho SnackBar / context không có widget.
class NavigationService {
  static final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();
}
