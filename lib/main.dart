import 'dart:async';
import 'dart:io';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'screens/home_page.dart';
import 'screens/categories_screen.dart';
import 'screens/saved_screen.dart';
import 'screens/settings_screen.dart';
import 'screens/grammar_screen.dart';
import 'services/language_manager.dart';
import 'services/audio_player_service.dart';
import 'services/navigation_service.dart';
import 'services/admob_service.dart';
import 'services/vocabulary_service.dart';
import 'services/rate_app_service.dart';
import 'services/saved_grammar_service.dart';
import 'services/learning_progress_service.dart';
import 'services/vocabulary_practice_service.dart';
import 'services/review_reminder_service.dart';
import 'services/speaking_review_service.dart';
import 'screens/splash_screen.dart';
import 'utils/double_back_exit.dart';
import 'services/back_navigation_service.dart';
import 'services/push_notification_service.dart';
import 'firebase_options.dart';
import 'widgets/app_update_prompt.dart';
import 'theme/app_theme.dart';
import 'widgets/floating_bottom_nav_bar.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  debugPrint('🚀 App starting...');

  await LanguageManager().initialize();

  if (!kIsWeb && (Platform.isAndroid || Platform.isIOS)) {
    await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
    FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);
  }

  debugPrint('🏃‍♂️ Running app...');
  runApp(const BBCLearningApp());
}

class BBCLearningApp extends StatelessWidget {
  const BBCLearningApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: LanguageManager(),
      builder: (context, child) {
        return MaterialApp(
          navigatorKey: NavigationService.navigatorKey,
          title: '6 Mins Learning English Online',
          localizationsDelegates: const [
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          supportedLocales: LanguageManager.supportedLocales,
          locale: LanguageManager().currentLocale,
          themeMode: LanguageManager().themeMode,
          theme: AppTheme.light(LanguageManager().textScaleFactor),
          darkTheme: AppTheme.dark(LanguageManager().textScaleFactor),
          home: const SplashScreen(),
        );
      },
    );
  }
}

class BBCLearningAppStateful extends StatefulWidget {
  const BBCLearningAppStateful({super.key});

  @override
  State<BBCLearningAppStateful> createState() => _BBCLearningAppStatefulState();
}

class _BBCLearningAppStatefulState extends State<BBCLearningAppStateful> 
    with WidgetsBindingObserver, DoubleBackExitMixin {
  static const Duration _appOpenStartupDelay = Duration(milliseconds: 2500);
  static const Duration _appOpenResumeBackgroundThreshold = Duration(minutes: 5);
  static const Duration _appOpenShowAttemptDelay = Duration(milliseconds: 900);

  int currentPageIndex = 0;
  String? categoriesInitialTab;
  String? grammarInitialTab;
  bool scrollMyHubToDailyGoal = false;
  DateTime? _lastBackgroundAt;
  bool _didShowReviewReminderThisSession = false;

  void navigateToCategoriesWithTab(String tabName) {
    setState(() {
      categoriesInitialTab = tabName;
      currentPageIndex = 1; // Categories tab index
    });
  }

  void navigateToGrammarWithTab(String tabName) {
    setState(() {
      grammarInitialTab = tabName;
      currentPageIndex = 3; // Grammar tab index
    });
  }

  void navigateToMyHubDailyGoal() {
    setState(() {
      scrollMyHubToDailyGoal = true;
      currentPageIndex = 2; // My Hub
    });
  }

  Future<void> _checkAndShowRateDialog() async {
    try {
      if (await RateAppService.shouldShowRatePrompt()) {
        if (!mounted) return;
        await RateAppService.incrementPromptCount();
        if (!mounted) return;
        await RateAppService.showRateDialog(context);
      }
    } catch (e) {
      debugPrint('Error showing rate dialog: $e');
    }
  }

  Future<void> _tryShowAppOpenAd({required String trigger}) async {
    if (kIsWeb || !mounted) return;
    final adService = AdMobService();
    await adService.preloadAppOpenAd();
    await Future.delayed(_appOpenShowAttemptDelay);
    if (!mounted) return;
    await adService.showAppOpenAdIfReady(trigger: trigger);
  }

  Future<void> _syncStreakReminder() async {
    try {
      final progress = LearningProgressService();
      final grammar = SavedGrammarService();
      final vocabPractice = VocabularyPracticeService();
      final speakingReview = SpeakingReviewService();
      await vocabPractice.initialize();

      final vocabItems = VocabularyService().savedVocabularies;
      final word = await vocabPractice.pickWordOfTheDayCached(vocabItems);
      final dueSpeaking = speakingReview.dueReviewItems;

      await ReviewReminderService().syncAllLocalReminders(
        isActiveToday: progress.isActiveToday,
        grammarItems: grammar.dueReviewItems,
        wordOfTheDay: word?.vocab,
        speakingDueCount: dueSpeaking.length,
        speakingEpisodeTitle:
            dueSpeaking.isNotEmpty ? dueSpeaking.first.episodeTitle : null,
      );
    } catch (e) {
      debugPrint('syncStreakReminder error: $e');
    }
  }

  Future<void> _checkAndShowReviewReminder() async {
    if (!mounted || _didShowReviewReminderThisSession) return;
    final dueItems = SavedGrammarService().dueReviewItems;
    if (dueItems.isEmpty) return;

    _didShowReviewReminderThisSession = true;
    await Future.delayed(const Duration(milliseconds: 400));
    if (!mounted) return;
    final languageManager = LanguageManager();
    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (sheetContext) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  languageManager.getText('reviewQueueLabel'),
                  style: Theme.of(sheetContext).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                ),
                const SizedBox(height: 8),
                Text(
                  '${languageManager.getText('reviewDueNow')}: ${dueItems.length}',
                  style: Theme.of(sheetContext).textTheme.bodyMedium,
                ),
                const SizedBox(height: 14),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => Navigator.of(sheetContext).pop(),
                        child: Text(languageManager.getText('later')),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: () {
                          Navigator.of(sheetContext).pop();
                          setState(() {
                            currentPageIndex = 2; // My Learning
                          });
                        },
                        child: Text(languageManager.getText('reviewNowLabel')),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    
    // Set callback để reset back timer (cho double back exit)
    BackNavigationService().setResetBackTimerCallback(() {
      resetBackTimer();
    });
    
    // Khởi tạo dữ liệu cho rate app service
    RateAppService.initializeForNewUser();
    
    // App Open policy cân bằng:
    // - Cold start: thử hiển thị sau khi UI ổn định.
    // - Resume: chỉ thử khi app ở background đủ lâu.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      unawaited(PushNotificationService.instance.processPendingLaunchNotification());

      Future.delayed(_appOpenStartupDelay, () {
        if (mounted) {
          _tryShowAppOpenAd(trigger: 'startup');
        }
      });
      Future.delayed(const Duration(milliseconds: 1800), () {
        if (mounted) {
          _checkAndShowReviewReminder();
          _syncStreakReminder();
        }
      });
      
      // Hiển thị popup rate app nếu cần
      Future.delayed(const Duration(milliseconds: 5000), () {
        if (mounted) {
          _checkAndShowRateDialog();
        }
      });

      // Kiểm tra bản cập nhật (RTDB AppUpdate) sau khi shell ổn định
      Future.delayed(const Duration(milliseconds: 1200), () {
        if (!kIsWeb && mounted) {
          AppUpdateCoordinator.checkAndPrompt(context);
        }
      });
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);

    // Xử lý audio player khi có cuộc gọi điện thoại
    AudioPlayerService().handleAppLifecycleChange(state);

    if (state == AppLifecycleState.paused || state == AppLifecycleState.inactive) {
      _lastBackgroundAt = DateTime.now();
    }

    if (state == AppLifecycleState.resumed && !kIsWeb && mounted) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          AppUpdateCoordinator.checkAndPrompt(context, fromResume: true);
        }
      });

      final lastBackgroundAt = _lastBackgroundAt;
      if (lastBackgroundAt != null) {
        final backgroundDuration = DateTime.now().difference(lastBackgroundAt);
        if (backgroundDuration >= _appOpenResumeBackgroundThreshold) {
          _tryShowAppOpenAd(trigger: 'resume');
        } else {
          debugPrint(
            'Skip app open ad on resume (background too short: $backgroundDuration)',
          );
        }
      }
      _checkAndShowReviewReminder();
    }
  }

  @override
  Widget build(BuildContext context) {
    final languageManager = LanguageManager();
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop) {
          final shouldExit = onWillPop();
          if (shouldExit) {
            SystemNavigator.pop();
          }
        }
      },
      child: Scaffold(
        // Stack overlay: content full-screen, navbar float trên — vùng quanh pill
        // hiện nền của tab (trắng ở Categories), không còn dải #F7FAFF của shell.
        body: Stack(
          children: [
            Positioned.fill(
              child: <Widget>[
                HomePage(
                  onNavigateToCategory: navigateToCategoriesWithTab,
                  onNavigateToGrammar: navigateToGrammarWithTab,
                  onNavigateToMyHubDailyGoal: navigateToMyHubDailyGoal,
                ),
                Builder(
                  builder: (context) {
                    if (categoriesInitialTab != null) {
                      WidgetsBinding.instance.addPostFrameCallback((_) {
                        if (mounted) {
                          setState(() {
                            categoriesInitialTab = null;
                          });
                        }
                      });
                    }
                    return CategoriesScreen(initialTab: categoriesInitialTab);
                  },
                ),
                Builder(
                  builder: (context) {
                    final scrollToDailyGoal = scrollMyHubToDailyGoal;
                    if (scrollToDailyGoal) {
                      WidgetsBinding.instance.addPostFrameCallback((_) {
                        if (mounted) {
                          setState(() {
                            scrollMyHubToDailyGoal = false;
                          });
                        }
                      });
                    }
                    return MyLearningScreen(scrollToDailyGoal: scrollToDailyGoal);
                  },
                ),
                Builder(
                  builder: (context) {
                    if (grammarInitialTab != null) {
                      WidgetsBinding.instance.addPostFrameCallback((_) {
                        if (mounted) {
                          setState(() {
                            grammarInitialTab = null;
                          });
                        }
                      });
                    }
                    return GrammarScreen(initialTab: grammarInitialTab);
                  },
                ),
                const SettingsScreen(),
              ][currentPageIndex],
            ),
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: SafeArea(
                top: false,
                child: FloatingBottomNavBar(
                  selectedIndex: currentPageIndex,
                  onDestinationSelected: (int index) {
                    setState(() {
                      currentPageIndex = index;
                    });
                  },
                  destinations: [
                    FloatingNavDestination(
                      icon: Icons.home_outlined,
                      selectedIcon: Icons.home_rounded,
                      label: languageManager.getText('home'),
                    ),
                    FloatingNavDestination(
                      icon: Icons.list_outlined,
                      selectedIcon: Icons.list_rounded,
                      label: languageManager.getText('categories'),
                    ),
                    FloatingNavDestination(
                      icon: Icons.favorite_border_rounded,
                      selectedIcon: Icons.favorite_rounded,
                      label: languageManager.getText('myLearning'),
                    ),
                    FloatingNavDestination(
                      icon: Icons.menu_book_outlined,
                      selectedIcon: Icons.menu_book_rounded,
                      label: languageManager.getText('grammar'),
                    ),
                    FloatingNavDestination(
                      icon: Icons.settings_outlined,
                      selectedIcon: Icons.settings_rounded,
                      label: languageManager.getText('settings'),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}