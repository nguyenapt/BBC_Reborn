import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import '../services/heart_service.dart';
import '../services/admob_service.dart';
import '../services/language_manager.dart';

/// Dialog hiển thị thông tin hearts và nút xem quảng cáo
class HeartDialog extends StatelessWidget {
  const HeartDialog({super.key});

  static void show(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => const HeartDialog(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final heartService = HeartService();
    final admobService = AdMobService();
    final lm = LanguageManager();

    return Dialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
      ),
      child: ListenableBuilder(
        listenable: heartService,
        builder: (context, child) {
          final cfg = heartService.config;
          final desc = heartService.allowCredit
              ? lm.getTextWithParams('heartEarnHintCredit', {
                  'credits': cfg.creditNumber,
                  'speaking': cfg.speakingTicketNumber,
                  'rewardHearts': cfg.rewardedHearts,
                })
              : lm.getText('heartEarnHintLegacy');

          return Container(
            padding: const EdgeInsets.all(24),
            constraints: const BoxConstraints(maxWidth: 400),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'AI Hearts',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: Colors.red.shade600,
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: List.generate(
                    heartService.maxHearts,
                    (index) => Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 4),
                      child: Icon(
                        Icons.favorite,
                        color: index < heartService.hearts
                            ? Colors.red.shade400
                            : Colors.grey.shade300,
                        size: 32,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  'You have ${heartService.hearts} out of ${heartService.maxHearts} hearts',
                  style: TextStyle(
                    fontSize: 16,
                    color: Colors.grey.shade700,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),
                Text(
                  desc,
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey.shade600,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),
                Text(
                  'Hearts reset daily at midnight',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey.shade500,
                    fontStyle: FontStyle.italic,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 24),
                if (heartService.canEarnMoreHearts && !kIsWeb)
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: admobService.isRewardedAdReady()
                          ? () {
                              Navigator.of(context).pop();
                              admobService.showRewardedAd(
                                onRewarded: () async {
                                  final added =
                                      await heartService.earnRewardedHearts();
                                  if (!context.mounted) return;
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text(
                                        lm.getTextWithParams(
                                          'heartEarnedCount',
                                          {'count': added},
                                        ),
                                      ),
                                      backgroundColor: Colors.green,
                                      duration: const Duration(seconds: 2),
                                    ),
                                  );
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
                          : () {
                              admobService.createRewardedAd();
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text(lm.getText('adLoadingTryAgain')),
                                  duration: const Duration(seconds: 2),
                                ),
                              );
                            },
                      icon: const Icon(Icons.play_circle_outline),
                      label: Text(
                        lm.getTextWithParams(
                          'heartWatchAdHearts',
                          {'count': cfg.rewardedHearts},
                        ),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.red.shade400,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                  ),
                if (heartService.canEarnMoreHearts && !kIsWeb)
                  const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: TextButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: const Text('Close'),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
