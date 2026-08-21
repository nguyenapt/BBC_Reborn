import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../services/admob_service.dart';
import '../services/ai/ai_error_handler.dart';
import '../services/ai/exceptions.dart';
import '../services/heart_service.dart';
import '../services/language_manager.dart';

/// Bottom sheets / snackbars for Episode Pass, credits, speaking ticket, soft cap.
class HeartEconomyUi {
  HeartEconomyUi._();

  static final _lm = LanguageManager();

  /// Handle economy-related exceptions; returns true if handled (caller should not show generic snackbar).
  static Future<bool> handleError(
    BuildContext context,
    dynamic error, {
    required VoidCallback onRetry,
    String? episodeId,
  }) async {
    if (!context.mounted) return false;
    final hearts = HeartService();

    if (error is NeedsEpisodePassException) {
      final id = episodeId ?? error.episodeId;
      final ok = await showOpenEpisodePassSheet(context, id);
      if (ok && context.mounted) {
        onRetry();
      }
      return true;
    }

    if (error is NoEpisodeCreditsException) {
      final id = episodeId ?? error.episodeId;
      final ok = await showRefillEpisodeCreditsSheet(context, id);
      if (ok && context.mounted) {
        onRetry();
      }
      return true;
    }

    if (error is NeedsSpeakingTicketException) {
      final ok = await showOpenSpeakingTicketSheet(context);
      if (ok && context.mounted) {
        onRetry();
      }
      return true;
    }

    if (error is NoSpeakingAttemptsException) {
      final ok = await showRefillSpeakingTicketSheet(context);
      if (ok && context.mounted) {
        onRetry();
      }
      return true;
    }

    if (error is DailyLiveAiCapException) {
      await showDailyLiveCapSheet(context, episodeId: episodeId);
      return true;
    }

    if (error is NoHeartsException) {
      await showNoHeartsSheet(context, onRetry: onRetry);
      return true;
    }

    // Low-credits nudge (optional) — not an exception path.
    if (hearts.allowCredit &&
        episodeId != null &&
        hearts.episodeCreditsRemaining(episodeId) > 0 &&
        hearts.episodeCreditsRemaining(episodeId) <= 3 &&
        hearts.shouldShowPassOpenedHint(episodeId)) {
      // no-op here; use maybeShowCreditsSnack after success
    }

    return false;
  }

  static Future<void> maybeShowCreditsSnack(
    BuildContext context,
    String episodeId,
  ) async {
    final hearts = HeartService();
    if (!hearts.allowCredit || !context.mounted) return;
    if (!hearts.shouldShowPassOpenedHint(episodeId)) return;
    final left = hearts.episodeCreditsRemaining(episodeId);
    if (left <= 0) return;
    await hearts.markPassOpenedHintShown(episodeId);
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          _lm.getTextWithParams('heartCreditsRemaining', {'count': left}),
        ),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  static Future<bool> showOpenEpisodePassSheet(
    BuildContext context,
    String episodeId,
  ) async {
    final hearts = HeartService();
    final credits = hearts.config.creditNumber;
    final result = await showModalBottomSheet<bool>(
      context: context,
      showDragHandle: true,
      useSafeArea: true,
      builder: (ctx) {
        return _sheetPadding(
          ctx,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                _lm.getText('heartOpenPassTitle'),
                style: Theme.of(ctx).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
              ),
              const SizedBox(height: 8),
              Text(
                _lm.getTextWithParams('heartOpenPassBody', {
                  'credits': credits,
                }),
                style: TextStyle(
                  color: Theme.of(ctx).colorScheme.onSurface.withValues(alpha: 0.75),
                  height: 1.35,
                ),
              ),
              const SizedBox(height: 20),
              FilledButton(
                onPressed: hearts.hasHearts
                    ? () async {
                        final ok = await hearts
                            .openOrRefillEpisodePassWithHeart(episodeId);
                        if (ctx.mounted) Navigator.pop(ctx, ok);
                      }
                    : null,
                child: Text(
                  _lm.getTextWithParams('heartUseOneHeart', {
                    'credits': credits,
                  }),
                ),
              ),
              TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: Text(_lm.getText('cancel')),
              ),
            ],
          ),
        );
      },
    );
    return result == true;
  }

  static Future<bool> showRefillEpisodeCreditsSheet(
    BuildContext context,
    String episodeId,
  ) async {
    final hearts = HeartService();
    final admob = AdMobService();
    final rewardedCredits = hearts.config.rewardedCredits;
    final canHeartRefill = hearts.canHeartRefillEpisode(episodeId);

    final result = await showModalBottomSheet<bool>(
      context: context,
      showDragHandle: true,
      useSafeArea: true,
      builder: (ctx) {
        return _sheetPadding(
          ctx,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                _lm.getText('heartNoCreditsTitle'),
                style: Theme.of(ctx).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
              ),
              const SizedBox(height: 8),
              Text(
                _lm.getTextWithParams('heartNoCreditsBody', {
                  'adCredits': rewardedCredits,
                  'credits': rewardedCredits,
                }),
                style: TextStyle(
                  color: Theme.of(ctx)
                      .colorScheme
                      .onSurface
                      .withValues(alpha: 0.75),
                ),
              ),
              const SizedBox(height: 16),
              if (!kIsWeb)
                FilledButton(
                  onPressed: hearts.canAdRefillEpisodeCredits(episodeId)
                      ? () {
                          _showRewarded(
                            ctx,
                            admob,
                            onRewarded: () async {
                              final ok = await hearts
                                  .refillEpisodeCreditsWithAd(episodeId);
                              if (ctx.mounted) Navigator.pop(ctx, ok);
                            },
                          );
                        }
                      : null,
                  child: Text(
                    _lm.getTextWithParams('heartWatchAdCredits', {
                      'credits': rewardedCredits,
                    }),
                  ),
                ),
              if (canHeartRefill) ...[
                const SizedBox(height: 8),
                OutlinedButton(
                  onPressed: () async {
                    final ok = await hearts
                        .openOrRefillEpisodePassWithHeart(episodeId);
                    if (ctx.mounted) Navigator.pop(ctx, ok);
                  },
                  child: Text(
                    _lm.getTextWithParams('heartRefillWithHeart', {
                      'credits': rewardedCredits,
                    }),
                  ),
                ),
              ],
              TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: Text(_lm.getText('cancel')),
              ),
            ],
          ),
        );
      },
    );
    return result == true;
  }

  static Future<bool> showOpenSpeakingTicketSheet(BuildContext context) async {
    final hearts = HeartService();
    final n = hearts.config.speakingTicketNumber;
    final result = await showModalBottomSheet<bool>(
      context: context,
      showDragHandle: true,
      useSafeArea: true,
      builder: (ctx) {
        return _sheetPadding(
          ctx,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                _lm.getText('heartSpeakingTicketTitle'),
                style: Theme.of(ctx).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
              ),
              const SizedBox(height: 8),
              Text(
                _lm.getTextWithParams('heartSpeakingTicketBody', {'count': n}),
              ),
              const SizedBox(height: 16),
              FilledButton(
                onPressed: hearts.hasHearts
                    ? () async {
                        final ok =
                            await hearts.openOrRefillSpeakingTicketWithHeart();
                        if (ctx.mounted) Navigator.pop(ctx, ok);
                      }
                    : null,
                child: Text(
                  _lm.getTextWithParams('heartSpeakingUseHeart', {'count': n}),
                ),
              ),
              TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: Text(_lm.getText('cancel')),
              ),
            ],
          ),
        );
      },
    );
    return result == true;
  }

  static Future<bool> showRefillSpeakingTicketSheet(BuildContext context) async {
    final hearts = HeartService();
    final admob = AdMobService();
    final n = hearts.config.speakingTicketNumber;
    final result = await showModalBottomSheet<bool>(
      context: context,
      showDragHandle: true,
      useSafeArea: true,
      builder: (ctx) {
        return _sheetPadding(
          ctx,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                _lm.getText('heartSpeakingNoAttemptsTitle'),
                style: Theme.of(ctx).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
              ),
              const SizedBox(height: 16),
              FilledButton(
                onPressed: hearts.hasHearts
                    ? () async {
                        final ok =
                            await hearts.openOrRefillSpeakingTicketWithHeart();
                        if (ctx.mounted) Navigator.pop(ctx, ok);
                      }
                    : null,
                child: Text(
                  _lm.getTextWithParams('heartSpeakingUseHeart', {'count': n}),
                ),
              ),
              const SizedBox(height: 8),
              if (!kIsWeb)
                OutlinedButton(
                  onPressed: hearts.canAdTopup
                      ? () {
                          _showRewarded(
                            ctx,
                            admob,
                            onRewarded: () async {
                              final ok =
                                  await hearts.refillSpeakingTicketWithAd();
                              if (ctx.mounted) Navigator.pop(ctx, ok);
                            },
                          );
                        }
                      : null,
                  child: Text(
                    _lm.getTextWithParams('heartSpeakingWatchAd', {'count': n}),
                  ),
                ),
              TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: Text(_lm.getText('cancel')),
              ),
            ],
          ),
        );
      },
    );
    return result == true;
  }

  static Future<void> showDailyLiveCapSheet(
    BuildContext context, {
    String? episodeId,
  }) async {
    final hearts = HeartService();
    final admob = AdMobService();
    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      useSafeArea: true,
      builder: (ctx) {
        return _sheetPadding(
          ctx,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                _lm.getText('heartDailyCapTitle'),
                style: Theme.of(ctx).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
              ),
              const SizedBox(height: 8),
              Text(_lm.getText('heartDailyCapBody')),
              const SizedBox(height: 16),
              if (!kIsWeb &&
                  episodeId != null &&
                  hearts.canAdRefillEpisodeCredits(episodeId))
                OutlinedButton(
                  onPressed: () {
                    _showRewarded(
                      ctx,
                      admob,
                      onRewarded: () async {
                        await hearts.topUpCreditsPastLiveCapWithAd(episodeId);
                        if (ctx.mounted) Navigator.pop(ctx);
                      },
                    );
                  },
                  child: Text(
                    _lm.getTextWithParams('heartWatchAdCredits', {
                      'credits': hearts.config.rewardedCredits,
                    }),
                  ),
                ),
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: Text(_lm.getText('cancel')),
              ),
            ],
          ),
        );
      },
    );
  }

  static Future<void> showNoHeartsSheet(
    BuildContext context, {
    VoidCallback? onRetry,
  }) async {
    final hearts = HeartService();
    final admob = AdMobService();
    final reward = hearts.config.rewardedHearts;

    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      useSafeArea: true,
      builder: (ctx) {
        return _sheetPadding(
          ctx,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                _lm.getText('noHeartsAvailable'),
                style: Theme.of(ctx).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
              ),
              const SizedBox(height: 16),
              if (!kIsWeb && hearts.canEarnMoreHearts)
                FilledButton(
                  onPressed: () {
                    _showRewarded(
                      ctx,
                      admob,
                      onRewarded: () async {
                        final added = await hearts.earnRewardedHearts();
                        if (ctx.mounted) {
                          Navigator.pop(ctx);
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(
                                _lm.getTextWithParams('heartEarnedCount', {
                                  'count': added,
                                }),
                              ),
                              backgroundColor: Colors.green,
                            ),
                          );
                          onRetry?.call();
                        }
                      },
                    );
                  },
                  child: Text(
                    _lm.getTextWithParams('heartWatchAdHearts', {
                      'count': reward,
                    }),
                  ),
                ),
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: Text(_lm.getText('cancel')),
              ),
            ],
          ),
        );
      },
    );
  }

  /// Padding đáy theo viewPadding (Android edge-to-edge / gesture nav).
  static Widget _sheetPadding(BuildContext context, {required Widget child}) {
    final mq = MediaQuery.of(context);
    // padding.bottom có thể = 0 khi hệ thống đã “ăn” inset; viewPadding vẫn đúng.
    final bottom =
        mq.padding.bottom > 0 ? mq.padding.bottom : mq.viewPadding.bottom;
    return Padding(
      padding: EdgeInsets.fromLTRB(20, 8, 20, 16 + bottom),
      child: child,
    );
  }

  static void _showRewarded(
    BuildContext context,
    AdMobService admob, {
    required Future<void> Function() onRewarded,
  }) {
    if (admob.isRewardedAdReady()) {
      admob.showRewardedAd(
        onRewarded: () {
          onRewarded();
        },
        onAdFailedToShow: (error) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Failed to show ad: $error'),
              backgroundColor: Theme.of(context).colorScheme.error,
            ),
          );
        },
      );
    } else {
      admob.createRewardedAd();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(_lm.getText('adLoadingTryAgain')),
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }

  /// Fallback message helper when not using sheets.
  static String messageFor(dynamic error) =>
      AIErrorHandler.getErrorMessage(error);
}
