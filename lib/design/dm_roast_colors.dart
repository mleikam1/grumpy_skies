import 'package:flutter/material.dart';

/// Shared sky treatment for persona roast cards and their forecaster presentation.
/// It follows the resolved app theme, independently of persona, mood, or weather.
@immutable
class DMRoastColors extends ThemeExtension<DMRoastColors> {
  const DMRoastColors({
    required this.canvas,
    required this.gradientStart,
    required this.gradientMiddle,
    required this.gradientEnd,
    required this.surface,
    required this.border,
    required this.textPrimary,
    required this.textSecondary,
    required this.personaSurface,
    required this.personaText,
    required this.personaBorder,
    required this.moodSurface,
    required this.moodText,
    required this.moodBorder,
    required this.anotherSurface,
    required this.anotherText,
    required this.anotherOutline,
    required this.shareSurface,
    required this.shareText,
    required this.divider,
    required this.cloudColor,
    required this.illuminationColor,
  });

  final Color canvas;
  final Color gradientStart;
  final Color gradientMiddle;
  final Color gradientEnd;
  final Color surface;
  final Color border;
  final Color textPrimary;
  final Color textSecondary;
  final Color personaSurface;
  final Color personaText;
  final Color personaBorder;
  final Color moodSurface;
  final Color moodText;
  final Color moodBorder;
  final Color anotherSurface;
  final Color anotherText;
  final Color anotherOutline;
  final Color shareSurface;
  final Color shareText;
  final Color divider;
  final Color cloudColor;
  final Color illuminationColor;

  LinearGradient get gradient => LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        stops: const [0, .55, 1],
        colors: [gradientStart, gradientMiddle, gradientEnd],
      );

  static const light = DMRoastColors(
    canvas: Color(0xFFF3FAFF),
    gradientStart: Color(0xFFC4E6FF),
    gradientMiddle: Color(0xFFDDF1FF),
    gradientEnd: Color(0xFFF2FAFF),
    surface: Color(0xFFDDF1FF),
    border: Color(0xFFA6CEED),
    textPrimary: Color(0xFF101B3E),
    textSecondary: Color(0xFF476487),
    personaSurface: Color(0xFFE4F3FF),
    personaText: Color(0xFF476487),
    personaBorder: Color(0xFFA6CEED),
    moodSurface: Color(0xFFF8FCFF),
    moodText: Color(0xFF101B3E),
    moodBorder: Color(0xFFB8D8F0),
    anotherSurface: Color(0xFFE4F3FF),
    anotherText: Color(0xFF101B3E),
    anotherOutline: Color(0xFF5B7EA0),
    shareSurface: Color(0xFFFFE16A),
    shareText: Color(0xFF101B3E),
    divider: Color(0xFFB8D8F0),
    cloudColor: Color(0x2EFFFFFF),
    illuminationColor: Color(0x00547FAC),
  );

  static const dark = DMRoastColors(
    canvas: Color(0xFF08182E),
    gradientStart: Color(0xFF173D73),
    gradientMiddle: Color(0xFF112D53),
    gradientEnd: Color(0xFF0C203D),
    surface: Color(0xFF112D53),
    border: Color(0xFF355A86),
    textPrimary: Color(0xFFF4F8FF),
    textSecondary: Color(0xFFB8CCE7),
    personaSurface: Color(0xFF17385F),
    personaText: Color(0xFFC2DCF5),
    personaBorder: Color(0xFF426A98),
    moodSurface: Color(0xFF244E7A),
    moodText: Color(0xFFF4F8FF),
    moodBorder: Color(0xFF547FAC),
    anotherSurface: Color(0xFF163459),
    anotherText: Color(0xFFF4F8FF),
    anotherOutline: Color(0xFF7098CA),
    shareSurface: Color(0xFFFFE16A),
    shareText: Color(0xFF101B3E),
    divider: Color(0xFF33547A),
    cloudColor: Color(0x00FFFFFF),
    illuminationColor: Color(0x28547FAC),
  );

  @override
  DMRoastColors copyWith({
    Color? canvas,
    Color? gradientStart,
    Color? gradientMiddle,
    Color? gradientEnd,
    Color? surface,
    Color? border,
    Color? textPrimary,
    Color? textSecondary,
    Color? personaSurface,
    Color? personaText,
    Color? personaBorder,
    Color? moodSurface,
    Color? moodText,
    Color? moodBorder,
    Color? anotherSurface,
    Color? anotherText,
    Color? anotherOutline,
    Color? shareSurface,
    Color? shareText,
    Color? divider,
    Color? cloudColor,
    Color? illuminationColor,
  }) =>
      DMRoastColors(
        canvas: canvas ?? this.canvas,
        gradientStart: gradientStart ?? this.gradientStart,
        gradientMiddle: gradientMiddle ?? this.gradientMiddle,
        gradientEnd: gradientEnd ?? this.gradientEnd,
        surface: surface ?? this.surface,
        border: border ?? this.border,
        textPrimary: textPrimary ?? this.textPrimary,
        textSecondary: textSecondary ?? this.textSecondary,
        personaSurface: personaSurface ?? this.personaSurface,
        personaText: personaText ?? this.personaText,
        personaBorder: personaBorder ?? this.personaBorder,
        moodSurface: moodSurface ?? this.moodSurface,
        moodText: moodText ?? this.moodText,
        moodBorder: moodBorder ?? this.moodBorder,
        anotherSurface: anotherSurface ?? this.anotherSurface,
        anotherText: anotherText ?? this.anotherText,
        anotherOutline: anotherOutline ?? this.anotherOutline,
        shareSurface: shareSurface ?? this.shareSurface,
        shareText: shareText ?? this.shareText,
        divider: divider ?? this.divider,
        cloudColor: cloudColor ?? this.cloudColor,
        illuminationColor: illuminationColor ?? this.illuminationColor,
      );

  @override
  DMRoastColors lerp(covariant DMRoastColors? other, double t) {
    if (other == null) return this;
    return DMRoastColors(
      canvas: Color.lerp(canvas, other.canvas, t)!,
      gradientStart: Color.lerp(gradientStart, other.gradientStart, t)!,
      gradientMiddle: Color.lerp(gradientMiddle, other.gradientMiddle, t)!,
      gradientEnd: Color.lerp(gradientEnd, other.gradientEnd, t)!,
      surface: Color.lerp(surface, other.surface, t)!,
      border: Color.lerp(border, other.border, t)!,
      textPrimary: Color.lerp(textPrimary, other.textPrimary, t)!,
      textSecondary: Color.lerp(textSecondary, other.textSecondary, t)!,
      personaSurface: Color.lerp(personaSurface, other.personaSurface, t)!,
      personaText: Color.lerp(personaText, other.personaText, t)!,
      personaBorder: Color.lerp(personaBorder, other.personaBorder, t)!,
      moodSurface: Color.lerp(moodSurface, other.moodSurface, t)!,
      moodText: Color.lerp(moodText, other.moodText, t)!,
      moodBorder: Color.lerp(moodBorder, other.moodBorder, t)!,
      anotherSurface: Color.lerp(anotherSurface, other.anotherSurface, t)!,
      anotherText: Color.lerp(anotherText, other.anotherText, t)!,
      anotherOutline: Color.lerp(anotherOutline, other.anotherOutline, t)!,
      shareSurface: Color.lerp(shareSurface, other.shareSurface, t)!,
      shareText: Color.lerp(shareText, other.shareText, t)!,
      divider: Color.lerp(divider, other.divider, t)!,
      cloudColor: Color.lerp(cloudColor, other.cloudColor, t)!,
      illuminationColor:
          Color.lerp(illuminationColor, other.illuminationColor, t)!,
    );
  }
}
