import 'dart:async';

import '../../models/weather_models.dart';
import '../../repositories/weather_repository.dart';

/// An isolated consumer of the established repository. Never publishes into the
/// main selected-location controller. Cache/in-flight keys contain coordinates
/// only; calendar titles, IDs and payloads cannot reach a service request.
class VenueWeatherRepository {
  VenueWeatherRepository(WeatherRepository repository,
      {DateTime Function()? clock,
      this.maxConcurrent = 2,
      this.maximumRequestsPerHour = 12,
      this.maximumCacheEntries = 32,
      this.lifetime = cacheLifetime,
      this.failureCooldown = const Duration(minutes: 1),
      this.requestTimeout = const Duration(seconds: 30)})
      : repository = repository.privateLocationConsumer(),
        clock = clock ?? DateTime.now;
  final WeatherRepository repository;
  final DateTime Function() clock;
  final int maxConcurrent;
  final int maximumRequestsPerHour, maximumCacheEntries;
  final Duration lifetime, failureCooldown, requestTimeout;
  final Map<String, ({WeatherBundle value, DateTime fetched})> _cache = {};
  final Map<String, Future<WeatherBundle>> _pending = {};
  final Map<String, DateTime> _failures = {};
  final List<DateTime> _requestTimes = [];
  final List<Completer<void>> _waiters = [];
  int _active = 0;
  int _generation = 0;
  static const cacheLifetime = Duration(minutes: 10);
  static String keyFor(LocationCandidate venue) =>
      '${venue.lat.toStringAsFixed(5)},${venue.lon.toStringAsFixed(5)}';
  bool hasReusable(LocationCandidate venue) {
    final key = keyFor(venue);
    final cached = _cache[key];
    return _pending.containsKey(key) ||
        cached != null && _fresh(cached.fetched);
  }

  bool _fresh(DateTime fetched) {
    final age = clock().difference(fetched);
    return !age.isNegative && age < lifetime;
  }

  Future<WeatherBundle> get(LocationCandidate venue) {
    if (!venue.hasValidCoordinates) {
      return Future.error(ArgumentError('Invalid venue coordinates'));
    }
    final key = keyFor(venue);
    final cached = _cache[key];
    if (cached != null && _fresh(cached.fetched)) {
      return Future.value(cached.value);
    }
    final inFlight = _pending[key];
    if (inFlight != null) return inFlight;
    _requestTimes.removeWhere(
        (time) => clock().difference(time) >= const Duration(hours: 1));
    if (_requestTimes.length >= maximumRequestsPerHour) {
      return Future.error(const VenueWeatherDeferred());
    }
    final failure = _failures[key];
    if (failure != null && clock().difference(failure) < failureCooldown) {
      return cached == null
          ? Future.error(StateError('Venue forecast temporarily unavailable'))
          : Future.value(cached.value.asOfflineCache());
    }
    final generation = _generation;
    _requestTimes.add(clock());
    final operation = _fetch(key, venue, generation);
    _pending[key] = operation;
    return operation;
  }

  Future<WeatherBundle> _fetch(
      String key, LocationCandidate venue, int generation) async {
    if (_active >= maxConcurrent) {
      final waiter = Completer<void>();
      _waiters.add(waiter);
      await waiter.future;
    }
    _active++;
    try {
      if (generation != _generation) throw StateError('PlanCast disconnected');
      // Deliberately omit LocationCandidate: only coordinates reach the backend.
      final value = await repository
          .getWeather(latitude: venue.lat, longitude: venue.lon)
          .timeout(requestTimeout);
      if (generation == _generation) {
        _cache[key] = (value: value, fetched: clock());
        _failures.remove(key);
        if (_cache.length > maximumCacheEntries) {
          _cache.remove(_cache.keys.first);
        }
      }
      return value;
    } catch (_) {
      if (generation == _generation) _failures[key] = clock();
      rethrow;
    } finally {
      if (generation == _generation) _pending.remove(key);
      _active--;
      if (_waiters.isNotEmpty) _waiters.removeAt(0).complete();
    }
  }

  /// Geocoding is user initiated, with explicit selection even for one result.
  /// This approved search service resolves cities/ZIPs, not arbitrary addresses.
  Future<List<LocationCandidate>> search(String query) async {
    final text = query.trim();
    if (text.length < 2 || text.length > 200 || !isPhysicalLocationText(text)) {
      return const [];
    }
    return (await repository.searchLocations(query: text, limit: 5))
        .where((v) => v.hasValidCoordinates)
        .toList();
  }

  static bool isPhysicalLocationText(String text) {
    final value = text.trim().toLowerCase();
    return value.isNotEmpty &&
        !RegExp(r'https?://|www\.|zoom\.|meet\.google|teams\.microsoft|^(tbd|online|virtual|remote|room\s*\d+|conference room|to be determined)$')
            .hasMatch(value);
  }

  void clear() {
    _generation++;
    _cache.clear();
    _pending.clear();
    _failures.clear();
  }
}

/// An intentional cost bound, represented as an honest deferred UI state.
class VenueWeatherDeferred implements Exception {
  const VenueWeatherDeferred();
}
