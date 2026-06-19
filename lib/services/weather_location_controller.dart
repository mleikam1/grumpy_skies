import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/weather_models.dart';
import '../repositories/weather_repository.dart';
import 'location_service.dart';

enum LocationSelectionStatus {
  idle,
  loading,
  success,
  denied,
  deniedForever,
  unavailable,
  timeout,
  error,
}

class WeatherLocationController extends ChangeNotifier {
  WeatherLocationController({
    required WeatherRepository repository,
    LocationService locationService = const GeolocatorLocationService(),
    SharedPreferences? preferences,
    WeatherLocation? initialLocation,
  })  : _repository = repository,
        _locationService = locationService,
        _preferences = preferences,
        _selectedLocation = initialLocation;

  static const _selectedLocationKey = 'weather_selected_location';

  static Future<WeatherLocationController> create({
    required WeatherRepository repository,
    LocationService locationService = const GeolocatorLocationService(),
  }) async {
    final preferences = await SharedPreferences.getInstance();
    final controller = WeatherLocationController(
      repository: repository,
      locationService: locationService,
      preferences: preferences,
    );
    await controller.restoreLastSelectedLocation();
    return controller;
  }

  final WeatherRepository _repository;
  final LocationService _locationService;
  final SharedPreferences? _preferences;

  WeatherLocation? _selectedLocation;
  LocationSelectionStatus _status = LocationSelectionStatus.idle;
  String? _message;

  WeatherLocation? get selectedLocation => _selectedLocation;
  LocationSelectionStatus get status => _status;
  String? get message => _message;
  bool get hasSelectedLocation => _selectedLocation != null;

  Future<void> restoreLastSelectedLocation() async {
    final raw = _preferences?.getString(_selectedLocationKey);
    if (raw == null || raw.trim().isEmpty) return;

    try {
      final json = jsonDecode(raw) as Map<String, dynamic>;
      if (_isLegacyBundledLocation(json)) {
        await _preferences?.remove(_selectedLocationKey);
        return;
      }

      _selectedLocation = WeatherLocation.fromJson(json);
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

    final result = await _locationService.getCurrentLocation();
    final deviceLocation = result.location;
    if (deviceLocation == null) {
      final failure = result.failure ??
          const DeviceLocationFailure(
            type: DeviceLocationFailureType.unknown,
            message: 'Location is unavailable right now. Search manually.',
          );
      _setStatus(_statusForFailure(failure.type), failure.message);
      return;
    }

    _setStatus(
        LocationSelectionStatus.loading, 'Getting your forecast spot...');
    try {
      final candidate = await _repository.reverseGeocode(
            latitude: deviceLocation.latitude,
            longitude: deviceLocation.longitude,
          ) ??
          LocationCandidate(
            name: 'Current location',
            country: '',
            lat: deviceLocation.latitude,
            lon: deviceLocation.longitude,
            source: WeatherLocationSource.device.storageValue,
          );
      await selectLocation(candidate, source: WeatherLocationSource.device);
    } catch (_) {
      await selectLocation(
        LocationCandidate(
          name: 'Current location',
          country: '',
          lat: deviceLocation.latitude,
          lon: deviceLocation.longitude,
          source: WeatherLocationSource.device.storageValue,
        ),
        source: WeatherLocationSource.device,
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

  Future<void> selectLocation(
    LocationCandidate location, {
    WeatherLocationSource source = WeatherLocationSource.manual,
  }) async {
    _selectedLocation = location is WeatherLocation
        ? location.copyWith(updatedAt: DateTime.now())
        : WeatherLocation.fromCandidate(
            location,
            source: source,
            updatedAt: DateTime.now(),
          );
    _status = LocationSelectionStatus.success;
    _message = 'Using ${_selectedLocation!.displayName}.';
    await _preferences?.setString(
      _selectedLocationKey,
      jsonEncode(_selectedLocation!.toJson()),
    );
    _debugSelectedLocation(_selectedLocation!);
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

  static LocationSelectionStatus _statusForFailure(
    DeviceLocationFailureType type,
  ) {
    return switch (type) {
      DeviceLocationFailureType.servicesDisabled =>
        LocationSelectionStatus.unavailable,
      DeviceLocationFailureType.permissionDenied =>
        LocationSelectionStatus.denied,
      DeviceLocationFailureType.permissionDeniedForever =>
        LocationSelectionStatus.deniedForever,
      DeviceLocationFailureType.timeout => LocationSelectionStatus.timeout,
      DeviceLocationFailureType.unknown => LocationSelectionStatus.error,
    };
  }

  static bool _isLegacyBundledLocation(Map<String, dynamic> json) {
    if (json['updatedAt'] != null) return false;
    final name = (json['name'] as String?)
        ?.trim()
        .toLowerCase()
        .replaceAll(RegExp(r'\s+'), ' ');
    final lat = (json['lat'] as num?)?.toDouble();
    final lon = (json['lon'] as num?)?.toDouble();
    final bundledName = ['san', 'francisco'].join(' ');
    return name == bundledName &&
        lat != null &&
        lon != null &&
        lat > 37.7 &&
        lat < 37.8 &&
        lon > -122.5 &&
        lon < -122.3;
  }

  static void _debugSelectedLocation(WeatherLocation location) {
    if (!kDebugMode) return;
    debugPrint(
      '[GrumpySkies] selected ${location.source} location '
      'lat=${location.latitude.toStringAsFixed(3)} '
      'lon=${location.longitude.toStringAsFixed(3)} '
      'name=${location.displayName}',
    );
  }
}
