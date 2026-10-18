import 'package:shared_preferences/shared_preferences.dart';

import '../models/temperature_unit.dart';
import '../models/weather_models.dart';
import 'settings_repository.dart';
import '../services/wingman_upgrade_migration.dart';

class SharedPreferencesSettingsRepository extends SettingsRepository {
  SharedPreferencesSettingsRepository(this._preferences);

  static const _appearanceKey = 'settings.appearance';
  static const _temperatureUnitKey = 'settings.temperatureUnit';
  static const _notificationsEnabledKey = 'settings.notificationsEnabled';
  static const _adsEnabledKey = 'settings.adsEnabled';
  static const _xpKey = 'settings.xp';
  static const _levelKey = 'settings.level';
  static const _streakDaysKey = 'settings.streakDays';

  final SharedPreferences _preferences;

  static Future<SharedPreferencesSettingsRepository> create() async {
    return SharedPreferencesSettingsRepository(
      await SharedPreferences.getInstance(),
    );
  }

  @override
  Future<UserSettings> loadSettings() async {
    await WingmanUpgradeMigration.run(_preferences);
    const defaults = UserSettings.defaults;

    return defaults.copyWith(
      appearance: _readAppearance(),
      temperatureUnit: _readTemperatureUnit() ?? defaults.temperatureUnit,
      notificationsEnabled: _preferences.getBool(_notificationsEnabledKey) ??
          defaults.notificationsEnabled,
      adsEnabled: _preferences.getBool(_adsEnabledKey) ?? defaults.adsEnabled,
      xp: _preferences.getInt(_xpKey) ?? defaults.xp,
      level: _preferences.getInt(_levelKey) ?? defaults.level,
      streakDays: _preferences.getInt(_streakDaysKey) ?? defaults.streakDays,
    );
  }

  @override
  Future<void> saveSettings(UserSettings settings) async {
    final saved = await Future.wait([
      _preferences.setString(_appearanceKey, settings.appearance.name),
      _preferences.setString(
        _temperatureUnitKey,
        settings.temperatureUnit.name,
      ),
      _preferences.setBool(
        _notificationsEnabledKey,
        settings.notificationsEnabled,
      ),
      _preferences.setBool(_adsEnabledKey, settings.adsEnabled),
      _preferences.setInt(_xpKey, settings.xp),
      _preferences.setInt(_levelKey, settings.level),
      _preferences.setInt(_streakDaysKey, settings.streakDays),
    ]);
    if (saved.any((success) => !success)) {
      throw StateError('One or more settings could not be saved.');
    }
  }

  AppAppearance _readAppearance() {
    // Read-only compatibility: preserve legacy/unknown entries and every other
    // preference. A later ordinary save writes the canonical appearance key.
    for (final key in const [
      _appearanceKey,
      'settings.themeMode',
      'themeMode',
      'theme_mode',
      'appearance',
    ]) {
      final parsed = AppAppearance.tryParse(_preferences.get(key));
      if (parsed != null) return parsed;
    }
    for (final key in const ['settings.darkMode', 'darkMode', 'isDarkMode']) {
      final legacy = _preferences.get(key);
      if (legacy is bool) {
        return legacy ? AppAppearance.dark : AppAppearance.light;
      }
    }
    return AppAppearance.light;
  }

  TemperatureUnit? _readTemperatureUnit() {
    final stored = _preferences.getString(_temperatureUnitKey);
    if (stored == null) return null;

    for (final unit in TemperatureUnit.values) {
      if (unit.name == stored) return unit;
    }

    return null;
  }
}
