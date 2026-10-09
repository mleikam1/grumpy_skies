import 'package:flutter/material.dart';

/// Semantic UI colors calibrated to the approved DayMaker light/dark boards.
/// Artwork and document colors deliberately remain outside this extension.
@immutable
class DMSemanticColors extends ThemeExtension<DMSemanticColors> {
  const DMSemanticColors({
    required this.appBackground,
    required this.surface,
    required this.surfaceSecondary,
    required this.textPrimary,
    required this.textSecondary,
    required this.textMuted,
    required this.border,
    required this.divider,
    required this.primary,
    required this.onPrimary,
    required this.link,
    required this.focusRing,
    required this.navSurface,
    required this.navSelected,
    required this.navSelectedForeground,
    required this.navInactive,
    required this.karenSurface,
    required this.karenBorder,
    required this.grandpaSurface,
    required this.grandpaBorder,
    required this.insightSurface,
    required this.insightIcon,
    required this.promoSurface,
    required this.promoText,
    required this.promoAction,
    required this.onPromoAction,
    required this.templateSun,
    required this.templateCoffee,
    required this.templateStorm,
    required this.shadow,
    required this.heroGradient,
    required this.karenGradient,
    required this.grandpaGradient,
  });

  final Color appBackground;
  final Color surface;
  final Color surfaceSecondary;
  final Color textPrimary;
  final Color textSecondary;
  final Color textMuted;
  final Color border;
  final Color divider;
  final Color primary;
  final Color onPrimary;
  final Color link;
  final Color focusRing;
  final Color navSurface;
  final Color navSelected;
  final Color navSelectedForeground;
  final Color navInactive;
  final Color karenSurface;
  final Color karenBorder;
  final Color grandpaSurface;
  final Color grandpaBorder;
  final Color insightSurface;
  final Color insightIcon;
  final Color promoSurface;
  final Color promoText;
  final Color promoAction;
  final Color onPromoAction;
  final Color templateSun;
  final Color templateCoffee;
  final Color templateStorm;
  final Color shadow;
  final LinearGradient heroGradient;
  final LinearGradient karenGradient;
  final LinearGradient grandpaGradient;

  // Compatibility names for migrating existing surface/text consumers.
  Color get surfaceElevated => surfaceSecondary;
  Color get surfaceRaised => surfaceSecondary;
  Color get surfaceDisabled => surfaceSecondary;
  Color get textDisabled => textMuted.withValues(alpha: .6);
  Color get outline => border;
  Color get outlineVariant => divider;
  Color get glass => surface;
  Color get glassStrong => surfaceSecondary;
  Color get glassNavy => surface;
  Color get glassBorder => border;
  Color get glassBorderStrong => border;
  Color get shadowSoft => shadow;
  Color get deepNavy => appBackground;
  Color get midnightNavy => surface;
  Color get twilightNavy => surfaceSecondary;

  List<BoxShadow> get cardShadows => [
        BoxShadow(color: shadow, blurRadius: 18, offset: const Offset(0, 6)),
      ];

  static const light = DMSemanticColors(
    appBackground: Color(0xFFF6FAFD),
    surface: Color(0xFFFFFFFF),
    surfaceSecondary: Color(0xFFEDF4F8),
    textPrimary: Color(0xFF0B1C40),
    textSecondary: Color(0xFF4B6286),
    textMuted: Color(0xFF566A86),
    border: Color(0xFFDCE6EE),
    divider: Color(0xFFE6EEF3),
    primary: Color(0xFFFFDF70),
    onPrimary: Color(0xFF10213C),
    link: Color(0xFF365F8F),
    focusRing: Color(0xFF0769A8),
    navSurface: Color(0xFFFFFFFF),
    navSelected: Color(0xFFFFDF70),
    navSelectedForeground: Color(0xFF10213C),
    navInactive: Color(0xFF4B6286),
    karenSurface: Color(0xFFFBE8F0),
    karenBorder: Color(0xFFF1D4E1),
    grandpaSurface: Color(0xFFFBEAEF),
    grandpaBorder: Color(0xFFEFDAE2),
    insightSurface: Color(0xFFFFFFFF),
    insightIcon: Color(0xFF258D87),
    promoSurface: Color(0xFFFFE8A4),
    promoText: Color(0xFF10213C),
    promoAction: Color(0xFF112442),
    onPromoAction: Color(0xFFFFFFFF),
    templateSun: Color(0xFFFFF5D8),
    templateCoffee: Color(0xFFE9E0F9),
    templateStorm: Color(0xFFE0EFED),
    shadow: Color(0x14142D4A),
    heroGradient: LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [Color(0xFFF5FAFD), Color(0xFFDDF1FC), Color(0xFFF6FAFD)]),
    karenGradient: LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [Color(0xFFFBE5EE), Color(0xFFFCEEF2)]),
    grandpaGradient: LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [Color(0xFFFBECEF), Color(0xFFFBE8ED)]),
  );

  static const dark = DMSemanticColors(
    appBackground: Color(0xFF08162B),
    surface: Color(0xFF10243D),
    surfaceSecondary: Color(0xFF142C49),
    textPrimary: Color(0xFFF6F8FF),
    textSecondary: Color(0xFFB9CCE9),
    textMuted: Color(0xFFA4BBDD),
    border: Color(0xFF2C466A),
    divider: Color(0xFF243B5A),
    primary: Color(0xFFFFDF70),
    onPrimary: Color(0xFF10213C),
    link: Color(0xFFADCDF6),
    focusRing: Color(0xFF73DDFF),
    navSurface: Color(0xFF0E223C),
    navSelected: Color(0xFFFFDF70),
    navSelectedForeground: Color(0xFF10213C),
    navInactive: Color(0xFFB9CCE9),
    karenSurface: Color(0xFF30223E),
    karenBorder: Color(0xFF694A79),
    grandpaSurface: Color(0xFF142740),
    grandpaBorder: Color(0xFF2F4A70),
    insightSurface: Color(0xFF122740),
    insightIcon: Color(0xFF8BE3D6),
    promoSurface: Color(0xFF10253F),
    promoText: Color(0xFFF6F8FF),
    promoAction: Color(0xFFFFDF70),
    onPromoAction: Color(0xFF10213C),
    templateSun: Color(0xFF152D43),
    templateCoffee: Color(0xFF233964),
    templateStorm: Color(0xFF1D404A),
    shadow: Color(0x38000713),
    heroGradient: LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [Color(0xFF08162B), Color(0xFF153255), Color(0xFF08162B)]),
    karenGradient: LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [Color(0xFF42263F), Color(0xFF211F38)]),
    grandpaGradient: LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [Color(0xFF182941), Color(0xFF10243D)]),
  );

  @override
  DMSemanticColors copyWith({
    Color? appBackground,
    Color? surface,
    Color? surfaceSecondary,
    Color? textPrimary,
    Color? textSecondary,
    Color? textMuted,
    Color? border,
    Color? divider,
    Color? primary,
    Color? onPrimary,
    Color? link,
    Color? focusRing,
    Color? navSurface,
    Color? navSelected,
    Color? navSelectedForeground,
    Color? navInactive,
    Color? karenSurface,
    Color? karenBorder,
    Color? grandpaSurface,
    Color? grandpaBorder,
    Color? insightSurface,
    Color? insightIcon,
    Color? promoSurface,
    Color? promoText,
    Color? promoAction,
    Color? onPromoAction,
    Color? templateSun,
    Color? templateCoffee,
    Color? templateStorm,
    Color? shadow,
    LinearGradient? heroGradient,
    LinearGradient? karenGradient,
    LinearGradient? grandpaGradient,
  }) =>
      DMSemanticColors(
        appBackground: appBackground ?? this.appBackground,
        surface: surface ?? this.surface,
        surfaceSecondary: surfaceSecondary ?? this.surfaceSecondary,
        textPrimary: textPrimary ?? this.textPrimary,
        textSecondary: textSecondary ?? this.textSecondary,
        textMuted: textMuted ?? this.textMuted,
        border: border ?? this.border,
        divider: divider ?? this.divider,
        primary: primary ?? this.primary,
        onPrimary: onPrimary ?? this.onPrimary,
        link: link ?? this.link,
        focusRing: focusRing ?? this.focusRing,
        navSurface: navSurface ?? this.navSurface,
        navSelected: navSelected ?? this.navSelected,
        navSelectedForeground:
            navSelectedForeground ?? this.navSelectedForeground,
        navInactive: navInactive ?? this.navInactive,
        karenSurface: karenSurface ?? this.karenSurface,
        karenBorder: karenBorder ?? this.karenBorder,
        grandpaSurface: grandpaSurface ?? this.grandpaSurface,
        grandpaBorder: grandpaBorder ?? this.grandpaBorder,
        insightSurface: insightSurface ?? this.insightSurface,
        insightIcon: insightIcon ?? this.insightIcon,
        promoSurface: promoSurface ?? this.promoSurface,
        promoText: promoText ?? this.promoText,
        promoAction: promoAction ?? this.promoAction,
        onPromoAction: onPromoAction ?? this.onPromoAction,
        templateSun: templateSun ?? this.templateSun,
        templateCoffee: templateCoffee ?? this.templateCoffee,
        templateStorm: templateStorm ?? this.templateStorm,
        shadow: shadow ?? this.shadow,
        heroGradient: heroGradient ?? this.heroGradient,
        karenGradient: karenGradient ?? this.karenGradient,
        grandpaGradient: grandpaGradient ?? this.grandpaGradient,
      );

  @override
  DMSemanticColors lerp(covariant DMSemanticColors? other, double t) {
    if (other == null) return this;
    return DMSemanticColors(
      appBackground: Color.lerp(appBackground, other.appBackground, t)!,
      surface: Color.lerp(surface, other.surface, t)!,
      surfaceSecondary:
          Color.lerp(surfaceSecondary, other.surfaceSecondary, t)!,
      textPrimary: Color.lerp(textPrimary, other.textPrimary, t)!,
      textSecondary: Color.lerp(textSecondary, other.textSecondary, t)!,
      textMuted: Color.lerp(textMuted, other.textMuted, t)!,
      border: Color.lerp(border, other.border, t)!,
      divider: Color.lerp(divider, other.divider, t)!,
      primary: Color.lerp(primary, other.primary, t)!,
      onPrimary: Color.lerp(onPrimary, other.onPrimary, t)!,
      link: Color.lerp(link, other.link, t)!,
      focusRing: Color.lerp(focusRing, other.focusRing, t)!,
      navSurface: Color.lerp(navSurface, other.navSurface, t)!,
      navSelected: Color.lerp(navSelected, other.navSelected, t)!,
      navSelectedForeground:
          Color.lerp(navSelectedForeground, other.navSelectedForeground, t)!,
      navInactive: Color.lerp(navInactive, other.navInactive, t)!,
      karenSurface: Color.lerp(karenSurface, other.karenSurface, t)!,
      karenBorder: Color.lerp(karenBorder, other.karenBorder, t)!,
      grandpaSurface: Color.lerp(grandpaSurface, other.grandpaSurface, t)!,
      grandpaBorder: Color.lerp(grandpaBorder, other.grandpaBorder, t)!,
      insightSurface: Color.lerp(insightSurface, other.insightSurface, t)!,
      insightIcon: Color.lerp(insightIcon, other.insightIcon, t)!,
      promoSurface: Color.lerp(promoSurface, other.promoSurface, t)!,
      promoText: Color.lerp(promoText, other.promoText, t)!,
      promoAction: Color.lerp(promoAction, other.promoAction, t)!,
      onPromoAction: Color.lerp(onPromoAction, other.onPromoAction, t)!,
      templateSun: Color.lerp(templateSun, other.templateSun, t)!,
      templateCoffee: Color.lerp(templateCoffee, other.templateCoffee, t)!,
      templateStorm: Color.lerp(templateStorm, other.templateStorm, t)!,
      shadow: Color.lerp(shadow, other.shadow, t)!,
      heroGradient: LinearGradient.lerp(heroGradient, other.heroGradient, t)!,
      karenGradient:
          LinearGradient.lerp(karenGradient, other.karenGradient, t)!,
      grandpaGradient:
          LinearGradient.lerp(grandpaGradient, other.grandpaGradient, t)!,
    );
  }
}
