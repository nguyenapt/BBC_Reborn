import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
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
import 'screens/splash_screen.dart';
import 'utils/double_back_exit.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Khởi tạo các service
  await LanguageManager().initialize();
  await UserService().initialize();
  await AuthService().initialize();
  await AudioPlayerService().initialize();
  
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

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    
    // Tạo App Open Ad và hiển thị sau khi UI đã sẵn sàng (chỉ trên mobile)
    WidgetsBinding.instance.addPostFrameCallback((_) {
      // Delay lâu hơn để đảm bảo UI đã render xong và ổn định
      Future.delayed(const Duration(milliseconds: 2000), () {
        if (!kIsWeb && mounted) {
          // Tạo App Open Ad trước khi hiển thị
          AdMobService().createAppOpenAd();
          // Delay thêm một chút để ad load xong
          Future.delayed(const Duration(milliseconds: 1000), () {
            if (mounted) {
              AdMobService().showAppOpenAdIfReady();
            }
          });
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
    
    // Hiển thị App Open Ad khi app được resume từ background (chỉ trên mobile)
    if (state == AppLifecycleState.resumed && !kIsWeb) {
      // Delay một chút để tránh hiển thị ngay lập tức
      Future.delayed(const Duration(milliseconds: 1000), () {
        AdMobService().showAppOpenAdIfReady();
      });
    }
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
        const HomePage(),

        /// Categories page
        const CategoriesScreen(),

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