import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/weather_models.dart';
import '../repositories/weather_repository.dart';

enum LocationSelectionStatus {
  idle,
  loading,
  success,
  denied,
  unavailable,
  error,
}

class WeatherLocationController extends ChangeNotifier {
  WeatherLocationController({
    required WeatherRepository repository,
    SharedPreferences? preferences,
    LocationCandidate? initialLocation,
  })  : _repository = repository,
        _preferences = preferences,
        _selectedLocation = initialLocation;

  static const _selectedLocationKey = 'weather_selected_location';
  static const fallbackLocation = LocationCandidate(
    name: 'San Francisco',
    state: 'CA',
    country: 'US',
    lat: 37.7749,
    lon: -122.4194,
    source: 'city',
  );

  static Future<WeatherLocationController> create({
    required WeatherRepository repository,
  }) async {
    final preferences = await SharedPreferences.getInstance();
    final controller = WeatherLocationController(
      repository: repository,
      preferences: preferences,
    );
    await controller.restoreLastSelectedLocation();
    return controller;
  }

  final WeatherRepository _repository;
  final SharedPreferences? _preferences;

  LocationCandidate? _selectedLocation;
  LocationSelectionStatus _status = LocationSelectionStatus.idle;
  String? _message;

  LocationCandidate? get selectedLocation => _selectedLocation;
  LocationSelectionStatus get status => _status;
  String? get message => _message;
  bool get hasSelectedLocation => _selectedLocation != null;

  Future<void> restoreLastSelectedLocation() async {
    final raw = _preferences?.getString(_selectedLocationKey);
    if (raw == null || raw.trim().isEmpty) return;

    try {
      final json = jsonDecode(raw) as Map<String, dynamic>;
      _selectedLocation = LocationCandidate.fromJson(json);
      _status = LocationSelectionStatus.success;
      _message = 'Restored ${_selectedLocation!.displayName}.';
      notifyListeners();
    } catch (_) {
      await _preferences?.remove(_selectedLocationKey);
    }
  }

  Future<void> useCurrentLocation() async {
    _setStatus(
      LocationSelectionStatus.loading,
      'Checking location permission...',
    );

    try {
      final serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        _setStatus(
          LocationSelectionStatus.unavailable,
          'Location services are unavailable. Search by city or ZIP instead.',
        );
        return;
      }

      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }

      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        _setStatus(
          LocationSelectionStatus.denied,
          'Location permission was denied. City or ZIP search still works.',
        );
        return;
      }

      _setStatus(LocationSelectionStatus.loading, 'Getting your location...');
      final position = await Geolocator.getCurrentPosition(
        locationSettings: _locationSettings(),
      );
      final location = await _repository.reverseGeocode(
            latitude: position.latitude,
            longitude: position.longitude,
          ) ??
          LocationCandidate(
            name: 'Current location',
            country: 'US',
            lat: position.latitude,
            lon: position.longitude,
            source: 'browser',
          );
      await selectLocation(location);
    } on TimeoutException {
      _setStatus(
        LocationSelectionStatus.unavailable,
        'Location lookup timed out. Try city or ZIP search.',
      );
    } catch (_) {
      _setStatus(
        LocationSelectionStatus.error,
        'Location is unavailable right now. Try city or ZIP search.',
      );
    }
  }

  Future<List<LocationCandidate>> searchCity(String query) async {
    final trimmed = query.trim();
    if (trimmed.length < 2) return const [];
    return _repository.searchLocations(query: trimmed);
  }

  Future<LocationCandidate?> searchZip(
    String zip, {
    String country = 'US',
  }) async {
    final trimmed = zip.trim();
    if (trimmed.length < 2) return null;
    return _repository.lookupZip(zip: trimmed, country: country);
  }

  Future<void> selectLocation(LocationCandidate location) async {
    _selectedLocation = location;
    _status = LocationSelectionStatus.success;
    _message = 'Using ${location.displayName}.';
    await _preferences?.setString(
      _selectedLocationKey,
      jsonEncode(location.toJson()),
    );
    notifyListeners();
  }

  Future<void> clearLocation() async {
    _selectedLocation = null;
    _status = LocationSelectionStatus.idle;
    _message = null;
    await _preferences?.remove(_selectedLocationKey);
    notifyListeners();
  }

  void _setStatus(LocationSelectionStatus status, String message) {
    _status = status;
    _message = message;
    notifyListeners();
  }

  LocationSettings _locationSettings() {
    const timeout = Duration(seconds: 10);
    if (kIsWeb) {
      return WebSettings(
        accuracy: LocationAccuracy.low,
        timeLimit: timeout,
        maximumAge: const Duration(minutes: 10),
      );
    }

    return const LocationSettings(
      accuracy: LocationAccuracy.low,
      timeLimit: timeout,
    );
  }
}
