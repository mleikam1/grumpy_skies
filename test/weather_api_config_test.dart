import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'package:grumpy_skies/config/weather_api_config.dart';
import 'package:grumpy_skies/services/open_weather_backend_client.dart';

void main() {
  group('WeatherApiConfig', () {
    test('defaults Android production to deployed HTTPS backend', () {
      final config = WeatherApiConfig.resolve(
        isWeb: false,
        platform: TargetPlatform.android,
      );

      expect(config.baseUrl, 'https://wingman-interactive-live.web.app/api');
      expect(config.baseUrl, isNot(contains('127.0.0.1')));
      expect(config.baseUrl, isNot(contains('grumpy-skies')));
    });

    test('uses Android emulator host only when emulator mode is explicit', () {
      final config = WeatherApiConfig.resolve(
        useFunctionsEmulator: true,
        isWeb: false,
        platform: TargetPlatform.android,
      );

      expect(
        config.baseUrl,
        'http://10.0.2.2:5001/wingman-interactive-live/us-central1/api',
      );
    });

    test('manual WEATHER_API_BASE_URL override wins', () {
      final config = WeatherApiConfig.resolve(
        baseUrlOverride: 'https://example.test/custom-api/',
        useFunctionsEmulator: true,
        isWeb: false,
        platform: TargetPlatform.android,
      );

      expect(config.baseUrl, 'https://example.test/custom-api');
    });

    test('web production uses Firebase Hosting rewrite path', () {
      final config = WeatherApiConfig.resolve(isWeb: true);

      expect(config.baseUrl, '/api');
    });
  });

  group('OpenWeatherBackendClient', () {
    test('maps normalized One Call 4.0 current DTO fields', () async {
      final client = OpenWeatherBackendClient(
        baseUrl: 'https://example.test/api',
        httpClient: MockClient((request) async {
          expect(request.url.path, '/api/weather/current');
          expect(request.url.queryParameters['lat'], '38.8672283');
          expect(request.url.queryParameters['lon'], '-94.6520357');
          return http.Response(
            jsonEncode({
              'current': {
                'latitude': 38.8672283,
                'longitude': -94.6520357,
                'timezone': 'America/Chicago',
                'timezoneOffset': -18000,
                'observedAt': 1782043200,
                'sourceUpdatedAt': 1782043200,
                'fetchedAt': '2026-06-21T12:03:00Z',
                'sunrise': 1782030000,
                'sunset': 1782085200,
                'temp': 76,
                'feelsLike': 78,
                'pressure': 1014,
                'humidity': 64,
                'dewPoint': 63,
                'uvi': 7.2,
                'visibility': 10000,
                'windSpeed': 12,
                'windGust': 19,
                'windDeg': 225,
                'rain1h': 1.27,
                'weatherId': 500,
                'weatherMain': 'Rain',
                'weatherDescription': 'light rain',
                'weatherIcon': '10d',
                'alertIds': ['alert-1'],
                'units': 'imperial',
              },
            }),
            200,
          );
        }),
      );

      final weather = await client.current(
        latitude: 38.8672283,
        longitude: -94.6520357,
        locationName: 'Overland Park, KS, US',
      );

      expect(weather.locationName, 'Overland Park, KS, US');
      expect(weather.temperatureF.round(), 76);
      expect(weather.feelsLikeF.round(), 78);
      expect(weather.humidity, 64);
      expect(weather.windMph.round(), 12);
      expect(weather.windDirection, 'SW');
      expect(weather.pressureHpa, 1014);
      expect(weather.visibilityMiles, closeTo(6.21, 0.01));
      expect(weather.rainLastHour, closeTo(0.05, 0.001));
      expect(weather.weatherId, 500);
      expect(weather.weatherIcon, '10d');
      expect(weather.alertIds, ['alert-1']);
      expect(weather.timezone, 'America/Chicago');
      expect(weather.timezoneOffset, -18000);
      expect(
          weather.displayUpdatedAt.toUtc(), DateTime.utc(2026, 6, 21, 12, 3));
    });

    test('does not expose raw socket exceptions to callers', () async {
      final client = OpenWeatherBackendClient(
        baseUrl: 'https://example.test/api',
        httpClient: MockClient((_) async {
          throw http.ClientException(
            'SocketConnection refused, address = 127.0.0.1, port = 5001',
          );
        }),
      );

      await expectLater(
        client.current(latitude: 1, longitude: 2),
        throwsA(
          isA<OpenWeatherBackendException>().having(
            (error) => error.message,
            'message',
            allOf(
              contains("Couldn't reach the forecast server"),
              isNot(contains('127.0.0.1')),
              isNot(contains('SocketConnection')),
            ),
          ),
        ),
      );
    });
  });
}
