import 'dart:io';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'screens/home_page.dart';
import 'screens/categories_screen.dart';
import 'screens/saved_screen.dart';
import 'screens/settings_screen.dart';
import 'screens/grammar_screen.dart';
import 'services/language_manager.dart';
import 'services/audio_player_service.dart';
import 'services/user_service.dart';
import 'services/auth_service.dart';
import 'services/navigation_service.dart';
import 'services/admob_service.dart';
import 'services/vocabulary_service.dart';
import 'services/rate_app_service.dart';
import 'services/heart_service.dart';
import 'screens/splash_screen.dart';
import 'utils/double_back_exit.dart';
import 'services/back_navigation_service.dart';
import 'services/push_notification_service.dart';
import 'services/consent_service.dart';
import 'firebase_options.dart';
import 'widgets/app_update_prompt.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  debugPrint('🚀 App starting...');
  final ConsentService consentService = ConsentService();

  if (!kIsWeb && (Platform.isAndroid || Platform.isIOS)) {
    await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
    FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);
    await PushNotificationService.instance.initialize();
  }
  
  // Thu thập consent trước khi khởi tạo và request ads.
  if (!kIsWeb && (Platform.isAndroid || Platform.isIOS)) {
    debugPrint('🛡️ Running UMP consent flow...');
    await consentService.initializeConsentFlow();
    debugPrint(
        '🛡️ UMP completed. canRequestAds=${consentService.canRequestAds}, status=${consentService.consentStatus}');

    if (consentService.canRequestAds) {
      debugPrint('📱 Initializing MobileAds...');
      await MobileAds.instance.initialize();
      debugPrint('✅ MobileAds initialized');
    } else {
      debugPrint('⚠️ MobileAds init skipped because consent not granted yet');
    }
  }
  
  // Khởi tạo các service với error handling
  try {
    debugPrint('🔧 Initializing services...');
    await LanguageManager().initialize();
    debugPrint('✅ LanguageManager initialized');
    
    await UserService().initialize();
    debugPrint('✅ UserService initialized');
    
    await AuthService().initialize();
    debugPrint('✅ AuthService initialized');
    
    await AudioPlayerService().initialize();
    debugPrint('✅ AudioPlayerService initialized');
    
    await VocabularyService().initialize();
    debugPrint('✅ VocabularyService initialized');
    
    await HeartService().initialize();
    debugPrint('✅ HeartService initialized');
    
    // Preload rewarded ad for hearts
    if (!kIsWeb && consentService.canRequestAds) {
      AdMobService().createRewardedAd();
    }
    
    debugPrint('🎉 All services initialized successfully');
  } catch (e) {
    debugPrint('❌ Error initializing services: $e');
    // Tiếp tục chạy app ngay cả khi có lỗi khởi tạo service
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
          title: 'Learning English 6 minutes',
          localizationsDelegates: const [
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          supportedLocales: LanguageManager.supportedLocales,
          locale: LanguageManager().currentLocale,
          themeMode: LanguageManager().themeMode,
          theme: ThemeData(
            useMaterial3: true,
            brightness: Brightness.light,
            textTheme: TextTheme(
              bodyLarge: TextStyle(
                fontSize: 16 * LanguageManager().textScaleFactor,
                decoration: TextDecoration.none,
              ),
              bodyMedium: TextStyle(
                fontSize: 14 * LanguageManager().textScaleFactor,
                decoration: TextDecoration.none,
              ),
              bodySmall: TextStyle(
                fontSize: 12 * LanguageManager().textScaleFactor,
                decoration: TextDecoration.none,
              ),
            ),
          ),
          darkTheme: ThemeData(
            useMaterial3: true,
            brightness: Brightness.dark,
            textTheme: TextTheme(
              bodyLarge: TextStyle(
                fontSize: 16 * LanguageManager().textScaleFactor,
                decoration: TextDecoration.none,
              ),
              bodyMedium: TextStyle(
                fontSize: 14 * LanguageManager().textScaleFactor,
                decoration: TextDecoration.none,
              ),
              bodySmall: TextStyle(
                fontSize: 12 * LanguageManager().textScaleFactor,
                decoration: TextDecoration.none,
              ),
            ),
          ),
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
  int currentPageIndex = 0;
  String? categoriesInitialTab;
  String? grammarInitialTab;

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

  Future<void> _checkAndShowRateDialog() async {
    try {
      if (await RateAppService.shouldShowRatePrompt()) {
        await RateAppService.incrementPromptCount();
        await RateAppService.showRateDialog(context);
      }
    } catch (e) {
      debugPrint('Error showing rate dialog: $e');
    }
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
    
    // Giảm tần suất App Open Ad khi khởi động app
    WidgetsBinding.instance.addPostFrameCallback((_) {
      // Delay lâu hơn để đảm bảo UI đã render xong và ổn định
      Future.delayed(const Duration(milliseconds: 3000), () {
        if (!kIsWeb && mounted) {
          // Chỉ hiển thị App Open Ad 30% thời gian để giảm quảng cáo
          if (DateTime.now().millisecondsSinceEpoch % 10 < 3) {
            // Tạo App Open Ad trước khi hiển thị
            AdMobService().createAppOpenAd();
            // Delay thêm một chút để ad load xong
            Future.delayed(const Duration(milliseconds: 1000), () {
              if (mounted) {
                AdMobService().showAppOpenAdIfReady();
              }
            });
          }
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

    if (state == AppLifecycleState.resumed && !kIsWeb && mounted) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          AppUpdateCoordinator.checkAndPrompt(context, fromResume: true);
        }
      });
    }

    // Bỏ App Open Ad khi resume từ background để giảm quảng cáo
    // Chỉ giữ lại App Open Ad khi app khởi động lần đầu
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
      bottomNavigationBar: NavigationBar(
        onDestinationSelected: (int index) {
          setState(() {
            currentPageIndex = index;
          });
        },
        indicatorColor: Colors.amber,
        selectedIndex: currentPageIndex,
        destinations: <Widget>[
          NavigationDestination(
            selectedIcon: const Icon(Icons.home),
            icon: const Icon(Icons.home_outlined),
            label: languageManager.getText('home'),
          ),
          NavigationDestination(
            icon: const Icon(Icons.list_outlined),
            label: languageManager.getText('categories'),
          ),
          NavigationDestination(
            icon: const Icon(Icons.favorite),
            label: languageManager.getText('saved'),
          ),
          NavigationDestination(
            icon: const Icon(Icons.menu_book),
            label: languageManager.getText('grammar'),
          ),
          NavigationDestination(
            icon: const Icon(Icons.settings),
            label: languageManager.getText('settings'),
          ),
        ],
      ),
      body: <Widget>[
        /// Home page
        HomePage(
          onNavigateToCategory: navigateToCategoriesWithTab,
          onNavigateToGrammar: navigateToGrammarWithTab,
        ),

        /// Categories page
        Builder(
          builder: (context) {
            // Reset categoriesInitialTab sau khi CategoriesScreen được tạo
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

        /// Saved page
        const SavedScreen(),

        /// Grammar page
        Builder(
          builder: (context) {
            // Reset grammarInitialTab sau khi GrammarScreen được tạo
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

        /// Settings page
        const SettingsScreen(),
      ][currentPageIndex],
      ),
    );
  }
}