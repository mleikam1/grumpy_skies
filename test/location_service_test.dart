import 'package:flutter_test/flutter_test.dart';
import 'package:geolocator/geolocator.dart';

import 'package:grumpy_skies/services/location_service.dart';

void main() {
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
