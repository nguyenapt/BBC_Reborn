import 'package:flutter/material.dart';
import '../services/language_manager.dart';

class AdsSupportNoticeScreen extends StatelessWidget {
  final Future<void> Function(BuildContext context) onContinue;

  const AdsSupportNoticeScreen({
    super.key,
    required this.onContinue,
  });

  @override
  Widget build(BuildContext context) {
    final languageManager = LanguageManager();
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    return Scaffold(
      backgroundColor: cs.surface,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 24, 24, 24),
          child: Column(
            children: [
              const Spacer(),
              Container(
                width: 200,
                height: 200,
                decoration: BoxDecoration(
                  color: cs.primary.withOpacity(0.14),
                  shape: BoxShape.circle,
                ),
                child: Center(
                  child: Icon(
                    Icons.campaign_outlined,
                    color: cs.primary,
                    size: 86,
                  ),
                ),
              ),
              const SizedBox(height: 44),
              Text(
                languageManager.getText('adsInterstitialTitle'),
                textAlign: TextAlign.center,
                style: theme.textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w800,
                  color: cs.onSurface,
                ),
              ),
              const SizedBox(height: 14),
              Text(
                languageManager.getText('adsInterstitialBodyLine1'),
                textAlign: TextAlign.center,
                style: theme.textTheme.bodyLarge?.copyWith(
                  color: cs.onSurface.withOpacity(0.8),
                  height: 1.45,
                ),
              ),
              const SizedBox(height: 14),
              Text(
                languageManager.getText('adsInterstitialBodyLine2'),
                textAlign: TextAlign.center,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: cs.onSurface.withOpacity(0.72),
                  height: 1.45,
                ),
              ),
              const Spacer(),
              SizedBox(
                width: double.infinity,
                height: 52,
                child: FilledButton(
                  onPressed: () => onContinue(context),
                  style: FilledButton.styleFrom(
                    backgroundColor: cs.primary,
                    foregroundColor: cs.onPrimary,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  child: Text(
                    languageManager.getText('adsInterstitialCta'),
                    style: TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w700,
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
