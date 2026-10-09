import 'package:flutter/material.dart';
import 'dm_theme.dart';

/// Metric-specific semantic roles. Accents identify a metric, never its value.
enum DMMetricTone { water, air, warm, cool, lunar }

@immutable
class DMMetricColors {
  const DMMetricColors(
      {required this.surface,
      required this.border,
      required this.value,
      required this.label,
      required this.unavailable,
      required this.status,
      required this.accent});

  final Color surface;
  final Color border;
  final Color value;
  final Color label;
  final Color unavailable;
  final Color status;
  final Color accent;

  factory DMMetricColors.of(BuildContext context, DMMetricTone tone) {
    final colors = context.dmColors;
    final dark = Theme.of(context).brightness == Brightness.dark;
    final accent = switch (tone) {
      DMMetricTone.water =>
        dark ? const Color(0xFF84DFDD) : const Color(0xFF176F73),
      DMMetricTone.air =>
        dark ? const Color(0xFF93E1C6) : const Color(0xFF267354),
      DMMetricTone.warm =>
        dark ? const Color(0xFFFFD985) : const Color(0xFF8B5C14),
      DMMetricTone.cool =>
        dark ? const Color(0xFFA4D9F3) : const Color(0xFF336D93),
      DMMetricTone.lunar =>
        dark ? const Color(0xFFD0BCF4) : const Color(0xFF71569A),
    };
    return DMMetricColors(
        surface: colors.surface,
        border: colors.border,
        value: colors.textPrimary,
        label: colors.textSecondary,
        unavailable: colors.textMuted,
        status: colors.textSecondary,
        accent: accent);
  }
}
