import 'package:flutter_test/flutter_test.dart';
import 'package:grumpy_skies/core/weather/forecast_solar_context.dart';
import 'package:grumpy_skies/core/weather/openweather_icon_mapper.dart';

void main() {
  test(
      'San Francisco future 3-5 AM is night, noon is day without provider icon',
      () {
    for (final hour in [3, 4, 5, 12]) {
      final instant = DateTime.utc(2026, 10, 17, hour + 7);
      expect(
          forecastIsDaylight(
              instant: instant, latitude: 37.7749, longitude: -122.4194),
          hour == 12,
          reason: 'PDT $hour:00 for this forecast date');
      expect(
          OpenWeatherIconMapper.map(
              conditionId: 800,
              forecastTime: instant,
              forecastLocalTime: DateTime.utc(2026, 10, 17, hour),
              latitude: 37.7749,
              longitude: -122.4194),
          hour == 12 ? 'clear-day' : 'clear-night');
    }
  });

  test('polar midnight sun and midday winter darkness have no clock heuristic',
      () {
    // Longyearbyen, Svalbard: sun remains above the horizon in June,
    // below it in December, including the local noon/midnight extremes.
    for (final utcHour in [0, 10, 12, 22]) {
      expect(
          forecastIsDaylight(
              instant: DateTime.utc(2026, 6, 21, utcHour),
              latitude: 78.2232,
              longitude: 15.6469),
          isTrue);
      expect(
          forecastIsDaylight(
              instant: DateTime.utc(2026, 12, 21, utcHour),
              latitude: 78.2232,
              longitude: 15.6469),
          isFalse);
    }
    expect(
        forecastIsDaylight(
            instant: DateTime.utc(2026, 12, 21),
            latitude: -78.2232,
            longitude: 15.6469),
        isTrue);
    expect(
        forecastIsDaylight(
            instant: DateTime.utc(2026, 6, 21, 12),
            latitude: -78.2232,
            longitude: 15.6469),
        isFalse);
  });

  test('date-line locations use absolute target instant and coordinate sign',
      () {
    for (final longitude in [179.9, -179.9]) {
      expect(
          forecastIsDaylight(
              instant: DateTime.utc(2026, 3, 20),
              latitude: 0,
              longitude: longitude),
          isTrue);
      expect(
          forecastIsDaylight(
              instant: DateTime.utc(2026, 3, 20, 12),
              latitude: 0,
              longitude: longitude),
          isFalse);
    }
    // +14 wall time crosses into the next date; its UTC instant is unchanged.
    expect(
        forecastIsDaylight(
            instant: DateTime.parse('2026-03-21T12:00:00+14:00'),
            latitude: 1.8721,
            longitude: -157.4278),
        isTrue);
    expect(
        forecastIsDaylight(
            instant: DateTime.parse('2026-03-21T00:00:00+14:00'),
            latitude: 1.8721,
            longitude: -157.4278),
        isFalse);
  });

  test('leap-day noon and midnight stay well-defined', () {
    expect(
        forecastIsDaylight(
            instant: DateTime.utc(2028, 2, 29, 12), latitude: 0, longitude: 0),
        isTrue);
    expect(
        forecastIsDaylight(
            instant: DateTime.utc(2028, 2, 29), latitude: 0, longitude: 0),
        isFalse);
  });

  test('explicit provider day/night and same-day solar events remain priority',
      () {
    final midnight = DateTime.utc(2026, 10, 17, 10);
    expect(
        OpenWeatherIconMapper.resolveIsDay(
            openWeatherIconCode: '01d',
            forecastTime: midnight,
            latitude: 37.7749,
            longitude: -122.4194),
        isTrue);
    expect(
        OpenWeatherIconMapper.resolveIsDay(
            openWeatherIconCode: '01n',
            forecastTime: DateTime.utc(2026, 10, 17, 19),
            latitude: 37.7749,
            longitude: -122.4194),
        isFalse);
    // Deliberately disagreeing coordinates prove valid supplied event priority.
    expect(
        OpenWeatherIconMapper.resolveIsDay(
            forecastTime: DateTime.utc(2026, 3, 20, 12),
            sunrise: DateTime.utc(2026, 3, 20, 6),
            sunset: DateTime.utc(2026, 3, 20, 18),
            latitude: 0,
            longitude: 180),
        isTrue);
  });

  test('old solar events do not override the future location calculation', () {
    expect(
        OpenWeatherIconMapper.resolveIsDay(
            forecastTime: DateTime.utc(2026, 10, 17, 10),
            forecastLocalTime: DateTime.utc(2026, 10, 17, 3),
            sunrise: DateTime.utc(2026, 10, 10, 14),
            sunset: DateTime.utc(2026, 10, 11, 1),
            latitude: 37.7749,
            longitude: -122.4194),
        isFalse);
  });

  test('missing invalid or nonfinite coordinates remain unknown', () {
    final target = DateTime.utc(2026, 10, 17, 10);
    for (final coordinates in <(double?, double?)>[
      (null, null),
      (null, 0),
      (0, null),
      (91, 0),
      (-91, 0),
      (0, 181),
      (0, -181),
      (double.nan, 0),
      (0, double.infinity),
    ]) {
      expect(
          forecastIsDaylight(
              instant: target,
              latitude: coordinates.$1,
              longitude: coordinates.$2),
          isNull);
      expect(
          OpenWeatherIconMapper.map(
              conditionId: 800,
              forecastTime: target,
              forecastLocalTime: DateTime.utc(2026, 10, 17, 3),
              latitude: coordinates.$1,
              longitude: coordinates.$2),
          OpenWeatherIconMapper.fallbackSlug);
    }
    // Existing daily summaries use a sun as their clear-weather symbol.
    expect(OpenWeatherIconMapper.map(conditionId: 800), 'clear-day');
    expect(
        OpenWeatherIconMapper.map(
            conditionId: -1,
            forecastTime: target,
            latitude: 37.7749,
            longitude: -122.4194),
        OpenWeatherIconMapper.fallbackSlug);
  });
}
