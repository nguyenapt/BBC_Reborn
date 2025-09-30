import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../l10n/en/app_en.dart';
import '../l10n/vi/app_vi.dart';
import '../l10n/ar/app_ar.dart';
import '../l10n/zh/app_zh.dart';
import '../l10n/ko/app_ko.dart';
import '../l10n/ja/app_ja.dart';
import '../l10n/ru/app_ru.dart';
import '../l10n/es/app_es.dart';
import '../l10n/pt/app_pt.dart';

class LanguageManager extends ChangeNotifier {
  static final LanguageManager _instance = LanguageManager._internal();
  factory LanguageManager() => _instance;
  LanguageManager._internal();

  static const String _languageKey = 'selected_language';
  static const String _themeKey = 'selected_theme';
  static const String _fontSizeKey = 'selected_font_size';
  
  // Danh sách các ngôn ngữ được hỗ trợ
  static const List<Locale> supportedLocales = [
    Locale('en', ''), // English
    Locale('vi', ''), // Vietnamese
    Locale('ar', ''), // Arabic
    Locale('zh', ''), // Chinese
    Locale('ko', ''), // Korean
    Locale('ja', ''), // Japanese
    Locale('ru', ''), // Russian
    Locale('es', ''), // Spanish
    Locale('pt', ''), // Portuguese
  ];

  // Tên ngôn ngữ hiển thị
  static const Map<String, String> languageNames = {
    'en': 'English',
    'vi': 'Tiếng Việt',
    'ar': 'العربية',
    'zh': '中文',
    'ko': '한국어',
    'ja': '日本語',
    'ru': 'Русский',
    'es': 'Español',
    'pt': 'Português',
  };

  Locale _currentLocale = const Locale('en', '');
  String _currentTheme = 'system';
  String _currentFontSize = 'normal';
  
  Locale get currentLocale => _currentLocale;
  String get currentTheme => _currentTheme;
  String get currentFontSize => _currentFontSize;

  /// Khởi tạo service và load settings đã lưu
  Future<void> initialize() async {
    final prefs = await SharedPreferences.getInstance();
    
    // Load language
    final savedLanguage = prefs.getString(_languageKey);
    if (savedLanguage != null) {
      _currentLocale = Locale(savedLanguage, '');
    } else {
      _currentLocale = const Locale('en', '');
    }
    
    // Load theme
    final savedTheme = prefs.getString(_themeKey);
    if (savedTheme != null) {
      _currentTheme = savedTheme;
    } else {
      _currentTheme = 'system';
    }
    
    // Load font size
    final savedFontSize = prefs.getString(_fontSizeKey);
    if (savedFontSize != null) {
      _currentFontSize = savedFontSize;
    } else {
      _currentFontSize = 'normal';
    }
    
    notifyListeners();
  }

  /// Thay đổi ngôn ngữ
  Future<void> changeLanguage(Locale locale) async {
    if (supportedLocales.contains(locale)) {
      _currentLocale = locale;
      
      // Lưu ngôn ngữ đã chọn
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_languageKey, locale.languageCode);
      
      notifyListeners();
    }
  }

  /// Thay đổi theme
  Future<void> changeTheme(String theme) async {
    if (['light', 'dark', 'system'].contains(theme)) {
      _currentTheme = theme;
      
      // Lưu theme đã chọn
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_themeKey, theme);
      
      notifyListeners();
    }
  }

  /// Thay đổi font size
  Future<void> changeFontSize(String fontSize) async {
    if (['small', 'normal', 'large'].contains(fontSize)) {
      _currentFontSize = fontSize;
      
      // Lưu font size đã chọn
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_fontSizeKey, fontSize);
      
      notifyListeners();
    }
  }

  /// Lấy text theo key và ngôn ngữ hiện tại
  String getText(String key) {
    switch (_currentLocale.languageCode) {
      case 'vi':
        return AppVi.texts[key] ?? AppEn.texts[key] ?? key;
      case 'ar':
        return AppAr.texts[key] ?? AppEn.texts[key] ?? key;
      case 'zh':
        return AppZh.texts[key] ?? AppEn.texts[key] ?? key;
      case 'ko':
        return AppKo.texts[key] ?? AppEn.texts[key] ?? key;
      case 'ja':
        return AppJa.texts[key] ?? AppEn.texts[key] ?? key;
      case 'ru':
        return AppRu.texts[key] ?? AppEn.texts[key] ?? key;
      case 'es':
        return AppEs.texts[key] ?? AppEn.texts[key] ?? key;
      case 'pt':
        return AppPt.texts[key] ?? AppEn.texts[key] ?? key;
      default:
        return AppEn.texts[key] ?? key;
    }
  }

  /// Lấy tên ngôn ngữ theo code
  String getLanguageName(String languageCode) {
    return languageNames[languageCode] ?? languageCode;
  }

  /// Kiểm tra xem ngôn ngữ có được hỗ trợ không
  bool isLanguageSupported(String languageCode) {
    return supportedLocales.any((locale) => locale.languageCode == languageCode);
  }

  /// Lấy danh sách ngôn ngữ với tên hiển thị
  List<Map<String, String>> getLanguageList() {
    return supportedLocales.map((locale) => {
      'code': locale.languageCode,
      'name': getLanguageName(locale.languageCode),
    }).toList();
  }

  /// Format text với parameters (cho các text có {count})
  String getTextWithParams(String key, Map<String, dynamic> params) {
    String text = getText(key);
    
    params.forEach((key, value) {
      text = text.replaceAll('{$key}', value.toString());
    });
    
    return text;
  }

  /// Lấy theme mode từ string
  ThemeMode get themeMode {
    switch (_currentTheme) {
      case 'light':
        return ThemeMode.light;
      case 'dark':
        return ThemeMode.dark;
      case 'system':
      default:
        return ThemeMode.system;
    }
  }

  /// Lấy text scale factor từ font size
  double get textScaleFactor {
    switch (_currentFontSize) {
      case 'small':
        return 0.85;
      case 'large':
        return 1.15;
      case 'normal':
      default:
        return 1.0;
    }
  }

  /// Lấy tên theme hiển thị
  String getThemeName(String theme) {
    switch (theme) {
      case 'light':
        return getText('lightTheme');
      case 'dark':
        return getText('darkTheme');
      case 'system':
        return getText('systemTheme');
      default:
        return theme;
    }
  }

  /// Lấy tên font size hiển thị
  String getFontSizeName(String fontSize) {
    switch (fontSize) {
      case 'small':
        return getText('smallFont');
      case 'normal':
        return getText('normalFont');
      case 'large':
        return getText('largeFont');
      default:
        return fontSize;
    }
  }
}
