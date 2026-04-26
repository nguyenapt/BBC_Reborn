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
    final lm = LanguageManager();

    return Scaffold(
      backgroundColor: cs.surface,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(18, 14, 18, 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Align(
                alignment: Alignment.topRight,
                child: IconButton(
                  tooltip: lm.getText('close'),
                  onPressed: onClose,
                  icon: const Icon(Icons.close),
                ),
              ),
              Text(
                lm.getText('adsInterstitialTitle'),
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w800,
                      color: cs.onSurface,
                    ),
              ),
              const SizedBox(height: 10),
              Text(
                lm.getText('adsInterstitialBodyLine1'),
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: cs.onSurface.withOpacity(0.82),
                      height: 1.45,
                    ),
              ),
              const SizedBox(height: 6),
              Text(
                lm.getText('adsInterstitialBodyLine2'),
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: cs.onSurface.withOpacity(0.75),
                      height: 1.45,
                    ),
              ),
              const SizedBox(height: 18),
              Expanded(
                child: Center(
                  child: SizedBox(
                    height: 360,
                    width: 420,
                    child: Card(
                      margin: EdgeInsets.zero,
                      clipBehavior: Clip.antiAlias,
                      child: const NativeAdWidget(category: 'sponsored'),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
