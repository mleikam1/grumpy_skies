import 'package:flutter/foundation.dart';

import '../models/weather_models.dart';
import '../services/cache_service.dart';
import '../services/open_weather_backend_client.dart';
import 'weather_repository.dart';

class OpenWeatherRepository extends WeatherRepository {
  OpenWeatherRepository({
    required OpenWeatherBackendClient client,
    CacheService? cacheService,
    Duration cacheDuration = const Duration(minutes: 10),
  })  : _client = client,
        _cacheService = cacheService,
        _cacheDuration = cacheDuration;

  final OpenWeatherBackendClient _client;
  final CacheService? _cacheService;
  final Duration _cacheDuration;
  final _inFlightBundles = <String, Future<WeatherBundle>>{};
  final _recentFailures = <String, _WeatherRequestFailure>{};
  static const _failureCooldown = Duration(minutes: 1);

  @override
  Future<List<LocationCandidate>> searchLocations({
    required String query,
    int limit = 5,
  }) {
    return _client.geocode(query: query, limit: limit);
  }

  @override
  Future<LocationCandidate?> lookupZip({
    required String zip,
    String country = 'US',
  }) {
    return _client.zip(zip: zip, country: country);
  }

  @override
  Future<LocationCandidate?> reverseGeocode({
    required double latitude,
    required double longitude,
  }) {
    _validateCoordinates(latitude, longitude);
    return _client.reverse(latitude: latitude, longitude: longitude);
  }

  @override
  Future<WeatherSnapshot> getSnapshot({
    required double latitude,
    required double longitude,
    bool forceRefresh = false,
  }) async {
    _validateCoordinates(latitude, longitude);
    final bundle = await getWeather(
      latitude: latitude,
      longitude: longitude,
      forceRefresh: forceRefresh,
    );
    return bundle.snapshot ?? _snapshotFromBundle(bundle);
  }

  @override
  Future<WeatherBundle> getWeather({
    required double latitude,
    required double longitude,
    bool forceRefresh = false,
    LocationCandidate? location,
  }) async {
    _validateCoordinates(latitude, longitude);
    final recentFailure = _recentFailure(latitude, longitude);
    if (recentFailure != null &&
        (!forceRefresh || _throttleForcedRefresh(recentFailure.error))) {
      throw recentFailure.error;
    }

    if (!forceRefresh) {
      final cached = _validCachedBundle(latitude, longitude);
      if (cached != null) return cached;
    }

    final cacheKey = _requestKey(latitude, longitude);
    final inFlight = _inFlightBundles[cacheKey];
    if (inFlight != null) return inFlight;

    final request = _fetchAndCacheWeatherBundle(
      latitude: latitude,
      longitude: longitude,
      location: location,
    );
    _inFlightBundles[cacheKey] = request;
    try {
      final bundle = await request;
      _recentFailures.remove(cacheKey);
      return bundle;
    } catch (error) {
      _recentFailures[cacheKey] = _WeatherRequestFailure(
        error: error,
        failedAt: DateTime.now(),
      );
      final cached = _cacheService?.getWeatherBundle(latitude, longitude);
      if (cached != null) return cached;
      rethrow;
    } finally {
      if (identical(_inFlightBundles[cacheKey], request)) {
        _inFlightBundles.remove(cacheKey);
      }
    }
  }

  @override
  Future<List<RadarAlert>> getRadarAlerts({
    required double latitude,
    required double longitude,
  }) async {
    return const [];
  }

  @override
  Future<List<WeatherAlert>> getWeatherAlerts({
    required List<String> alertIds,
  }) async {
    final safeIds = alertIds
        .where((id) => RegExp(r'^[A-Za-z0-9_-]{1,120}$').hasMatch(id))
        .take(5)
        .toList();
    final alerts = <WeatherAlert>[];
    for (final id in safeIds) {
      try {
        alerts.add(await _client.alert(id));
      } catch (_) {
        // Individual alert detail failures should not hide current weather.
      }
    }
    return alerts;
  }

  WeatherBundle? _validCachedBundle(double latitude, double longitude) {
    final lastFetch = _cacheService?.getLastFetchTime(latitude, longitude);
    if (lastFetch == null) return null;
    if (DateTime.now().difference(lastFetch) > _cacheDuration) return null;
    return _cacheService?.getWeatherBundle(latitude, longitude);
  }

  _WeatherRequestFailure? _recentFailure(double latitude, double longitude) {
    final failure = _recentFailures[_requestKey(latitude, longitude)];
    if (failure == null) return null;
    if (DateTime.now().difference(failure.failedAt) <= _failureCooldown) {
      return failure;
    }
    _recentFailures.remove(_requestKey(latitude, longitude));
    return null;
  }

  Future<WeatherBundle> _fetchAndCacheWeatherBundle({
    required double latitude,
    required double longitude,
    LocationCandidate? location,
  }) async {
    final bundle = await _fetchWeatherBundle(
      latitude: latitude,
      longitude: longitude,
      location: location,
    );
    await _cacheService?.saveWeatherBundle(
      lat: latitude,
      lon: longitude,
      bundle: bundle,
    );
    return bundle;
  }

  Future<WeatherBundle> _fetchWeatherBundle({
    required double latitude,
    required double longitude,
    LocationCandidate? location,
  }) async {
    final displayLocation = location ??
        await _client.reverse(latitude: latitude, longitude: longitude);
    final locationName = displayLocation.displayName;
    _debugWeatherLocation(
      latitude: latitude,
      longitude: longitude,
      locationName: locationName,
    );

    final liveWeather = await _client.forecast(
      latitude: latitude,
      longitude: longitude,
      locationName: locationName,
    );
    final current = liveWeather.current;
    final hourly = liveWeather.hourly.isEmpty
        ? _hourlyFromTimeline(liveWeather.timeline, current)
        : liveWeather.hourly;
    final daily = liveWeather.daily.isEmpty
        ? _dailyFromHourly(hourly, current)
        : liveWeather.daily;
    final bundle = WeatherBundle(
      current: current,
      hourly: hourly,
      daily: daily,
      snapshot: _snapshotFromWeather(
        current: current,
        hourly: hourly,
        daily: daily,
      ),
      location: displayLocation,
      minutePrecipitation: liveWeather.minutePrecipitation,
      timeline: liveWeather.timeline,
      alerts: liveWeather.alerts,
    );
    return bundle;
  }

  static List<HourlyForecast> _hourlyFromTimeline(
    List<TimelineWeatherPoint> timeline,
    CurrentWeather current,
  ) {
    if (timeline.isEmpty) {
      return [
        HourlyForecast(
          time: current.lastUpdated,
          temperatureC: current.temperatureC,
          condition: current.condition,
          precipitationChance: current.precipitationChance,
          weatherIcon: current.weatherIcon,
          weatherMain: current.weatherMain,
          weatherId: current.weatherId,
        ),
      ];
    }

    return timeline.take(24).map((point) {
      return HourlyForecast(
        time: point.time,
        temperatureC: point.temperatureF == null
            ? current.temperatureC
            : _fToC(point.temperatureF!),
        condition: point.condition,
        precipitationChance: point.precipitationChance,
        weatherIcon: point.icon,
        weatherMain: point.weatherMain,
        weatherId: point.weatherId,
      );
    }).toList();
  }

  static List<DailyForecast> _dailyFromHourly(
    List<HourlyForecast> hourly,
    CurrentWeather current,
  ) {
    final byDate = <DateTime, List<HourlyForecast>>{};
    for (final hour in hourly) {
      final day = DateTime(hour.time.year, hour.time.month, hour.time.day);
      byDate.putIfAbsent(day, () => []).add(hour);
    }

    if (byDate.isEmpty) {
      return [
        DailyForecast(
          date: current.lastUpdated,
          minTempC: current.temperatureC,
          maxTempC: current.temperatureC,
          condition: current.condition,
          precipitationChance: current.precipitationChance,
          weatherIcon: current.weatherIcon,
          weatherMain: current.weatherMain,
          weatherId: current.weatherId,
        ),
      ];
    }

    return byDate.entries.take(7).map((entry) {
      final representative = _representativeDailyHour(entry.value);
      final temps = entry.value.map((hour) => hour.temperatureC).toList();
      final rainChance = entry.value
          .map((hour) => hour.precipitationChance)
          .fold<int>(0, (max, value) => value > max ? value : max);
      return DailyForecast(
        date: entry.key,
        minTempC: temps.reduce((a, b) => a < b ? a : b),
        maxTempC: temps.reduce((a, b) => a > b ? a : b),
        condition: representative.condition,
        precipitationChance: rainChance,
        weatherIcon: representative.weatherIcon,
        weatherMain: representative.weatherMain,
        weatherId: representative.weatherId,
      );
    }).toList();
  }

  static HourlyForecast _representativeDailyHour(List<HourlyForecast> hours) {
    return hours.reduce((best, next) {
      final bestScore = _daytimeScore(best.time);
      final nextScore = _daytimeScore(next.time);
      return nextScore < bestScore ? next : best;
    });
  }

  static int _daytimeScore(DateTime time) {
    final middayDistance = (time.hour - 12).abs() * 60 + time.minute.abs();
    final daylightPenalty = time.hour >= 6 && time.hour < 20 ? 0 : 10000;
    return daylightPenalty + middayDistance;
  }

  static WeatherSnapshot _snapshotFromBundle(WeatherBundle bundle) {
    return bundle.snapshot ??
        _snapshotFromWeather(
          current: bundle.current,
          hourly: bundle.hourly,
          daily: bundle.daily,
        );
  }

  static WeatherSnapshot _snapshotFromWeather({
    required CurrentWeather current,
    required List<HourlyForecast> hourly,
    required List<DailyForecast> daily,
  }) {
    final maxRainChance = hourly
        .take(12)
        .map((hour) => hour.precipitationChance)
        .fold<int>(current.precipitationChance, (max, value) {
      return value > max ? value : max;
    });

    return WeatherSnapshot(
      id: 'openweather-${current.lastUpdated.millisecondsSinceEpoch}',
      locationName: current.locationName,
      condition: current.condition,
      temperatureF: current.temperatureF.round(),
      feelsLikeF: current.feelsLikeF.round(),
      windMph: current.windMph,
      windDirection: current.windDirection,
      humidityPercent: current.humidity,
      rainChancePercent: maxRainChance,
      aqi: 0,
      aqiCategory: 'Live',
      uvIndex: current.uvIndex,
      uvCategory: current.uvCategory,
      chaosMeterPercent: current.chaosMeterPercent,
      observedAt: current.lastUpdated,
      hourly: hourly
          .map(
            (hour) => ForecastHour(
              time: hour.time,
              temperatureF: hour.temperatureF.round(),
              condition: hour.condition,
              rainChancePercent: hour.precipitationChance,
            ),
          )
          .toList(),
      daily: daily
          .map(
            (day) => ForecastDay(
              date: day.date,
              lowF: day.minTempF.round(),
              highF: day.maxTempF.round(),
              condition: day.condition,
              rainChancePercent: day.precipitationChance,
            ),
          )
          .toList(),
      metrics: [
        WeatherMetric(
          id: 'pressure',
          label: 'Pressure',
          value: current.pressureLabel,
        ),
        WeatherMetric(
          id: 'visibility',
          label: 'Visibility',
          value: current.visibilityLabel,
        ),
      ],
    );
  }

  static double _fToC(double tempF) => (tempF - 32) * 5 / 9;

  static void _validateCoordinates(double latitude, double longitude) {
    if (!LocationCandidate.hasValidCoordinatePair(latitude, longitude)) {
      throw ArgumentError.value(
        'lat=$latitude lon=$longitude',
        'coordinates',
        'Weather requests require valid latitude and longitude.',
      );
    }
  }

  static String _requestKey(double latitude, double longitude) {
    return '${latitude.toStringAsFixed(3)},${longitude.toStringAsFixed(3)}';
  }

  static bool _throttleForcedRefresh(Object error) {
    return error is OpenWeatherBackendException &&
        error.isProviderAuthorizationFailure;
  }

  static void _debugWeatherLocation({
    required double latitude,
    required double longitude,
    required String locationName,
  }) {
    if (!kDebugMode) return;
    debugPrint(
      '[GrumpySkies] weather display location=$locationName '
      'lat=${latitude.toStringAsFixed(3)} '
      'lon=${longitude.toStringAsFixed(3)}',
    );
  }
}

class _WeatherRequestFailure {
  const _WeatherRequestFailure({
    required this.error,
    required this.failedAt,
  });

  final Object error;
  final DateTime failedAt;
}
