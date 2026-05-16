import 'package:flutter/material.dart';
import '../services/language_manager.dart';
import '../widgets/native_ad_widget.dart';

class AdsInterstitialFallbackScreen extends StatelessWidget {
  final VoidCallback onClose;

  const AdsInterstitialFallbackScreen({
    super.key,
    required this.onClose,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final theme = Theme.of(context);
    final lm = LanguageManager();
    final dimBackdrop = Color.alphaBlend(
      cs.onSurface.withValues(
        alpha: theme.brightness == Brightness.dark ? 0.12 : 0.06,
      ),
      cs.surface,
    );

    return Scaffold(
      backgroundColor: dimBackdrop,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  IconButton(
                    tooltip: lm.getText('close'),
                    onPressed: onClose,
                    icon: const Icon(Icons.close),
                  ),
                  Expanded(
                    child: Text(
                      lm.getText('adsInterstitialTitle'),
                      textAlign: TextAlign.center,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.w700,
                            color: cs.onSurface.withValues(alpha: 0.82),
                          ) ??
                          TextStyle(
                            fontWeight: FontWeight.w700,
                            fontSize: 15,
                            color: cs.onSurface.withValues(alpha: 0.82),
                          ),
                    ),
                  ),
                  const SizedBox(width: 48),
                ],
              ),
              const SizedBox(height: 8),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      lm.getText('adsInterstitialBodyLine1'),
                      textAlign: TextAlign.center,
                      style: theme.textTheme.bodySmall?.copyWith(
                            height: 1.4,
                            color: cs.onSurface.withValues(alpha: 0.78),
                          ) ??
                          TextStyle(
                            height: 1.4,
                            fontSize: 13,
                            color: cs.onSurface.withValues(alpha: 0.78),
                          ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      lm.getText('adsInterstitialBodyLine2'),
                      textAlign: TextAlign.center,
                      style: theme.textTheme.bodySmall?.copyWith(
                            height: 1.4,
                            color: cs.onSurface.withValues(alpha: 0.64),
                          ) ??
                          TextStyle(
                            height: 1.4,
                            fontSize: 12,
                            color: cs.onSurface.withValues(alpha: 0.64),
                          ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 10),
              Expanded(
                child: NativeAdWidget(
                  category: 'sponsored',
                  layout: NativeAdLayout.interstitialFallback,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
