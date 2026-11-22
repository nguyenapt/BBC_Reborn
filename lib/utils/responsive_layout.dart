import 'dart:ui' show DisplayFeatureType, DisplayFeatureState;

import 'package:flutter/widgets.dart';

/// Material-inspired window size classes for adaptive layouts.
enum WindowSizeClass { compact, medium, expanded }

class ResponsiveLayout {
  /// Phone / narrow pane.
  static const double compactMax = 600;

  /// Tablet / large phone landscape threshold for episode split.
  /// 700dp: iPad Mini portrait (~768) được split; pane hẹp đã xử lý bằng
  /// flex 5:5 + EpisodeInfoSlide cột dọc / ẩn banner khi <320.
  static const double episodeSplitMin = 700;

  /// Expanded (large tablet / desktop).
  static const double expandedMin = 840;

  static WindowSizeClass sizeClassOf(double width) {
    if (width >= expandedMin) return WindowSizeClass.expanded;
    if (width >= compactMax) return WindowSizeClass.medium;
    return WindowSizeClass.compact;
  }

  /// Vertical fold/hinge (Z Fold open, Duo) that suggests a two-pane layout.
  static bool hasVerticalFold(BuildContext context) {
    final features = MediaQuery.displayFeaturesOf(context);
    for (final f in features) {
      final isFoldOrHinge =
          f.type == DisplayFeatureType.fold ||
          f.type == DisplayFeatureType.hinge;
      if (!isFoldOrHinge) continue;
      if (f.state == DisplayFeatureState.postureFlat ||
          f.state == DisplayFeatureState.postureHalfOpened ||
          f.state == DisplayFeatureState.unknown) {
        // Vertical seam: taller than wide.
        if (f.bounds.height > f.bounds.width) return true;
      }
    }
    return false;
  }

  /// Gap (dp) to leave for a vertical hinge/fold, if any.
  static double hingeGapWidth(BuildContext context) {
    final features = MediaQuery.displayFeaturesOf(context);
    for (final f in features) {
      final isFoldOrHinge =
          f.type == DisplayFeatureType.fold ||
          f.type == DisplayFeatureType.hinge;
      if (!isFoldOrHinge) continue;
      if (f.bounds.height > f.bounds.width) {
        return f.bounds.width.clamp(0.0, 48.0);
      }
    }
    return 0;
  }

  /// Episode Detail: two-pane when wide enough or vertical fold present.
  static bool useEpisodeSplitLayout(
    BuildContext context, {
    double? width,
  }) {
    final w = width ?? MediaQuery.sizeOf(context).width;
    return w >= episodeSplitMin || hasVerticalFold(context);
  }
}
