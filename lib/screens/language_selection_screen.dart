import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/language_manager.dart';
import '../services/user_profile_service.dart';
import '../main.dart';
import '../widgets/language_flag_icon.dart';
import 'ads_support_notice_screen.dart';
import 'onboarding_profile_screen.dart';

class LanguageSelectionScreen extends StatefulWidget {
  const LanguageSelectionScreen({super.key});

  @override
  State<LanguageSelectionScreen> createState() => _LanguageSelectionScreenState();
}

class _LanguageSelectionScreenState extends State<LanguageSelectionScreen> {
  static const String _adsNoticeSeenKey = 'ads_notice_seen_v1';
  final LanguageManager _languageManager = LanguageManager();
  Locale? _selectedLocale;

  static const List<LanguageOption> _allLanguages = [
    LanguageOption(
      locale: Locale('ar'),
      name: 'Arabic',
      nativeName: 'العربية',
    ),
    LanguageOption(
      locale: Locale('zh'),
      name: 'Chinese',
      nativeName: '中文',
    ),
    LanguageOption(
      locale: Locale('de'),
      name: 'German',
      nativeName: 'Deutsch',
    ),
    LanguageOption(
      locale: Locale('en'),
      name: 'English',
      nativeName: 'English',
    ),
    LanguageOption(
      locale: Locale('es'),
      name: 'Spanish',
      nativeName: 'Español',
    ),
    LanguageOption(
      locale: Locale('fr'),
      name: 'French',
      nativeName: 'Français',
    ),
    LanguageOption(
      locale: Locale('ja'),
      name: 'Japanese',
      nativeName: '日本語',
    ),
    LanguageOption(
      locale: Locale('ko'),
      name: 'Korean',
      nativeName: '한국어',
    ),
    LanguageOption(
      locale: Locale('pt'),
      name: 'Portuguese',
      nativeName: 'Português',
    ),
    LanguageOption(
      locale: Locale('ru'),
      name: 'Russian',
      nativeName: 'Русский',
    ),
    LanguageOption(
      locale: Locale('vi'),
      name: 'Vietnamese',
      nativeName: 'Tiếng Việt',
    ),
  ];

  late final List<LanguageOption> _languages;

  @override
  void initState() {
    super.initState();
    _languages = List<LanguageOption>.from(_allLanguages)
      ..sort((a, b) => a.name.compareTo(b.name));
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
        final profileService = UserProfileService();
        await profileService.initialize();
        final hasSeenAdsNotice = prefs.getBool(_adsNoticeSeenKey) ?? false;

        if (!profileService.hasCompletedProfile) {
          Navigator.of(context).pushReplacement(
            MaterialPageRoute(
              builder: (context) => const OnboardingProfileScreen(),
            ),
          );
          return;
        }

        if (!hasSeenAdsNotice) {
          Navigator.of(context).pushReplacement(
            MaterialPageRoute(
              builder: (context) => AdsSupportNoticeScreen(
                onContinue: (noticeContext) async {
                  final localPrefs = await SharedPreferences.getInstance();
                  await localPrefs.setBool(_adsNoticeSeenKey, true);
                  if (!noticeContext.mounted) return;
                  Navigator.of(noticeContext).pushAndRemoveUntil(
                    MaterialPageRoute(
                      builder: (context) => const BBCLearningAppStateful(),
                    ),
                    (route) => false,
                  );
                },
              ),
            ),
          );
          return;
        }

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
    final colorScheme = Theme.of(context).colorScheme;
    return Scaffold(
      backgroundColor: colorScheme.surface,
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
                  fontWeight: FontWeight.w800,
                  color: colorScheme.onSurface,
                ),
                textAlign: TextAlign.center,
              ),
              
              const SizedBox(height: 8),
              
              Text(
                'You can change the language anytime in the settings',
                style: TextStyle(
                  fontSize: 16,
                  color: colorScheme.onSurface.withValues(alpha: 0.74),
                ),
                textAlign: TextAlign.center,
              ),
              
              const SizedBox(height: 32),

              // Language chips
              Expanded(
                child: SingleChildScrollView(
                  child: Wrap(
                    alignment: WrapAlignment.center,
                    spacing: 10,
                    runSpacing: 10,
                    children: _languages.map((language) {
                      final isSelected = _selectedLocale?.languageCode ==
                          language.locale.languageCode;
                      return _LanguageChip(
                        language: language,
                        isSelected: isSelected,
                        onTap: () {
                          setState(() {
                            _selectedLocale = language.locale;
                          });
                        },
                      );
                    }).toList(),
                  ),
                ),
              ),
              
              const SizedBox(height: 24),
              
              // CTA button
              SizedBox(
                width: double.infinity,
                height: 52,
                child: FilledButton(
                  onPressed: _selectedLocale != null ? _completeSetup : null,
                  style: FilledButton.styleFrom(
                    backgroundColor: colorScheme.primary,
                    foregroundColor: colorScheme.onPrimary,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  child: const Text(
                    'Continue',
                    style: TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
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

  const LanguageOption({
    required this.locale,
    required this.name,
    required this.nativeName,
  });
}

class _LanguageChip extends StatelessWidget {
  static const double _radius = 10;

  final LanguageOption language;
  final bool isSelected;
  final VoidCallback onTap;

  const _LanguageChip({
    required this.language,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(_radius),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeOut,
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: isSelected
                ? colorScheme.primary.withValues(alpha: 0.12)
                : colorScheme.surfaceContainerHighest.withValues(alpha: 0.45),
            borderRadius: BorderRadius.circular(_radius),
            border: Border.all(
              color: isSelected
                  ? colorScheme.primary
                  : colorScheme.outlineVariant.withValues(alpha: 0.55),
              width: isSelected ? 2 : 1,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              LanguageFlagIcon(
                languageCode: language.locale.languageCode,
                size: 22,
              ),
              const SizedBox(width: 8),
              Text(
                language.nativeName,
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                  color: isSelected
                      ? colorScheme.primary
                      : colorScheme.onSurface,
                ),
              ),
              if (isSelected) ...[
                const SizedBox(width: 6),
                Icon(
                  Icons.check_rounded,
                  size: 18,
                  color: colorScheme.primary,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
