// Synthetic preview data. Never import this library from production code.
import '../models/weather_models.dart';
import '../repositories/weather_repository.dart';
import '../services/location_service.dart';

/// Mirrors docs/daymaker_exact_ui/fixtures/approved_design_fixture.json.
/// Values outside that file are explicitly synthetic model adapters below.
abstract final class ApprovedFixture {
  static final now = DateTime.parse('2026-10-12T10:00:00-05:00');
  static final observedAt = DateTime.parse('2026-10-12T09:58:00-05:00');
  static final location = WeatherLocation(
    name: 'Overland Park',
    state: 'KS',
    country: 'US',
    latitude: 38.9822,
    longitude: -94.6708,
    updatedAt: now,
  );
  static double c(num f) => (f - 32) * 5 / 9;
  static final hourly = <HourlyForecast>[
    for (final data in <(int, int, String, String, int)>[
      (10, 72, 'Partly cloudy', '02d', 802),
      (11, 74, 'Clear', '01d', 800),
      (13, 76, 'Cloudy', '03d', 803),
      (15, 73, 'Cloudy', '03d', 803),
      (17, 69, 'Rain', '10d', 500),
    ])
      HourlyForecast(
        time: DateTime.utc(2026, 10, 12, data.$1 + 5),
        temperatureC: c(data.$2),
        condition: data.$3,
        weatherIcon: data.$4,
        weatherId: data.$5,
        precipitationChance: data.$1 == 17 ? 40 : 0,
        precipitationChanceKnown: data.$1 == 17,
      ),
  ];
  static final daily = <DailyForecast>[
    for (final data in <(int, int, int, String, String, int)>[
      (12, 76, 61, 'Clear', '01d', 800),
      (13, 71, 54, 'Rain', '10d', 500),
      (14, 68, 52, 'Cloudy', '03d', 803),
    ])
      DailyForecast(
        date: DateTime.utc(2026, 10, data.$1, 5),
        maxTempC: c(data.$2),
        minTempC: c(data.$3),
        condition: data.$4,
        weatherIcon: data.$5,
        weatherId: data.$6,
        precipitationChanceKnown: false,
      ),
  ];
  // The model requires finite metrics absent from the board. Zero values are
  // synthetic adapters only; they are not observations or reference values.
  static final snapshot = WeatherSnapshot(
    id: 'approved-preview-2026-10-12',
    locationName: 'Overland Park, KS',
    condition: 'Partly cloudy',
    temperatureF: 72,
    feelsLikeF: 74,
    windMph: 0,
    windDirection: '',
    humidityPercent: 0,
    rainChancePercent: 0,
    aqi: 0,
    aqiCategory: 'Not supplied',
    uvIndex: 0,
    uvCategory: 'Not supplied',
    chaosMeterPercent: 0,
    observedAt: observedAt,
    hourly: [
      for (final hour in hourly)
        ForecastHour(
            time: hour.time,
            temperatureF: hour.temperatureF.round(),
            condition: hour.condition,
            rainChancePercent: hour.precipitationChance)
    ],
    daily: [
      for (final day in daily)
        ForecastDay(
            date: day.date,
            highF: day.maxTempF.round(),
            lowF: day.minTempF.round(),
            condition: day.condition,
            rainChancePercent: 0)
    ],
  );
  static final weather = WeatherBundle(
    current: CurrentWeather(
      locationName: 'Overland Park, KS',
      latitude: location.lat,
      longitude: location.lon,
      timezoneOffset: -18000,
      timezone: 'America/Chicago',
      temperatureC: c(72),
      feelsLikeC: c(74),
      condition: 'Partly cloudy',
      weatherIcon: '02d',
      weatherMain: 'Clouds',
      weatherId: 802,
      windKph: 0,
      humidity: 0,
      precipitationChance: 0,
      precipitationChanceKnown: false,
      aqi: 0,
      aqiCategory: 'Not supplied',
      uvIndex: 0,
      sunrise: DateTime.fromMillisecondsSinceEpoch(0, isUtc: true),
      sunset: DateTime.fromMillisecondsSinceEpoch(0, isUtc: true),
      moonrise: DateTime.fromMillisecondsSinceEpoch(0, isUtc: true),
      moonset: DateTime.fromMillisecondsSinceEpoch(0, isUtc: true),
      lastUpdated: observedAt,
      sourceUpdatedAt: observedAt,
      fetchedAt: now,
    ),
    hourly: hourly,
    daily: daily,
    snapshot: snapshot,
    location: location,
    alertCoverageVerified: true,
    alertsCheckedAt: now,
  );
}

class ApprovedWeatherRepository extends WeatherRepository {
  int requestCount = 0;
  bool failRequests = false;
  bool offline = false;
  @override
  Future<WeatherBundle> getWeather(
      {required double latitude,
      required double longitude,
      bool forceRefresh = false,
      LocationCandidate? location}) async {
    requestCount++;
    if (failRequests) throw StateError('Synthetic unavailable weather fixture');
    return offline
        ? ApprovedFixture.weather.asOfflineCache()
        : ApprovedFixture.weather;
  }

  @override
  Future<WeatherSnapshot> getSnapshot(
          {required double latitude,
          required double longitude,
          bool forceRefresh = false}) async =>
      ApprovedFixture.snapshot;
  @override
  Future<List<RadarAlert>> getRadarAlerts(
          {required double latitude, required double longitude}) async =>
      const [];
  @override
  Future<List<LocationCandidate>> searchLocations(
          {required String query, int limit = 5}) async =>
      [ApprovedFixture.location];
}

class PreviewLocationService extends LocationService {
  const PreviewLocationService();
  @override
  Future<DeviceLocationResult> getCurrentLocation() async =>
      const DeviceLocationResult.failure(DeviceLocationFailure(
        type: DeviceLocationFailureType.permissionDenied,
        message: 'Fixture preview does not request device location.',
      ));
}
