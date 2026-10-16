import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'dm_breakpoints.dart';
import 'dm_motion.dart';
import 'dm_roast_colors.dart';
import 'dm_semantic_colors.dart';
import 'dm_typography.dart';

export 'dm_semantic_colors.dart';
export 'dm_roast_colors.dart';

abstract final class DMTheme {
  const DMTheme._();

  static final ThemeData lightTheme = _build(Brightness.light);
  static final ThemeData darkTheme = _build(Brightness.dark);

  // Compatibility for existing tests and callers.
  static ThemeData get light => lightTheme;
  static ThemeData get dark => darkTheme;
  static ThemeData get lightOnDark => darkTheme;

  static ThemeData _build(Brightness brightness) {
    final dark = brightness == Brightness.dark;
    final c = dark ? DMSemanticColors.dark : DMSemanticColors.light;
    final scheme = ColorScheme(
      brightness: brightness,
      primary: c.primary,
      onPrimary: c.onPrimary,
      secondary: c.link,
      onSecondary: dark ? const Color(0xFF10213C) : Colors.white,
      tertiary: c.insightIcon,
      onTertiary: dark ? const Color(0xFF10213C) : Colors.white,
      error: dark ? const Color(0xFFFFB4AB) : const Color(0xFFB3261E),
      onError: dark ? const Color(0xFF690005) : Colors.white,
      errorContainer: dark ? const Color(0xFF512923) : const Color(0xFFFFE9E3),
      onErrorContainer:
          dark ? const Color(0xFFFFDAD6) : const Color(0xFF7A1C13),
      surface: c.surface,
      onSurface: c.textPrimary,
      onSurfaceVariant: c.textSecondary,
      surfaceContainerLowest: c.appBackground,
      surfaceContainerLow: c.surface,
      surfaceContainer: c.surface,
      surfaceContainerHigh: c.surfaceSecondary,
      surfaceContainerHighest: c.surfaceSecondary,
      outline: c.border,
      outlineVariant: c.divider,
      shadow: c.shadow,
      scrim: Colors.black,
      inverseSurface:
          dark ? DMSemanticColors.light.surface : DMSemanticColors.dark.surface,
      onInverseSurface: dark
          ? DMSemanticColors.light.textPrimary
          : DMSemanticColors.dark.textPrimary,
      inversePrimary: c.link,
      surfaceTint: Colors.transparent,
    );
    final text = DMTypography.withColor(c.textPrimary).copyWith(
      bodyMedium: DMTypography.body.copyWith(color: c.textPrimary),
      bodySmall: DMTypography.bodySmall.copyWith(color: c.textMuted),
      labelMedium: DMTypography.label.copyWith(color: c.textSecondary),
      labelSmall: DMTypography.labelSmall.copyWith(color: c.textMuted),
    );
    const radius = BorderRadius.all(Radius.circular(16));
    const shape = RoundedRectangleBorder(borderRadius: radius);
    final button = ButtonStyle(
      minimumSize: const WidgetStatePropertyAll(Size(48, 48)),
      padding: const WidgetStatePropertyAll(
          EdgeInsets.symmetric(horizontal: 18, vertical: 12)),
      shape: const WidgetStatePropertyAll(shape),
      textStyle: const WidgetStatePropertyAll(DMTypography.labelLarge),
      overlayColor: WidgetStateProperty.resolveWith((states) =>
          states.contains(WidgetState.focused)
              ? c.focusRing.withValues(alpha: .16)
              : null),
    );
    final overlay = systemOverlayFor(brightness);
    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      colorScheme: scheme,
      extensions: [c, dark ? DMRoastColors.dark : DMRoastColors.light],
      scaffoldBackgroundColor: c.appBackground,
      canvasColor: c.surface,
      cardColor: c.surface,
      dividerColor: c.divider,
      disabledColor: c.textDisabled,
      focusColor: c.focusRing.withValues(alpha: .18),
      hoverColor: c.focusRing.withValues(alpha: .07),
      highlightColor: c.primary.withValues(alpha: .16),
      fontFamily: 'DaymakerSans',
      fontFamilyFallback: DMTypography.systemFontStack,
      textTheme: text,
      primaryTextTheme: text,
      visualDensity: VisualDensity.standard,
      materialTapTargetSize: MaterialTapTargetSize.padded,
      iconTheme: IconThemeData(color: c.textPrimary),
      appBarTheme: AppBarTheme(
        backgroundColor: c.appBackground,
        foregroundColor: c.textPrimary,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        centerTitle: false,
        titleTextStyle: text.headlineSmall,
        systemOverlayStyle: overlay,
      ),
      cardTheme: CardThemeData(
        color: c.surface,
        elevation: 0,
        margin: EdgeInsets.zero,
        surfaceTintColor: Colors.transparent,
        shadowColor: c.shadow,
        clipBehavior: Clip.antiAlias,
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(22),
            side: BorderSide(color: c.border)),
      ),
      dividerTheme: DividerThemeData(color: c.divider, thickness: 1, space: 24),
      elevatedButtonTheme: ElevatedButtonThemeData(
          style: button.copyWith(
        backgroundColor: WidgetStateProperty.resolveWith((states) =>
            states.contains(WidgetState.disabled)
                ? c.surfaceSecondary
                : c.primary),
        foregroundColor: WidgetStateProperty.resolveWith((states) =>
            states.contains(WidgetState.disabled)
                ? c.textDisabled
                : c.onPrimary),
        elevation: const WidgetStatePropertyAll(0),
      )),
      filledButtonTheme: FilledButtonThemeData(
          style: button.copyWith(
        backgroundColor: WidgetStateProperty.resolveWith((states) =>
            states.contains(WidgetState.disabled)
                ? c.surfaceSecondary
                : c.primary),
        foregroundColor: WidgetStateProperty.resolveWith((states) =>
            states.contains(WidgetState.disabled)
                ? c.textDisabled
                : c.onPrimary),
      )),
      outlinedButtonTheme: OutlinedButtonThemeData(
          style: button.copyWith(
        foregroundColor: WidgetStatePropertyAll(c.textPrimary),
        side: WidgetStatePropertyAll(BorderSide(color: c.border)),
      )),
      textButtonTheme: TextButtonThemeData(
          style:
              button.copyWith(foregroundColor: WidgetStatePropertyAll(c.link))),
      iconButtonTheme: IconButtonThemeData(
          style: ButtonStyle(
        foregroundColor: WidgetStatePropertyAll(c.textPrimary),
        minimumSize: const WidgetStatePropertyAll(Size(48, 48)),
      )),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: c.surface,
        labelStyle: text.labelMedium,
        hintStyle: text.bodyMedium,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        border: OutlineInputBorder(
            borderRadius: radius, borderSide: BorderSide(color: c.border)),
        enabledBorder: OutlineInputBorder(
            borderRadius: radius, borderSide: BorderSide(color: c.border)),
        focusedBorder: OutlineInputBorder(
            borderRadius: radius,
            borderSide: BorderSide(color: c.focusRing, width: 2)),
        errorBorder: OutlineInputBorder(
            borderRadius: radius, borderSide: BorderSide(color: scheme.error)),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: c.surfaceSecondary,
        selectedColor: c.primary,
        disabledColor: c.surfaceSecondary,
        labelStyle: text.labelMedium,
        secondaryLabelStyle: text.labelMedium!.copyWith(color: c.onPrimary),
        checkmarkColor: c.onPrimary,
        side: BorderSide(color: c.border),
        shape: const StadiumBorder(),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: c.navSurface,
        indicatorColor: c.navSelected,
        surfaceTintColor: Colors.transparent,
        labelTextStyle: WidgetStatePropertyAll(text.labelSmall),
        iconTheme: WidgetStatePropertyAll(IconThemeData(color: c.navInactive)),
      ),
      bottomNavigationBarTheme: BottomNavigationBarThemeData(
        backgroundColor: c.navSurface,
        selectedItemColor: c.textPrimary,
        unselectedItemColor: c.navInactive,
        type: BottomNavigationBarType.fixed,
        elevation: 0,
      ),
      dialogTheme: DialogThemeData(
          backgroundColor: c.surface,
          surfaceTintColor: Colors.transparent,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(22))),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: c.surface,
        modalBackgroundColor: c.surface,
        surfaceTintColor: Colors.transparent,
        dragHandleColor: c.textMuted,
        shape: const RoundedRectangleBorder(
            borderRadius: BorderRadius.vertical(top: Radius.circular(26))),
      ),
      popupMenuTheme: PopupMenuThemeData(
          color: c.surface,
          textStyle: text.bodyMedium,
          surfaceTintColor: Colors.transparent,
          shape: shape),
      menuTheme: MenuThemeData(
          style: MenuStyle(
              backgroundColor: WidgetStatePropertyAll(c.surface),
              surfaceTintColor:
                  const WidgetStatePropertyAll(Colors.transparent))),
      dropdownMenuTheme: DropdownMenuThemeData(
          textStyle: text.bodyMedium,
          menuStyle:
              MenuStyle(backgroundColor: WidgetStatePropertyAll(c.surface))),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: c.surfaceSecondary,
        contentTextStyle: text.bodyMedium!.copyWith(color: c.textPrimary),
        actionTextColor: c.link,
        behavior: SnackBarBehavior.floating,
        shape: shape,
      ),
      tooltipTheme: TooltipThemeData(
          decoration: BoxDecoration(
              color: c.surfaceSecondary,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: c.border)),
          textStyle: text.bodySmall!.copyWith(color: c.textPrimary)),
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith((states) =>
            states.contains(WidgetState.selected) ? c.onPrimary : c.textMuted),
        trackColor: WidgetStateProperty.resolveWith((states) =>
            states.contains(WidgetState.selected)
                ? c.primary
                : c.surfaceSecondary),
        trackOutlineColor: WidgetStatePropertyAll(c.border),
      ),
      sliderTheme: SliderThemeData(
          activeTrackColor: c.link,
          inactiveTrackColor: c.border,
          thumbColor: c.primary,
          overlayColor: c.focusRing.withValues(alpha: .18),
          valueIndicatorColor: c.surfaceSecondary,
          valueIndicatorTextStyle: text.labelMedium),
      textSelectionTheme: TextSelectionThemeData(
          cursorColor: c.link,
          selectionColor: c.focusRing.withValues(alpha: .22),
          selectionHandleColor: c.link),
    );
  }

  static SystemUiOverlayStyle systemOverlayFor(Brightness brightness) {
    final dark = brightness == Brightness.dark;
    return SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: dark ? Brightness.light : Brightness.dark,
      statusBarBrightness: brightness,
      systemNavigationBarColor: dark
          ? DMSemanticColors.dark.appBackground
          : DMSemanticColors.light.appBackground,
      systemNavigationBarIconBrightness:
          dark ? Brightness.light : Brightness.dark,
      systemNavigationBarDividerColor: Colors.transparent,
    );
  }
}

extension DMThemeContextX on BuildContext {
  ThemeData get dmTheme => Theme.of(this);
  DMRoastColors get dmRoastColors =>
      Theme.of(this).extension<DMRoastColors>() ??
      (Theme.of(this).brightness == Brightness.dark
          ? DMRoastColors.dark
          : DMRoastColors.light);
  DMSemanticColors get dmColors =>
      Theme.of(this).extension<DMSemanticColors>() ??
      (Theme.of(this).brightness == Brightness.dark
          ? DMSemanticColors.dark
          : DMSemanticColors.light);
  ColorScheme get dmScheme => Theme.of(this).colorScheme;
  TextTheme get dmText => Theme.of(this).textTheme;
  DMBreakpoint get dmBreakpoint => DMBreakpoints.of(this);
  bool get dmIsCompact => dmBreakpoint.isCompact;
  bool get dmReduceMotion => DMMotion.shouldReduceMotion(this);
}
