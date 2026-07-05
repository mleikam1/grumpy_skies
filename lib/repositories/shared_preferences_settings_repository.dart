import 'package:shared_preferences/shared_preferences.dart';

import '../data/daymaker_sample_data.dart';
import '../features/roasts/models/roast_persona.dart';
import '../models/temperature_unit.dart';
import '../models/weather_models.dart';
import 'settings_repository.dart';

class SharedPreferencesSettingsRepository extends SettingsRepository {
  SharedPreferencesSettingsRepository(this._preferences);

  static const _temperatureUnitKey = 'settings.temperatureUnit';
  static const _selectedPersonaIdKey = 'settings.selectedPersonaId';
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
    const defaults = DayMakerSampleData.userSettings;

    return defaults.copyWith(
      temperatureUnit: _readTemperatureUnit() ?? defaults.temperatureUnit,
      selectedPersonaId: RoastPersonas.normalizeId(
        _preferences.getString(_selectedPersonaIdKey) ??
            defaults.selectedPersonaId,
      ),
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
    await Future.wait([
      _preferences.setString(
        _temperatureUnitKey,
        settings.temperatureUnit.name,
      ),
      _preferences.setString(
        _selectedPersonaIdKey,
        RoastPersonas.normalizeId(settings.selectedPersonaId),
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
