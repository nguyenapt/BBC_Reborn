import 'package:flutter/material.dart';
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
          title: 'Learning English with B.B.C',
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
              bodyLarge: TextStyle(fontSize: 16 * LanguageManager().textScaleFactor),
              bodyMedium: TextStyle(fontSize: 14 * LanguageManager().textScaleFactor),
              bodySmall: TextStyle(fontSize: 12 * LanguageManager().textScaleFactor),
            ),
          ),
          darkTheme: ThemeData(
            useMaterial3: true,
            brightness: Brightness.dark,
            textTheme: TextTheme(
              bodyLarge: TextStyle(fontSize: 16 * LanguageManager().textScaleFactor),
              bodyMedium: TextStyle(fontSize: 14 * LanguageManager().textScaleFactor),
              bodySmall: TextStyle(fontSize: 12 * LanguageManager().textScaleFactor),
            ),
          ),
          home: const BBCLearningAppStateful(),
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

class _BBCLearningAppStatefulState extends State<BBCLearningAppStateful> {
  int currentPageIndex = 0;

  @override
  Widget build(BuildContext context) {
    final languageManager = LanguageManager();
    final ThemeData theme = Theme.of(context);
    return Scaffold(
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
    );
  }
}