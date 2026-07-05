import 'package:flutter/foundation.dart';

import '../data/daymaker_sample_data.dart';
import '../features/roasts/models/roast_persona.dart';
import '../models/temperature_unit.dart';
import '../models/weather_models.dart';
import '../repositories/settings_repository.dart';

class SettingsController extends ChangeNotifier {
  SettingsController({
    SettingsRepository? repository,
    UserSettings initialSettings = DayMakerSampleData.userSettings,
  })  : _repository = repository,
        _settings = initialSettings;

  final SettingsRepository? _repository;

  UserSettings _settings;
  bool _isLoaded = false;
  bool _isSaving = false;
  Object? _lastError;

  UserSettings get settings => _settings;

  TemperatureUnit get temperatureUnit => _settings.temperatureUnit;

  String get selectedPersonaId => _settings.selectedPersonaId;

  bool get notificationsEnabled => _settings.notificationsEnabled;

  bool get adsEnabled => _settings.adsEnabled;

  bool get isLoaded => _isLoaded;

  bool get isSaving => _isSaving;

  Object? get lastError => _lastError;

  Future<void> loadSettings() async {
    final repository = _repository;
    if (repository == null) {
      _settings = _normalized(_settings);
      _isLoaded = true;
      notifyListeners();
      return;
    }

    try {
      _settings = _normalized(await repository.loadSettings());
      _lastError = null;
    } catch (error) {
      _lastError = error;
    } finally {
      _isLoaded = true;
      notifyListeners();
    }
  }

  void setTemperatureUnit(TemperatureUnit unit) {
    if (unit == _settings.temperatureUnit) return;
    _updateSettings(_settings.copyWith(temperatureUnit: unit));
  }

  void setSelectedPersonaId(String personaId) {
    final normalized = RoastPersonas.normalizeId(personaId);
    if (normalized == _settings.selectedPersonaId) return;
    _updateSettings(_settings.copyWith(selectedPersonaId: normalized));
  }

  void setNotificationsEnabled(bool enabled) {
    if (enabled == _settings.notificationsEnabled) return;
    _updateSettings(_settings.copyWith(notificationsEnabled: enabled));
  }

  void setAdsEnabled(bool enabled) {
    if (enabled == _settings.adsEnabled) return;
    _updateSettings(_settings.copyWith(adsEnabled: enabled));
  }

  void _updateSettings(UserSettings next) {
    _settings = _normalized(next);
    _lastError = null;
    notifyListeners();
    _saveSettings();
  }

  Future<void> _saveSettings() async {
    final repository = _repository;
    if (repository == null) return;

    _isSaving = true;
    notifyListeners();

    try {
      await repository.saveSettings(_settings);
      _lastError = null;
    } catch (error) {
      _lastError = error;
    } finally {
      _isSaving = false;
      notifyListeners();
    }
  }

  UserSettings _normalized(UserSettings settings) {
    return settings.copyWith(
      selectedPersonaId: RoastPersonas.normalizeId(settings.selectedPersonaId),
    );
  }
}
