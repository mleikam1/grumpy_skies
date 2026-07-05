import '../data/daymaker_sample_data.dart';
import '../features/roasts/models/roast_persona.dart';
import '../models/weather_models.dart';
import 'settings_repository.dart';

class InMemorySettingsRepository extends SettingsRepository {
  UserSettings _settings;

  InMemorySettingsRepository({
    UserSettings initialSettings = DayMakerSampleData.userSettings,
  }) : _settings = initialSettings;

  @override
  Future<UserSettings> loadSettings() async {
    _settings = _normalized(_settings);
    return _settings;
  }

  @override
  Future<void> saveSettings(UserSettings settings) async {
    _settings = _normalized(settings);
  }

  UserSettings _normalized(UserSettings settings) {
    return settings.copyWith(
      selectedPersonaId: RoastPersonas.normalizeId(settings.selectedPersonaId),
    );
  }
}
