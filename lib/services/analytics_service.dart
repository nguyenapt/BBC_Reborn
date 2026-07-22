import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:flutter/foundation.dart';

/// Firebase Analytics — bật collection để gửi `first_open` (Google Ads install).
class AnalyticsService {
  AnalyticsService._();
  static final AnalyticsService instance = AnalyticsService._();

  FirebaseAnalytics get analytics => FirebaseAnalytics.instance;

  Future<void> activate() async {
    try {
      await analytics.setAnalyticsCollectionEnabled(true);
      debugPrint('📊 Firebase Analytics enabled');
    } catch (e) {
      debugPrint('📊 Firebase Analytics activate failed: $e');
    }
  }
}
