import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:grumpy_skies/features/roasts/content/roast_pack_csv_builder.dart';
import 'package:grumpy_skies/features/roasts/content/roast_pack_validator.dart';
import 'package:grumpy_skies/features/roasts/content/roast_selector.dart';
import 'package:grumpy_skies/features/roasts/content/weather_roast_models.dart';
import 'package:grumpy_skies/models/weather_models.dart';

void main() {
  group('roast pack content', () {
    test('JSON pack loads and validates', () {
      final pack = _loadBundledPack();
      final validation = const RoastPackValidator().validatePack(pack);

      expect(pack.schemaVersion, 1);
      expect(pack.packVersion, '2026.06.26.1');
      expect(pack.personas, containsAll(supportedWeatherRoastPersonas));
      expect(pack.roasts, hasLength(35));
      expect(validation.errors, isEmpty);
    });

    test('CSV builder validates and generates the bundled schema', () {
      final csv = File('content/roasts/roasts_template.csv').readAsStringSync();
      final result = const RoastPackCsvBuilder().build(csv);
      final json = jsonDecode(result.toPrettyJson()) as Map<String, dynamic>;

      expect(result.pack.roasts, hasLength(35));
      expect(result.warnings, isEmpty);
      expect(json['schema_version'], 1);
      expect(json['roasts'], isA<List<dynamic>>());
    });

    test('CSV builder fails on invalid placeholders', () {
      final csv = [
        roastCsvHeaders.join(','),
        'bad_placeholder,karen,Karen,today,clear,800,,,,,,any,mild,'
            '"Mystery {bogus}",,1,TRUE,en-US,"bad"',
      ].join('\n');

      expect(
        () => const RoastPackCsvBuilder().build(csv),
        throwsA(
          isA<RoastPackCsvBuildException>().having(
            (error) => error.errors.join('\n'),
            'errors',
            contains('Invalid placeholder {bogus}'),
          ),
        ),
      );
    });

    test('WeatherRoastContext maps loaded weather into tags', () {
      final context = WeatherRoastContext.fromWeatherBundle(
        WeatherBundle(
          current: _currentWeather(
            temperatureF: 94,
            feelsLikeF: 101,
            condition: 'Heavy thunderstorm',
            humidity: 70,
            windMph: 24,
            precipitationChance: 85,
            aqi: 160,
            aqiCategory: 'Unhealthy',
            uvIndex: 8,
            weatherId: 202,
            alertIds: const ['alert-1'],
          ),
          hourly: const [],
          daily: const [],
          alerts: const [
            WeatherAlert(
              senderName: 'Weather authority',
              event: 'Severe Thunderstorm Warning',
              description: 'Take shelter.',
            ),
          ],
        ),
        now: DateTime(2026, 6, 26, 15),
      );

      expect(context.tags, contains(WeatherRoastTag.hot));
      expect(context.tags, contains(WeatherRoastTag.humid));
      expect(context.tags, contains(WeatherRoastTag.windy));
      expect(context.tags, contains(WeatherRoastTag.storm));
      expect(context.tags, contains(WeatherRoastTag.heavyRain));
      expect(context.tags, contains(WeatherRoastTag.highUv));
      expect(context.tags, contains(WeatherRoastTag.badAir));
      expect(context.tags, contains(WeatherRoastTag.severe));
      expect(context.tags, contains(WeatherRoastTag.commuteRisk));
      expect(context.tags, contains(WeatherRoastTag.gross));
    });

    test('placeholder rendering handles known, missing, and unknown values',
        () {
      const context = WeatherRoastContext(
        city: '',
        tempF: 72,
        feelsLikeF: 74,
        condition: '',
        humidity: 56,
        windMph: 8.2,
        precipChance: 38,
        daypart: Daypart.morning,
        tags: {WeatherRoastTag.nice},
      );

      final rendered = context.render(
        '{city}: {temp}{temp_unit}, feels {feels_like}, {unknown}.',
      );

      expect(rendered, 'your area: 72°F, feels 74.');
      expect(rendered, isNot(contains('null')));
      expect(rendered, isNot(contains('{unknown}')));
    });

    test('selector uses persona fallback when weather copy is unavailable', () {
      final pack = _pack([
        _line(
          id: 'karen_fallback',
          tags: const [WeatherRoastTag.fallback],
          text: 'Karen fallback.',
        ),
      ]);

      final selection = const RoastSelector().select(
        pack: pack,
        context: WeatherRoastContext.fallback(),
        persona: 'karen',
        type: RoastType.today,
        seed: 'fallback',
      );

      expect(selection.line.id, 'karen_fallback');
      expect(selection.renderedText, 'Karen fallback.');
    });

    test('selector prefers severe safety-first copy', () {
      final pack = _loadBundledPack();
      final selection = const RoastSelector().select(
        pack: pack,
        context: const WeatherRoastContext(
          city: 'Demo City',
          tempF: 70,
          feelsLikeF: 70,
          condition: 'Severe thunderstorm',
          humidity: 80,
          windMph: 30,
          precipChance: 90,
          daypart: Daypart.afternoon,
          tags: {WeatherRoastTag.severe, WeatherRoastTag.storm},
          conditionCode: 212,
        ),
        persona: 'karen',
        type: RoastType.today,
        seed: 'severe',
      );

      expect(selection.line.id, 'karen_severe_today_001');
      expect(selection.renderedText, contains('Check alerts'));
    });

    test('selector excludes disabled IDs', () {
      final pack = _loadBundledPack();
      final selection = const RoastSelector().select(
        pack: pack,
        context: const WeatherRoastContext(
          city: 'Demo City',
          tempF: 70,
          feelsLikeF: 70,
          condition: 'Severe thunderstorm',
          humidity: 80,
          windMph: 30,
          precipChance: 90,
          daypart: Daypart.afternoon,
          tags: {WeatherRoastTag.severe, WeatherRoastTag.storm},
          conditionCode: 212,
        ),
        persona: 'karen',
        type: RoastType.today,
        disabledIds: const {'karen_severe_today_001'},
        seed: 'disabled',
      );

      expect(selection.line.id, isNot('karen_severe_today_001'));
    });

    test('selector avoids recent IDs when another top candidate exists', () {
      final pack = _pack([
        _line(id: 'clear_1', tags: const [WeatherRoastTag.clear]),
        _line(id: 'clear_2', tags: const [WeatherRoastTag.clear]),
      ]);

      final selection = const RoastSelector().select(
        pack: pack,
        context: _clearContext,
        persona: 'karen',
        type: RoastType.today,
        recentRoastIds: const ['clear_1'],
        seed: 'recent',
      );

      expect(selection.line.id, 'clear_2');
    });

    test('selector is deterministic for a stable seed', () {
      final pack = _pack([
        _line(id: 'clear_1', tags: const [WeatherRoastTag.clear]),
        _line(id: 'clear_2', tags: const [WeatherRoastTag.clear]),
      ]);
      const selector = RoastSelector();

      final first = selector.select(
        pack: pack,
        context: _clearContext,
        persona: 'karen',
        type: RoastType.today,
        seed: 'stable',
      );
      final second = selector.select(
        pack: pack,
        context: _clearContext,
        persona: 'karen',
        type: RoastType.today,
        seed: 'stable',
      );

      expect(second.line.id, first.line.id);
      expect(second.renderedText, first.renderedText);
    });
  });
}

RoastPack _loadBundledPack() {
  final raw = File('assets/roasts/roast_pack_v1.json').readAsStringSync();
  return RoastPack.fromJson(jsonDecode(raw) as Map<String, dynamic>);
}

RoastPack _pack(List<RoastLine> roasts) {
  return RoastPack(
    schemaVersion: 1,
    packVersion: 'test',
    generatedAt: DateTime.utc(2026, 6, 26),
    personas: const ['karen'],
    roasts: roasts,
  );
}

RoastLine _line({
  required String id,
  required List<WeatherRoastTag> tags,
  String text = 'Clear line.',
}) {
  return RoastLine(
    id: id,
    persona: 'karen',
    type: RoastType.today,
    tags: tags,
    dayparts: const [Daypart.any],
    level: RoastLevel.mild,
    weight: 1,
    text: text,
  );
}

const _clearContext = WeatherRoastContext(
  city: 'Demo City',
  tempF: 72,
  feelsLikeF: 74,
  condition: 'Clear',
  humidity: 50,
  windMph: 4,
  precipChance: 0,
  daypart: Daypart.afternoon,
  tags: {WeatherRoastTag.clear, WeatherRoastTag.nice},
  conditionCode: 800,
);

CurrentWeather _currentWeather({
  required int temperatureF,
  required int feelsLikeF,
  required String condition,
  required int humidity,
  required double windMph,
  required int precipitationChance,
  required int aqi,
  required String aqiCategory,
  required double uvIndex,
  int? weatherId,
  List<String> alertIds = const [],
}) {
  return CurrentWeather(
    locationName: 'Demo City, US',
    temperatureC: (temperatureF - 32) * 5 / 9,
    condition: condition,
    feelsLikeC: (feelsLikeF - 32) * 5 / 9,
    windKph: windMph * 1.609344,
    windDirection: 'SW',
    humidity: humidity,
    precipitationChance: precipitationChance,
    aqi: aqi,
    aqiCategory: aqiCategory,
    sunrise: DateTime(2026, 6, 26, 5, 45),
    sunset: DateTime(2026, 6, 26, 20, 30),
    moonrise: DateTime(2026, 6, 26, 22),
    moonset: DateTime(2026, 6, 27, 6),
    uvIndex: uvIndex,
    lastUpdated: DateTime(2026, 6, 26, 15),
    weatherId: weatherId,
    alertIds: alertIds,
  );
}
