import 'package:flutter/material.dart';

import 'dm_breakpoints.dart';
import 'dm_colors.dart';
import 'dm_motion.dart';
import 'dm_radius.dart';
import 'dm_spacing.dart';
import 'dm_typography.dart';

abstract final class DMTheme {
  const DMTheme._();

  static ThemeData get light => _lightOnDark;

  static ThemeData get lightOnDark => _lightOnDark;

  static ThemeData get dark => _lightOnDark;

  static final ColorScheme _colorScheme = ColorScheme.fromSeed(
    seedColor: DMColors.skyBlue,
    brightness: Brightness.dark,
  ).copyWith(
    primary: DMColors.skyBlue,
    onPrimary: DMColors.deepNavy,
    primaryContainer: DMColors.skyBlueDeep,
    onPrimaryContainer: DMColors.cloudWhite,
    secondary: DMColors.sunriseYellow,
    onSecondary: DMColors.deepNavy,
    secondaryContainer: DMColors.sunriseAmber,
    onSecondaryContainer: DMColors.deepNavy,
    tertiary: DMColors.playfulPink,
    onTertiary: DMColors.deepNavy,
    tertiaryContainer: DMColors.lavenderDeep,
    onTertiaryContainer: DMColors.cloudWhite,
    error: DMColors.alertRed,
    onError: DMColors.cloudWhite,
    errorContainer: DMColors.alertOrange,
    onErrorContainer: DMColors.deepNavy,
    surface: DMColors.surface,
    onSurface: DMColors.textPrimary,
    surfaceContainerLowest: DMColors.deepNavy,
    surfaceContainerLow: DMColors.midnightNavy,
    surfaceContainer: DMColors.surface,
    surfaceContainerHigh: DMColors.surfaceElevated,
    surfaceContainerHighest: DMColors.surfaceRaised,
    outline: DMColors.outline,
    outlineVariant: DMColors.outlineVariant,
    shadow: DMColors.shadow,
    scrim: Colors.black,
    inverseSurface: DMColors.cloudWhite,
    onInverseSurface: DMColors.deepNavy,
    inversePrimary: DMColors.skyBlueDeep,
    surfaceTint: DMColors.skyBlue,
  );

  static final ThemeData _lightOnDark = ThemeData(
    useMaterial3: true,
    brightness: Brightness.dark,
    colorScheme: _colorScheme,
    scaffoldBackgroundColor: DMColors.deepNavy,
    canvasColor: DMColors.deepNavy,
    cardColor: DMColors.glassNavy,
    dividerColor: DMColors.divider,
    disabledColor: DMColors.textDisabled,
    fontFamilyFallback: DMTypography.systemFontStack,
    textTheme: DMTypography.textTheme,
    primaryTextTheme: DMTypography.textTheme,
    visualDensity: VisualDensity.adaptivePlatformDensity,
    appBarTheme: const AppBarTheme(
      backgroundColor: Colors.transparent,
      foregroundColor: DMColors.textPrimary,
      elevation: 0,
      centerTitle: false,
      iconTheme: IconThemeData(color: DMColors.textPrimary),
      titleTextStyle: DMTypography.headingSmall,
    ),
    cardTheme: const CardThemeData(
      color: DMColors.glassNavy,
      elevation: 0,
      margin: EdgeInsets.zero,
      shadowColor: DMColors.shadow,
      surfaceTintColor: DMColors.skyBlue,
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(
        borderRadius: DMRadius.card,
        side: BorderSide(color: DMColors.glassBorder),
      ),
    ),
    dividerTheme: const DividerThemeData(
      color: DMColors.divider,
      space: DMSpacing.xl,
      thickness: 1,
    ),
    chipTheme: ChipThemeData(
      backgroundColor: DMColors.glass,
      selectedColor: DMColors.skyBlue,
      disabledColor: DMColors.surfaceDisabled,
      checkmarkColor: DMColors.deepNavy,
      labelStyle: DMTypography.label,
      secondaryLabelStyle: DMTypography.label.copyWith(
        color: DMColors.deepNavy,
      ),
      side: const BorderSide(color: DMColors.glassBorder),
      shape: const StadiumBorder(),
      padding: const EdgeInsets.symmetric(
        horizontal: DMSpacing.xs,
        vertical: DMSpacing.xxs,
      ),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: DMColors.skyBlue,
        foregroundColor: DMColors.deepNavy,
        disabledBackgroundColor: DMColors.surfaceDisabled,
        disabledForegroundColor: DMColors.textDisabled,
        elevation: 0,
        minimumSize: const Size(0, DMSpacing.tapTarget),
        padding: const EdgeInsets.symmetric(
          horizontal: DMSpacing.xl,
          vertical: DMSpacing.sm,
        ),
        textStyle: DMTypography.labelLarge,
        shape: const StadiumBorder(),
      ),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: DMColors.sunriseYellow,
        foregroundColor: DMColors.deepNavy,
        disabledBackgroundColor: DMColors.surfaceDisabled,
        disabledForegroundColor: DMColors.textDisabled,
        minimumSize: const Size(0, DMSpacing.tapTarget),
        padding: const EdgeInsets.symmetric(
          horizontal: DMSpacing.xl,
          vertical: DMSpacing.sm,
        ),
        textStyle: DMTypography.labelLarge,
        shape: const StadiumBorder(),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: DMColors.textPrimary,
        disabledForegroundColor: DMColors.textDisabled,
        side: const BorderSide(color: DMColors.glassBorderStrong),
        minimumSize: const Size(0, DMSpacing.tapTarget),
        padding: const EdgeInsets.symmetric(
          horizontal: DMSpacing.xl,
          vertical: DMSpacing.sm,
        ),
        textStyle: DMTypography.labelLarge,
        shape: const StadiumBorder(),
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        foregroundColor: DMColors.skyBlueSoft,
        disabledForegroundColor: DMColors.textDisabled,
        minimumSize: const Size(0, DMSpacing.tapTarget),
        padding: const EdgeInsets.symmetric(
          horizontal: DMSpacing.md,
          vertical: DMSpacing.xs,
        ),
        textStyle: DMTypography.labelLarge,
        shape: const StadiumBorder(),
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: DMColors.glass,
      labelStyle: DMTypography.label.copyWith(color: DMColors.textSecondary),
      hintStyle: DMTypography.body.copyWith(color: DMColors.textMuted),
      contentPadding: const EdgeInsets.symmetric(
        horizontal: DMSpacing.md,
        vertical: DMSpacing.sm,
      ),
      border: const OutlineInputBorder(
        borderRadius: DMRadius.medium,
        borderSide: BorderSide(color: DMColors.glassBorder),
      ),
      enabledBorder: const OutlineInputBorder(
        borderRadius: DMRadius.medium,
        borderSide: BorderSide(color: DMColors.glassBorder),
      ),
      focusedBorder: const OutlineInputBorder(
        borderRadius: DMRadius.medium,
        borderSide: BorderSide(color: DMColors.skyBlue, width: 1.5),
      ),
      errorBorder: const OutlineInputBorder(
        borderRadius: DMRadius.medium,
        borderSide: BorderSide(color: DMColors.alertRed),
      ),
    ),
    navigationBarTheme: const NavigationBarThemeData(
      backgroundColor: DMColors.glassNavy,
      indicatorColor: DMColors.glassStrong,
      surfaceTintColor: Colors.transparent,
      shadowColor: Colors.transparent,
      labelTextStyle: WidgetStatePropertyAll<TextStyle>(
        DMTypography.labelSmall,
      ),
      iconTheme: WidgetStatePropertyAll<IconThemeData>(
        IconThemeData(color: DMColors.textPrimary),
      ),
    ),
    bottomNavigationBarTheme: const BottomNavigationBarThemeData(
      backgroundColor: DMColors.glassNavy,
      selectedItemColor: DMColors.skyBlue,
      unselectedItemColor: DMColors.textMuted,
      type: BottomNavigationBarType.fixed,
      elevation: 0,
    ),
    snackBarTheme: SnackBarThemeData(
      backgroundColor: DMColors.surfaceRaised,
      contentTextStyle: DMTypography.body.copyWith(
        color: DMColors.textPrimary,
      ),
      behavior: SnackBarBehavior.floating,
      shape: const RoundedRectangleBorder(borderRadius: DMRadius.large),
    ),
    switchTheme: SwitchThemeData(
      thumbColor: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.selected)) {
          return DMColors.deepNavy;
        }
        return DMColors.textSecondary;
      }),
      trackColor: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.selected)) {
          return DMColors.mintGreen;
        }
        return DMColors.glassStrong;
      }),
    ),
    sliderTheme: SliderThemeData(
      activeTrackColor: DMColors.skyBlue,
      inactiveTrackColor: DMColors.glassStrong,
      thumbColor: DMColors.sunriseYellow,
      overlayColor: DMColors.skyGlow,
      valueIndicatorColor: DMColors.surfaceRaised,
      valueIndicatorTextStyle: DMTypography.label.copyWith(
        color: DMColors.textPrimary,
      ),
    ),
  );
}

extension DMThemeContextX on BuildContext {
  ThemeData get dmTheme => Theme.of(this);

  ColorScheme get dmScheme => Theme.of(this).colorScheme;

  TextTheme get dmText => Theme.of(this).textTheme;

  DMBreakpoint get dmBreakpoint => DMBreakpoints.of(this);

  bool get dmIsCompact => dmBreakpoint.isCompact;

  bool get dmReduceMotion => DMMotion.shouldReduceMotion(this);
}
