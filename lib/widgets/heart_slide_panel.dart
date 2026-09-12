import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import '../services/heart_service.dart';
import '../services/admob_service.dart';
import '../services/language_manager.dart';

/// Panel slide từ trên xuống.
/// - Không [episodeId] / chưa mở Pass → panel **tim**
/// - Có [episodeId] và Pass đã mở → panel **credits** episode
class HeartSlidePanel extends StatelessWidget {
  const HeartSlidePanel({super.key, this.episodeId});

  final String? episodeId;

  void _close(BuildContext context) {
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final heartService = HeartService();
    final admobService = AdMobService();
    final languageManager = LanguageManager();

    return ListenableBuilder(
      listenable: heartService,
      builder: (context, child) {
        final ep = episodeId;
        final creditMode =
            ep != null && heartService.shouldShowEpisodeCreditBadge(ep);

        if (creditMode) {
          return _buildCreditPanel(
            context,
            episodeId: ep,
            heartService: heartService,
            admobService: admobService,
            languageManager: languageManager,
          );
        }

        return _buildHeartsPanel(
          context,
          heartService: heartService,
          admobService: admobService,
          languageManager: languageManager,
        );
      },
    );
  }

  Widget _buildHeartsPanel(
    BuildContext context, {
    required HeartService heartService,
    required AdMobService admobService,
    required LanguageManager languageManager,
  }) {
    final cfg = heartService.config;
    final hint = heartService.allowCredit
        ? languageManager.getTextWithParams('heartEarnHintCredit', {
            'credits': cfg.creditNumber,
            'speaking': cfg.speakingTicketNumber,
            'rewardHearts': cfg.rewardedHearts,
          })
        : languageManager.getText('heartEarnHintLegacy');

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(
              heartService.maxHearts,
              (index) => Padding(
                padding: const EdgeInsets.symmetric(horizontal: 3),
                child: Icon(
                  Icons.favorite,
                  color: index < heartService.hearts
                      ? Colors.red.shade400
                      : Colors.grey.shade300,
                  size: 24,
                ),
              ),
            ),
          ),
          const SizedBox(height: 12),
          Text(
            hint,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 13,
              color: Theme.of(context)
                  .colorScheme
                  .onSurface
                  .withValues(alpha: 0.7),
              height: 1.35,
            ),
          ),
          const SizedBox(height: 16),
          if (heartService.canEarnMoreHearts && !kIsWeb)
            _buildPrimaryButton(
              context,
              color: Colors.red.shade600,
              label: languageManager.getTextWithParams(
                'heartWatchAdHearts',
                {'count': heartService.config.rewardedHearts},
              ),
              onTap: () => _runRewarded(
                context,
                admobService: admobService,
                languageManager: languageManager,
                onRewarded: () async {
                  final added = await heartService.earnRewardedHearts();
                  if (!context.mounted) return;
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                        languageManager.getTextWithParams(
                          'heartEarnedCount',
                          {'count': added},
                        ),
                      ),
                      backgroundColor: Colors.green,
                      duration: const Duration(seconds: 2),
                    ),
                  );
                },
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildCreditPanel(
    BuildContext context, {
    required String episodeId,
    required HeartService heartService,
    required AdMobService admobService,
    required LanguageManager languageManager,
  }) {
    final cfg = heartService.config;
    final left = heartService.episodeCreditsRemaining(episodeId);
    final canHeartRefill = heartService.canHeartRefillEpisode(episodeId);
    final canAd =
        heartService.canAdRefillEpisodeCredits(episodeId) && !kIsWeb;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.bolt_rounded, color: Colors.teal.shade500, size: 28),
          const SizedBox(height: 6),
          Text(
            languageManager.getTextWithParams(
              'heartCreditsRemaining',
              {'count': left},
            ),
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: Colors.teal.shade700,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            languageManager.getTextWithParams('heartCreditPanelHint', {
              'adCredits': cfg.rewardedCredits,
            }),
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 13,
              color: Theme.of(context)
                  .colorScheme
                  .onSurface
                  .withValues(alpha: 0.7),
              height: 1.35,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            languageManager.getTextWithParams('heartCreditPanelHeartsLeft', {
              'hearts': heartService.hearts,
              'max': heartService.maxHearts,
            }),
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 12,
              color: Theme.of(context)
                  .colorScheme
                  .onSurface
                  .withValues(alpha: 0.55),
            ),
          ),
          const SizedBox(height: 16),
          if (canAd)
            _buildPrimaryButton(
              context,
              color: Colors.teal.shade600,
              label: languageManager.getTextWithParams(
                'heartWatchAdCredits',
                {'credits': cfg.rewardedCredits},
              ),
              onTap: () => _runRewarded(
                context,
                admobService: admobService,
                languageManager: languageManager,
                onRewarded: () async {
                  final ok = await heartService
                      .refillEpisodeCreditsWithAd(episodeId);
                  if (!context.mounted || !ok) return;
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                        languageManager.getTextWithParams(
                          'heartCreditsEarnedCount',
                          {'count': cfg.rewardedCredits},
                        ),
                      ),
                      backgroundColor: Colors.teal.shade700,
                      duration: const Duration(seconds: 2),
                    ),
                  );
                },
              ),
            ),
          if (left <= 0 && canHeartRefill) ...[
            if (canAd) const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              child: _buildOutlinedButton(
                context,
                label: languageManager.getTextWithParams(
                  'heartRefillWithHeart',
                  {'credits': cfg.rewardedCredits},
                ),
                onTap: () async {
                  final ok = await heartService
                      .openOrRefillEpisodePassWithHeart(episodeId);
                  if (!context.mounted) return;
                  _close(context);
                  if (ok) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(
                          languageManager.getTextWithParams(
                            'heartCreditsEarnedCount',
                            {'count': cfg.rewardedCredits},
                          ),
                        ),
                        backgroundColor: Colors.teal.shade700,
                        duration: const Duration(seconds: 2),
                      ),
                    );
                  }
                },
              ),
            ),
          ],
        ],
      ),
    );
  }

  void _runRewarded(
    BuildContext context, {
    required AdMobService admobService,
    required LanguageManager languageManager,
    required Future<void> Function() onRewarded,
  }) {
    if (!admobService.isRewardedAdReady()) {
      admobService.createRewardedAd();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(languageManager.getText('adLoadingTryAgain')),
          duration: const Duration(seconds: 2),
        ),
      );
      return;
    }

    _close(context);
    admobService.showRewardedAd(
      onRewarded: () async {
        await onRewarded();
      },
      onAdFailedToShow: (error) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to show ad: $error'),
            backgroundColor: Colors.red,
          ),
        );
      },
    );
  }

  Widget _buildPrimaryButton(
    BuildContext context, {
    required Color color,
    required String label,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 24,
                height: 24,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.2),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.play_arrow,
                  color: Colors.white,
                  size: 16,
                ),
              ),
              const SizedBox(width: 12),
              Flexible(
                child: Text(
                  label,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildOutlinedButton(
    BuildContext context, {
    required String label,
    required VoidCallback onTap,
  }) {
    return OutlinedButton(
      onPressed: onTap,
      style: OutlinedButton.styleFrom(
        foregroundColor: Colors.teal.shade700,
        side: BorderSide(color: Colors.teal.shade300),
        padding: const EdgeInsets.symmetric(vertical: 14),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
      child: Text(
        label,
        style: const TextStyle(fontWeight: FontWeight.w600),
        textAlign: TextAlign.center,
      ),
    );
  }
}
