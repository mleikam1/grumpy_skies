import 'dart:async';
import 'dart:math' as math;

import '../../models/weather_models.dart';
import '../../services/location_service.dart';
import 'smart_location_models.dart';

typedef DeviceAreaLookup = Future<LocationCandidate?> Function(
    {required double latitude, required double longitude});

/// Only actual device observations enter this boundary. Browsing Today, saved
/// cities and event venues cannot write a device sample.
abstract class DeviceAreaService {
  DeviceAreaSample? get sample;
  DeviceLocationFailure? get failure;
  Stream<DeviceAreaSample?> get changes;
  Future<DeviceAreaSample?> refresh(
      {bool requestPermission = false, bool force = false});
  Future<void> setActive(bool active);
  Future<void> clear();
  void dispose();
}

class DeviceAreaPolicy {
  const DeviceAreaPolicy({
    this.reuseFor = const Duration(minutes: 5),
    this.maximumAge = const Duration(hours: 24),
    this.futureTolerance = const Duration(minutes: 2),
    this.maximumAccuracyMeters = 25000,
    this.movementMeters = 2000,
    this.labelTimeout = const Duration(seconds: 3),
  });
  final Duration reuseFor, maximumAge, futureTolerance, labelTimeout;
  final double maximumAccuracyMeters, movementMeters;
}

/// In-memory, foreground-only observations. Last-known OS fixes retain their
/// original timestamp; the resolver decides whether to label one as current or
/// last-known. Labels are optional and never replace measured coordinates.
class ForegroundDeviceAreaService implements DeviceAreaService {
  ForegroundDeviceAreaService({
    LocationService locationService = const GeolocatorLocationService(),
    DeviceAreaLookup? reverseGeocode,
    DateTime Function()? clock,
    this.policy = const DeviceAreaPolicy(),
  })  : _location = locationService,
        _lookup = reverseGeocode,
        _clock = clock ?? DateTime.now;

  final LocationService _location;
  final DeviceAreaLookup? _lookup;
  final DateTime Function() _clock;
  final DeviceAreaPolicy policy;
  final _changes = StreamController<DeviceAreaSample?>.broadcast();
  StreamSubscription<DeviceLocationResult>? _watch;
  Future<DeviceAreaSample?>? _refreshing;
  DeviceAreaSample? _sample;
  DeviceLocationFailure? _failure;
  bool _active = false, _disposed = false, _startingWatch = false;
  bool _suspended = false;
  int _generation = 0, _observation = 0;

  @override
  DeviceAreaSample? get sample => _validSample(_sample) ? _sample : null;
  @override
  DeviceLocationFailure? get failure => _failure;
  @override
  Stream<DeviceAreaSample?> get changes => _changes.stream;

  bool _current(int generation) => !_disposed && generation == _generation;
  bool _validSample(DeviceAreaSample? value) =>
      value != null &&
      value.candidate.hasValidCoordinates &&
      value.accuracyMeters.isFinite &&
      value.accuracyMeters >= 0 &&
      value.accuracyMeters <= policy.maximumAccuracyMeters &&
      !value.observedAt.isAfter(_clock().add(policy.futureTolerance)) &&
      _clock().difference(value.observedAt) <= policy.maximumAge;

  @override
  Future<DeviceAreaSample?> refresh(
      {bool requestPermission = false, bool force = false}) {
    if (_disposed || _suspended) return Future.value(sample);
    final generation = _generation;
    final existing = _refreshing;
    if (existing != null) {
      if (!requestPermission) return existing;
      // A deliberate action must not disappear behind a passive denied check.
      return existing.then((_) {
        if (!_current(generation) || _suspended) return sample;
        if (identical(_refreshing, existing)) _refreshing = null;
        return refresh(requestPermission: true, force: force);
      });
    }
    final pending =
        _refresh(generation, requestPermission, force).catchError((Object _) {
      if (_current(generation)) _fail(GeolocatorLocationService.unavailable);
      return sample;
    });
    _refreshing = pending;
    return pending.whenComplete(() {
      if (identical(_refreshing, pending)) _refreshing = null;
    });
  }

  Future<DeviceAreaSample?> _refresh(
      int generation, bool requestPermission, bool force) async {
    final access =
        await _location.checkAvailability(requestPermission: requestPermission);
    if (!_current(generation)) return sample;
    if (access != null) {
      _fail(access);
      return sample;
    }
    _failure = null;
    // Permission is always checked before reusing a previously accepted fix.
    final prior = sample;
    if (!force &&
        prior != null &&
        _clock().difference(prior.observedAt) <= policy.reuseFor) {
      if (!prior.permissionGranted) _publish(_withPermission(prior, true));
      unawaited(_startWatch());
      return sample;
    }
    if (prior == null) {
      final cached = await _location.getLastKnownLocationIfPermitted();
      if (!_current(generation)) return sample;
      await _accept(cached.location, generation);
      if (!_current(generation)) return sample;
      if (!force &&
          sample != null &&
          _clock().difference(sample!.observedAt) <= policy.reuseFor) {
        unawaited(_startWatch());
        return sample;
      }
    }
    final result = await _location.getCurrentLocationIfPermitted();
    if (!_current(generation)) return sample;
    if (result.location != null) {
      await _accept(result.location, generation);
    } else {
      final accessAfter = await _location.checkAvailability();
      if (!_current(generation)) return sample;
      _fail(accessAfter ??
          result.failure ??
          GeolocatorLocationService.unavailable);
    }
    if (_current(generation)) unawaited(_startWatch());
    return sample;
  }

  void _fail(DeviceLocationFailure failure) {
    _failure = failure;
    final denied = failure.type == DeviceLocationFailureType.permissionDenied ||
        failure.type == DeviceLocationFailureType.permissionDeniedForever;
    if (denied || failure.type == DeviceLocationFailureType.servicesDisabled) {
      unawaited(_watch?.cancel());
      _watch = null;
    }
    final retained = sample;
    _publish(retained == null
        ? null
        : _withPermission(
            retained, denied ? false : retained.permissionGranted));
  }

  DeviceAreaSample _withPermission(DeviceAreaSample value, bool permitted) =>
      DeviceAreaSample(
          candidate: value.candidate,
          observedAt: value.observedAt,
          accuracyMeters: value.accuracyMeters,
          locality: value.locality,
          permissionGranted: permitted,
          approximate: value.approximate,
          provenance: value.provenance);

  Future<void> _accept(DeviceLocation? location, int generation,
      {bool movementOnly = false}) async {
    if (!_current(generation) || location == null) return;
    final measuredAt = location.observedAt?.toUtc();
    final accuracy = location.accuracyMeters;
    final now = _clock().toUtc();
    if (measuredAt == null ||
        accuracy == null ||
        !accuracy.isFinite ||
        accuracy < 0 ||
        accuracy > policy.maximumAccuracyMeters ||
        !LocationCandidate.hasValidCoordinatePair(
            location.latitude, location.longitude) ||
        measuredAt.isAfter(now.add(policy.futureTolerance)) ||
        now.difference(measuredAt) > policy.maximumAge) {
      _failure = GeolocatorLocationService.unavailable;
      return;
    }
    // Preserve the provider timestamp, including tolerated clock skew.
    final observedAt = measuredAt;
    final previous = sample;
    if (previous != null && observedAt.isBefore(previous.observedAt)) return;
    final distance = previous == null
        ? double.infinity
        : distanceMeters(previous.candidate.lat, previous.candidate.lon,
            location.latitude, location.longitude);
    final meaningful = previous == null ||
        distance >
            math.max(policy.movementMeters, previous.accuracyMeters + accuracy);
    if (movementOnly &&
        !meaningful &&
        now.difference(previous.observedAt) < policy.reuseFor) {
      return;
    }
    final ticket = ++_observation;
    final reuseLabel = !meaningful && previous.locality != null;
    DeviceAreaSample makeSample(LocationCandidate? label) => DeviceAreaSample(
        candidate: LocationCandidate(
            name: label?.name ?? 'Your area',
            state: label?.state,
            country: label?.country ?? '',
            lat: location.latitude,
            lon: location.longitude,
            source: 'device'),
        observedAt: observedAt,
        accuracyMeters: accuracy,
        approximate: location.approximate,
        permissionGranted: true,
        locality: label?.name,
        provenance: 'device');
    final access = await _location.checkAvailability();
    if (!_current(generation) || ticket != _observation) return;
    if (access != null) {
      _fail(access);
      return;
    }
    _failure = null;
    _publish(makeSample(reuseLabel ? previous.candidate : null));
    final lookup = _lookup;
    if (lookup == null || reuseLabel) return;
    try {
      final label = await lookup(
              latitude: location.latitude, longitude: location.longitude)
          .timeout(policy.labelTimeout);
      if (!_current(generation) || ticket != _observation || label == null) {
        return;
      }
      final stillAllowed = await _location.checkAvailability();
      if (!_current(generation) || ticket != _observation) return;
      if (stillAllowed != null) {
        _fail(stillAllowed);
        return;
      }
      // Reverse results are labels only, never a replacement location fix.
      _publish(makeSample(label));
    } catch (_) {/* Area forecasts work without a reverse lookup. */}
  }

  void _publish(DeviceAreaSample? value) {
    if (_disposed) return;
    _sample = value;
    _changes.add(value);
  }

  @override
  Future<void> setActive(bool active) async {
    if (_disposed || (active == _active && _suspended == !active)) return;
    _active = active;
    _suspended = !active;
    if (active) {
      await _startWatch();
    } else {
      _generation++;
      _refreshing = null;
      _startingWatch = false;
      final watch = _watch;
      _watch = null;
      await watch?.cancel();
    }
  }

  Future<void> _startWatch() async {
    if (_disposed || !_active || _watch != null || _startingWatch) return;
    _startingWatch = true;
    final generation = _generation;
    final access = await _location.checkAvailability();
    if (!_current(generation) || !_active) return;
    _startingWatch = false;
    if (access != null) {
      _fail(access);
      return;
    }
    _watch = _location.watchForegroundLocation().listen((result) {
      if (!_current(generation) || !_active) return;
      if (result.location != null) {
        unawaited(_accept(result.location, generation, movementOnly: true));
      } else {
        _fail(result.failure ?? GeolocatorLocationService.unavailable);
      }
    }, onError: (Object _) {
      if (_current(generation)) _fail(GeolocatorLocationService.unavailable);
    }, onDone: () {
      if (_current(generation)) _watch = null;
    });
  }

  @override
  Future<void> clear() async {
    _generation++;
    _observation++;
    _active = false;
    _suspended = true;
    _startingWatch = false;
    _refreshing = null;
    final watch = _watch;
    _watch = null;
    _failure = null;
    _publish(null);
    await watch?.cancel();
  }

  @override
  void dispose() {
    if (_disposed) return;
    _disposed = true;
    _generation++;
    _sample = null;
    unawaited(_watch?.cancel());
    unawaited(_changes.close());
  }

  static double distanceMeters(
      double lat1, double lon1, double lat2, double lon2) {
    const rad = math.pi / 180;
    final a = math.pow(math.sin((lat2 - lat1) * rad / 2), 2) +
        math.cos(lat1 * rad) *
            math.cos(lat2 * rad) *
            math.pow(math.sin((lon2 - lon1) * rad / 2), 2);
    return 6371000 *
        2 *
        math.atan2(math.sqrt(a.clamp(0, 1)), math.sqrt((1 - a).clamp(0, 1)));
  }
}
