import 'package:flutter/foundation.dart';

import '../models/weather_models.dart';
import '../services/cache_service.dart';
import '../services/open_weather_backend_client.dart';
import 'weather_repository.dart';

class OpenWeatherRepository extends WeatherRepository {
  const OpenWeatherRepository({
    required OpenWeatherBackendClient client,
    CacheService? cacheService,
    Duration cacheDuration = const Duration(minutes: 10),
  })  : _client = client,
        _cacheService = cacheService,
        _cacheDuration = cacheDuration;

  final OpenWeatherBackendClient _client;
  final CacheService? _cacheService;
  final Duration _cacheDuration;

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
    if (!forceRefresh) {
      final cached = _validCachedBundle(latitude, longitude);
      if (cached != null) return cached;
    }

    try {
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
    } catch (_) {
      final cached = _cacheService?.getWeatherBundle(latitude, longitude);
      if (cached != null) return cached;
      rethrow;
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

    final currentFuture = _client.current(
      latitude: latitude,
      longitude: longitude,
      locationName: locationName,
    );
    final minuteFuture = _client.minute(
      latitude: latitude,
      longitude: longitude,
    );
    final hourlyFuture = _client.hourly(
      latitude: latitude,
      longitude: longitude,
    );

    final current = await currentFuture;
    final minutes = await minuteFuture;
    final timeline = await hourlyFuture;
    final alerts = current.alertIds.isEmpty
        ? const <WeatherAlert>[]
        : await getWeatherAlerts(alertIds: current.alertIds);
    final hourly = _hourlyFromTimeline(timeline, current);
    final daily = _dailyFromHourly(hourly, current);
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
      minutePrecipitation: minutes,
      timeline: timeline,
      alerts: alerts,
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
        ),
      ];
    }

    return byDate.entries.take(7).map((entry) {
      final temps = entry.value.map((hour) => hour.temperatureC).toList();
      final rainChance = entry.value
          .map((hour) => hour.precipitationChance)
          .fold<int>(0, (max, value) => value > max ? value : max);
      return DailyForecast(
        date: entry.key,
        minTempC: temps.reduce((a, b) => a < b ? a : b),
        maxTempC: temps.reduce((a, b) => a > b ? a : b),
        condition: entry.value.first.condition,
        precipitationChance: rainChance,
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
