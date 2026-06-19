import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/weather_models.dart';
import '../repositories/weather_repository.dart';
import 'location_service.dart';

enum LocationSelectionStatus {
  noSavedLocation,
  requestingPermission,
  permissionGranted,
  permissionDenied,
  permissionDeniedForever,
  locationServicesDisabled,
  locationTimeout,
  locationError,
  fetchingWeather,
  weatherLoaded,
  weatherError,
  manualSearch,
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
        _selectedLocation = initialLocation?.hasValidCoordinates == true
            ? initialLocation
            : null,
        _status = initialLocation?.hasValidCoordinates == true
            ? LocationSelectionStatus.weatherLoaded
            : LocationSelectionStatus.noSavedLocation;

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
  LocationSelectionStatus _status;
  String? _message;
  bool _disposed = false;

  WeatherLocation? get selectedLocation => _selectedLocation;
  LocationSelectionStatus get status => _status;
  String? get message => _message;
  bool get hasSelectedLocation => _selectedLocation != null;

  Future<void> restoreLastSelectedLocation() async {
    final raw = _preferences?.getString(_selectedLocationKey);
    if (raw == null || raw.trim().isEmpty) {
      _selectedLocation = null;
      _status = LocationSelectionStatus.noSavedLocation;
      _message = null;
      return;
    }

    try {
      final json = jsonDecode(raw) as Map<String, dynamic>;
      if (_isBundledSanFranciscoLocation(json)) {
        await _clearStoredLocation();
        return;
      }

      final restored = WeatherLocation.fromJson(json);
      if (!restored.hasValidCoordinates) {
        await _clearStoredLocation();
        return;
      }

      _selectedLocation = restored;
      _status = LocationSelectionStatus.weatherLoaded;
      _message = 'Restored ${_selectedLocation!.displayName}.';
      _notifyListenersSafely();
    } catch (_) {
      await _clearStoredLocation();
    }
  }

  Future<void> useCurrentLocation() async {
    _setStatus(
      LocationSelectionStatus.requestingPermission,
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

    if (!LocationCandidate.hasValidCoordinatePair(
      deviceLocation.latitude,
      deviceLocation.longitude,
    )) {
      _setStatus(
        LocationSelectionStatus.locationError,
        'Location returned invalid coordinates. Search manually instead.',
      );
      return;
    }

    _setStatus(
      LocationSelectionStatus.permissionGranted,
      'Location permission granted. Finding your forecast spot...',
    );
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
    if (!location.hasValidCoordinates) {
      _setStatus(
        LocationSelectionStatus.locationError,
        'That location has invalid coordinates. Search manually instead.',
      );
      return;
    }

    _selectedLocation = location is WeatherLocation
        ? location.copyWith(updatedAt: DateTime.now())
        : WeatherLocation.fromCandidate(
            location,
            source: source,
            updatedAt: DateTime.now(),
          );
    _status = source == WeatherLocationSource.device
        ? LocationSelectionStatus.permissionGranted
        : LocationSelectionStatus.manualSearch;
    _message = 'Using ${_selectedLocation!.displayName}.';
    await _preferences?.setString(
      _selectedLocationKey,
      jsonEncode(_selectedLocation!.toJson()),
    );
    _debugSelectedLocation(_selectedLocation!);
    _notifyListenersSafely();
  }

  Future<void> clearLocation() async {
    _selectedLocation = null;
    _status = LocationSelectionStatus.noSavedLocation;
    _message = null;
    await _preferences?.remove(_selectedLocationKey);
    _notifyListenersSafely();
  }

  void beginManualSearch() {
    _setStatus(
      LocationSelectionStatus.manualSearch,
      'Search by city or ZIP to choose your forecast location.',
    );
  }

  void markFetchingWeather() {
    final location = _selectedLocation;
    if (location == null) return;
    _setStatus(
      LocationSelectionStatus.fetchingWeather,
      'Fetching weather for ${location.displayName}...',
    );
    _debugWeatherFetchStarted(location);
  }

  void markWeatherLoaded() {
    final location = _selectedLocation;
    if (location == null) return;
    _setStatus(
      LocationSelectionStatus.weatherLoaded,
      'Showing weather for ${location.displayName}.',
    );
    _debugWeatherFetchSucceeded(location);
  }

  void markWeatherError(String message) {
    if (_selectedLocation == null) return;
    _setStatus(LocationSelectionStatus.weatherError, message);
    _debugWeatherFetchFailed(message);
  }

  void _setStatus(LocationSelectionStatus status, String message) {
    _status = status;
    _message = message;
    _notifyListenersSafely();
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }

  static LocationSelectionStatus _statusForFailure(
    DeviceLocationFailureType type,
  ) {
    return switch (type) {
      DeviceLocationFailureType.servicesDisabled =>
        LocationSelectionStatus.locationServicesDisabled,
      DeviceLocationFailureType.permissionDenied =>
        LocationSelectionStatus.permissionDenied,
      DeviceLocationFailureType.permissionDeniedForever =>
        LocationSelectionStatus.permissionDeniedForever,
      DeviceLocationFailureType.timeout =>
        LocationSelectionStatus.locationTimeout,
      DeviceLocationFailureType.unknown =>
        LocationSelectionStatus.locationError,
    };
  }

  Future<void> _clearStoredLocation() async {
    _selectedLocation = null;
    _status = LocationSelectionStatus.noSavedLocation;
    _message = null;
    await _preferences?.remove(_selectedLocationKey);
    _notifyListenersSafely();
  }

  void _notifyListenersSafely() {
    if (_disposed) return;
    notifyListeners();
  }

  static bool _isBundledSanFranciscoLocation(Map<String, dynamic> json) {
    final name = (json['name'] as String?)
        ?.trim()
        .toLowerCase()
        .replaceAll(RegExp(r'\s+'), ' ');
    final lat = (json['lat'] as num?)?.toDouble();
    final lon = (json['lon'] as num?)?.toDouble();
    final bundledName = ['san', 'francisco'].join(' ');
    final looksLikeBundledLocation = name == bundledName &&
        lat != null &&
        lon != null &&
        lat > 37.7 &&
        lat < 37.8 &&
        lon > -122.5 &&
        lon < -122.3;
    if (!looksLikeBundledLocation) return false;

    final source = WeatherLocationSourceX.parse(json['source']);
    return json['updatedAt'] == null || source == WeatherLocationSource.unknown;
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

  static void _debugWeatherFetchStarted(WeatherLocation location) {
    if (!kDebugMode) return;
    debugPrint(
      '[GrumpySkies] weather fetch started '
      'source=${location.source} '
      'lat=${location.latitude.toStringAsFixed(3)} '
      'lon=${location.longitude.toStringAsFixed(3)} '
      'name=${location.displayName}',
    );
  }

  static void _debugWeatherFetchSucceeded(WeatherLocation location) {
    if (!kDebugMode) return;
    debugPrint(
      '[GrumpySkies] weather fetch succeeded '
      'source=${location.source} '
      'lat=${location.latitude.toStringAsFixed(3)} '
      'lon=${location.longitude.toStringAsFixed(3)} '
      'name=${location.displayName}',
    );
  }

  static void _debugWeatherFetchFailed(String message) {
    if (!kDebugMode) return;
    debugPrint('[GrumpySkies] weather fetch failed: $message');
  }
}
