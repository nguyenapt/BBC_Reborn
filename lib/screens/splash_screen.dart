import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/app_bootstrap_service.dart';
import '../services/language_manager.dart';
import 'onboarding_screen.dart';
import 'ads_support_notice_screen.dart';
import '../main.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  static const String _adsNoticeSeenKey = 'ads_notice_seen_v1';

  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _setupAnimations();
    _initializeApp();
  }

  void _setupAnimations() {
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 2000),
      vsync: this,
    );

    _fadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: const Interval(0.0, 0.6, curve: Curves.easeIn),
    ));

    _scaleAnimation = Tween<double>(
      begin: 0.5,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: const Interval(0.0, 0.6, curve: Curves.elasticOut),
    ));

    _animationController.forward();
  }

  Future<void> _initializeApp() async {
    try {
      debugPrint('🎬 Splash screen starting...');
      await AppBootstrapService.instance.ensureReadyForNavigation();
      debugPrint('🚀 Navigating to appropriate screen...');
      await _navigateToAppropriateScreen();
    } catch (e) {
      debugPrint('❌ Error in splash screen initialization: $e');
      if (mounted) {
        await _navigateToAppropriateScreen();
      }
    }
  }

  Future<void> _navigateToAppropriateScreen() async {
    final prefs = await SharedPreferences.getInstance();
    await _navigateToOnboardingOrMain(prefs);
  }

  Future<void> _navigateToOnboardingOrMain(SharedPreferences prefs) async {
    final isOnboardingCompleted =
        prefs.getBool('onboarding_completed') ?? false;
    final hasSeenAdsNotice = prefs.getBool(_adsNoticeSeenKey) ?? false;

    if (mounted) {
      if (isOnboardingCompleted) {
        if (!hasSeenAdsNotice) {
          Navigator.of(context).pushReplacement(
            MaterialPageRoute(
              builder: (context) => AdsSupportNoticeScreen(
                onContinue: (noticeContext) async {
                  final localPrefs = await SharedPreferences.getInstance();
                  await localPrefs.setBool(_adsNoticeSeenKey, true);
                  if (!noticeContext.mounted) return;
                  Navigator.of(noticeContext).pushReplacement(
                    MaterialPageRoute(
                      builder: (context) => const BBCLearningAppStateful(),
                    ),
                  );
                },
              ),
            ),
          );
        } else {
          Navigator.of(context).pushReplacement(
            MaterialPageRoute(
              builder: (context) => const BBCLearningAppStateful(),
            ),
          );
        }
      } else {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (context) => const OnboardingScreen()),
        );
      }
    }
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          color: Colors.black,
        ),
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              AnimatedBuilder(
                animation: _animationController,
                builder: (context, child) {
                  return FadeTransition(
                    opacity: _fadeAnimation,
                    child: ScaleTransition(
                      scale: _scaleAnimation,
                      child: Image.asset(
                        'assets/images/logo.png',
                        width: 220,
                        fit: BoxFit.contain,
                      ),
                    ),
                  );
                },
              ),
              const SizedBox(height: 32),
              FadeTransition(
                opacity: _fadeAnimation,
                child: Text(
                  LanguageManager().getText('appTitle'),
                  style: const TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                  ),
                ),
              ),
              const SizedBox(height: 8),
              FadeTransition(
                opacity: _fadeAnimation,
                child: Text(
                  'Listen. Engage. Own.',
                  style: TextStyle(
                    fontSize: 16,
                    color: Colors.white.withOpacity(0.8),
                  ),
                ),
              ),
              const SizedBox(height: 60),
              FadeTransition(
                opacity: _fadeAnimation,
                child: Column(
                  children: [
                    const SizedBox(
                      width: 32,
                      height: 32,
                      child: CircularProgressIndicator(
                        valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                        strokeWidth: 3,
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Loading...',
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.white.withOpacity(0.7),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
