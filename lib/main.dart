import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
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
import 'services/image_cache_service.dart';
import 'services/admob_service.dart';
import 'services/vocabulary_service.dart';
import 'services/rate_app_service.dart';
import 'screens/splash_screen.dart';
import 'utils/double_back_exit.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Khởi tạo Google Mobile Ads (chỉ trên mobile, không phải web)
  if (!kIsWeb) {
    await MobileAds.instance.initialize();
  }
  
  // Khởi tạo các service
  await LanguageManager().initialize();
  await UserService().initialize();
  await AuthService().initialize();
  await AudioPlayerService().initialize();
  await VocabularyService().initialize();
  
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
          title: 'Learning English - 6 minutes',
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

  void navigateToCategoriesWithTab(String tabName) {
    setState(() {
      categoriesInitialTab = tabName;
      currentPageIndex = 1; // Categories tab index
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
          onWillPop();
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
        HomePage(onNavigateToCategory: navigateToCategoriesWithTab),

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
        const GrammarScreen(),

        /// Settings page
        const SettingsScreen(),
      ][currentPageIndex],
      ),
    );
  }
}