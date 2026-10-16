import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';

enum DeviceLocationFailureType {
  servicesDisabled,
  permissionDenied,
  permissionDeniedForever,
  timeout,
  unknown,
}

class DeviceLocation {
  const DeviceLocation({
    required this.latitude,
    required this.longitude,
    this.accuracyMeters,
    this.observedAt,
    this.approximate = false,
  });

  final double latitude;
  final double longitude;
  final double? accuracyMeters;

  /// Time measured by the device provider, never the time a cached fix is read.
  final DateTime? observedAt;
  final bool approximate;
}

class DeviceLocationFailure {
  const DeviceLocationFailure({
    required this.type,
    required this.message,
  });

  final DeviceLocationFailureType type;
  final String message;
}

class DeviceLocationResult {
  const DeviceLocationResult._({
    this.location,
    this.failure,
  });

  const DeviceLocationResult.success(DeviceLocation location)
      : this._(location: location);

  const DeviceLocationResult.failure(DeviceLocationFailure failure)
      : this._(failure: failure);

  final DeviceLocation? location;
  final DeviceLocationFailure? failure;

  bool get isSuccess => location != null;
}

abstract class LocationService {
  const LocationService();

  Future<DeviceLocationResult> getCurrentLocation();

  /// Passive capabilities default to unavailable for legacy/custom adapters.
  /// They must never fall through to the permission-requesting legacy method.
  Future<DeviceLocationFailure?> checkAvailability(
          {bool requestPermission = false}) async =>
      GeolocatorLocationService.unavailable;
  Future<DeviceLocationResult> getCurrentLocationIfPermitted() async =>
      const DeviceLocationResult.failure(GeolocatorLocationService.unavailable);
  Future<DeviceLocationResult> getLastKnownLocationIfPermitted() async =>
      const DeviceLocationResult.failure(GeolocatorLocationService.unavailable);
  Stream<DeviceLocationResult> watchForegroundLocation() =>
      const Stream.empty();
}

class GeolocatorLocationService extends LocationService {
  const GeolocatorLocationService({GeolocatorPlatform? platform})
      : _platform = platform;
  final GeolocatorPlatform? _platform;
  GeolocatorPlatform get _provider => _platform ?? GeolocatorPlatform.instance;

  static const unavailable = DeviceLocationFailure(
    type: DeviceLocationFailureType.unknown,
    message:
        'Location is unavailable right now. Choose a default area instead.',
  );

  @override
  Future<DeviceLocationFailure?> checkAvailability(
      {bool requestPermission = false}) async {
    try {
      if (!await _provider.isLocationServiceEnabled()) {
        return const DeviceLocationFailure(
          type: DeviceLocationFailureType.servicesDisabled,
          message:
              'Location services are off. Turn them on or search manually.',
        );
      }
      var permission = await _provider.checkPermission();
      if (requestPermission &&
          (permission == LocationPermission.denied ||
              permission == LocationPermission.unableToDetermine)) {
        permission = await _provider.requestPermission();
      }
      return failureForPermission(permission);
    } catch (_) {
      return unavailable;
    }
  }

  /// Existing Today action remains explicit and permission requesting.
  @override
  Future<DeviceLocationResult> getCurrentLocation() =>
      _locate(requestPermission: true);

  @override
  Future<DeviceLocationResult> getCurrentLocationIfPermitted() => _locate();

  @override
  Future<DeviceLocationResult> getLastKnownLocationIfPermitted() =>
      _locate(lastKnown: true);

  Future<DeviceLocationResult> _locate(
      {bool requestPermission = false, bool lastKnown = false}) async {
    try {
      final failure =
          await checkAvailability(requestPermission: requestPermission);
      if (failure != null) return DeviceLocationResult.failure(failure);
      final position = lastKnown
          ? await _provider.getLastKnownPosition()
          : await _provider.getCurrentPosition(
              locationSettings: _locationSettings());
      if (position == null) {
        return const DeviceLocationResult.failure(unavailable);
      }
      final location = await _convert(position);
      // One-time grants and Settings revocations may change during a lookup.
      final after = await checkAvailability();
      return after == null
          ? DeviceLocationResult.success(location)
          : DeviceLocationResult.failure(after);
    } on TimeoutException {
      return const DeviceLocationResult.failure(DeviceLocationFailure(
        type: DeviceLocationFailureType.timeout,
        message: 'Location lookup timed out. Choose a default area instead.',
      ));
    } catch (_) {
      return const DeviceLocationResult.failure(unavailable);
    }
  }

  Future<DeviceLocation> _convert(Position position) async {
    LocationAccuracyStatus accuracy;
    try {
      accuracy = await _provider.getLocationAccuracy();
    } catch (_) {
      accuracy = LocationAccuracyStatus.unknown;
    }
    return DeviceLocation(
      latitude: position.latitude,
      longitude: position.longitude,
      accuracyMeters: position.accuracy,
      observedAt: position.timestamp.toUtc(),
      approximate: accuracy == LocationAccuracyStatus.reduced ||
          (accuracy == LocationAccuracyStatus.unknown &&
              position.accuracy >= 1000),
    );
  }

  /// The owner cancels this stream whenever the app leaves the foreground.
  /// No foreground service or background location permission is configured.
  @override
  Stream<DeviceLocationResult> watchForegroundLocation() async* {
    final failure = await checkAvailability();
    if (failure != null) {
      yield DeviceLocationResult.failure(failure);
      return;
    }
    try {
      await for (final position in _provider.getPositionStream(
          locationSettings: _locationSettings(watch: true))) {
        final location = await _convert(position);
        final after = await checkAvailability();
        if (after != null) {
          yield DeviceLocationResult.failure(after);
          return;
        }
        yield DeviceLocationResult.success(location);
      }
    } catch (_) {
      yield DeviceLocationResult.failure(
          await checkAvailability() ?? unavailable);
    }
  }

  @visibleForTesting
  static DeviceLocationFailure? failureForPermission(
    LocationPermission permission,
  ) {
    return switch (permission) {
      LocationPermission.denied => const DeviceLocationFailure(
          type: DeviceLocationFailureType.permissionDenied,
          message:
              'Location permission was denied. City or ZIP search still works.',
        ),
      LocationPermission.deniedForever => const DeviceLocationFailure(
          type: DeviceLocationFailureType.permissionDeniedForever,
          message:
              'Location permission is blocked. Enable it in settings or search manually.',
        ),
      LocationPermission.unableToDetermine => const DeviceLocationFailure(
          type: DeviceLocationFailureType.permissionDenied,
          message:
              'Location permission could not be determined. Search manually instead.',
        ),
      LocationPermission.whileInUse || LocationPermission.always => null,
    };
  }

  LocationSettings _locationSettings({bool watch = false}) {
    const timeout = Duration(seconds: 10);
    if (kIsWeb) {
      return WebSettings(
        accuracy: LocationAccuracy.medium,
        timeLimit: timeout,
        maximumAge: const Duration(minutes: 10),
      );
    }

    if (defaultTargetPlatform == TargetPlatform.iOS ||
        defaultTargetPlatform == TargetPlatform.macOS) {
      return AppleSettings(
        accuracy: LocationAccuracy.medium,
        distanceFilter: watch ? 500 : 0,
        timeLimit: watch ? null : timeout,
        pauseLocationUpdatesAutomatically: true,
        allowBackgroundLocationUpdates: false,
        showBackgroundLocationIndicator: false,
      );
    }
    return LocationSettings(
      accuracy: LocationAccuracy.medium,
      distanceFilter: watch ? 500 : 0,
      timeLimit: watch ? null : timeout,
    );
  }
}
