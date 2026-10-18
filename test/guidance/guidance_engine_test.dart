import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:grumpy_skies/features/guidance/domain/guidance.dart';
import 'package:grumpy_skies/models/weather_models.dart';
import 'package:grumpy_skies/preview/approved_fixture.dart';

final now = DateTime.utc(2026, 10, 19, 8);
const location = GuidanceLocation(
    key: 'fixture:UTC', label: 'Fixture point', timezone: 'UTC');
const engine = GuidanceEngine();

Map<String, dynamic> jsonFile(String name) =>
    (jsonDecode(File('assets/guidance/$name').readAsStringSync()) as Map)
        .cast<String, dynamic>();
GuidanceCatalog catalog() => GuidanceCatalog.fromJson(
    jsonFile('wingman_tips.en-US.json'),
    jsonFile('wingman_tip_family_contracts.json'));

EvidenceField<Object> fact(
        GuidanceField key, Object? value, GuidanceInterval interval,
        {EvidenceKind kind = EvidenceKind.forecast,
        DateTime? sourceTime,
        String? unit,
        GuidanceLocation at = location}) =>
    EvidenceField<Object>(
        field: key,
        value: value,
        unit: unit ??
            switch (key) {
              GuidanceField.temperatureC ||
              GuidanceField.lowTemperatureC ||
              GuidanceField.feelsLikeC ||
              GuidanceField.dewPointC =>
                '°C',
              GuidanceField.windKph || GuidanceField.gustKph => 'km/h',
              GuidanceField.precipitationProbability => 'fraction',
              GuidanceField.humidityPercent => '%',
              GuidanceField.visibilityMeters => 'm',
              GuidanceField.uvIndex => 'UV Index',
              GuidanceField.aqi => 'us_epa',
              GuidanceField.sunset => 'UTC instant',
              _ => 'fixture named scheme',
            },
        provider: 'fixture source',
        kind: kind,
        location: at,
        interval: interval,
        sourceTime: sourceTime ?? now,
        fetchedAt: now);

WeatherEvidencePeriod hour(DateTime start,
    {double temp = 20,
    double probability = 0,
    PrecipitationType type = PrecipitationType.none,
    double gust = 10,
    double wind = 8,
    bool danger = false,
    bool daylight = true,
    int code = 800,
    double humidity = 50,
    double? aqi,
    double? uv,
    DateTime? sunset,
    DateTime? sourceTime,
    String? aqiUnit}) {
  final interval = GuidanceInterval(start, start.add(const Duration(hours: 1)));
  return WeatherEvidencePeriod(interval: interval, fields: [
    fact(GuidanceField.temperatureC, temp, interval, sourceTime: sourceTime),
    fact(GuidanceField.precipitationProbability, probability, interval,
        sourceTime: sourceTime),
    fact(GuidanceField.precipitationType, type, interval,
        sourceTime: sourceTime),
    fact(GuidanceField.gustKph, gust, interval, sourceTime: sourceTime),
    fact(GuidanceField.windKph, wind, interval, sourceTime: sourceTime),
    fact(GuidanceField.humidityPercent, humidity, interval,
        sourceTime: sourceTime),
    fact(GuidanceField.severeHazard, danger, interval, sourceTime: sourceTime),
    fact(GuidanceField.daylight, daylight, interval, sourceTime: sourceTime),
    fact(GuidanceField.conditionCode, code, interval, sourceTime: sourceTime),
    if (aqi != null)
      fact(GuidanceField.aqi, aqi, interval,
          sourceTime: sourceTime, unit: aqiUnit),
    if (uv != null)
      fact(GuidanceField.uvIndex, uv, interval, sourceTime: sourceTime),
    if (sunset != null)
      fact(GuidanceField.sunset, sunset, interval, sourceTime: sourceTime),
  ]);
}

WeatherEvidencePeriod observed(
    {bool raining = false, double rainLastHour = 0, DateTime? sourceTime}) {
  final interval = GuidanceInterval(now, now.add(const Duration(minutes: 30)));
  return WeatherEvidencePeriod(interval: interval, fields: [
    fact(GuidanceField.temperatureC, 20, interval,
        kind: EvidenceKind.observation, sourceTime: sourceTime),
    fact(
        GuidanceField.precipitationType,
        raining ? PrecipitationType.liquidRain : PrecipitationType.none,
        interval,
        kind: EvidenceKind.observation,
        sourceTime: sourceTime),
    fact(GuidanceField.rainIntensity,
        raining ? RainIntensity.light : RainIntensity.unknown, interval,
        kind: EvidenceKind.observation, sourceTime: sourceTime),
    fact(GuidanceField.rainMillimeters, rainLastHour, interval,
        kind: EvidenceKind.observation, sourceTime: sourceTime),
  ]);
}

({WeatherEvidence weather, GuidanceContext context}) fixture(String id) {
  var activity = id.startsWith('dog_')
      ? GuidanceActivity.dogWalking
      : id.startsWith('bike_')
          ? GuidanceActivity.cycling
          : id.startsWith('commute_')
              ? GuidanceActivity.drivingCommute
              : id.startsWith('event_')
                  ? GuidanceActivity.outdoorEvent
                  : const {'wet_walk', 'fog_outing', 'snow_outing'}.contains(id)
                      ? GuidanceActivity.walking
                      : GuidanceActivity.outdoor;
  var start = now;
  if (id.endsWith('after_dark') || id == 'event_cool_evening') {
    start = DateTime.utc(2026, 10, 19, 19);
  }
  final target =
      GuidanceInterval(start, start.add(const Duration(minutes: 30)));
  var hours = List.generate(16, (i) => hour(now.add(Duration(hours: i))));
  WeatherEvidencePeriod? current;
  final rain = id.contains('rain') &&
      !id.contains('lower_') &&
      !const {'rain_current', 'rain_later', 'rain_evening', 'rain_ending_trend'}
          .contains(id);
  if (rain) {
    hours = [
      hour(start,
          probability: id == 'rain_possible_outing' ? .4 : .8,
          type: PrecipitationType.liquidRain)
    ];
  }
  if (id == 'rain_current' || id == 'wet_walk' || id == 'rain_ending_trend') {
    current = observed(raining: true);
  }
  if (id.contains('lower_rain_window') || id == 'rain_ending_trend') {
    hours = [
      hour(now, probability: .8, type: PrecipitationType.liquidRain),
      hour(now.add(const Duration(hours: 1)),
          probability: .1, type: PrecipitationType.liquidRain)
    ];
  }
  if (id == 'rain_later' || id == 'rain_evening') {
    final change = id == 'rain_later'
        ? now.add(const Duration(hours: 2))
        : DateTime.utc(2026, 10, 19, 19);
    hours = [
      hour(now),
      hour(change, probability: .8, type: PrecipitationType.liquidRain)
    ];
  }
  if (id.contains('heat') || id == 'hot_day') hours = [hour(start, temp: 30)];
  if (id.contains('cold') || id == 'event_cool_evening') {
    hours = [hour(start, temp: 5)];
  }
  if (id.endsWith('_wind') || id == 'gusty_day') {
    hours = [hour(start, gust: 40)];
  }
  if (id.contains('snow')) {
    hours = [hour(start, type: PrecipitationType.snow, code: 601)];
  }
  if (id.contains('freezing_precip')) {
    hours = [
      hour(start, type: PrecipitationType.freezing, code: 511, danger: true)
    ];
  }
  if (id.contains('fog')) hours = [hour(start, code: 741)];
  if (id.endsWith('after_dark')) {
    hours = [
      hour(start, daylight: false, sunset: DateTime.utc(2026, 10, 19, 18))
    ];
  }
  if (id == 'humid_day') hours = [hour(start, temp: 30, humidity: 80)];
  if (id == 'uv_elevated') hours = [hour(start, uv: 6)];
  if (id == 'aqi_elevated') hours = [hour(start, aqi: 120)];
  if (id == 'cool_morning_warm_afternoon' || id == 'warm_day_cool_evening') {
    hours = List.generate(18, (i) {
      final at = DateTime.utc(2026, 10, 19, 6 + i);
      return hour(at,
          temp: at.hour < 12
              ? 10
              : at.hour < 18
                  ? 30
                  : 12);
    });
  }
  if (id == 'forecast_unavailable') hours = [];
  final selected = id.startsWith('commute_') ||
      id.startsWith('event_') ||
      id.endsWith('after_dark') ||
      (id.startsWith('dog_') || id.startsWith('bike_')) &&
          !id.contains('lower_rain_window');
  return (
    weather:
        WeatherEvidence(location: location, current: current, hourly: hours),
    context: GuidanceContext(
        surface: id.startsWith('event_')
            ? GuidanceSurface.eventDetail
            : GuidanceSurface.todaySummary,
        location: location,
        activity: activity,
        window: selected ? target : null,
        knownActivity: selected,
        allowRefresh: id == 'forecast_unavailable')
  );
}

List<GuidanceCandidate> evaluate(WeatherEvidence weather,
        {GuidanceContext? context, DateTime? clock}) =>
    engine.evaluate(
        weather: weather,
        context: context ??
            const GuidanceContext(
                surface: GuidanceSurface.todaySummary, location: location),
        now: clock ?? now,
        catalog: catalog());

void main() {
  final pack = catalog();
  test(
      'all 240 reviewed variants are eligible only with their complete evidence contracts',
      () {
    expect(pack.templates.length, 240);
    expect(pack.families.length, 40);
    for (final family in pack.families) {
      final scenario = fixture(family.id);
      final selected = engine.evaluate(
          weather: scenario.weather,
          context: scenario.context,
          now: now,
          catalog: pack);
      final ids = selected.map((c) => c.templateId).toSet();
      for (final template
          in pack.templates.where((t) => t.familyId == family.id)) {
        expect(ids, contains(template.id),
            reason: 'positive evidence fixture ${template.id}');
        // Removing all weather cannot leave any of this variant's weather claims eligible.
        final missing = engine.evaluate(
            weather: WeatherEvidence(location: location),
            context: GuidanceContext(
                surface: scenario.context.surface,
                location: location,
                activity: scenario.context.activity,
                knownActivity: scenario.context.knownActivity,
                window: scenario.context.window),
            now: now,
            catalog: pack);
        expect(missing.any((c) => c.templateId == template.id), isFalse,
            reason: 'missing evidence ${template.id}');
      }
    }
  });
  test(
      'every narrower variant guard fails closed when its extra context is removed',
      () {
    for (final template
        in pack.templates.where((t) => t.requiredGuards.isNotEmpty)) {
      final scenario = fixture(template.familyId);
      final context = GuidanceContext(
          surface: template.requiredGuards.contains('current_forecast_context')
              ? GuidanceSurface.hourlyDetail
              : scenario.context.surface,
          location: location,
          activity: template.requiredGuards.contains('walking_activity_context')
              ? GuidanceActivity.outdoor
              : scenario.context.activity,
          window: scenario.context.window,
          knownActivity: false,
          allowRefresh: scenario.context.allowRefresh);
      expect(
          engine
              .evaluate(
                  weather: scenario.weather,
                  context: context,
                  now: now,
                  catalog: pack)
              .any((c) => c.templateId == template.id),
          isFalse,
          reason: template.id);
    }
  });
  test('probability units and liquid/snow/freezing discrimination are explicit',
      () {
    expect(normalizeProbability(30, percent: true), .3);
    expect(normalizeProbability(.3, percent: false), .3);
    expect(normalizeProbability(30, percent: false), isNull);
    expect(normalizeProbability(-1, percent: true), isNull);
    expect(normalizeProbability(double.nan, percent: false), isNull);
    expect(normalizeProbability(null, percent: true), isNull);
    for (final value in [.29, .30, .59, .60, 1.0]) {
      final list = evaluate(WeatherEvidence(location: location, hourly: [
        hour(now, probability: value, type: PrecipitationType.liquidRain)
      ]));
      expect(list.any((c) => c.familyId == 'rain_possible_outing'),
          value >= .30 && value < .60);
      expect(list.any((c) => c.familyId == 'rain_likely_outing'), value >= .60);
    }
    for (final type in [
      PrecipitationType.snow,
      PrecipitationType.freezing,
      PrecipitationType.mixed,
      PrecipitationType.unknown
    ]) {
      final list = evaluate(WeatherEvidence(
          location: location,
          hourly: [hour(now, probability: .9, type: type)]));
      expect(list.any((c) => c.familyId == 'rain_likely_outing'), isFalse);
    }
  });
  test(
      'fresh observed rain overrides low hourly probability but last-hour amount does not prove now',
      () {
    final weather = WeatherEvidence(
        location: location,
        current: observed(raining: true),
        hourly: [hour(now, probability: 0)]);
    expect(evaluate(weather).first.familyId, 'rain_current');
    final accumulation = WeatherEvidence(
        location: location,
        current: observed(rainLastHour: 2),
        hourly: [hour(now, probability: 0)]);
    expect(evaluate(accumulation).any((c) => c.familyId == 'rain_current'),
        isFalse);
    final stale = WeatherEvidence(
        location: location,
        current: observed(
            raining: true,
            sourceTime: now.subtract(const Duration(minutes: 31))),
        hourly: [hour(now, probability: 0)]);
    expect(evaluate(stale).any((c) => c.familyId == 'rain_current'), isFalse);
  });
  test('preference alone selects only conditional activity variants', () {
    final scenario = fixture('dog_heat');
    const context = GuidanceContext(
        surface: GuidanceSurface.todaySummary,
        location: location,
        activity: GuidanceActivity.dogWalking);
    final tips = evaluate(scenario.weather, context: context)
        .where((c) => c.familyId == 'dog_heat');
    expect(tips, isNotEmpty);
    for (final tip in tips) {
      expect(
          pack.templates
              .singleWhere((t) => t.id == tip.templateId)
              .requiredGuards,
          isNot(contains('known_or_user_selected_activity_window')));
    }
    expect(evaluate(scenario.weather).any((c) => c.familyId.startsWith('dog_')),
        isFalse);
  });
  test(
      'routine commute needs an explicit applicable interval and does not imply traffic',
      () {
    final scenario = fixture('commute_rain');
    expect(
        evaluate(scenario.weather,
                context: const GuidanceContext(
                    surface: GuidanceSurface.todaySummary,
                    location: location,
                    activity: GuidanceActivity.drivingCommute))
            .any((c) => c.familyId.startsWith('commute')),
        isFalse);
    final tips = evaluate(scenario.weather,
        context: GuidanceContext(
            surface: GuidanceSurface.todaySummary,
            location: location,
            activity: GuidanceActivity.drivingCommute,
            userSelectedWindow: true,
            window:
                GuidanceInterval(now, now.add(const Duration(minutes: 30)))));
    expect(tips.any((c) => c.familyId == 'commute_rain'), isTrue);
    expect(
        tips.any((c) => RegExp(r'\b(traffic|ETA|delay of|road closure)\b',
                caseSensitive: false)
            .hasMatch(c.text)),
        isFalse);
  });
  test(
      'windows require every interval, meaningful improvement, and reject known hazards',
      () {
    final base = hour(now, probability: .8, type: PrecipitationType.liquidRain);
    final later = hour(now.add(const Duration(hours: 1)),
        probability: .1, type: PrecipitationType.liquidRain);
    final normal =
        evaluate(WeatherEvidence(location: location, hourly: [base, later]));
    final tip = normal.firstWhere((c) => c.familyId == 'lower_rain_window');
    expect(tip.comparisonWindow!.start, later.interval.start);
    expect(
        tip.supportedFacts
            .where((f) => f.field == GuidanceField.precipitationProbability)
            .every((f) =>
                f.interval.end.difference(f.interval.start) ==
                const Duration(hours: 1)),
        isTrue);
    const context = GuidanceContext(
        surface: GuidanceSurface.todaySummary,
        location: location,
        outingDuration: Duration(minutes: 90));
    expect(
        evaluate(
                WeatherEvidence(location: location, hourly: [
                  base,
                  hour(now.add(const Duration(hours: 2)),
                      probability: .1, type: PrecipitationType.liquidRain)
                ]),
                context: context)
            .any((c) => c.comparisonWindow != null),
        isFalse);
    for (final hazard in [
      hour(later.interval.start, probability: .05, danger: true),
      hour(later.interval.start,
          probability: .05, type: PrecipitationType.freezing),
      hour(later.interval.start, probability: .05, temp: 42),
      hour(later.interval.start, probability: .05, gust: 75),
      hour(later.interval.start, probability: .05, aqi: 250)
    ]) {
      expect(
          evaluate(WeatherEvidence(location: location, hourly: [base, hazard]))
              .any((c) => c.familyId == 'lower_rain_window'),
          isFalse);
    }
    expect(
        evaluate(WeatherEvidence(location: location, hourly: [
          base,
          hour(later.interval.start,
              probability: .65, type: PrecipitationType.liquidRain)
        ])).any((c) => c.familyId == 'lower_rain_window'),
        isFalse);
  });
  test('daily-only data cannot produce precise windows or current UV', () {
    final interval = GuidanceInterval(
        DateTime.utc(2026, 10, 19), DateTime.utc(2026, 10, 20));
    final day = WeatherEvidencePeriod(interval: interval, daily: true, fields: [
      fact(GuidanceField.temperatureC, 30, interval),
      fact(GuidanceField.uvIndex, 8, interval)
    ]);
    final list = evaluate(WeatherEvidence(location: location, daily: [day]),
        context: GuidanceContext(
            surface: GuidanceSurface.dayDetail,
            location: location,
            window: interval,
            allDay: true));
    expect(list.any((c) => c.familyId == 'hot_day'), isTrue);
    expect(
        list.any(
            (c) => c.comparisonWindow != null || c.familyId == 'uv_elevated'),
        isFalse);
  });
  test('UV AQI weather expiry and named index thresholds never renew on fetch',
      () {
    expect(
        evaluate(WeatherEvidence(
            location: location,
            hourly: [hour(now, aqi: 120, uv: 6)])).map((c) => c.familyId),
        containsAll(['aqi_elevated', 'uv_elevated']));
    final stale = evaluate(WeatherEvidence(location: location, hourly: [
      hour(now,
          aqi: 120, uv: 6, sourceTime: now.subtract(const Duration(hours: 2)))
    ]));
    expect(
        stale.any(
            (c) => c.familyId == 'aqi_elevated' || c.familyId == 'uv_elevated'),
        isFalse);
    for (final pair in [
      ('openweather_1_5', 2.0, false),
      ('openweather_1_5', 3.0, true),
      ('us_epa', 100.0, false),
      ('us_epa', 101.0, true),
      ('unknown', 150.0, false)
    ]) {
      expect(
          evaluate(WeatherEvidence(
                  location: location,
                  hourly: [hour(now, aqi: pair.$2, aqiUnit: pair.$1)]))
              .any((c) => c.familyId == 'aqi_elevated'),
          pair.$3);
    }
    expect(
        evaluate(WeatherEvidence(location: location, hourly: [
          hour(now,
              temp: 30, sourceTime: now.subtract(const Duration(hours: 7)))
        ])),
        isEmpty);
    expect(
        evaluate(
            WeatherEvidence(location: location, hourly: [hour(now, temp: 30)]),
            clock: now.add(const Duration(hours: 1))),
        isEmpty);
  });
  test('official alert has fixed priority and preserved authoritative detail',
      () {
    final alert = GuidanceAlert(
        id: 'warning',
        event: 'Wind Warning',
        issuer: 'Fixture authority',
        description: 'Authoritative description',
        instructions: 'Follow official instruction',
        area: 'Fixture county',
        severity: 'Severe',
        location: location,
        interval: GuidanceInterval(now, now.add(const Duration(hours: 2))),
        checkedAt: now);
    final tips = evaluate(WeatherEvidence(
        location: location, hourly: [hour(now, temp: 30)], alerts: [alert]));
    expect(tips.single.serious, isTrue);
    expect(tips.single.priority, 1000);
    expect(tips.single.alert, same(alert));
    final expired = GuidanceAlert(
        id: 'old',
        event: 'Old Warning',
        issuer: 'Fixture',
        description: 'Old',
        location: location,
        interval: GuidanceInterval(now.subtract(const Duration(hours: 2)), now),
        checkedAt: now);
    expect(
        evaluate(WeatherEvidence(
            location: location,
            hourly: [hour(now, temp: 30)],
            alerts: [expired])).any((c) => c.familyId == 'official_alert'),
        isFalse);
    final remote = GuidanceAlert(
        id: 'remote',
        event: 'Remote Warning',
        issuer: 'Fixture',
        description: 'Remote',
        location: const GuidanceLocation(key: 'remote', label: 'Remote'),
        interval: GuidanceInterval(now, now.add(const Duration(hours: 1))),
        checkedAt: now);
    expect(
        evaluate(WeatherEvidence(
            location: location,
            hourly: [hour(now, temp: 30)],
            alerts: [remote])).any((c) => c.familyId == 'official_alert'),
        isFalse);
  });
  test('official declared severity and warning designation outrank stable IDs',
      () {
    GuidanceAlert alert(String id, String title, String severity) =>
        GuidanceAlert(
            id: id,
            event: title,
            issuer: 'Fixture authority',
            description: title,
            severity: severity,
            location: location,
            interval: GuidanceInterval(now, now.add(const Duration(hours: 1))),
            checkedAt: now);
    final watch = alert('a-watch', 'Severe Thunderstorm Watch', 'Severe');
    final warning = alert('z-warning', 'Severe Thunderstorm Warning', 'Severe');
    final advisory = alert('first', 'Wind Advisory', 'Minor');
    final tips = evaluate(WeatherEvidence(
        location: location,
        hourly: [hour(now, temp: 30)],
        alerts: [advisory, watch, warning]));
    expect(tips.single.alert, same(warning));
    final extreme = alert('z-extreme', 'Extreme Official Hazard', 'Extreme');
    expect(
        evaluate(WeatherEvidence(
            location: location,
            hourly: [hour(now, temp: 30)],
            alerts: [warning, extreme])).single.alert,
        same(extreme));
  });
  test(
      'location mismatch, stale assumption, and source unit mismatch fail closed',
      () {
    expect(
        evaluate(WeatherEvidence(
            location: location,
            locationMatched: false,
            hourly: [hour(now, temp: 30)])),
        isEmpty);
    final expired =
        GuidanceLocation(key: location.key, label: 'Old area', validUntil: now);
    expect(
        evaluate(
            WeatherEvidence(location: expired, hourly: [hour(now, temp: 30)]),
            context: GuidanceContext(
                surface: GuidanceSurface.todaySummary, location: expired)),
        isEmpty);
    final interval = GuidanceInterval(now, now.add(const Duration(hours: 1)));
    final wrong = WeatherEvidencePeriod(
        interval: interval,
        fields: [fact(GuidanceField.temperatureC, 86, interval, unit: '°F')]);
    expect(evaluate(WeatherEvidence(location: location, hourly: [wrong])),
        isEmpty);
    expect(celsiusFromFahrenheit(86), 30);
    expect(kilometersPerHourFromMph(10), closeTo(16.09344, .000001));
  });
  test('night icon alone and pre-dawn cannot become after-sunset activity copy',
      () {
    final context = GuidanceContext(
        surface: GuidanceSurface.hourlyDetail,
        location: location,
        activity: GuidanceActivity.cycling,
        knownActivity: true,
        window: GuidanceInterval(now, now.add(const Duration(minutes: 30))));
    expect(
        evaluate(
                WeatherEvidence(
                    location: location, hourly: [hour(now, daylight: false)]),
                context: context)
            .any((c) => c.familyId == 'bike_after_dark'),
        isFalse);
    expect(
        evaluate(
                WeatherEvidence(location: location, hourly: [
                  hour(now,
                      daylight: false,
                      sunset: now.add(const Duration(hours: 10)))
                ]),
                context: context)
            .any((c) => c.familyId == 'bike_after_dark'),
        isFalse);
  });
  test('NWS coarse aliases do not turn freezing rain or sleet into liquid rain',
      () {
    for (final condition in ['Freezing Rain', 'Sleet', 'Rain And Snow']) {
      final base = ApprovedFixture.weather;
      final weather = WeatherBundle(
          current: base.current,
          forecastSource: 'nws_api',
          hourly: [
            HourlyForecast(
                time: base.hourly.first.time,
                temperatureC: 1,
                condition: condition,
                weatherId: condition == 'Sleet' ? 600 : 500,
                precipitationChance: 80)
          ],
          daily: const [],
          location: base.location);
      final location = GuidanceLocation(
          key: 'nws', label: 'Fixture', timezone: base.current.timezone);
      final period =
          GuidanceWeatherAdapter.fromBundle(weather, location: location)
              .hourly
              .single;
      expect(
          period.field(GuidanceField.precipitationType)!.value,
          condition == 'Rain And Snow'
              ? PrecipitationType.mixed
              : PrecipitationType.freezing);
      expect(period.field(GuidanceField.rainIntensity)!.available, isFalse);
    }
  });
  test('daily evidence cannot be relabeled as a timed event interval', () {
    final interval = GuidanceInterval(
        DateTime.utc(2026, 10, 19), DateTime.utc(2026, 10, 20));
    final period =
        WeatherEvidencePeriod(interval: interval, daily: true, fields: [
      fact(GuidanceField.precipitationType, PrecipitationType.liquidRain,
          interval),
      fact(GuidanceField.precipitationProbability, .8, interval)
    ]);
    final context = GuidanceContext(
        surface: GuidanceSurface.eventDetail,
        location: location,
        activity: GuidanceActivity.outdoorEvent,
        knownActivity: true,
        allDay: true,
        window: GuidanceInterval(now, now.add(const Duration(hours: 1))));
    expect(
        evaluate(WeatherEvidence(location: location, daily: [period]),
            context: context),
        isEmpty);
  });
  test(
      'comparable lower rain windows also consider supported heat gusts and daylight',
      () {
    final weather = WeatherEvidence(location: location, hourly: [
      hour(now, probability: .8, type: PrecipitationType.liquidRain),
      hour(now.add(const Duration(hours: 1)),
          probability: .1,
          type: PrecipitationType.liquidRain,
          temp: 39,
          gust: 55,
          daylight: false),
      hour(now.add(const Duration(hours: 2)),
          probability: .2,
          type: PrecipitationType.liquidRain,
          temp: 20,
          gust: 10),
    ]);
    const context = GuidanceContext(
        surface: GuidanceSurface.todaySummary,
        location: location,
        activity: GuidanceActivity.dogWalking);
    final candidate = evaluate(weather, context: context)
        .firstWhere((c) => c.familyId == 'dog_lower_rain_window');
    expect(
        candidate.comparisonWindow!.start, now.add(const Duration(hours: 2)));
    expect(
        candidate.supportedFacts
            .any((f) => f.field == GuidanceField.temperatureC),
        isTrue);
  });
  test(
      'specific activity preparation ranks above generic preparation and generic keeps outdoor scope',
      () {
    final scenario = fixture('dog_heat');
    final tips = evaluate(scenario.weather, context: scenario.context);
    expect(tips.first.familyId, 'dog_heat');
    expect(tips.first.activity, GuidanceActivity.dogWalking);
    expect(tips.firstWhere((c) => c.familyId == 'hot_day').activity,
        GuidanceActivity.outdoor);
  });
  test('liquid type and probability must describe the same interval and source',
      () {
    final weather = WeatherEvidence(location: location, hourly: [
      hour(now, probability: .1, type: PrecipitationType.liquidRain),
      hour(now.add(const Duration(hours: 1)),
          probability: .9, type: PrecipitationType.snow)
    ]);
    final context = GuidanceContext(
        surface: GuidanceSurface.eventDetail,
        location: location,
        activity: GuidanceActivity.outdoorEvent,
        knownActivity: true,
        window: GuidanceInterval(now, now.add(const Duration(hours: 2))));
    expect(
        evaluate(weather, context: context)
            .any((c) => c.familyId == 'event_rain'),
        isFalse);
    final right = WeatherEvidence(location: location, hourly: [
      hour(now, probability: .8, type: PrecipitationType.liquidRain),
      hour(now.add(const Duration(hours: 1)),
          probability: .9, type: PrecipitationType.snow)
    ]);
    expect(
        evaluate(right, context: context)
            .any((c) => c.familyId == 'event_rain'),
        isTrue);
  });
  test('warm humidity requires co-occurring fields instead of unrelated hours',
      () {
    final weather = WeatherEvidence(location: location, hourly: [
      hour(now, temp: 30, humidity: 40),
      hour(now.add(const Duration(hours: 1)), temp: 10, humidity: 90)
    ]);
    final context = GuidanceContext(
        surface: GuidanceSurface.todaySummary,
        location: location,
        window: GuidanceInterval(now, now.add(const Duration(hours: 2))));
    expect(
        evaluate(weather, context: context)
            .any((c) => c.familyId == 'humid_day'),
        isFalse);
  });
  test(
      'positive probability with unknown liquid type cannot recommend lower rain',
      () {
    final weather = WeatherEvidence(location: location, hourly: [
      hour(now, probability: .8, type: PrecipitationType.liquidRain),
      hour(now.add(const Duration(hours: 1)),
          probability: .1, type: PrecipitationType.none)
    ]);
    expect(evaluate(weather).any((c) => c.comparisonWindow != null), isFalse);
  });
  test(
      'legacy cached defaults and unknown observation time cannot create advice facts',
      () {
    final raw = ApprovedFixture.weather.toJson();
    final current = (raw['current'] as Map).cast<String, dynamic>();
    current.remove('temperatureKnown');
    current['temperatureC'] = 0;
    raw['current'] = current;
    final legacy = WeatherBundle.fromJson(raw);
    expect(legacy.guidanceAvailabilityVerified, isFalse);
    expect(WeatherBundle.fromJson(legacy.toJson()).guidanceAvailabilityVerified,
        isFalse);
    final at = GuidanceLocation(
        key: 'legacy', label: 'Fixture', timezone: legacy.current.timezone);
    final evidence = GuidanceWeatherAdapter.fromBundle(legacy, location: at);
    expect(evidence.current!.fields.any((f) => f.available), isFalse);
    expect(evidence.hourly.expand((p) => p.fields).any((f) => f.available),
        isFalse);
    final noTime = ApprovedFixture.weather.toJson();
    (noTime['current'] as Map)['sourceUpdatedAt'] = null;
    (noTime['current'] as Map)['lastUpdated'] =
        ApprovedFixture.now.toIso8601String();
    (noTime['current'] as Map)['fetchedAt'] =
        ApprovedFixture.now.toIso8601String();
    final data = GuidanceWeatherAdapter.fromBundle(
        WeatherBundle.fromJson(noTime),
        location: at);
    expect(data.hourly.first.fields.every((f) => f.sourceTime == null), isTrue);
    expect(
        engine.evaluate(
            weather: data,
            context: GuidanceContext(
                surface: GuidanceSurface.todaySummary, location: at),
            now: ApprovedFixture.now,
            catalog: pack),
        isEmpty);
    expect(
        WeatherBundle.fromSnapshot(ApprovedFixture.snapshot)
            .guidanceAvailabilityVerified,
        isFalse);
  });
  test('requested location metadata cannot mask a mismatched provider point',
      () {
    final raw = ApprovedFixture.weather.toJson();
    (raw['current'] as Map)['latitude'] = 51.5;
    (raw['current'] as Map)['longitude'] = -.12;
    final weather = WeatherBundle.fromJson(raw);
    final requested = GuidanceLocation(
        key: 'requested',
        label: 'Requested point',
        latitude: ApprovedFixture.location.lat,
        longitude: ApprovedFixture.location.lon);
    final data =
        GuidanceWeatherAdapter.fromBundle(weather, location: requested);
    expect(data.locationMatched, isFalse);
    expect(
        engine.evaluate(
            weather: data,
            context: GuidanceContext(
                surface: GuidanceSurface.todaySummary, location: requested),
            now: ApprovedFixture.now,
            catalog: pack),
        isEmpty);
  });
  test(
      'current observations cannot become forecast-worded snow warmth or gust claims',
      () {
    final interval =
        GuidanceInterval(now, now.add(const Duration(minutes: 30)));
    for (final type in [PrecipitationType.snow, PrecipitationType.freezing]) {
      final current = WeatherEvidencePeriod(interval: interval, fields: [
        fact(GuidanceField.precipitationType, type, interval,
            kind: EvidenceKind.observation),
        fact(GuidanceField.temperatureC, 30, interval,
            kind: EvidenceKind.observation),
        fact(GuidanceField.gustKph, 40, interval,
            kind: EvidenceKind.observation),
        fact(GuidanceField.conditionCode, 741, interval,
            kind: EvidenceKind.observation)
      ]);
      final tips =
          evaluate(WeatherEvidence(location: location, current: current));
      expect(
          tips.any((c) => const {
                'snow_outing',
                'freezing_precip_outing',
                'hot_day',
                'gusty_day',
                'fog_outing'
              }.contains(c.familyId)),
          isFalse);
      if (type == PrecipitationType.freezing) {
        expect(tips.single.familyId, 'serious_weather');
      }
    }
  });
  test(
      '1000 identical pure evaluations retain IDs fingerprint and original evidence times',
      () {
    final scenario = fixture('rain_likely_outing');
    final first = engine
        .evaluate(
            weather: scenario.weather,
            context: scenario.context,
            now: now,
            catalog: pack)
        .first;
    for (var i = 0; i < 1000; i++) {
      final again = engine
          .evaluate(
              weather: scenario.weather,
              context: scenario.context,
              now: now,
              catalog: pack)
          .first;
      expect(again.templateId, first.templateId);
      expect(again.situationFingerprint, first.situationFingerprint);
      expect(again.supportedFacts.every((f) => f.sourceTime == now), isTrue);
    }
  });
  test(
      'catalog rejects weakened rules, unknown guards, placeholders and malformed locale',
      () {
    void reject(
        void Function(Map<String, dynamic>, Map<String, dynamic>) mutate) {
      final a = jsonFile('wingman_tips.en-US.json'),
          b = jsonFile('wingman_tip_family_contracts.json');
      mutate(a, b);
      expect(() => GuidanceCatalog.fromJson(a, b), throwsFormatException);
    }

    reject((a, b) => a['locale'] = 'fr-FR');
    reject(
        (a, b) => (a['templates'] as List).first['text'] = 'Missing {value}');
    reject((a, b) =>
        (a['templates'] as List).first['requiredGuards'] = ['made_up']);
    reject((a, b) => (b['families'] as List).first['requiredEvidence'] = []);
    reject((a, b) =>
        (b['families'] as List).first['allowedSurfaces'] = ['event_detail']);
    reject((a, b) {
      (a['templates'] as List)
          .firstWhere((t) => t['id'] == 'dog_rain_01')['requiredGuards'] = [];
      b['variantOverrides'] = [];
    });
  });
  test(
      'WeatherBundle adapter preserves source times, units and honest unknown AQI provenance',
      () {
    final fixture = ApprovedFixture.weather;
    final loc = GuidanceLocation(
        key: 'preview',
        label: fixture.current.locationName,
        timezone: fixture.current.timezone,
        latitude: fixture.location?.lat ?? fixture.current.latitude,
        longitude: fixture.location?.lon ?? fixture.current.longitude);
    final data = GuidanceWeatherAdapter.fromBundle(fixture, location: loc);
    expect(data.current!.field(GuidanceField.temperatureC)!.value,
        fixture.current.temperatureC);
    expect(data.current!.field(GuidanceField.temperatureC)!.sourceTime,
        fixture.current.displayUpdatedAt);
    expect(data.current!.field(GuidanceField.aqi)!.availability,
        EvidenceAvailability.unsupported);
    final old = WeatherBundle.fromJson(
        {...fixture.toJson(), 'forecastSource': 'nws_api'});
    final restored = WeatherBundle.fromJson(old.toJson());
    expect(restored.forecastSource, 'nws_api');
    expect(
        GuidanceWeatherAdapter.fromBundle(restored, location: loc)
            .hourly
            .first
            .fields
            .first
            .provider,
        'National Weather Service');
  });
}
