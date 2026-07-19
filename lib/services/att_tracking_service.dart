import 'dart:io';

import 'package:app_tracking_transparency/app_tracking_transparency.dart';
import 'package:flutter/foundation.dart';

/// App Tracking Transparency (iOS 14.5+) — xin phép trước khi init Ads SDK.
class AttTrackingService {
  AttTrackingService._();
  static final AttTrackingService instance = AttTrackingService._();

  Future<void> requestIfNeeded() async {
    if (kIsWeb || !Platform.isIOS) return;

    try {
      // Đợi UI sẵn sàng — Apple khuyến cáo không hiện popup ngay lúc cold start.
      await Future<void>.delayed(const Duration(milliseconds: 800));

      final status = await AppTrackingTransparency.trackingAuthorizationStatus;
      debugPrint('📱 ATT current status: $status');

      if (status == TrackingStatus.notDetermined) {
        final result =
            await AppTrackingTransparency.requestTrackingAuthorization();
        debugPrint('📱 ATT request result: $result');
      }
    } catch (e) {
      debugPrint('📱 ATT request failed: $e');
    }
  }
}
