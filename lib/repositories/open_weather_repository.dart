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

    final liveWeather = await _fetchPreferredWeatherBundle(
      latitude: latitude,
      longitude: longitude,
      locationName: locationName,
    );
    final current = liveWeather.current;
    final hourly = liveWeather.hourly.isEmpty
        ? _hourlyFromTimeline(liveWeather.timeline, current)
        : liveWeather.hourly;
    final daily = liveWeather.daily;
    _debugForecastCounts(
      hourlyCount: hourly.length,
      dailyCount: daily.length,
      hourlyMessage: liveWeather.hourlyForecastMessage,
      dailyMessage: liveWeather.dailyForecastMessage,
    );
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
      hourlyForecastMessage: liveWeather.hourlyForecastMessage,
      dailyForecastMessage: liveWeather.dailyForecastMessage,
    );
    return bundle;
  }

  Future<WeatherBundle> _fetchPreferredWeatherBundle({
    required double latitude,
    required double longitude,
    required String locationName,
  }) async {
    try {
      return await _client.forecast(
        latitude: latitude,
        longitude: longitude,
        locationName: locationName,
      );
    } catch (error) {
      if (!_shouldUseLegacyWeatherFallback(error)) rethrow;
      _debugLegacyWeatherFallback(error);
      return _fetchLegacyWeatherBundle(
        latitude: latitude,
        longitude: longitude,
        locationName: locationName,
        forecastError: error,
      );
    }
  }

  Future<WeatherBundle> _fetchLegacyWeatherBundle({
    required double latitude,
    required double longitude,
    required String locationName,
    Object? forecastError,
  }) async {
    final current = await _client.current(
      latitude: latitude,
      longitude: longitude,
      locationName: locationName,
    );
    Object? hourlyError;
    final minutesFuture = _client
        .minute(
      latitude: latitude,
      longitude: longitude,
    )
        .catchError((Object error) {
      _debugOptionalWeatherFailure('minute', error);
      return <MinutePrecipitation>[];
    });
    final timelineFuture = _client
        .hourly(
      latitude: latitude,
      longitude: longitude,
    )
        .catchError((Object error) {
      hourlyError = error;
      _debugOptionalWeatherFailure('hourly', error);
      return <TimelineWeatherPoint>[];
    });

    final minutes = await minutesFuture;
    final timeline = await timelineFuture;
    final alerts = current.alertIds.isEmpty
        ? const <WeatherAlert>[]
        : await getWeatherAlerts(alertIds: current.alertIds);

    return WeatherBundle(
      current: current,
      hourly: _hourlyFromTimeline(timeline, current),
      daily: const [],
      minutePrecipitation: minutes,
      timeline: timeline,
      alerts: alerts,
      hourlyForecastMessage:
          timeline.isEmpty ? _forecastIssueMessage(hourlyError) : null,
      dailyForecastMessage: _forecastIssueMessage(forecastError) ??
          '7-day forecast needs the bundled forecast backend.',
    );
  }

  static List<HourlyForecast> _hourlyFromTimeline(
    List<TimelineWeatherPoint> timeline,
    CurrentWeather current,
  ) {
    if (timeline.isEmpty) {
      return const [];
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

  static void _debugForecastCounts({
    required int hourlyCount,
    required int dailyCount,
    String? hourlyMessage,
    String? dailyMessage,
  }) {
    if (!kDebugMode) return;
    debugPrint(
      '[GrumpySkies] Forecast repository hourly count: $hourlyCount '
      'daily count: $dailyCount',
    );
    if (hourlyMessage != null) {
      debugPrint('[GrumpySkies] hourly forecast issue: $hourlyMessage');
    }
    if (dailyMessage != null) {
      debugPrint('[GrumpySkies] daily forecast issue: $dailyMessage');
    }
  }

  static bool _shouldUseLegacyWeatherFallback(Object error) {
    if (error is! OpenWeatherBackendException) return false;
    return error.statusCode == 404 || error.isProviderAuthorizationFailure;
  }

  static void _debugLegacyWeatherFallback(Object error) {
    if (!kDebugMode) return;
    debugPrint(
      '[GrumpySkies] bundled forecast unavailable; '
      'using deployed legacy weather endpoints: $error',
    );
  }

  static void _debugOptionalWeatherFailure(String endpoint, Object error) {
    if (!kDebugMode) return;
    debugPrint(
      '[GrumpySkies] optional $endpoint weather failed: $error',
    );
  }

  static String? _forecastIssueMessage(Object? error) {
    if (error is! OpenWeatherBackendException) return null;
    return switch (error.code) {
      'openweather_one_call_access_denied' =>
        'Forecast timeline needs OpenWeather One Call API 4.0 access.',
      'openweather_key_rejected' =>
        'Forecast timeline credentials need attention.',
      'openweather_not_found' => 'Forecast timeline data was not found.',
      'openweather_timeout' => 'Forecast timeline timed out. Try again soon.',
      'openweather_unavailable' =>
        'Forecast timeline is temporarily unavailable.',
      _ => error.message,
    };
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
