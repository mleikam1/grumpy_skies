import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:grumpy_skies/features/roasts/content/roast_context_adapter.dart';
import 'package:grumpy_skies/features/roasts/content/roast_local_preferences.dart';
import 'package:grumpy_skies/features/roasts/content/roast_selector.dart';
import 'package:grumpy_skies/features/roasts/content/weather_roast_models.dart';
import 'package:grumpy_skies/features/roasts/services/local_roast_engine.dart';
import 'package:grumpy_skies/features/roasts/services/roast_safety.dart';
import 'package:grumpy_skies/models/temperature_unit.dart';
import 'package:grumpy_skies/models/weather_models.dart';
import 'package:grumpy_skies/models/weather_safety.dart';
import 'package:grumpy_skies/shared/assets/persona_emotion_assets.dart';

final now = DateTime.utc(2026, 10, 9, 17);
const place = LocationCandidate(
    name: 'Chicago',
    country: 'US',
    state: 'IL',
    lat: 41.8,
    lon: -87.6,
    source: 'city');

void main() {
  group('frozen handoff safety', () {
    RoastSelection saved(
            {bool requiresAlerts = false,
            List<WeatherRoastTag> tags = const []}) =>
        RoastSelection(
            line: line('saved', tags: tags),
            renderedText: 'Saved exact caption.',
            packVersion: 'old-pack',
            primaryWeatherTag: WeatherRoastTag.fallback,
            requiresVerifiedAlerts: requiresAlerts);
    test(
        'missing weather blocks archived rule requirement with no positive tags',
        () {
      final positive = saved(requiresAlerts: true);
      expect(positive.line.tags, isEmpty);
      expect(roastHumorBlocked(null, now: now, selection: positive), isTrue);
      expect(roastHumorBlocked(null, now: now, selection: saved()), isFalse);
    });
    test('actual tornado and freezing rain block without an official alert',
        () {
      for (final code in [781, 511]) {
        final weather = bundle(code: code);
        expect(weather.alerts, isEmpty);
        expect(
            roastHumorBlocked(weather, now: now, selection: saved()), isTrue);
      }
    });
    test(
        'unknown alert coverage blocks positive metadata and legacy positive tags',
        () {
      final unknown = bundle(alertCoverageVerified: false);
      expect(
          roastHumorBlocked(unknown,
              now: now, selection: saved(requiresAlerts: true)),
          isTrue);
      expect(
          roastHumorBlocked(unknown,
              now: now, selection: saved(tags: [WeatherRoastTag.nice])),
          isTrue);
      expect(roastHumorBlocked(unknown, now: now, selection: saved()), isFalse);
      expect(
          roastHumorBlocked(bundle(),
              now: now, selection: saved(requiresAlerts: true)),
          isFalse);
    });
  });
  group('local feedback soft ranking', () {
    test(
        'liked favorites change chances deterministically independent of row order',
        () {
      const selector = RoastSelector();
      final rows = [line('a'), line('b')];
      final pack = packOf(rows);
      final reversed = packOf(rows.reversed.toList());
      final preferences = RoastLocalPreferences()
        ..setFavorite('a', true)
        ..setFeedback('a', RoastFeedback.liked)
        ..setFeedback('b', RoastFeedback.disliked);
      var baseline = 0;
      var preferred = 0;
      for (var i = 0; i < 1024; i++) {
        final seed = '${i * 7919}:review';
        RoastSelection pick(RoastPack source, Map<String, double> weights) =>
            selector.select(
                pack: source,
                context: ctx(),
                persona: 'karen',
                type: RoastType.today,
                seed: seed,
                preferenceWeights: weights);
        if (pick(pack, const {}).id == 'a') baseline++;
        final selected = pick(pack, preferences.weights);
        if (selected.id == 'a') preferred++;
        expect(pick(reversed, preferences.weights).id, selected.id);
      }
      expect(preferred, greaterThan(baseline + 150));
      expect(preferred, lessThan(1024)); // A dislike remains a soft weight.
    });

    test('preferences never bypass hard facts, intensity, recalls or safety',
        () {
      const selector = RoastSelector();
      final pack = packOf([
        line('truthful'),
        line('rain', codes: [501]),
        line('spicy', level: RoastLevel.spicy),
        line('recalled'),
      ]);
      const preferences = {
        'truthful': .5,
        'rain': 1e200,
        'spicy': 1e200,
        'recalled': 1e200
      };
      final selected = selector.select(
          pack: pack,
          context: ctx(),
          persona: 'karen',
          type: RoastType.today,
          maxLevel: RoastLevel.mild,
          disabledIds: {'recalled'},
          preferenceWeights: preferences);
      expect(selected.id, 'truthful');
      final hazard = selector.select(
          pack: pack,
          context: WeatherRoastContext.fromWeatherBundle(bundle(code: 781),
              now: now),
          persona: 'karen',
          type: RoastType.today,
          preferenceWeights: preferences);
      expect(hazard.reason, 'application_safety_gate');
    });
  });
  group('truthful roast context', () {
    test('probability is not current rain or intensity', () {
      final context =
          WeatherRoastContext.fromWeatherBundle(bundle(pop: 99), now: now);
      expect(context.precipChance, 99);
      expect(context.tags, isNot(contains(WeatherRoastTag.lightRain)));
      expect(context.tags, isNot(contains(WeatherRoastTag.heavyRain)));
      expect(context.facts, isNot(contains('observed_rain')));
      expect(context.facts, contains('forecast_rain_probability'));
    });
    test(
        '511/520/781, smoke, ash, squall and heavy thunder have precise meaning',
        () {
      for (final code in [511, 781, 711, 762, 771]) {
        final context =
            WeatherRoastContext.fromWeatherBundle(bundle(code: code), now: now);
        expect(context.tags, isNot(contains(WeatherRoastTag.fog)),
            reason: '$code');
        expect(context.tags, isNot(contains(WeatherRoastTag.heavyRain)),
            reason: '$code');
        expect(context.requiresSafetyMessage, isTrue, reason: '$code');
      }
      expect(roastWeatherTags(code: 520), contains(WeatherRoastTag.lightRain));
      for (final code in [520, 521, 531, 212]) {
        expect(roastWeatherTags(code: code),
            isNot(contains(WeatherRoastTag.heavyRain)));
      }
      expect(roastWeatherTags(code: 502), contains(WeatherRoastTag.heavyRain));
      expect(roastWeatherTags(code: 741), contains(WeatherRoastTag.fog));
    });
    test('explicit precipitation units and AQI scales stay distinct', () {
      final imperial =
          WeatherRoastContext.fromWeatherBundle(bundle(rain: .4), now: now);
      final metric = WeatherRoastContext.fromWeatherBundle(
          bundle(rain: .4, units: 'metric'),
          now: now);
      expect(imperial.observedRainMm, closeTo(10.16, .001));
      expect(imperial.tags, isNot(contains(WeatherRoastTag.heavyRain)));
      expect(imperial.facts, contains('observed_rain'));
      expect(metric.tags, isNot(contains(WeatherRoastTag.lightRain)));
      expect(metric.observedRainMm, .4);
      expect(roastWeatherTags(aqi: 5, aqiScale: 'openweather_1_5'),
          contains(WeatherRoastTag.badAir));
      expect(roastWeatherTags(aqi: 5, aqiScale: 'us_epa'),
          isNot(contains(WeatherRoastTag.badAir)));
      expect(
          roastWeatherTags(aqi: 170), isNot(contains(WeatherRoastTag.badAir)));
    });
    test('missing DTO fields and unavailable bundle never fabricate zeros', () {
      final unknown = WeatherRoastContext.unavailable(now: now);
      expect(unknown.tempF, isNull);
      expect(unknown.precipChance, isNull);
      expect(() => unknown.render('{temp}'), throwsFormatException);
      expect(() => unknown.render('{bogus}'), throwsFormatException);
      final unknownDto =
          WeatherRoastContext.fromWeatherBundle(bundle(known: false), now: now);
      expect(unknownDto.tempF, isNull);
      expect(unknownDto.feelsLikeF, isNull);
      expect(unknownDto.humidity, isNull);
      expect(unknownDto.windMph, isNull);
      expect(unknownDto.precipChance, isNull);
      expect(unknownDto.tags, isNot(contains(WeatherRoastTag.cold)));
    });
    test('local evaluation time is independent from observation time', () {
      final context = WeatherRoastContext.fromWeatherBundle(
          bundle(observedAt: now.subtract(const Duration(hours: 8))),
          now: now);
      expect(context.daypart, Daypart.afternoon);
      expect(context.freshness, WeatherFreshness.stale);
      expect(context.observedAt, now.subtract(const Duration(hours: 8)));
      final noZone =
          WeatherRoastContext.fromWeatherBundle(bundle(zone: null), now: now);
      expect(noZone.daypart, Daypart.any);
    });
    test('IANA DST spring gap, autumn overlap and selected midnight', () {
      expect(
          roastLocalTime(
                  DateTime.utc(2026, 3, 8, 7, 30), 'America/Chicago', null)!
              .hour,
          1);
      expect(
          roastLocalTime(
                  DateTime.utc(2026, 3, 8, 8, 30), 'America/Chicago', null)!
              .hour,
          3);
      final first = roastLocalTime(
          DateTime.utc(2026, 11, 1, 6, 30), 'America/Chicago', null)!;
      final second = roastLocalTime(
          DateTime.utc(2026, 11, 1, 7, 30), 'America/Chicago', null)!;
      expect(first.hour, 1);
      expect(second.hour, 1);
      expect(first.timeZoneOffset, isNot(second.timeZoneOffset));
      expect(
          roastLocalTime(
                  DateTime.utc(2026, 10, 10, 3), 'America/Chicago', null)!
              .day,
          9);
      expect(roastLocalTime(now, 'bad/zone', null), isNull);
      expect(roastLocalTime(now, null, -18000, forecast: true), isNull);
    });
    test('hourly and commute use actual complete intervals, no invented hours',
        () {
      final hour = now.add(const Duration(hours: 1));
      final weather = bundle(hourly: [
        hourly(hour, 520),
        hourly(hour.add(const Duration(hours: 2)), 800)
      ]);
      final current = WeatherRoastContext.fromWeatherBundle(weather, now: now);
      final target = WeatherRoastContext.fromWeatherBundle(weather,
          now: now, scope: RoastScope.hourly, targetTime: hour);
      expect(current.tags, contains(WeatherRoastTag.clear));
      expect(target.tags, contains(WeatherRoastTag.lightRain));
      expect(target.tempF, 50);
      expect(target.humidity, isNull);
      expect(target.windowStart, hour);
      final gap = WeatherRoastContext.fromWeatherBundle(weather,
          now: now,
          scope: RoastScope.commute,
          targetTime: hour,
          targetEnd: hour.add(const Duration(hours: 3)));
      expect(gap.forecastComplete, isFalse);
      expect(gap.tempF, isNull);
      expect(gap.tags, isNot(contains(WeatherRoastTag.clear)));
      final unspecified = WeatherRoastContext.fromWeatherBundle(weather,
          now: now, scope: RoastScope.commute);
      expect(unspecified.forecastComplete, isFalse);
    });
    test('weekend requires both actual weekend dates, never Friday current',
        () {
      final missing = WeatherRoastContext.fromWeatherBundle(bundle(),
          now: now, scope: RoastScope.weekend);
      expect(missing.forecastComplete, isFalse);
      expect(missing.tags, isNot(contains(WeatherRoastTag.weekendGood)));
      final weather = bundle(daily: [daily(10, 800), daily(11, 800)]);
      final weekend = WeatherRoastContext.fromWeatherBundle(weather,
          now: now, scope: RoastScope.weekend);
      expect(weekend.forecastComplete, isTrue);
      expect(weekend.tags, contains(WeatherRoastTag.weekendGood));
      expect(weekend.tempF, isNull);
      expect(weekend.windowStart, DateTime.utc(2026, 10, 10, 5));
      expect(weekend.windowEnd, DateTime.utc(2026, 10, 12, 5));
      final partial = WeatherRoastContext.fromWeatherBundle(
          bundle(daily: [daily(10, 800)]),
          now: now,
          scope: RoastScope.weekend);
      expect(partial.forecastComplete, isFalse);
    });
    test('any hazardous forecast period and current hazards gate future jokes',
        () {
      final weekend = WeatherRoastContext.fromWeatherBundle(
          bundle(daily: [daily(10, 800), daily(11, 202)]),
          now: now,
          scope: RoastScope.weekend);
      expect(weekend.requiresSafetyMessage, isTrue);
      final currentHazard = WeatherRoastContext.fromWeatherBundle(
          bundle(code: 781, daily: [daily(10, 800), daily(11, 800)]),
          now: now,
          scope: RoastScope.weekend);
      expect(currentHazard.requiresSafetyMessage, isTrue);
    });
    test(
        'hazard at only one daily temperature extreme still gates the interval',
        () {
      final weather = bundle(daily: [
        DailyForecast(
            date: DateTime.utc(2026, 10, 10),
            minTempC: 20,
            maxTempC: 44,
            condition: 'Clear',
            weatherId: 800),
        daily(11, 800),
      ]);
      final weekend = WeatherRoastContext.fromWeatherBundle(weather,
          now: now, scope: RoastScope.weekend);
      expect(weekend.forecastComplete, isTrue);
      expect(weekend.requiresSafetyMessage, isTrue);
    });

    test('selected place identity uses validated bundle metadata', () {
      final context = WeatherRoastContext.fromWeatherBundle(bundle(),
          now: now, selectedLocation: place);
      expect(context.city, 'Chicago');
      expect(context.tempF, 72);
      final other = WeatherRoastContext.fromWeatherBundle(bundle(),
          now: now,
          selectedLocation: const LocationCandidate(
              name: 'Elsewhere',
              country: 'US',
              lat: 40,
              lon: -90,
              source: 'city'));
      expect(other.tempF, isNull);
      expect(other.city, 'Elsewhere');
    });
    test('units only change rendering and explicit activity is a local fact',
        () {
      final c = WeatherRoastContext.fromWeatherBundle(bundle(),
          now: now,
          temperatureUnit: TemperatureUnit.celsius,
          activity: RoastActivity.walking);
      expect(c.render('{temp}{temp_unit}'), '22°C');
      expect(c.tempF, 72);
      expect(c.facts, contains('activity_walking'));
      expect(WeatherRoastContext.fromWeatherBundle(bundle(), now: now).facts,
          isNot(contains('activity_walking')));
    });
  });

  test(
      'serialized displays contain opaque place keys and explicit alert requirements',
      () {
    final context = WeatherRoastContext(
        city: 'Chicago',
        placeId: '41.8,-87.6',
        tempF: 72,
        tags: const {WeatherRoastTag.nice},
        observedAt: now,
        evaluatedAt: now,
        safetyStatus: WeatherSafetyStatus.clear);
    final pack = packOf([
      line('nice_rule', tags: [], rule: 'outdoors')
    ], rules: [
      const RoastRule(id: 'outdoors', requiredAll: ['nice'])
    ]);
    final engine = LocalRoastEngine();
    final selection = engine.select(
        pack: pack, context: context, persona: 'karen', type: RoastType.today);
    expect(selection.requiresVerifiedAlerts, isTrue);
    expect(RoastSelection.fromJson(selection.toJson()).requiresVerifiedAlerts,
        isTrue);
    engine.commitDisplayed(selection);
    final encoded = jsonEncode(engine.exportHistory());
    expect(encoded, isNot(contains('41.8')));
    expect(encoded, isNot(contains('-87.6')));
    expect(engine.exportHistory()['schema'], 2);
  });

  test('undocumented codes and invalid AQI cannot invent weather facts', () {
    for (final code in [299, 599, 699]) {
      final context =
          WeatherRoastContext.fromWeatherBundle(bundle(code: code), now: now);
      expect(context.tags, isNot(contains(WeatherRoastTag.storm)));
      expect(context.tags, isNot(contains(WeatherRoastTag.snow)));
      expect(context.facts, isNot(contains('observed_rain')));
      expect(context.factValue('clear'), isNull);
    }
    expect(roastWeatherTags(aqi: 99, aqiScale: 'openweather_1_5'),
        isNot(contains(WeatherRoastTag.badAir)));
    expect(roastWeatherTags(code: 611), isNot(contains(WeatherRoastTag.snow)));
    expect(roastWeatherTags(code: 611), contains(WeatherRoastTag.severe));
  });

  test('unknown forbidden fact rejects negative claims', () {
    final target = line('not_raining', tags: [], rule: 'dry_claim');
    final pack = packOf([
      target
    ], rules: [
      const RoastRule(id: 'dry_claim', forbidden: ['light_rain'])
    ]);
    final failed = const RoastSelector().eligibilityFailures(
        line: target,
        pack: pack,
        context: ctx(code: null),
        persona: 'karen',
        type: RoastType.today);
    expect(failed, contains('rule_forbidden'));
    expect(
        const RoastSelector().eligibilityFailures(
            line: target,
            pack: pack,
            context: ctx(),
            persona: 'karen',
            type: RoastType.today),
        isEmpty);
  });

  test(
      'same text refreshes weather provenance without a new selection exposure',
      () {
    final engine = LocalRoastEngine();
    final pack = packOf([line('unchanged_quote')]);
    final first = engine.select(
        pack: pack, context: ctx(), persona: 'karen', type: RoastType.today);
    engine.commitDisplayed(first);
    final later = now.add(const Duration(minutes: 1));
    final refreshedContext = WeatherRoastContext(
        city: 'Chicago',
        placeId: '41.8,-87.6',
        tempF: 72,
        conditionCode: 800,
        daypart: Daypart.afternoon,
        tags: const {WeatherRoastTag.clear},
        precipChance: 0,
        evaluatedAt: later,
        observedAt: later,
        localTime: DateTime.utc(2026, 10, 9, 12));
    final updated = engine.select(
        pack: pack,
        context: refreshedContext,
        persona: 'karen',
        type: RoastType.today);
    expect(updated.id, first.id);
    expect(updated.selectionId, first.selectionId);
    expect(updated.renderedText, first.renderedText);
    expect(updated.weatherTimestamp, later);
    expect(engine.commitDisplayed(updated), isFalse);
    expect(engine.exposureCount, 1);
  });

  group('hard eligibility and local presentation', () {
    test('legacy conjunction, missing codes, locale and intensity never relax',
        () {
      final pack = packOf([
        line('and', tags: [WeatherRoastTag.clear, WeatherRoastTag.hot]),
        line('missing', codes: [800]),
        line('spicy_fallback',
            level: RoastLevel.spicy, tags: [WeatherRoastTag.fallback]),
        line('foreign', locale: 'es-ES', tags: [WeatherRoastTag.fallback]),
      ]);
      final context = ctx(code: null);
      final selection = const RoastSelector().select(
          pack: pack,
          context: context,
          persona: 'karen',
          type: RoastType.today,
          maxLevel: RoastLevel.mild);
      expect(selection.source, 'application');
      expect(selection.line.level, RoastLevel.mild);
      expect(selection.line.locale, 'en-US');
      final es = const RoastSelector().select(
          pack: pack,
          context: const WeatherRoastContext(city: '', locale: 'es-ES'),
          persona: 'karen',
          type: RoastType.today,
          maxLevel: RoastLevel.mild);
      expect(es.id, 'foreign');
    });
    test(
        'explicit rules separate hard requirements from flavor and reject unknown',
        () {
      final line1 =
          line('chance', tags: [WeatherRoastTag.lightRain], rule: 'chance');
      final p = packOf([
        line1
      ], rules: [
        const RoastRule(id: 'chance', requiredAll: [
          'forecast_rain_probability'
        ], numeric: [
          RoastNumericConstraint(
              fact: 'precip_chance', unit: 'percent', min: 50)
        ])
      ]);
      const selector = RoastSelector();
      expect(
          selector
              .select(
                  pack: p,
                  context: ctx(pop: 70),
                  persona: 'karen',
                  type: RoastType.today)
              .id,
          'chance');
      expect(
          selector
              .select(
                  pack: p,
                  context: ctx(pop: null),
                  persona: 'karen',
                  type: RoastType.today)
              .id,
          isNot('chance'));
      expect(
          selector
              .select(
                  pack: p,
                  context: ctx(pop: 70, freshness: WeatherFreshness.stale),
                  persona: 'karen',
                  type: RoastType.today)
              .id,
          isNot('chance'));
    });
    test(
        'rules enforce any groups, forbidden facts, scope, dates and placeholders',
        () {
      final target =
          line('bounded', rule: 'r', text: '{humidity}', validUntil: now);
      final p = packOf([
        target
      ], rules: [
        const RoastRule(id: 'r', requiredAll: [
          'clear'
        ], anyOf: [
          ['cold', 'hot']
        ], forbidden: [
          'clear'
        ], scopes: [
          RoastScope.weekend
        ], placeholders: [
          'humidity'
        ])
      ]);
      final fails = const RoastSelector().eligibilityFailures(
          line: target,
          pack: p,
          context: ctx(),
          persona: 'karen',
          type: RoastType.today);
      expect(
          fails,
          containsAll([
            'valid_until',
            'required_placeholder',
            'rule_any_of',
            'rule_forbidden',
            'rule_scope',
            'rule_placeholders'
          ]));
    });
    test(
        'stale facts and unknown alert availability do not grant reassuring copy',
        () {
      final p = packOf([
        line('nice', tags: [WeatherRoastTag.nice])
      ]);
      for (final status in [
        WeatherSafetyStatus.unknown,
        WeatherSafetyStatus.stale
      ]) {
        final context = WeatherRoastContext(
            city: 'X',
            tags: const {WeatherRoastTag.nice},
            safetyStatus: status);
        expect(
            const RoastSelector()
                .select(
                    pack: p,
                    context: context,
                    persona: 'karen',
                    type: RoastType.today)
                .id,
            isNot('nice'));
      }
      final stale = ctx(freshness: WeatherFreshness.stale);
      expect(
          const RoastSelector()
              .select(
                  pack: packOf([line('clear')]),
                  context: stale,
                  persona: 'karen',
                  type: RoastType.today)
              .source,
          'application');
    });
    test('active alerts are application owned regardless of catalog weight',
        () {
      final context = WeatherRoastContext.fromWeatherBundle(
          bundle(alerts: const [
            WeatherAlert(
                senderName: 'NWS', event: 'Warning', description: 'Official')
          ]),
          now: now);
      final selection = const RoastSelector().select(
          pack: packOf([line('unsafe')]),
          context: context,
          persona: 'karen',
          type: RoastType.today);
      expect(selection.reason, 'application_safety_gate');
      expect(selection.source, 'application');
      expect(selection.mood, RoastMood.worried);
      expect(selection.renderedText, contains('official alert'));
    });
    test('seeded weights are invariant to catalog order and honor all aliases',
        () {
      final rows = [line('a'), line('b'), line('c')];
      const s = RoastSelector();
      expect(
          s
              .select(
                  pack: packOf(rows),
                  context: ctx(),
                  persona: 'karen',
                  type: RoastType.today,
                  seed: 'seed')
              .id,
          s
              .select(
                  pack: packOf(rows.reversed.toList()),
                  context: ctx(),
                  persona: 'karen',
                  type: RoastType.today,
                  seed: 'seed')
              .id);
      for (final pair in {
        'frat-bro': 'frat_bro',
        'fratbro': 'frat_bro',
        'old_grandpa': 'grandpa',
        'two-year-old': 'two_year_old',
        '2_year_old': 'two_year_old',
        'toddler': 'two_year_old'
      }.entries) {
        expect(normalizeRoastPersonaId(pair.key), pair.value);
      }
    });
    test(
        'rebuilds, tiny changes, tabs, offline restart and share reuse snapshot',
        () {
      final e = LocalRoastEngine();
      final p = packOf([line('a'), line('b'), line('c')]);
      final first = e.select(
          pack: p, context: ctx(), persona: 'karen', type: RoastType.today);
      expect(e.exposureCount, 0);
      expect(e.commitDisplayed(first), isTrue);
      expect(e.commitDisplayed(first), isFalse);
      for (var i = 0; i < 100; i++) {
        expect(
            identical(
                first,
                e.select(
                    pack: p,
                    context: ctx(temp: 73),
                    persona: 'karen',
                    type: RoastType.today)),
            isTrue);
      }
      expect(e.exposureCount, 1);
      final state =
          jsonDecode(jsonEncode(e.exportHistory())) as Map<String, dynamic>;
      final restarted = LocalRoastEngine()..importHistory(state);
      final restored = restarted.select(
          pack: p, context: ctx(), persona: 'karen', type: RoastType.today);
      expect(restored.toJson(), first.toJson());
      expect(restarted.exposureCount, 1);
      expect(RoastSelection.fromJson(first.toJson()).toJson(), first.toJson());
      expect(() => restored.line.tags.add(WeatherRoastTag.hot),
          throwsUnsupportedError);
      final another = e.select(
          pack: p,
          context: ctx(),
          persona: 'karen',
          type: RoastType.today,
          another: true);
      expect(another.id, isNot(first.id));
      e.commitDisplayed(another);
      expect(e.exposureCount, 2);
    });
    test(
        '100 explicit interactions only mutate bounded local history; reuse LRU',
        () {
      final e = LocalRoastEngine();
      final p = packOf([line('a'), line('b'), line('c')]);
      final selected = <String>[];
      for (var i = 0; i < 100; i++) {
        final choice = e.select(
            pack: p,
            context: ctx(at: now.add(Duration(seconds: i))),
            persona: 'karen',
            type: RoastType.today,
            another: true);
        e.commitDisplayed(choice);
        selected.add(choice.id);
      }
      expect(selected.take(3).toSet().length, 3);
      for (var i = 3; i < selected.length; i++) {
        expect(selected[i], selected[i - 3]);
      }
      expect(e.exposureCount, 100);
      expect((e.exportHistory()['ids'] as Map)['karen'].length, 3);
    });
    test('numeric-only and any-of-only rules reject stale values', () {
      for (final rule in [
        const RoastRule(id: 'r', numeric: [
          RoastNumericConstraint(fact: 'temp_f', unit: 'fahrenheit', min: 60)
        ]),
        const RoastRule(id: 'r', anyOf: [
          ['clear', 'hot']
        ]),
      ]) {
        final p = packOf([line('candidate', tags: const [], rule: 'r')],
            rules: [rule]);
        expect(
            const RoastSelector()
                .select(
                    pack: p,
                    context: ctx(freshness: WeatherFreshness.stale),
                    persona: 'karen',
                    type: RoastType.today)
                .source,
            'application');
      }
    });
    test('pack, rules and selected fallback metadata are immutable', () {
      final pack = RoastPack.fromJson(packOf([
        line('a', rule: 'r')
      ], rules: [
        const RoastRule(id: 'r', requiredAll: [
          'clear'
        ], anyOf: [
          ['clear']
        ])
      ]).toJson());
      expect(() => pack.roasts.clear(), throwsUnsupportedError);
      expect(() => pack.personas.clear(), throwsUnsupportedError);
      expect(() => pack.rules.clear(), throwsUnsupportedError);
      expect(
          () => pack.rules.first.requiredAll.clear(), throwsUnsupportedError);
      expect(
          () => pack.rules.first.anyOf.first.clear(), throwsUnsupportedError);
      final selection = const RoastSelector().select(
          pack: pack,
          context: WeatherRoastContext.unavailable(now: now),
          persona: 'karen',
          type: RoastType.today);
      expect(() => selection.line.tags.clear(), throwsUnsupportedError);
    });
    test('history is capped at 200 IDs and 50 families per persona', () {
      final e = LocalRoastEngine();
      for (var i = 0; i < 225; i++) {
        final p = packOf([line('row_$i')]);
        e.commitDisplayed(e.select(
            pack: p,
            context: ctx(at: now.add(Duration(seconds: i))),
            persona: 'karen',
            type: RoastType.today,
            another: true));
      }
      final history = e.exportHistory();
      expect((history['ids'] as Map)['karen'].length, 200);
      expect((history['families'] as Map)['karen'].length, 50);
      final restarted = LocalRoastEngine()..importHistory(history);
      expect(restarted.exportHistory()['ids'], history['ids']);
    });
    test('cached fallback is reconsidered when facts newly satisfy a rule', () {
      final e = LocalRoastEngine();
      final p = packOf([
        line('warm', tags: const [], rule: 'warm')
      ], rules: [
        const RoastRule(id: 'warm', numeric: [
          RoastNumericConstraint(fact: 'temp_f', unit: 'fahrenheit', min: 73)
        ])
      ]);
      final first = e.select(
          pack: p,
          context: ctx(temp: 72),
          persona: 'karen',
          type: RoastType.today);
      e.commitDisplayed(first);
      expect(first.source, 'application');
      expect(
          identical(
              first,
              e.select(
                  pack: p,
                  context: ctx(temp: 72),
                  persona: 'karen',
                  type: RoastType.today)),
          isTrue);
      expect(e.exposureCount, 1);
      expect(
          e
              .select(
                  pack: p,
                  context: ctx(temp: 73),
                  persona: 'karen',
                  type: RoastType.today)
              .id,
          'warm');
    });
    test(
        'all personas and all explicit moods preserve current expression metadata',
        () {
      for (final persona in supportedWeatherRoastPersonas) {
        for (final mood in RoastMood.values) {
          final target = line('m', persona: persona, mood: mood);
          final chosen = const RoastSelector().select(
              pack: packOf([target]),
              context: ctx(),
              persona: persona,
              type: RoastType.today);
          expect(chosen.mood, mood);
          expect(chosen.persona, persona);
          expect(PersonaEmotionAssets.path(chosen.persona, chosen.mood),
              'assets/personas/$persona/${mood.name}.png');
        }
      }
    });
  });
}

WeatherBundle bundle(
        {int code = 800,
        int pop = 0,
        double? rain,
        String units = 'imperial',
        String? zone = 'America/Chicago',
        bool known = true,
        bool alertCoverageVerified = true,
        DateTime? observedAt,
        List<HourlyForecast> hourly = const [],
        List<DailyForecast> daily = const [],
        List<WeatherAlert> alerts = const []}) =>
    WeatherBundle(
        current: CurrentWeather(
            locationName: 'Chicago, IL',
            latitude: 41.81,
            longitude: -87.61,
            temperatureC: (72 - 32) * 5 / 9,
            feelsLikeC: (74 - 32) * 5 / 9,
            temperatureKnown: known,
            feelsLikeKnown: known,
            windKnown: known,
            humidityKnown: known,
            uvKnown: known,
            condition: 'Clear',
            windKph: 8,
            humidity: 50,
            precipitationChance: pop,
            precipitationChanceKnown: known,
            aqi: 0,
            sunrise: DateTime.utc(1970),
            sunset: DateTime.utc(1970),
            moonrise: DateTime.utc(1970),
            moonset: DateTime.utc(1970),
            uvIndex: 2,
            lastUpdated: observedAt ?? now,
            timezone: zone,
            weatherId: code,
            rainLastHour: rain,
            units: units),
        hourly: hourly,
        daily: daily,
        location: place,
        alerts: alerts,
        alertCoverageVerified: alertCoverageVerified,
        alertsCheckedAt: now);
HourlyForecast hourly(DateTime time, int code) => HourlyForecast(
    time: time,
    temperatureC: 10,
    condition: 'Light rain',
    weatherId: code,
    precipitationChance: 80);
DailyForecast daily(int day, int code) => DailyForecast(
    date: DateTime.utc(2026, 10, day),
    minTempC: 18,
    maxTempC: 23,
    condition: 'Clear',
    weatherId: code);
WeatherRoastContext ctx(
        {int? code = 800,
        int? pop = 0,
        int temp = 72,
        DateTime? at,
        WeatherFreshness freshness = WeatherFreshness.fresh}) =>
    WeatherRoastContext(
        city: 'Chicago',
        placeId: '41.8,-87.6',
        tempF: temp,
        conditionCode: code,
        daypart: Daypart.afternoon,
        tags: const {WeatherRoastTag.clear},
        precipChance: pop,
        evaluatedAt: at ?? now,
        observedAt: now,
        localTime: DateTime.utc(2026, 10, 9, 12),
        freshness: freshness);
RoastPack packOf(List<RoastLine> rows, {List<RoastRule> rules = const []}) =>
    RoastPack(
        schemaVersion: 1,
        packVersion: 'test',
        generatedAt: now,
        personas: supportedWeatherRoastPersonas.toList(),
        roasts: rows,
        rules: rules);
RoastLine line(String id,
        {List<WeatherRoastTag> tags = const [WeatherRoastTag.clear],
        List<int> codes = const [],
        RoastLevel level = RoastLevel.mild,
        String locale = 'en-US',
        String? rule,
        String text = 'The sky has a comments section.',
        DateTime? validUntil,
        String persona = 'karen',
        RoastMood mood = RoastMood.annoyed}) =>
    RoastLine(
        id: id,
        persona: persona,
        type: RoastType.today,
        tags: tags,
        dayparts: const [Daypart.any],
        level: level,
        weight: 1,
        text: text,
        conditionCodes: codes,
        locale: locale,
        ruleId: rule,
        familyId: id,
        mood: mood,
        validUntil: validUntil);
