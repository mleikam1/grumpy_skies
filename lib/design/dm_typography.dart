import 'package:flutter/material.dart';

import 'dm_colors.dart';

abstract final class DMTypography {
  const DMTypography._();

  static const List<String> systemFontStack = <String>[
    'SF Pro Display',
    'SF Pro Text',
    'Roboto',
    'Inter',
    'system-ui',
    '-apple-system',
    'BlinkMacSystemFont',
    'Segoe UI',
    'Arial',
    'sans-serif',
  ];

  static const TextStyle displayWeather = TextStyle(
    fontFamily: 'DaymakerSans',
    fontFamilyFallback: systemFontStack,
    fontSize: 88,
    fontWeight: FontWeight.w800,
    height: 0.96,
    letterSpacing: 0,
  );

  static const TextStyle brandDisplay = TextStyle(
    fontFamily: 'DaymakerSans',
    fontFamilyFallback: systemFontStack,
    fontSize: 27,
    fontWeight: FontWeight.w800,
    height: 1.05,
    letterSpacing: 0,
  );

  static const TextStyle headingLarge = TextStyle(
    fontFamily: 'DaymakerSans',
    fontFamilyFallback: systemFontStack,
    fontSize: 25,
    fontWeight: FontWeight.w800,
    height: 1.12,
    letterSpacing: 0,
  );

  static const TextStyle headingMedium = TextStyle(
    fontFamily: 'DaymakerSans',
    fontFamilyFallback: systemFontStack,
    fontSize: 24,
    fontWeight: FontWeight.w700,
    height: 1.16,
    letterSpacing: 0,
  );

  static const TextStyle headingSmall = TextStyle(
    fontFamily: 'DaymakerSans',
    fontFamilyFallback: systemFontStack,
    fontSize: 20,
    fontWeight: FontWeight.w700,
    height: 1.2,
    letterSpacing: 0,
  );

  static const TextStyle title = TextStyle(
    fontFamily: 'DaymakerSans',
    fontFamilyFallback: systemFontStack,
    fontSize: 17,
    fontWeight: FontWeight.w700,
    height: 1.22,
    letterSpacing: 0,
  );

  static const TextStyle bodyLarge = TextStyle(
    fontFamily: 'DaymakerSans',
    fontFamilyFallback: systemFontStack,
    fontSize: 17,
    fontWeight: FontWeight.w500,
    height: 1.42,
    letterSpacing: 0,
  );

  static const TextStyle body = TextStyle(
    fontFamily: 'DaymakerSans',
    fontFamilyFallback: systemFontStack,
    fontSize: 14,
    fontWeight: FontWeight.w500,
    height: 1.4,
    letterSpacing: 0,
  );

  static const TextStyle bodySmall = TextStyle(
    fontFamily: 'DaymakerSans',
    fontFamilyFallback: systemFontStack,
    fontSize: 13,
    fontWeight: FontWeight.w500,
    height: 1.36,
    letterSpacing: 0,
  );

  static const TextStyle labelLarge = TextStyle(
    fontFamily: 'DaymakerSans',
    fontFamilyFallback: systemFontStack,
    fontSize: 14,
    fontWeight: FontWeight.w700,
    height: 1.2,
    letterSpacing: 0,
  );

  static const TextStyle label = TextStyle(
    fontFamily: 'DaymakerSans',
    fontFamilyFallback: systemFontStack,
    fontSize: 13,
    fontWeight: FontWeight.w700,
    height: 1.18,
    letterSpacing: 0,
  );

  static const TextStyle labelSmall = TextStyle(
    fontFamily: 'DaymakerSans',
    fontFamilyFallback: systemFontStack,
    fontSize: 11,
    fontWeight: FontWeight.w700,
    height: 1.18,
    letterSpacing: 0,
  );

  static const TextStyle numeral = TextStyle(
    fontFamily: 'DaymakerSans',
    fontFamilyFallback: systemFontStack,
    fontSize: 28,
    fontWeight: FontWeight.w800,
    height: 1.08,
    letterSpacing: 0,
  );

  static const TextTheme textTheme = TextTheme(
    displayLarge: displayWeather,
    displayMedium: brandDisplay,
    displaySmall: headingLarge,
    headlineLarge: headingLarge,
    headlineMedium: headingMedium,
    headlineSmall: headingSmall,
    titleLarge: title,
    titleMedium: headingSmall,
    titleSmall: labelLarge,
    bodyLarge: bodyLarge,
    bodyMedium: body,
    bodySmall: bodySmall,
    labelLarge: labelLarge,
    labelMedium: label,
    labelSmall: labelSmall,
  );

  static TextStyle weatherNumeral({
    Color color = DMColors.textPrimary,
    double fontSize = 76,
  }) {
    return displayWeather.copyWith(color: color, fontSize: fontSize);
  }

  static TextTheme withColor(Color color) {
    return textTheme.apply(
      bodyColor: color,
      displayColor: color,
    );
  }
}

extension DMTextThemeX on TextTheme {
  TextStyle get weatherDisplay => displayLarge ?? DMTypography.displayWeather;

  TextStyle get brand => displayMedium ?? DMTypography.brandDisplay;

  TextStyle get heading => headlineMedium ?? DMTypography.headingMedium;

  TextStyle get cardTitle => titleLarge ?? DMTypography.title;

  TextStyle get bodyCopy => bodyMedium ?? DMTypography.body;

  TextStyle get metaLabel => labelMedium ?? DMTypography.label;

  TextStyle get number => DMTypography.numeral;
}
