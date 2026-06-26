import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import '../services/heart_service.dart';
import '../services/admob_service.dart';
import '../services/language_manager.dart';

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
    final languageManager = LanguageManager();

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
              const SizedBox(height: 12),
              Text(
                languageManager.getText('heartEarnHint'),
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 13,
                  color: Theme.of(context).colorScheme.onSurface.withOpacity(0.7),
                  height: 1.35,
                ),
              ),
              const SizedBox(height: 16),
              
              // Watch Ad Button (chỉ hiển thị khi heart < 5)
              if (heartService.hearts < 5 && !kIsWeb)
                _buildWatchAdButton(
                  context,
                  admobService: admobService,
                  heartService: heartService,
                  onClose: () => _close(context),
                ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildWatchAdButton(
    BuildContext context, {
    required AdMobService admobService,
    required HeartService heartService,
    required VoidCallback onClose,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: admobService.isRewardedAdReady()
            ? () {
                onClose();
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
        borderRadius: BorderRadius.circular(12),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          decoration: BoxDecoration(
            color: Colors.red.shade600, // Bright red như trong hình
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Play icon trắng trong vòng tròn
              Container(
                width: 24,
                height: 24,
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.2),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.play_arrow,
                  color: Colors.white,
                  size: 16,
                ),
              ),
              const SizedBox(width: 12),
              // Text trắng
              const Text(
                'Watch ad to recover hearts',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: Colors.white,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

}

