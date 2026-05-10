import 'package:flutter/material.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

/// [NativeTemplateStyle] derived from app [ColorScheme] for light/dark consistency.
NativeTemplateStyle nativeTemplateStyleForColorScheme(
  ColorScheme scheme, {
  required TemplateType templateType,
  double cornerRadius = 12,
}) {
  final surface = scheme.surface;
  final onSurface = scheme.onSurface;
  final secondaryMuted =
      Color.alphaBlend(onSurface.withValues(alpha: 0.62), surface);
  final tertiaryMuted =
      Color.alphaBlend(onSurface.withValues(alpha: 0.5), surface);

  return NativeTemplateStyle(
    templateType: templateType,
    mainBackgroundColor: surface,
    cornerRadius: cornerRadius,
    callToActionTextStyle: NativeTemplateTextStyle(
      textColor: scheme.onPrimary,
      backgroundColor: scheme.primary,
      style: NativeTemplateFontStyle.bold,
      size: 16.0,
    ),
    primaryTextStyle: NativeTemplateTextStyle(
      textColor: onSurface,
      style: NativeTemplateFontStyle.bold,
      size: 16.0,
    ),
    secondaryTextStyle: NativeTemplateTextStyle(
      textColor: secondaryMuted,
      style: NativeTemplateFontStyle.normal,
      size: 14.0,
    ),
    tertiaryTextStyle: NativeTemplateTextStyle(
      textColor: tertiaryMuted,
      style: NativeTemplateFontStyle.normal,
      size: 12.0,
    ),
  );
}
