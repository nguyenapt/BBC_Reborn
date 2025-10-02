import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/language_manager.dart';
import '../main.dart';

class LanguageSelectionScreen extends StatefulWidget {
  const LanguageSelectionScreen({super.key});

  @override
  State<LanguageSelectionScreen> createState() => _LanguageSelectionScreenState();
}

class _LanguageSelectionScreenState extends State<LanguageSelectionScreen> {
  final LanguageManager _languageManager = LanguageManager();
  Locale? _selectedLocale;

  final List<LanguageOption> _languages = [
    LanguageOption(
      locale: const Locale('vi', 'VN'),
      name: 'Tiếng Việt',
      nativeName: 'Tiếng Việt',
      flag: '🇻🇳',
    ),
    LanguageOption(
      locale: const Locale('en', 'US'),
      name: 'English',
      nativeName: 'English',
      flag: '🇺🇸',
    ),
    LanguageOption(
      locale: const Locale('zh', 'CN'),
      name: '中文',
      nativeName: '中文',
      flag: '🇨🇳',
    ),
    LanguageOption(
      locale: const Locale('ja', 'JP'),
      name: '日本語',
      nativeName: '日本語',
      flag: '🇯🇵',
    ),
    LanguageOption(
      locale: const Locale('ko', 'KR'),
      name: '한국어',
      nativeName: '한국어',
      flag: '🇰🇷',
    ),
    LanguageOption(
      locale: const Locale('es', 'ES'),
      name: 'Español',
      nativeName: 'Español',
      flag: '🇪🇸',
    ),
    LanguageOption(
      locale: const Locale('pt', 'BR'),
      name: 'Português',
      nativeName: 'Português',
      flag: '🇧🇷',
    ),
    LanguageOption(
      locale: const Locale('ar', 'SA'),
      name: 'العربية',
      nativeName: 'العربية',
      flag: '🇸🇦',
    ),
    LanguageOption(
      locale: const Locale('ru', 'RU'),
      name: 'Русский',
      nativeName: 'Русский',
      flag: '🇷🇺',
    ),
  ];

  @override
  void initState() {
    super.initState();
    _selectedLocale = _languageManager.currentLocale;
  }

  Future<void> _completeSetup() async {
    // Lưu ngôn ngữ đã chọn trực tiếp vào SharedPreferences
    if (_selectedLocale != null) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('selected_language', _selectedLocale!.languageCode);
    }
    
    // Lưu trạng thái onboarding completed
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('onboarding_completed', true);
    
    if (mounted) {
      // Delay một chút để đảm bảo SharedPreferences được lưu
      await Future.delayed(const Duration(milliseconds: 100));
      
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (context) => const BBCLearningAppStateful()),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            children: [
              const SizedBox(height: 40),
              
              // Header
              Text(
                'Choose your language',
                style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: Colors.blue[700],
                ),
                textAlign: TextAlign.center,
              ),
              
              const SizedBox(height: 8),
              
              Text(
                'You can change the language anytime in the settings',
                style: TextStyle(
                  fontSize: 16,
                  color: Colors.grey[600],
                ),
                textAlign: TextAlign.center,
              ),
              
              const SizedBox(height: 40),
              
              // Language list
              Expanded(
                child: ListView.builder(
                  itemCount: _languages.length,
                  itemBuilder: (context, index) {
                    final language = _languages[index];
                    final isSelected = _selectedLocale == language.locale;
                    
                    return Container(
                      margin: const EdgeInsets.only(bottom: 12),
                      child: Material(
                        color: Colors.transparent,
                        child: InkWell(
                          onTap: () {
                            setState(() {
                              _selectedLocale = language.locale;
                            });
                          },
                          borderRadius: BorderRadius.circular(16),
                          child: Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: isSelected 
                                  ? Colors.blue[50] 
                                  : Colors.grey[50],
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(
                                color: isSelected 
                                    ? Colors.blue[300]! 
                                    : Colors.grey[200]!,
                                width: isSelected ? 2 : 1,
                              ),
                            ),
                            child: Row(
                              children: [
                                // Flag
                                Text(
                                  language.flag,
                                  style: const TextStyle(fontSize: 32),
                                ),
                                
                                const SizedBox(width: 16),
                                
                                // Language info
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        language.name,
                                        style: TextStyle(
                                          fontSize: 18,
                                          fontWeight: FontWeight.w600,
                                          color: isSelected 
                                              ? Colors.blue[700] 
                                              : Colors.black87,
                                        ),
                                      ),
                                      if (language.name != language.nativeName)
                                        Text(
                                          language.nativeName,
                                          style: TextStyle(
                                            fontSize: 14,
                                            color: Colors.grey[600],
                                          ),
                                        ),
                                    ],
                                  ),
                                ),
                                
                                // Check icon
                                if (isSelected)
                                  Icon(
                                    Icons.check_circle,
                                    color: Colors.blue[600],
                                    size: 24,
                                  ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
              
              const SizedBox(height: 24),
              
              // Continue button
              SizedBox(
                width: double.infinity,
                height: 56,
                child: ElevatedButton(
                  onPressed: _selectedLocale != null ? _completeSetup : null,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue[600],
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(28),
                    ),
                    elevation: 2,
                  ),
                  child: const Text(
                    'Complete',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
              
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }
}

class LanguageOption {
  final Locale locale;
  final String name;
  final String nativeName;
  final String flag;

  LanguageOption({
    required this.locale,
    required this.name,
    required this.nativeName,
    required this.flag,
  });
}
