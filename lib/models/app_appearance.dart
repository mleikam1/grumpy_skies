import 'package:flutter/material.dart' show ThemeMode;

/// An explicit app preference; weather day/night never selects this value.
enum AppAppearance {
  light,
  dark,
  system;

  ThemeMode get themeMode => switch (this) {
        AppAppearance.light => ThemeMode.light,
        AppAppearance.dark => ThemeMode.dark,
        AppAppearance.system => ThemeMode.system,
      };

  String get label => switch (this) {
        AppAppearance.light => 'Light',
        AppAppearance.dark => 'Dark',
        AppAppearance.system => 'System',
      };

  static AppAppearance? tryParse(Object? value) {
    if (value is! String) return null;
    final normalized = value.trim().toLowerCase().split('.').last;
    for (final appearance in values) {
      if (appearance.name == normalized) return appearance;
    }
    return null;
  }
}
