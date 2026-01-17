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
      locale: const Locale('vi'),
      name: 'Tiếng Việt',
      nativeName: 'Tiếng Việt',
      flag: '🇻🇳',
    ),
    LanguageOption(
      locale: const Locale('en'),
      name: 'English',
      nativeName: 'English',
      flag: '🇺🇸',
    ),
    LanguageOption(
      locale: const Locale('zh'),
      name: '中文',
      nativeName: '中文',
      flag: '🇨🇳',
    ),
    LanguageOption(
      locale: const Locale('ja'),
      name: '日本語',
      nativeName: '日本語',
      flag: '🇯🇵',
    ),
    LanguageOption(
      locale: const Locale('ko'),
      name: '한국어',
      nativeName: '한국어',
      flag: '🇰🇷',
    ),
    LanguageOption(
      locale: const Locale('es'),
      name: 'Español',
      nativeName: 'Español',
      flag: '🇪🇸',
    ),
    LanguageOption(
      locale: const Locale('pt'),
      name: 'Português',
      nativeName: 'Português',
      flag: '🇧🇷',
    ),
    LanguageOption(
      locale: const Locale('ar'),
      name: 'العربية',
      nativeName: 'العربية',
      flag: '🇸🇦',
    ),
    LanguageOption(
      locale: const Locale('ru'),
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
    if (_selectedLocale == null) return;
    
    try {
      // 1. Lưu trạng thái onboarding completed trước
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('onboarding_completed', true);
      debugPrint('✅ Onboarding completed flag saved');
      
      // 2. Update LanguageManager để apply locale ngay lập tức
      // Điều này sẽ trigger notifyListeners() và rebuild MaterialApp
      await _languageManager.changeLanguage(_selectedLocale!);
      debugPrint('✅ Language changed to: ${_selectedLocale!.languageCode}');
      debugPrint('   Current locale after change: ${_languageManager.currentLocale.languageCode}');
      
      if (mounted) {
        // 3. Đợi đủ lâu để MaterialApp rebuild với locale mới
        // ListenableBuilder sẽ rebuild MaterialApp khi LanguageManager notify
        await Future.delayed(const Duration(milliseconds: 500));
        
        // 4. Pop về root và push lại để đảm bảo MaterialApp được rebuild hoàn toàn
        // Sử dụng pushAndRemoveUntil để clear toàn bộ stack
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(
            builder: (context) => const BBCLearningAppStateful(),
          ),
          (route) => false, // Remove all previous routes
        );
        debugPrint('✅ Navigated to main app with new locale: ${_languageManager.currentLocale.languageCode}');
      }
    } catch (e, stackTrace) {
      debugPrint('❌ Error completing setup: $e');
      debugPrint('   Stack trace: $stackTrace');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
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
                    final isSelected = _selectedLocale?.languageCode == language.locale.languageCode;
                    
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
