import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:grumpy_skies/core/weather/temperature_format.dart';
import 'package:grumpy_skies/features/roasts/content/roast_context_adapter.dart';
import 'package:grumpy_skies/features/roasts/content/roast_selector.dart';
import 'package:grumpy_skies/features/roasts/content/weather_roast_models.dart';
import 'package:grumpy_skies/features/roasts/controllers/local_roast_controller.dart';
import 'package:grumpy_skies/features/roasts/services/hourly_timeline_roasts.dart';
import 'package:grumpy_skies/features/roasts/services/local_roast_engine.dart';
import 'package:grumpy_skies/models/temperature_unit.dart';
import 'package:grumpy_skies/models/weather_models.dart';
import 'package:grumpy_skies/services/network_counters.dart';
import 'package:grumpy_skies/shared/assets/persona_emotion_assets.dart';

import 'local_roast_engine_test.dart' as fixture;

HourlyForecast hour(DateTime time,
        {double celsius = 21.49,
        int code = 800,
        bool known = true,
        int pop = 0,
        bool popKnown = true}) =>
    HourlyForecast(
        time: time,
        temperatureC: celsius,
        temperatureKnown: known,
        condition: code == 800 ? 'Clear' : 'Cloudy',
        weatherId: code,
        precipitationChance: pop,
        precipitationChanceKnown: popKnown);

RoastLine line(String id,
        {String? text,
        String? rule,
        List<WeatherRoastTag> tags = const [WeatherRoastTag.clear]}) =>
    RoastLine(
        id: id,
        persona: 'karen',
        type: RoastType.hourly,
        tags: tags,
        dayparts: const [Daypart.any],
        level: RoastLevel.mild,
        weight: 1,
        text: text ?? 'Forecast {temp}{temp_unit}. Unique opinion $id.',
        mood: RoastMood.annoyed,
        familyId: id,
        ruleId: rule);

RoastSelection prepared(HourlyForecast hour) => RoastSelection(
    line: line('hour_${hour.time.millisecondsSinceEpoch}'),
    renderedText: 'Unique forecast opinion ${hour.time.millisecondsSinceEpoch}',
    packVersion: 'test',
    primaryWeatherTag: WeatherRoastTag.clear,
    windowStart: hour.time,
    windowEnd: hour.time.add(const Duration(hours: 1)),
    scope: RoastScope.hourly);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final now = fixture.now;
  final actualPack = RoastPack.fromJson(
      (jsonDecode(File('assets/roasts/roast_pack_v1.json').readAsStringSync())
              as Map)
          .cast<String, dynamic>());

  test('default starts early, uses four hours and enforces rolling cap', () {
    final hours = List.generate(73, (i) => hour(now.add(Duration(hours: i))));
    final entries = scheduleHourlyTimelineRoasts(
        hours: hours, select: (h, ids, texts) => prepared(h));
    expect(entries.first.targetTime, now.add(const Duration(hours: 2)));
    for (var i = 1; i < entries.length; i++) {
      expect(entries[i].targetTime.difference(entries[i - 1].targetTime),
          const Duration(hours: 4));
    }
    for (final entry in entries) {
      expect(
          entries
              .where((e) =>
                  !e.targetTime.isBefore(entry.targetTime) &&
                  e.targetTime.difference(entry.targetTime) <
                      const Duration(hours: 24))
              .length,
          lessThanOrEqualTo(6));
    }
  });

  test('nearby changes win without shortening the three elapsed hour minimum',
      () {
    final hours = List.generate(
        32,
        (i) => hour(now.add(Duration(hours: i)),
            code: i < 5 || i >= 8 && i < 11 ? 800 : 804));
    final entries = scheduleHourlyTimelineRoasts(
        hours: hours, select: (h, ids, texts) => prepared(h));
    expect(entries[1].targetTime, now.add(const Duration(hours: 5)));
    for (var i = 1; i < entries.length; i++) {
      expect(entries[i].targetTime.difference(entries[i - 1].targetTime),
          greaterThanOrEqualTo(const Duration(hours: 3)));
    }
    for (final entry in entries) {
      expect(
          entries
              .where((e) =>
                  !e.targetTime.isBefore(entry.targetTime) &&
                  e.targetTime.difference(entry.targetTime) <
                      const Duration(hours: 24))
              .length,
          lessThanOrEqualTo(6));
    }
  });

  test('missing hours, duplicate records and DST repeated clocks use instants',
      () {
    final start = DateTime.utc(2026, 11, 1, 5);
    final hours = [0, 1, 2, 5, 9, 12, 13, 16, 20, 24]
        .map((i) => hour(start.add(Duration(hours: i))))
        .toList();
    final firstOne =
        roastLocalTime(hours[1].time, 'America/Chicago', null, forecast: true)!;
    final secondOne =
        roastLocalTime(hours[2].time, 'America/Chicago', null, forecast: true)!;
    expect(firstOne.hour, secondOne.hour);
    final entries = scheduleHourlyTimelineRoasts(
        hours: [...hours.reversed, hours[1]],
        select: (h, ids, texts) => prepared(h));
    expect(entries.map((e) => e.targetTime).toSet().length, entries.length);
    for (var i = 1; i < entries.length; i++) {
      expect(entries[i].targetTime.difference(entries[i - 1].targetTime),
          greaterThanOrEqualTo(const Duration(hours: 3)));
    }
    expect(entries.every((e) => hours.contains(e.hour)), isTrue);
  });

  test('pending choices reserve IDs and text without recording impressions',
      () {
    final hours = List.generate(25, (i) => hour(now.add(Duration(hours: i))));
    final controller = LocalRoastController(
        initialPack: fixture.packOf([
      line('a', text: 'Exactly the same hourly opinion.'),
      line('b', text: 'Exactly the same hourly opinion!'),
      line('c', text: 'A different forecast remark.'),
    ]));
    addTearDown(controller.dispose);
    final entries = controller.selectHourlyTimeline(
        persona: 'karen', bundle: fixture.bundle(hourly: hours), now: now);
    expect(entries.length, 2);
    expect(entries.map((e) => e.selection.id).toSet().length, entries.length);
    expect(
        entries
            .map((e) => normalizeRoastText(e.selection.renderedText))
            .toSet()
            .length,
        entries.length);
    expect(controller.engine.exposureCount, 0);
    expect(controller.exposures, isEmpty);
    expect(controller.commitDisplayed(entries.first.selection), isTrue);
    expect(controller.commitDisplayed(entries.first.selection), isFalse);
    expect(controller.engine.exposureCount, 1);
  });

  test('target value rounds once in both units; current now remains real', () {
    final hours = List.generate(12, (i) => hour(now.add(Duration(hours: i))));
    final controller = LocalRoastController(
        initialPack: fixture.packOf(List.generate(8, (i) => line('value_$i'))));
    addTearDown(controller.dispose);
    final source = fixture.bundle(hourly: hours);
    final first = controller.selectHourlyTimeline(
        persona: 'karen', bundle: source, now: now);
    for (final unit in TemperatureUnit.values) {
      final entries = controller.selectHourlyTimeline(
          persona: 'karen', bundle: source, now: now, unit: unit);
      expect(
          entries.map((e) => e.selection.id), first.map((e) => e.selection.id));
      for (final entry in entries) {
        expect(entry.selection.selectedAt, now);
        expect(entry.selection.windowStart, entry.targetTime);
        expect(entry.selection.windowEnd, entry.targetEnd);
        expect(
            entry.selection.renderedText,
            contains(forecastTemperature(entry.hour.temperatureC, unit,
                suffix: true)));
      }
    }
    // 21.49 C -> 71 F -> 22 C would incorrectly display 22 C; the row correctly shows 21 C.
    // every supplied fractional C value is kept, never re-derived.
    expect(controller.lastContext!.temperatureC, 21.49);
  });

  test(
      'reopen, history restore, tiny weather changes and preferences stay stable',
      () {
    final hours = List.generate(25, (i) => hour(now.add(Duration(hours: i))));
    final pack = fixture.packOf(List.generate(10, (i) => line('stable_$i')));
    final controller = LocalRoastController(initialPack: pack);
    addTearDown(controller.dispose);
    final source = fixture.bundle(hourly: hours);
    final first = controller.selectHourlyTimeline(
        persona: 'karen', bundle: source, now: now);
    controller.commitDisplayed(first.first.selection);
    controller.setFavorite(first.first.selection.id, true);
    NetworkCounters.instance.reset();
    for (var rebuild = 0; rebuild < 10; rebuild++) {
      final reopened = controller.selectHourlyTimeline(
          persona: 'karen',
          bundle: source,
          now: now.add(Duration(minutes: rebuild)));
      expect(reopened.map((e) => e.selection.selectionId),
          first.map((e) => e.selection.selectionId));
      expect(reopened.map((e) => e.selection.renderedText),
          first.map((e) => e.selection.renderedText));
    }
    final restored = LocalRoastController(
        initialPack: pack,
        engine: LocalRoastEngine()
          ..importHistory(controller.engine.exportHistory()));
    addTearDown(restored.dispose);
    final reopened = restored.selectHourlyTimeline(
        persona: 'karen', bundle: source, now: now);
    expect(reopened.map((e) => e.selection.selectionId),
        first.map((e) => e.selection.selectionId));
    expect(restored.commitDisplayed(reopened.first.selection), isFalse);
    expect(NetworkCounters.instance.snapshot, isEmpty);
  });

  test('rolling first hour and fresh publications retain upcoming targets', () {
    final hours = List.generate(31, (i) => hour(now.add(Duration(hours: i))));
    final controller = LocalRoastController(
        initialPack:
            fixture.packOf(List.generate(20, (i) => line('rolling_$i'))));
    addTearDown(controller.dispose);
    controller.publishWeather(fixture.bundle(hourly: hours), fixture.place);
    final original = controller.selectHourlyTimeline(
        persona: 'karen', hours: hours, now: now);
    final later = now.add(const Duration(hours: 1, minutes: 1));
    final nextHours =
        hours.skip(1).map((h) => hour(h.time, celsius: 21.8)).toList();
    controller.publishWeather(
        fixture.bundle(hourly: nextHours, observedAt: later), fixture.place);
    controller.setIntensity(RoastLevel.mild);
    controller.setActivity('walking');
    final refreshed = controller.selectHourlyTimeline(
        persona: 'karen',
        hours: nextHours,
        now: later,
        unit: TemperatureUnit.celsius);
    for (final before in original) {
      final after = refreshed.singleWhere(
          (entry) => entry.targetTime.isAtSameMomentAs(before.targetTime));
      expect(after.selection.id, before.selection.id);
      expect(after.selection.selectionId, before.selection.selectionId);
      expect(after.selection.renderedText, contains('22°C'));
    }
    final reopened = controller.selectHourlyTimeline(
        persona: 'karen',
        hours: nextHours,
        now: later,
        unit: TemperatureUnit.celsius);
    expect(reopened.map((e) => e.selection.selectionId),
        refreshed.map((e) => e.selection.selectionId));
    expect(controller.exposures, isEmpty);
  });

  test('replacing an ineligible target cannot steal a later retained joke', () {
    final hours = List.generate(25, (i) => hour(now.add(Duration(hours: i))));
    final controller = LocalRoastController(
        initialPack:
            fixture.packOf(List.generate(20, (i) => line('reserve_$i'))));
    addTearDown(controller.dispose);
    final first = controller.selectHourlyTimeline(
        persona: 'karen', bundle: fixture.bundle(hourly: hours), now: now);
    final replacedTime = first.first.targetTime;
    final changed = hours
        .map((h) => hour(h.time,
            code: h.time.isAtSameMomentAs(replacedTime) ? 804 : 800))
        .toList();
    final next = controller.selectHourlyTimeline(
        persona: 'karen', bundle: fixture.bundle(hourly: changed), now: now);
    expect(
        next.any((e) => e.targetTime.isAtSameMomentAs(replacedTime)), isFalse);
    for (final before in first.skip(1)) {
      final after = next
          .singleWhere((e) => e.targetTime.isAtSameMomentAs(before.targetTime));
      expect(after.selection.selectionId, before.selection.selectionId);
    }
    expect(next.map((e) => e.selection.id).toSet().length, next.length);
    for (var i = 1; i < next.length; i++) {
      expect(next[i].targetTime.difference(next[i - 1].targetTime),
          greaterThanOrEqualTo(const Duration(hours: 3)));
    }
    for (final entry in next) {
      expect(
          next
              .where((e) =>
                  !e.targetTime.isBefore(entry.targetTime) &&
                  e.targetTime.difference(entry.targetTime) <
                      const Duration(hours: 24))
              .length,
          lessThanOrEqualTo(6));
    }
    final last = next.last;
    final single = controller.selectHourlyTimeline(
        persona: 'karen',
        hours: [last.hour],
        bundle: fixture.bundle(hourly: changed),
        now: now);
    expect(single.single.selection.selectionId, last.selection.selectionId);
  });

  test('missing fields, stale weather, hazards and fallback pools skip cards',
      () {
    final hours = List.generate(
        20,
        (i) => hour(now.add(Duration(hours: i)),
            code: 0, known: false, popKnown: false));
    final controller = LocalRoastController(initialPack: actualPack);
    addTearDown(controller.dispose);
    for (final persona in supportedWeatherRoastPersonas) {
      expect(
          controller.selectHourlyTimeline(
              persona: persona,
              bundle: fixture.bundle(hourly: hours),
              now: now),
          isEmpty);
      final known = hours.map((h) => hour(h.time)).toList();
      for (final source in [
        fixture.bundle(
            hourly: known, observedAt: now.subtract(const Duration(hours: 4))),
        fixture.bundle(hourly: known, code: 781),
        fixture.bundle(hourly: known, alerts: const [
          WeatherAlert(
              senderName: 'NWS', event: 'Warning', description: 'Official')
        ]),
      ]) {
        expect(
            controller.selectHourlyTimeline(
                persona: persona, bundle: source, now: now),
            isEmpty);
      }
    }
    final context = WeatherRoastContext.fromWeatherBundle(
        fixture.bundle(hourly: hours),
        now: now,
        scope: RoastScope.hourly,
        targetTime: hours[2].time,
        targetEnd: hours[2].time.add(const Duration(hours: 1)));
    expect(context.precipChance, isNull);
    expect(context.windMph, isNull);
    expect(context.humidity, isNull);
    expect(context.feelsLikeF, isNull);
  });

  test(
      'trends require known adjacent hour values and rain chance stays uncertain',
      () {
    final target = now.add(const Duration(hours: 4));
    WeatherRoastContext context(List<HourlyForecast> hours) =>
        WeatherRoastContext.fromWeatherBundle(fixture.bundle(hourly: hours),
            now: now,
            scope: RoastScope.hourly,
            targetTime: target,
            targetEnd: target.add(const Duration(hours: 1)));
    final warming = context([
      hour(target.subtract(const Duration(hours: 1)), celsius: 18),
      hour(target, celsius: 21, pop: 70)
    ]);
    expect(warming.facts, contains('forecast_warming'));
    expect(warming.facts, isNot(contains('forecast_rain_condition')));
    expect(warming.facts, isNot(contains('observed_rain')));
    for (final code in [601, 611, 511, 0]) {
      expect(context([hour(target, code: code, pop: 80)]).facts,
          isNot(contains('forecast_rain_probability')));
    }
    for (final before in [
      hour(target.subtract(const Duration(hours: 2)), celsius: 18),
      hour(target.subtract(const Duration(hours: 1)), known: false)
    ]) {
      expect(context([before, hour(target, celsius: 21)]).facts,
          isNot(contains('forecast_warming')));
    }
    expect(
        context([
          hour(target.subtract(const Duration(hours: 1)), celsius: 25),
          hour(target, celsius: 21)
        ]).facts,
        contains('forecast_cooling'));
  });

  test(
      'catalog serves all personas with exact expression metadata and no duplicates',
      () {
    final hours = List.generate(49, (i) => hour(now.add(Duration(hours: i))));
    final controller = LocalRoastController(initialPack: actualPack);
    addTearDown(controller.dispose);
    for (final persona in supportedWeatherRoastPersonas) {
      final entries = controller.selectHourlyTimeline(
          persona: persona, bundle: fixture.bundle(hourly: hours), now: now);
      expect(entries.length, greaterThanOrEqualTo(6));
      expect(entries.first.targetTime.difference(now),
          lessThanOrEqualTo(const Duration(hours: 3)));
      expect(entries.map((e) => e.selection.id).toSet().length, entries.length);
      for (final entry in entries) {
        expect(entry.selection.persona, persona);
        expect(entry.selection.renderedText.length, lessThanOrEqualTo(140));
        expect(PersonaEmotionAssets.path(persona, entry.selection.mood),
            startsWith('assets/personas/$persona/'));
        expect(
            controller.isSelectionEligible(entry.selection,
                bundle: fixture.bundle(hourly: hours), now: now),
            isTrue);
      }
    }
  });
}
