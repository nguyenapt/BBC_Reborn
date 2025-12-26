import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import '../services/heart_service.dart';
import '../services/admob_service.dart';

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
    
    return Dialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
      ),
      child: ListenableBuilder(
        listenable: heartService,
        builder: (context, child) {
          return Container(
            padding: const EdgeInsets.all(24),
            constraints: const BoxConstraints(maxWidth: 400),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Title
                Text(
                  'AI Hearts',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: Colors.red.shade600,
                  ),
                ),
                const SizedBox(height: 16),
                
                // Hearts display
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
                
                // Description
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
                  'Each AI feature (translate, vocabulary, grammar...) uses 1 heart',
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
                
                // Watch ad button (only show if hearts < max)
                if (heartService.canEarnMoreHearts && !kIsWeb)
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: admobService.isRewardedAdReady()
                          ? () {
                              Navigator.of(context).pop(); // Close dialog first
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
                              // Ad not ready, try to load
                              admobService.createRewardedAd();
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text('Ad is loading, please try again in a moment'),
                                  duration: Duration(seconds: 2),
                                ),
                              );
                            },
                      icon: const Icon(Icons.play_circle_outline),
                      label: const Text('Watch Ad to Earn Heart'),
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
                
                // Close button
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

