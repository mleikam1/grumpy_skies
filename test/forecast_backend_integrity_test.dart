import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:grumpy_skies/services/open_weather_backend_client.dart';

OpenWeatherBackendClient clientFor(Map<String, dynamic> payload) =>
    OpenWeatherBackendClient(
      baseUrl: 'https://weather.invalid',
      httpClient: MockClient((_) async => http.Response(
          jsonEncode(payload), 200,
          headers: {'content-type': 'application/json'})),
    );

void main() {
  test(
      'invalid dates and missing conditions never inherit current observations',
      () async {
    final client = clientFor({
      'units': 'metric',
      'timezone': 'Asia/Tokyo',
      'timezoneOffset': 32400,
      'current': {
        'temp': 28,
        'weatherDescription': 'Thunderstorm',
        'precipitationProbability': .8,
        'observedAt': '2026-10-15T12:00:00Z'
      },
      'hourly': [
        {'temp': 1, 'condition': 'Snow'},
        {'time': 'invalid', 'temp': 1},
        {'time': '2026-02-30T14:00:00Z', 'temp': 1},
        {'time': '2026-10-15T13:00:00Z'},
        {'time': '2026-10-15T14:00:00Z', 'temp': 0, 'pop': 0},
      ],
      'daily': [
        {'minTemp': 12, 'maxTemp': 20},
        {'date': '2026-02-30', 'minTemp': 12},
        {'date': '2026-10-16'},
        {'date': '2026-10-17', 'minTemp': 0, 'maxTemp': 0, 'pop': 0},
      ],
    });
    final weather = await client.forecast(latitude: 35, longitude: 139);
    expect(weather.current.timezone, 'Asia/Tokyo');
    expect(weather.current.timezoneOffset, 32400);
    expect(weather.hourly, hasLength(2));
    expect(weather.timeline, hasLength(2));
    expect(weather.daily, hasLength(2));
    expect(weather.hourly.first.condition, 'Unknown');
    expect(weather.daily.first.condition, 'Unknown');
    expect(weather.hourly.first.temperatureKnown, isFalse);
    expect(weather.hourly.first.precipitationChanceKnown, isFalse);
    expect(weather.daily.first.temperatureKnown, isFalse);
    expect(weather.daily.first.precipitationChanceKnown, isFalse);
    expect(weather.hourly.last.temperatureKnown, isTrue);
    expect(weather.hourly.last.temperatureC, 0);
    expect(weather.hourly.last.precipitationChanceKnown, isTrue);
    expect(weather.hourly.last.precipitationChance, 0);
    expect(weather.daily.last.temperatureKnown, isTrue);
    expect(weather.daily.last.precipitationChanceKnown, isTrue);
    expect(weather.daily.last.precipitationChance, 0);
  });

  test('daily epochs use IANA DST instead of a stale current offset', () async {
    final client = clientFor({
      'units': 'metric',
      'current': {'temp': 20, 'observedAt': '2026-10-15T12:00:00Z'},
      'dailyTimeline': {
        'timezone': 'America/Chicago',
        'timezoneOffset': -18000,
        'data': [
          {
            'dt':
                DateTime.utc(2026, 11, 2, 5, 30).millisecondsSinceEpoch ~/ 1000,
            'minTemp': 5,
            'maxTemp': 15
          },
        ],
      },
    });
    final weather = await client.forecast(latitude: 41, longitude: -87);
    expect(weather.current.timezone, 'America/Chicago');
    expect(weather.daily, hasLength(1));
    expect(weather.daily.single.date, DateTime(2026, 11, 1));
  });

  test(
      'standalone timelines filter malformed times without manufacturing points',
      () async {
    final client = clientFor({
      'points': [
        {'temperatureF': 72},
        {'time': '2026-02-30T12:00:00Z'},
        {'time': '2026-10-15T12:00:00Z', 'temperatureF': 72},
      ]
    });
    expect(await client.hourly(latitude: 41, longitude: -87), hasLength(1));
    expect(await client.timeline15(latitude: 41, longitude: -87), hasLength(1));
  });
}
