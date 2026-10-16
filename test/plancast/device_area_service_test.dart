import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:grumpy_skies/features/plancast/device_area_service.dart';
import 'package:grumpy_skies/models/weather_models.dart';
import 'package:grumpy_skies/services/location_service.dart';

final _now = DateTime.utc(2026, 10, 16, 12);
DeviceLocation _fix(
        {DateTime? at,
        double lat = 38.9,
        double lon = -94.7,
        double accuracy = 200,
        bool approximate = false}) =>
    DeviceLocation(
        latitude: lat,
        longitude: lon,
        accuracyMeters: accuracy,
        observedAt: at ?? _now,
        approximate: approximate);
const _denied = DeviceLocationFailure(
    type: DeviceLocationFailureType.permissionDenied, message: 'Denied');
const _timeout = DeviceLocationFailure(
    type: DeviceLocationFailureType.timeout, message: 'Timed out');

void main() {
  test('reuses a recent actual OS fix with timestamp and approximate accuracy',
      () async {
    final source = _Source()
      ..cached = _fix(
          at: _now.subtract(const Duration(minutes: 2)),
          accuracy: 5000,
          approximate: true);
    final service =
        ForegroundDeviceAreaService(locationService: source, clock: () => _now);
    addTearDown(service.dispose);
    final area = await service.refresh();
    expect(area!.candidate.lat, 38.9);
    expect(area.observedAt, source.cached!.observedAt);
    expect(area.approximate, isTrue);
    expect(area.accuracyMeters, 5000);
    expect(source.currentReads, 0);
    expect(source.permissionRequests, 0);
  });

  test('passive denied refresh never asks permission or acquires coordinates',
      () async {
    final source = _Source()..accessFailure = _denied;
    final service =
        ForegroundDeviceAreaService(locationService: source, clock: () => _now);
    addTearDown(service.dispose);
    expect(await service.refresh(), isNull);
    expect(service.failure!.type, DeviceLocationFailureType.permissionDenied);
    expect(source.currentReads + source.cachedReads, 0);
    expect(source.permissionRequests, 0);
  });

  test('only explicit permission action requests access', () async {
    final source = _Source()..accessFailure = _denied;
    final service =
        ForegroundDeviceAreaService(locationService: source, clock: () => _now);
    addTearDown(service.dispose);
    expect(await service.refresh(requestPermission: true), isNotNull);
    await service.refresh();
    expect(source.permissionRequests, 1);
  });

  test('explicit request waits for a passive denial then still asks once',
      () async {
    final source = _Source()..accessFailure = _denied;
    final blockedCheck = Completer<DeviceLocationFailure?>();
    var first = true;
    source.availability = (request) async {
      if (first) {
        first = false;
        return blockedCheck.future;
      }
      if (request) source.accessFailure = null;
      return source.accessFailure;
    };
    final service =
        ForegroundDeviceAreaService(locationService: source, clock: () => _now);
    addTearDown(service.dispose);
    final passive = service.refresh();
    final explicit = service.refresh(requestPermission: true);
    blockedCheck.complete(_denied);
    await passive;
    expect(await explicit, isNotNull);
    expect(source.permissionRequests, 1);
  });

  test('revocation during failed acquisition cannot retain an authorized area',
      () async {
    final source = _Source();
    final service =
        ForegroundDeviceAreaService(locationService: source, clock: () => _now);
    addTearDown(service.dispose);
    await service.refresh();
    source.pending = Completer<DeviceLocationResult>();
    final pending = service.refresh(force: true);
    await _flush();
    source.accessFailure = _denied;
    source.pending!.complete(const DeviceLocationResult.failure(_timeout));
    final area = await pending;
    expect(area!.permissionGranted, isFalse);
    expect(service.failure!.type, DeviceLocationFailureType.permissionDenied);
  });

  test(
      'revocation prevents fresh labeling but retains acceptable last-known fix',
      () async {
    final source = _Source();
    final service =
        ForegroundDeviceAreaService(locationService: source, clock: () => _now);
    addTearDown(service.dispose);
    final before = await service.refresh();
    source.accessFailure = _denied;
    final after = await service.refresh();
    expect(after!.permissionGranted, isFalse);
    expect(after.observedAt, before!.observedAt);
    expect(source.currentReads, 1);
    expect(source.permissionRequests, 0);
  });

  test('old OS fixes and invalid uncertainty cannot become current area',
      () async {
    for (final bad in [
      _fix(at: _now.subtract(const Duration(hours: 25))),
      _fix(at: _now.add(const Duration(minutes: 5))),
      _fix(accuracy: double.nan),
      _fix(accuracy: -1),
      _fix(accuracy: 26000),
      _fix(lat: 95),
      _fix(lon: double.infinity),
      const DeviceLocation(latitude: 38, longitude: -94, accuracyMeters: 50),
    ]) {
      final source = _Source()
        ..cached = bad
        ..current = bad;
      final service = ForegroundDeviceAreaService(
          locationService: source, clock: () => _now);
      expect(await service.refresh(), isNull);
      service.dispose();
    }
  });

  test('acceptable older fix survives timeout with its original age', () async {
    final source = _Source()
      ..cached = _fix(at: _now.subtract(const Duration(hours: 2)))
      ..currentFailure = _timeout;
    final service =
        ForegroundDeviceAreaService(locationService: source, clock: () => _now);
    addTearDown(service.dispose);
    final area = await service.refresh();
    expect(area!.observedAt, _now.subtract(const Duration(hours: 2)));
    expect(service.failure!.type, DeviceLocationFailureType.timeout);
  });

  test(
      'concurrent refreshes share acquisition; deliberate force bypasses reuse',
      () async {
    final source = _Source();
    final pending = Completer<DeviceLocationResult>();
    source.pending = pending;
    final service =
        ForegroundDeviceAreaService(locationService: source, clock: () => _now);
    addTearDown(service.dispose);
    final a = service.refresh();
    final b = service.refresh();
    await _flush();
    expect(source.currentReads, 1);
    pending.complete(DeviceLocationResult.success(_fix()));
    await Future.wait([a, b]);
    source.pending = null;
    await service.refresh();
    expect(source.currentReads, 1);
    await service.refresh(force: true);
    expect(source.currentReads, 2);
  });

  test('reverse result labels area without replacing actual coordinates',
      () async {
    final service = ForegroundDeviceAreaService(
        locationService: _Source(),
        clock: () => _now,
        reverseGeocode: ({required latitude, required longitude}) async =>
            const LocationCandidate(
                name: 'Overland Park',
                country: 'US',
                lat: 0,
                lon: 0,
                source: 'geocoder'));
    addTearDown(service.dispose);
    final area = await service.refresh();
    expect(area!.locality, 'Overland Park');
    expect(area.candidate.lat, 38.9);
    expect(area.candidate.lon, -94.7);
    expect(area.candidate.source, 'device');
  });

  test('disconnect rejects late reverse lookup and pending fix', () async {
    final label = Completer<LocationCandidate?>();
    final service = ForegroundDeviceAreaService(
        locationService: _Source(),
        clock: () => _now,
        reverseGeocode: ({required latitude, required longitude}) =>
            label.future);
    addTearDown(service.dispose);
    final pending = service.refresh();
    await _flush();
    expect(service.sample, isNotNull);
    await service.clear();
    label.complete(const LocationCandidate(
        name: 'Old city', country: '', lat: 1, lon: 2, source: 'geocoder'));
    await pending;
    expect(service.sample, isNull);
    final source = _Source()..pending = Completer<DeviceLocationResult>();
    final another =
        ForegroundDeviceAreaService(locationService: source, clock: () => _now);
    addTearDown(another.dispose);
    final acquisition = another.refresh();
    await _flush();
    await another.clear();
    source.pending!.complete(DeviceLocationResult.success(_fix()));
    await acquisition;
    expect(another.sample, isNull);
  });

  test(
      'foreground watcher ignores uncertainty-sized jitter and accepts meaningful move',
      () async {
    final source = _Source();
    var clock = _now;
    final service = ForegroundDeviceAreaService(
        locationService: source, clock: () => clock);
    addTearDown(service.dispose);
    await service.refresh();
    await service.setActive(true);
    expect(source.watches, 1);
    clock = clock.add(const Duration(minutes: 1));
    source.positions
        .add(DeviceLocationResult.success(_fix(at: clock, lat: 38.9001)));
    await _flush();
    expect(service.sample!.candidate.lat, 38.9);
    source.positions
        .add(DeviceLocationResult.success(_fix(at: clock, lat: 39.1)));
    await _flush();
    expect(service.sample!.candidate.lat, 39.1);
    await service.setActive(false);
    expect(source.positions.hasListener, isFalse);
    source.positions
        .add(DeviceLocationResult.success(_fix(at: clock, lat: 40)));
    await _flush();
    expect(service.sample!.candidate.lat, 39.1);
  });

  test('pause rejects a late acquisition and clear empties the sample',
      () async {
    final source = _Source()..pending = Completer<DeviceLocationResult>();
    final service =
        ForegroundDeviceAreaService(locationService: source, clock: () => _now);
    addTearDown(service.dispose);
    await service.setActive(true);
    final pending = service.refresh();
    await _flush();
    await service.setActive(false);
    source.pending!.complete(DeviceLocationResult.success(_fix()));
    await pending;
    expect(service.sample, isNull);
    await service.clear();
    expect(service.sample, isNull);
  });

  test(
      'permission loss during reverse lookup never republishes authorized sample',
      () async {
    final source = _Source();
    final label = Completer<LocationCandidate?>();
    final service = ForegroundDeviceAreaService(
        locationService: source,
        clock: () => _now,
        reverseGeocode: ({required latitude, required longitude}) =>
            label.future);
    addTearDown(service.dispose);
    final pending = service.refresh();
    await _flush();
    source.accessFailure = _denied;
    label.complete(const LocationCandidate(
        name: 'Area', country: '', lat: 0, lon: 0, source: 'geo'));
    final area = await pending;
    expect(area!.permissionGranted, isFalse);
  });

  test('pause before watcher starts blocks acquisition until foreground resume',
      () async {
    final source = _Source();
    final service =
        ForegroundDeviceAreaService(locationService: source, clock: () => _now);
    addTearDown(service.dispose);
    await service.setActive(false);
    expect(await service.refresh(force: true), isNull);
    expect(source.currentReads + source.cachedReads, 0);
    await service.setActive(true);
    expect(await service.refresh(), isNotNull);
    await service.clear();
    await service.refresh(force: true);
    expect(source.currentReads, 1);
  });

  test('last-known sample expires without another location request', () async {
    var clock = _now;
    final service = ForegroundDeviceAreaService(
        locationService: _Source(), clock: () => clock);
    addTearDown(service.dispose);
    await service.refresh();
    clock = clock.add(const Duration(hours: 25));
    expect(service.sample, isNull);
  });
}

Future<void> _flush() async {
  for (var i = 0; i < 8; i++) {
    await Future<void>.delayed(Duration.zero);
  }
}

class _Source extends LocationService {
  DeviceLocation? cached;
  DeviceLocation current = _fix();
  DeviceLocationFailure? accessFailure, currentFailure;
  Completer<DeviceLocationResult>? pending;
  Future<DeviceLocationFailure?> Function(bool)? availability;
  int currentReads = 0, cachedReads = 0, permissionRequests = 0, watches = 0;
  final positions = StreamController<DeviceLocationResult>.broadcast();
  @override
  Future<DeviceLocationFailure?> checkAvailability(
      {bool requestPermission = false}) async {
    if (requestPermission) permissionRequests++;
    final check = availability;
    if (check != null) return check(requestPermission);
    if (requestPermission) accessFailure = null;
    return accessFailure;
  }

  @override
  Future<DeviceLocationResult> getCurrentLocation() => throw StateError(
      'Passive PlanCast must never call this permission-requesting API.');
  @override
  Future<DeviceLocationResult> getCurrentLocationIfPermitted() async {
    currentReads++;
    if (pending != null) return pending!.future;
    return currentFailure != null
        ? DeviceLocationResult.failure(currentFailure!)
        : DeviceLocationResult.success(current);
  }

  @override
  Future<DeviceLocationResult> getLastKnownLocationIfPermitted() async {
    cachedReads++;
    return cached == null
        ? const DeviceLocationResult.failure(
            GeolocatorLocationService.unavailable)
        : DeviceLocationResult.success(cached!);
  }

  @override
  Stream<DeviceLocationResult> watchForegroundLocation() {
    watches++;
    return positions.stream;
  }
}
