import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:geolocator/geolocator.dart';

import 'package:grumpy_skies/services/location_service.dart';

void main() {
  test('passive reads never request denied or undetermined permission',
      () async {
    for (final permission in [
      LocationPermission.denied,
      LocationPermission.deniedForever,
      LocationPermission.unableToDetermine
    ]) {
      final provider = _LocationPlatform()..permission = permission;
      final service = GeolocatorLocationService(platform: provider);
      expect(
          (await service.getCurrentLocationIfPermitted()).isSuccess, isFalse);
      expect(
          (await service.getLastKnownLocationIfPermitted()).isSuccess, isFalse);
      expect(provider.permissionRequests, 0);
      expect(provider.currentReads, 0);
    }
  });

  test('existing explicit current-location action requests permission once',
      () async {
    final provider = _LocationPlatform()
      ..permission = LocationPermission.denied;
    final service = GeolocatorLocationService(platform: provider);
    expect((await service.getCurrentLocation()).isSuccess, isTrue);
    await service.getCurrentLocationIfPermitted();
    expect(provider.permissionRequests, 1);
  });

  test('cached fixes preserve device timestamp and reduced precision',
      () async {
    final provider = _LocationPlatform()
      ..precision = LocationAccuracyStatus.reduced;
    final result = await GeolocatorLocationService(platform: provider)
        .getLastKnownLocationIfPermitted();
    expect(result.location!.observedAt, provider.fix.timestamp);
    expect(result.location!.accuracyMeters, 3000);
    expect(result.location!.approximate, isTrue);
    expect(provider.currentReads, 0);
  });

  test('permission revoked during acquisition rejects the returned coordinates',
      () async {
    final provider = _LocationPlatform();
    final pending = Completer<Position>();
    provider.current = () => pending.future;
    final result = GeolocatorLocationService(platform: provider)
        .getCurrentLocationIfPermitted();
    await Future<void>.delayed(Duration.zero);
    provider.permission = LocationPermission.denied;
    pending.complete(provider.fix);
    expect((await result).failure!.type,
        DeviceLocationFailureType.permissionDenied);
  });

  test('Apple acquisition explicitly disables background location', () async {
    debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
    addTearDown(() => debugDefaultTargetPlatformOverride = null);
    final provider = _LocationPlatform();
    await GeolocatorLocationService(platform: provider)
        .getCurrentLocationIfPermitted();
    final settings = provider.receivedSettings! as AppleSettings;
    expect(settings.allowBackgroundLocationUpdates, isFalse);
    expect(settings.showBackgroundLocationIndicator, isFalse);
    expect(settings.accuracy, LocationAccuracy.medium);
    expect(settings.timeLimit, const Duration(seconds: 10));
  });

  test('maps denied permission to a user-facing denied failure', () {
    final failure = GeolocatorLocationService.failureForPermission(
      LocationPermission.denied,
    );

    expect(failure, isNotNull);
    expect(failure!.type, DeviceLocationFailureType.permissionDenied);
    expect(failure.message, contains('denied'));
  });

  test('maps denied forever permission to a settings failure', () {
    final failure = GeolocatorLocationService.failureForPermission(
      LocationPermission.deniedForever,
    );

    expect(failure, isNotNull);
    expect(failure!.type, DeviceLocationFailureType.permissionDeniedForever);
    expect(failure.message, contains('settings'));
  });

  test('allows foreground location permissions', () {
    expect(
      GeolocatorLocationService.failureForPermission(
        LocationPermission.whileInUse,
      ),
      isNull,
    );
    expect(
      GeolocatorLocationService.failureForPermission(LocationPermission.always),
      isNull,
    );
  });
}

class _LocationPlatform extends GeolocatorPlatform {
  LocationPermission permission = LocationPermission.whileInUse;
  LocationAccuracyStatus precision = LocationAccuracyStatus.precise;
  int permissionRequests = 0, currentReads = 0;
  bool enabled = true;
  LocationSettings? receivedSettings;
  Future<Position> Function()? current;
  final fix = Position(
      latitude: 38.9,
      longitude: -94.7,
      timestamp: DateTime.utc(2026, 10, 16, 10),
      accuracy: 3000,
      altitude: 0,
      altitudeAccuracy: 0,
      heading: 0,
      headingAccuracy: 0,
      speed: 0,
      speedAccuracy: 0);
  @override
  Future<bool> isLocationServiceEnabled() async => enabled;
  @override
  Future<LocationPermission> checkPermission() async => permission;
  @override
  Future<LocationPermission> requestPermission() async {
    permissionRequests++;
    return permission = LocationPermission.whileInUse;
  }

  @override
  Future<LocationAccuracyStatus> getLocationAccuracy() async => precision;
  @override
  Future<Position?> getLastKnownPosition(
          {bool forceLocationManager = false}) async =>
      fix;
  @override
  Future<Position> getCurrentPosition(
      {LocationSettings? locationSettings}) async {
    currentReads++;
    receivedSettings = locationSettings;
    return current == null ? fix : await current!();
  }
}
