import 'dart:async';
import 'package:flutter/foundation.dart';

import '../models/temperature_unit.dart';
import '../models/weather_models.dart';
import '../repositories/settings_repository.dart';

class SettingsController extends ChangeNotifier {
  SettingsController({
    SettingsRepository? repository,
    UserSettings initialSettings = UserSettings.defaults,
  })  : _repository = repository,
        _settings = initialSettings;

  final SettingsRepository? _repository;

  UserSettings _settings;
  bool _isLoaded = false;
  bool _isSaving = false;
  Object? _lastError;
  UserSettings? _pendingSave;
  Future<void> _saveTask = Future.value();
  bool _disposed = false;

  UserSettings get settings => _settings;

  AppAppearance get appearance => _settings.appearance;

  TemperatureUnit get temperatureUnit => _settings.temperatureUnit;

  bool get notificationsEnabled => _settings.notificationsEnabled;

  bool get adsEnabled => _settings.adsEnabled;

  bool get isLoaded => _isLoaded;

  bool get isSaving => _isSaving;

  Object? get lastError => _lastError;

  Future<void> loadSettings() async {
    final repository = _repository;
    if (repository == null) {
      _isLoaded = true;
      if (!_disposed) notifyListeners();
      return;
    }

    try {
      _settings = await repository.loadSettings();
      _lastError = null;
    } catch (error) {
      _lastError = error;
    } finally {
      _isLoaded = true;
      if (!_disposed) notifyListeners();
    }
  }

  void setAppearance(AppAppearance appearance) {
    if (appearance == _settings.appearance) return;
    _updateSettings(_settings.copyWith(appearance: appearance));
  }

  void setTemperatureUnit(TemperatureUnit unit) {
    if (unit == _settings.temperatureUnit) return;
    _updateSettings(_settings.copyWith(temperatureUnit: unit));
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
    _settings = next;
    _lastError = null;
    notifyListeners();
    if (_repository != null) {
      _pendingSave = _settings;
      if (!_isSaving) _saveTask = _saveSettings();
      unawaited(_saveTask);
    }
  }

  void retrySave() {
    if (_repository == null || _isSaving) return;
    _pendingSave = _settings;
    _saveTask = _saveSettings();
    unawaited(_saveTask);
  }

  /// Useful at explicit save/exit boundaries without delaying optimistic UI.
  Future<void> waitForPendingSave() => _saveTask;

  Future<void> _saveSettings() async {
    final repository = _repository;
    if (repository == null) return;
    _isSaving = true;
    notifyListeners();
    while (_pendingSave != null) {
      final snapshot = _pendingSave!;
      _pendingSave = null;
      try {
        // Only one immutable snapshot is written at a time. Rapid changes
        // coalesce into the next snapshot and can never finish out of order.
        await repository.saveSettings(snapshot);
        _lastError = null;
      } catch (error) {
        _lastError = error;
      }
    }
    _isSaving = false;
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}
