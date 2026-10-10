import 'dart:async';
import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:grumpy_skies/services/open_weather_backend_client.dart';
import 'package:grumpy_skies/services/network_counters.dart';
import 'package:grumpy_skies/services/cache_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test('corrupt exact cache is ignored without clearing any saved preferences',
      () async {
    SharedPreferences.setMockInitialValues({
      'weather_cache_exact_v2_38.8611_-94.6501': '{partial',
      'selectedPersonaId': 'grandpa',
    });
    final cache = await CacheService.create();
    expect(cache.getWeatherBundle(38.8611, -94.6501), isNull);
    expect(
        (await SharedPreferences.getInstance()).getString('selectedPersonaId'),
        'grandpa');
  });
  test(
      'concurrent exact backend requests deduplicate; nearby locations remain separate',
      () async {
    final gate = Completer<void>();
    var calls = 0;
    final counters = NetworkCounters();
    final client = OpenWeatherBackendClient(
        baseUrl: 'https://weather.example',
        counters: counters,
        httpClient: MockClient((request) async {
          calls++;
          await gate.future;
          return http.Response(
              jsonEncode({
                'current': {
                  'temp': 70,
                  'units': 'imperial',
                  'observedAt': '2026-10-10T12:00:00Z'
                }
              }),
              200,
              headers: {'content-type': 'application/json'});
        }));
    final first = client.current(latitude: 38.8611, longitude: -94.6501);
    final same = client.current(latitude: 38.8611, longitude: -94.6501);
    final nearby = client.current(latitude: 38.8612, longitude: -94.6502);
    gate.complete();
    final values = await Future.wait([first, same, nearby]);
    expect(calls, 2);
    expect(counters.snapshot['weatherBackendRequests'], 2);
    expect(counters.snapshot['backendDeduplicated'], 1);
    expect(counters.snapshot.containsKey('upstreamRequests'), isFalse);
    expect(values.first.temperatureKnown, isTrue);
    expect(values.first.feelsLikeKnown, isFalse);
    expect(values.first.windKnown, isFalse);
    expect(values.first.humidityKnown, isFalse);
    expect(values.first.uvKnown, isFalse);
    expect(values.first.sunriseKnown, isFalse);
    expect(values.first.aqiScale, isNull);
    SharedPreferences.setMockInitialValues({});
    final cache = await CacheService.create();
    // No data at a nearby location may masquerade as this exact place.
    expect(cache.getWeatherBundle(38.8612, -94.6502), isNull);
  });
  test('AQI value preserves explicit scale/source without converting to US AQI',
      () async {
    final client = OpenWeatherBackendClient(
        baseUrl: 'https://weather.example',
        httpClient: MockClient((_) async => http.Response(
            jsonEncode({
              'current': {
                'aqi': 4,
                'aqiScale': 'openweather_1_5',
                'aqiSource': 'openweather'
              }
            }),
            200,
            headers: {'content-type': 'application/json'})));
    final weather = await client.current(latitude: 1, longitude: 2);
    expect(weather.aqi, 4);
    expect(weather.aqiScale, 'openweather_1_5');
    expect(weather.aqiSource, 'openweather');
    expect(weather.temperatureKnown, isFalse);
  });
}
