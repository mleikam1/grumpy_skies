import 'package:flutter_test/flutter_test.dart';
import 'package:grumpy_skies/models/temperature_unit.dart';
import 'package:grumpy_skies/repositories/fake_roast_repository.dart';
import 'package:grumpy_skies/repositories/fake_weather_repository.dart';
import 'package:grumpy_skies/repositories/in_memory_settings_repository.dart';
import 'package:grumpy_skies/repositories/open_weather_repository.dart';
import 'package:grumpy_skies/services/open_weather_backend_client.dart';
import 'package:grumpy_skies/models/weather_models.dart';

void main() {
  test('FakeWeatherRepository returns stable demo sample data', () async {
    const repo = FakeWeatherRepository();

    final snapshot = await repo.getSnapshot(
      latitude: 41.8781,
      longitude: -87.6298,
    );
    final bundle = await repo.getWeather(
      latitude: 41.8781,
      longitude: -87.6298,
    );

    expect(snapshot.locationName, 'Demo City, US');
    expect(snapshot.condition, 'Partly Cloudy');
    expect(snapshot.temperatureF, 72);
    expect(snapshot.feelsLikeF, 74);
    expect(snapshot.windLabel, '8 mph SW');
    expect(snapshot.humidityPercent, 56);
    expect(snapshot.rainChancePercent, 38);
    expect(snapshot.aqiLabel, '82 Moderate');
    expect(snapshot.uvLabel, '5 Moderate');
    expect(snapshot.chaosMeterPercent, 82);
    expect(bundle.current.temperatureF.round(), 72);
    expect(bundle.current.windLabel, '8 mph SW');
  });

  test('FakeRoastRepository returns stable Karen roast sample', () async {
    const repo = FakeRoastRepository();

    final persona = await repo.getPersona('karen');
    final roast = await repo.getDailyRoast(
      personaId: persona.id,
      weatherSnapshotId: 'demo-partly-cloudy-2026-06-14',
    );

    expect(persona.displayName, 'Karen, Roast Queen');
    expect(roast.text, 'It’s 72°F and somehow still making a scene.');
  });

  test('InMemorySettingsRepository starts with sample settings and saves',
      () async {
    final repo = InMemorySettingsRepository();

    final initial = await repo.loadSettings();
    expect(initial.xp, 420);
    expect(initial.level, 3);
    expect(initial.streakDays, 5);
    expect(initial.temperatureUnit, TemperatureUnit.fahrenheit);

    await repo.saveSettings(
      initial.copyWith(
        temperatureUnit: TemperatureUnit.celsius,
        adsEnabled: false,
      ),
    );

    final updated = await repo.loadSettings();
    expect(updated.temperatureUnit, TemperatureUnit.celsius);
    expect(updated.adsEnabled, isFalse);
    expect(updated.xp, 420);
  });

  test('OpenWeatherRepository rejects invalid coordinates before backend calls',
      () async {
    final repo = OpenWeatherRepository(
      client: OpenWeatherBackendClient(baseUrl: 'https://example.com/api'),
    );

    await expectLater(
      repo.getWeather(latitude: 91, longitude: -87.6298),
      throwsA(isA<ArgumentError>()),
    );
  });

  test('OpenWeatherRepository skips minute and hourly when current fails',
      () async {
    final client = _RecordingBackendClient(
      currentError: const OpenWeatherBackendException(
        'OpenWeather rejected the server key.',
        statusCode: 502,
      ),
    );
    final repo = OpenWeatherRepository(client: client);

    await expectLater(
      repo.getWeather(
        latitude: 38.974,
        longitude: -94.685,
        location: _testLocation,
      ),
      throwsA(isA<OpenWeatherBackendException>()),
    );

    expect(client.currentCalls, 1);
    expect(client.minuteCalls, 0);
    expect(client.hourlyCalls, 0);

    await expectLater(
      repo.getWeather(
        latitude: 38.974,
        longitude: -94.685,
        location: _testLocation,
      ),
      throwsA(isA<OpenWeatherBackendException>()),
    );
    expect(client.currentCalls, 1);
  });

  test('OpenWeatherRepository still displays current if optional feeds fail',
      () async {
    final client = _RecordingBackendClient(
      minuteError: const OpenWeatherBackendException('Minute unavailable'),
      hourlyError: const OpenWeatherBackendException('Hourly unavailable'),
    );
    final repo = OpenWeatherRepository(client: client);

    final bundle = await repo.getWeather(
      latitude: 38.974,
      longitude: -94.685,
      location: _testLocation,
    );

    expect(bundle.current.locationName, 'Overland Park, Kansas, US');
    expect(bundle.current.temperatureF.round(), 76);
    expect(bundle.minutePrecipitation, isEmpty);
    expect(bundle.timeline, isEmpty);
    expect(bundle.hourly, hasLength(1));
    expect(client.currentCalls, 1);
    expect(client.minuteCalls, 1);
    expect(client.hourlyCalls, 1);
  });

  test('OpenWeatherRepository throttles forced auth retries', () async {
    final client = _RecordingBackendClient(
      currentError: const OpenWeatherBackendException(
        'OpenWeather rejected the server key for One Call API 4.0.',
        statusCode: 502,
        code: 'openweather_one_call_access_denied',
      ),
    );
    final repo = OpenWeatherRepository(client: client);

    await expectLater(
      repo.getWeather(
        latitude: 38.974,
        longitude: -94.685,
        forceRefresh: true,
        location: _testLocation,
      ),
      throwsA(isA<OpenWeatherBackendException>()),
    );
    await expectLater(
      repo.getWeather(
        latitude: 38.974,
        longitude: -94.685,
        forceRefresh: true,
        location: _testLocation,
      ),
      throwsA(isA<OpenWeatherBackendException>()),
    );

    expect(client.currentCalls, 1);
    expect(client.minuteCalls, 0);
    expect(client.hourlyCalls, 0);
  });
}

const _testLocation = LocationCandidate(
  name: 'Overland Park',
  state: 'Kansas',
  country: 'US',
  lat: 38.974,
  lon: -94.685,
  source: 'device',
);

class _RecordingBackendClient extends OpenWeatherBackendClient {
  _RecordingBackendClient({
    this.currentError,
    this.minuteError,
    this.hourlyError,
  }) : super(baseUrl: 'https://example.com/api');

  final Object? currentError;
  final Object? minuteError;
  final Object? hourlyError;
  int currentCalls = 0;
  int minuteCalls = 0;
  int hourlyCalls = 0;

  @override
  Future<CurrentWeather> current({
    required double latitude,
    required double longitude,
    String units = 'imperial',
    String locationName = '',
  }) async {
    currentCalls++;
    final error = currentError;
    if (error != null) throw error;
    return CurrentWeather(
      locationName: locationName,
      latitude: latitude,
      longitude: longitude,
      timezone: 'America/Chicago',
      timezoneOffset: -18000,
      temperatureC: (76 - 32) * 5 / 9,
      condition: 'Clear',
      feelsLikeC: (78 - 32) * 5 / 9,
      windKph: 12 * 1.609344,
      windDirection: 'SW',
      humidity: 64,
      precipitationChance: 0,
      aqi: 0,
      sunrise: DateTime(2026, 6, 21, 6),
      sunset: DateTime(2026, 6, 21, 20),
      moonrise: DateTime(2026, 6, 21, 22),
      moonset: DateTime(2026, 6, 22, 6),
      uvIndex: 7,
      uvCategory: 'High',
      lastUpdated: DateTime(2026, 6, 21, 12),
      fetchedAt: DateTime(2026, 6, 21, 12, 2),
      weatherId: 800,
      weatherIcon: '01d',
      units: units,
    );
  }

  @override
  Future<List<MinutePrecipitation>> minute({
    required double latitude,
    required double longitude,
    String units = 'imperial',
  }) async {
    minuteCalls++;
    final error = minuteError;
    if (error != null) throw error;
    return [
      MinutePrecipitation(
        time: DateTime(2026, 6, 21, 12, 1),
        precipitation: 0,
      ),
    ];
  }

  @override
  Future<List<TimelineWeatherPoint>> hourly({
    required double latitude,
    required double longitude,
    String units = 'imperial',
  }) async {
    hourlyCalls++;
    final error = hourlyError;
    if (error != null) throw error;
    return [
      TimelineWeatherPoint(
        time: DateTime(2026, 6, 21, 13),
        temperatureF: 77,
        condition: 'Clear',
      ),
    ];
  }
}
