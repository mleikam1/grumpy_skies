import '../models/weather_models.dart';
import 'settings_repository.dart';

class InMemorySettingsRepository extends SettingsRepository {
  UserSettings _settings;

  InMemorySettingsRepository({
    UserSettings initialSettings = UserSettings.defaults,
  }) : _settings = initialSettings;

  @override
  Future<UserSettings> loadSettings() async {
    return _settings;
  }

  @override
  Future<void> saveSettings(UserSettings settings) async {
    _settings = settings;
  }
}
