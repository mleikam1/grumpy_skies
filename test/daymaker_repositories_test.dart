import 'package:flutter_test/flutter_test.dart';
import 'package:grumpy_skies/models/temperature_unit.dart';
import 'package:grumpy_skies/repositories/fake_roast_repository.dart';
import 'package:grumpy_skies/repositories/fake_weather_repository.dart';
import 'package:grumpy_skies/repositories/in_memory_settings_repository.dart';
import 'package:grumpy_skies/repositories/open_weather_repository.dart';
import 'package:grumpy_skies/services/open_weather_backend_client.dart';

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
}
