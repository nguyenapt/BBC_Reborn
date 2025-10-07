import 'package:flutter/material.dart';
import '../services/language_manager.dart';

class LocalizedText extends StatelessWidget {
  final String textKey;
  final Map<String, dynamic>? args;
  final TextStyle? style;
  final TextAlign? textAlign;
  final int? maxLines;
  final TextOverflow? overflow;

  const LocalizedText(
    this.textKey, {
    super.key,
    this.args,
    this.style,
    this.textAlign,
    this.maxLines,
    this.overflow,
  });

  @override
  Widget build(BuildContext context) {
    final languageManager = LanguageManager();
    String text;
    
    if (args != null) {
      text = languageManager.getTextWithParams(textKey, args!);
    } else {
      text = languageManager.getText(textKey);
    }

    return Text(
      text,
      style: style,
      textAlign: textAlign,
      maxLines: maxLines,
      overflow: overflow,
    );
  }
}
