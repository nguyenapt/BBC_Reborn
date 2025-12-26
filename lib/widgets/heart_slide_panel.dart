import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import '../services/heart_service.dart';
import '../services/admob_service.dart';

/// Widget hiển thị heart panel dạng slide từ trên xuống
class HeartSlidePanel extends StatelessWidget {
  const HeartSlidePanel({super.key});

  void _close(BuildContext context) {
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final heartService = HeartService();
    final admobService = AdMobService();

    return ListenableBuilder(
      listenable: heartService,
      builder: (context, child) {
        return Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Hearts display
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
              const SizedBox(height: 24),
              
              // Watch Ad Card (full width, larger size)
              if (heartService.canEarnMoreHearts && !kIsWeb)
                _buildActionCard(
                      context,
                      icon: Icons.play_circle_outline,
                      iconColor: Colors.blue.shade400,
                      backgroundColor: Colors.blue.shade50,
                      title: 'Watch Ad',
                      subtitle: 'Earn Heart',
                      enabled: true,
                      onTap: admobService.isRewardedAdReady()
                          ? () {
                              _close(context);
                              admobService.showRewardedAd(
                                onRewarded: () {
                                  heartService.earnHeart();
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                      content: Text('❤️ You earned 1 heart!'),
                                      backgroundColor: Colors.green,
                                      duration: Duration(seconds: 2),
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
                                const SnackBar(
                                  content: Text('Ad is loading, please try again in a moment'),
                                  duration: Duration(seconds: 2),
                                ),
                              );
                            },
                    ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildActionCard(
    BuildContext context, {
    required IconData icon,
    required Color iconColor,
    required Color backgroundColor,
    required String title,
    required String subtitle,
    required bool enabled,
    required VoidCallback? onTap,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: enabled ? onTap : null,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
          decoration: BoxDecoration(
            color: backgroundColor,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: enabled ? iconColor.withOpacity(0.3) : Colors.grey.shade300,
              width: 1.5,
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  color: iconColor.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(
                  icon,
                  color: enabled ? iconColor : Colors.grey.shade400,
                  size: 28,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: enabled ? Colors.grey.shade800 : Colors.grey.shade400,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      style: TextStyle(
                        fontSize: 13,
                        color: enabled ? Colors.grey.shade600 : Colors.grey.shade400,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.arrow_forward_ios,
                color: enabled ? iconColor : Colors.grey.shade400,
                size: 18,
              ),
            ],
          ),
        ),
      ),
    );
  }

}

