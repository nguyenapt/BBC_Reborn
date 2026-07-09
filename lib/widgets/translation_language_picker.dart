import 'package:flutter/material.dart';
import 'language_flag_icon.dart';

/// Widget để chọn ngôn ngữ cho translation
class TranslationLanguagePicker extends StatelessWidget {
  final String? currentLanguageCode;
  final Function(String languageCode) onLanguageSelected;

  const TranslationLanguagePicker({
    super.key,
    this.currentLanguageCode,
    required this.onLanguageSelected,
  });

  static const List<Map<String, String>> _translationLanguages = [
    {'code': 'vi', 'name': 'Tiếng Việt', 'nativeName': 'Tiếng Việt'},
    {'code': 'zh', 'name': '中文', 'nativeName': '中文'},
    {'code': 'ja', 'name': '日本語', 'nativeName': '日本語'},
    {'code': 'ko', 'name': '한국어', 'nativeName': '한국어'},
    {'code': 'es', 'name': 'Español', 'nativeName': 'Español'},
    {'code': 'pt', 'name': 'Português', 'nativeName': 'Português'},
    {'code': 'ar', 'name': 'العربية', 'nativeName': 'العربية'},
    {'code': 'ru', 'name': 'Русский', 'nativeName': 'Русский'},
    {'code': 'fr', 'name': 'Français', 'nativeName': 'Français'},
    {'code': 'de', 'name': 'Deutsch', 'nativeName': 'Deutsch'},
  ];

  static void show(
    BuildContext context, {
    String? currentLanguageCode,
    required Function(String languageCode) onLanguageSelected,
  }) {
    showDialog(
      context: context,
      builder: (context) => TranslationLanguagePicker(
        currentLanguageCode: currentLanguageCode,
        onLanguageSelected: onLanguageSelected,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Choose Translation Language'),
      content: SizedBox(
        width: double.maxFinite,
        child: ListView.builder(
          shrinkWrap: true,
          itemCount: _translationLanguages.length,
          itemBuilder: (context, index) {
            final language = _translationLanguages[index];
            final isSelected = currentLanguageCode == language['code'];
            
            return Container(
              margin: const EdgeInsets.only(bottom: 8),
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: () {
                    Navigator.of(context).pop();
                    onLanguageSelected(language['code']!);
                  },
                  borderRadius: BorderRadius.circular(12),
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: isSelected 
                          ? Theme.of(context).colorScheme.primary.withOpacity(0.1)
                          : Colors.transparent,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: isSelected 
                            ? Theme.of(context).colorScheme.primary
                            : Colors.transparent,
                        width: isSelected ? 2 : 0,
                      ),
                    ),
                    child: Row(
                      children: [
                        LanguageFlagIcon(
                          languageCode: language['code']!,
                          size: 24,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                language['name']!,
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                  color: isSelected
                                      ? Theme.of(context).colorScheme.primary
                                      : Theme.of(context).colorScheme.onSurface,
                                ),
                              ),
                              if (language['name'] != language['nativeName'])
                                Text(
                                  language['nativeName']!,
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
                                  ),
                                ),
                            ],
                          ),
                        ),
                        if (isSelected)
                          Icon(
                            Icons.check_circle,
                            color: Theme.of(context).colorScheme.primary,
                            size: 20,
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
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
      ],
    );
  }
}


