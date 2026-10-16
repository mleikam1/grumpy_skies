import 'dart:async';

import '../../repositories/weather_repository.dart';
import 'smart_location_models.dart';

/// Existing OpenWeather geocoding supports city/area names, not businesses or
/// street addresses: https://openweathermap.org/api/geocoding-api . Results stay
/// in bounded memory; this adapter makes no claim of perpetual provider storage.
class SmartLocationLookup {
  SmartLocationLookup(this.repository,
      {DateTime Function()? clock,
      this.successLifetime = const Duration(hours: 6),
      this.failureLifetime = const Duration(minutes: 5),
      this.maxRequestsPerHour = 12,
      this.maxEntries = 32,
      this.maxConcurrent = 2})
      : clock = clock ?? DateTime.now;
  final WeatherRepository repository;
  final DateTime Function() clock;
  final Duration successLifetime, failureLifetime;
  final int maxRequestsPerHour, maxEntries, maxConcurrent;
  int _active = 0;
  final _waiting = <Completer<void>>[];
  final _cache = <String, LocationLookupResult>{};
  final _pending = <String, Future<LocationLookupResult>>{};
  final _requests = <DateTime>[];
  int _generation = 0;
  bool get supportsVenueAddress => false;
  String get capabilityLabel =>
      'City and locality matching is available. Exact venue/address matching is not configured.';
  Map<String, LocationLookupResult> get cachedResults => Map.unmodifiable({
        for (final entry in _cache.entries)
          if (entry.value.expiresAt.isAfter(clock())) entry.key: entry.value
      });
  Future<LocationLookupResult> lookup(LocationLookupRequest request,
      {required bool enabled}) {
    final now = clock();
    LocationLookupResult unavailable(
            LocationLookupStatus status, String reason) =>
        LocationLookupResult(
            status: status,
            provider: 'OpenWeather geocoding',
            observedAt: now,
            expiresAt: now.add(failureLifetime),
            reason: reason);
    if (!enabled) {
      return Future.value(unavailable(LocationLookupStatus.unavailable,
          'Optional online location matching is off.'));
    }
    if (request.kind != LocationLookupKind.city) {
      return Future.value(
          unavailable(LocationLookupStatus.unsupported, capabilityLabel));
    }
    // Only the extractor's minimal geographic phrase can reach this service.
    final query = request.query.trim();
    if (query.length < 2 ||
        query.length > 100 ||
        !RegExp(r'^[A-Za-zÀ-ž][A-Za-zÀ-ž .,’\x27-]*$').hasMatch(query)) {
      return Future.value(unavailable(LocationLookupStatus.unsupported,
          'Use a city/locality phrase without links or private event details.'));
    }
    final cached = _cache[request.key];
    if (cached != null && cached.expiresAt.isAfter(now)) {
      return Future.value(cached);
    }
    final pending = _pending[request.key];
    if (pending != null) return pending;
    _requests.removeWhere(
        (time) => now.difference(time) >= const Duration(hours: 1));
    if (_requests.length >= maxRequestsPerHour) {
      return Future.value(unavailable(LocationLookupStatus.unavailable,
          'Location lookup deferred to limit requests.'));
    }
    _requests.add(now);
    final generation = _generation;
    final operation = _fetch(request, generation);
    _pending[request.key] = operation;
    return operation;
  }

  Future<void> _acquire() async {
    if (_active < (maxConcurrent < 1 ? 1 : maxConcurrent)) {
      _active++;
      return;
    }
    final slot = Completer<void>();
    _waiting.add(slot);
    await slot.future;
  }

  void _release() {
    if (_waiting.isNotEmpty) {
      _waiting.removeAt(0).complete();
    } else {
      _active--;
    }
  }

  Future<LocationLookupResult> _fetch(
      LocationLookupRequest request, int generation) async {
    await _acquire();
    LocationLookupResult result;
    try {
      if (generation != _generation) {
        return LocationLookupResult(
            status: LocationLookupStatus.unavailable,
            provider: 'OpenWeather geocoding',
            observedAt: clock(),
            expiresAt: clock(),
            reason: 'Location lookup was cleared.');
      }
      final found = await repository
          .searchLocations(query: request.query.trim(), limit: 5)
          .timeout(const Duration(seconds: 15));
      final expected = normalizeLocationText(request.query.split(',').first);
      final unique = {
        for (final candidate in found)
          if (candidate.hasValidCoordinates &&
              normalizeLocationText(candidate.name) == expected)
            '${candidate.lat.toStringAsFixed(5)},${candidate.lon.toStringAsFixed(5)}':
                candidate
      };
      final candidates = unique.values.toList();
      final now = clock();
      result = LocationLookupResult(
          status: candidates.length == 1
              ? LocationLookupStatus.matched
              : candidates.length > 1
                  ? LocationLookupStatus.ambiguous
                  : LocationLookupStatus.unavailable,
          provider: 'OpenWeather geocoding',
          observedAt: now,
          expiresAt: now
              .add(candidates.length == 1 ? successLifetime : failureLifetime),
          candidates: candidates,
          precision: LocationPrecision.city,
          reason: candidates.length == 1
              ? 'One exact city/locality name matched.'
              : candidates.length > 1
                  ? 'More than one geographic place has this name; user selection is needed.'
                  : 'No unambiguous city match was returned.');
    } catch (_) {
      final now = clock();
      result = LocationLookupResult(
          status: LocationLookupStatus.failed,
          provider: 'OpenWeather geocoding',
          observedAt: now,
          expiresAt: now.add(failureLifetime),
          reason: 'City matching is temporarily unavailable.');
    } finally {
      _release();
      if (generation == _generation) _pending.remove(request.key);
    }
    if (generation == _generation) {
      _cache.remove(request.key);
      _cache[request.key] = result;
      while (_cache.length > (maxEntries < 0 ? 0 : maxEntries)) {
        _cache.remove(_cache.keys.first);
      }
    }
    return result;
  }

  void clear() {
    _generation++;
    _cache.clear();
    _pending.clear();
  }
}
