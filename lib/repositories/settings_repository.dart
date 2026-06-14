import '../models/weather_models.dart';

abstract class SettingsRepository {
  Future<UserSettings> loadSettings();

  Future<void> saveSettings(UserSettings settings);

  Future<UserSettings> updateSettings(
    UserSettings Function(UserSettings current) update,
  ) async {
    final next = update(await loadSettings());
    await saveSettings(next);
    return next;
  }
}
