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
  });

  final double latitude;
  final double longitude;
  final double? accuracyMeters;
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
}

class GeolocatorLocationService extends LocationService {
  const GeolocatorLocationService();

  @override
  Future<DeviceLocationResult> getCurrentLocation() async {
    try {
      final serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        return const DeviceLocationResult.failure(
          DeviceLocationFailure(
            type: DeviceLocationFailureType.servicesDisabled,
            message:
                'Location services are off. Turn them on or search manually.',
          ),
        );
      }

      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.unableToDetermine) {
        permission = await Geolocator.requestPermission();
      }

      final permissionFailure = failureForPermission(permission);
      if (permissionFailure != null) {
        return DeviceLocationResult.failure(permissionFailure);
      }

      final position = await Geolocator.getCurrentPosition(
        locationSettings: _locationSettings(),
      );
      return DeviceLocationResult.success(
        DeviceLocation(
          latitude: position.latitude,
          longitude: position.longitude,
          accuracyMeters: position.accuracy,
        ),
      );
    } on TimeoutException {
      return const DeviceLocationResult.failure(
        DeviceLocationFailure(
          type: DeviceLocationFailureType.timeout,
          message: 'Location lookup timed out. Search manually instead.',
        ),
      );
    } catch (_) {
      return const DeviceLocationResult.failure(
        DeviceLocationFailure(
          type: DeviceLocationFailureType.unknown,
          message:
              'Location is unavailable right now. Search manually instead.',
        ),
      );
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

  LocationSettings _locationSettings() {
    const timeout = Duration(seconds: 10);
    if (kIsWeb) {
      return WebSettings(
        accuracy: LocationAccuracy.medium,
        timeLimit: timeout,
        maximumAge: const Duration(minutes: 10),
      );
    }

    return const LocationSettings(
      accuracy: LocationAccuracy.medium,
      timeLimit: timeout,
    );
  }
}
