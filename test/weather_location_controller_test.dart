import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:grumpy_skies/models/weather_models.dart';
import 'package:grumpy_skies/repositories/fake_weather_repository.dart';
import 'package:grumpy_skies/services/location_service.dart';
import 'package:grumpy_skies/services/weather_location_controller.dart';

void main() {
  const storageKey = 'weather_selected_location';

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  test('starts without a default production location', () async {
    final controller = await WeatherLocationController.create(
      repository: const FakeWeatherRepository(),
    );

    expect(controller.selectedLocation, isNull);
    expect(controller.hasSelectedLocation, isFalse);
  });

  test('loads persisted weather location', () async {
    final stored = WeatherLocation(
      name: 'Demo City',
      country: 'US',
      latitude: 41.8781,
      longitude: -87.6298,
      source: WeatherLocationSource.manual,
      updatedAt: DateTime(2026, 6, 19, 9),
    );
    SharedPreferences.setMockInitialValues({
      storageKey: jsonEncode(stored.toJson()),
    });

    final controller = await WeatherLocationController.create(
      repository: const FakeWeatherRepository(),
    );

    expect(controller.selectedLocation?.displayName, 'Demo City, US');
    expect(
        controller.selectedLocation?.appSource, WeatherLocationSource.manual);
    expect(controller.selectedLocation?.latitude, closeTo(41.8781, 0.0001));
    expect(controller.status, LocationSelectionStatus.success);
  });

  test('clears legacy bundled San Francisco location instead of restoring it',
      () async {
    SharedPreferences.setMockInitialValues({
      storageKey: jsonEncode({
        'name': 'San Francisco',
        'state': 'CA',
        'country': 'US',
        'lat': 37.7749,
        'lon': -122.4194,
        'source': 'city',
      }),
    });

    final controller = await WeatherLocationController.create(
      repository: const FakeWeatherRepository(),
    );
    final preferences = await SharedPreferences.getInstance();

    expect(controller.selectedLocation, isNull);
    expect(preferences.getString(storageKey), isNull);
  });

  test('useCurrentLocation persists device coordinates from location service',
      () async {
    final preferences = await SharedPreferences.getInstance();
    final controller = WeatherLocationController(
      repository: const _ReverseGeocodingRepository(),
      locationService: const _StaticLocationService(),
      preferences: preferences,
    );

    await controller.useCurrentLocation();

    final selected = controller.selectedLocation;
    expect(selected, isNotNull);
    expect(selected!.displayName, 'Device Town, IL, US');
    expect(selected.appSource, WeatherLocationSource.device);
    expect(selected.latitude, closeTo(12.3456, 0.0001));
    expect(selected.longitude, closeTo(-98.7654, 0.0001));
    expect(preferences.getString(storageKey), isNotNull);
  });
}

class _StaticLocationService extends LocationService {
  const _StaticLocationService();

  @override
  Future<DeviceLocationResult> getCurrentLocation() async {
    return const DeviceLocationResult.success(
      DeviceLocation(
        latitude: 12.3456,
        longitude: -98.7654,
        accuracyMeters: 500,
      ),
    );
  }
}

class _ReverseGeocodingRepository extends FakeWeatherRepository {
  const _ReverseGeocodingRepository();

  @override
  Future<LocationCandidate?> reverseGeocode({
    required double latitude,
    required double longitude,
  }) async {
    return LocationCandidate(
      name: 'Device Town',
      state: 'IL',
      country: 'US',
      lat: latitude,
      lon: longitude,
      source: 'device',
    );
  }
}
