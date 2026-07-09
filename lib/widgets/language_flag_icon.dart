import 'package:country_flags/country_flags.dart';
import 'package:flutter/material.dart';

class LanguageFlagIcon extends StatelessWidget {
  final String languageCode;
  final double size;

  const LanguageFlagIcon({
    super.key,
    required this.languageCode,
    this.size = 22,
  });

  @override
  Widget build(BuildContext context) {
    return CountryFlag.fromLanguageCode(
      languageCode,
      theme: ImageTheme(
        width: size,
        height: size,
        shape: RoundedRectangle(size * 0.15),
      ),
    );
  }
}
