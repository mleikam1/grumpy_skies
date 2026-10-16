import 'dart:async';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:grumpy_skies/features/plancast/calendar_repository.dart';
import 'package:grumpy_skies/features/plancast/event_weather_evaluator.dart';
import 'package:grumpy_skies/features/plancast/forecast_change_detector.dart';
import 'package:grumpy_skies/features/plancast/plancast_briefing.dart';
import 'package:grumpy_skies/features/plancast/plancast_controller.dart';
import 'package:grumpy_skies/features/plancast/plancast_notification_planner.dart';
import 'package:grumpy_skies/features/plancast/platform/plancast_platform.dart';
import 'package:grumpy_skies/features/plancast/venue_weather_repository.dart';
import 'package:grumpy_skies/features/roasts/content/roast_context_adapter.dart';
import 'package:grumpy_skies/features/roasts/content/roast_pack_repository.dart';
import 'package:grumpy_skies/features/roasts/content/weather_roast_models.dart';
import 'package:grumpy_skies/models/temperature_unit.dart';
import 'package:grumpy_skies/models/weather_models.dart';
import 'package:grumpy_skies/repositories/weather_repository.dart';
import 'package:shared_preferences/shared_preferences.dart';

final now = DateTime.utc(2026, 10, 15, 10);
CalendarEvent event(
        {String id = 'one',
        DateTime? start,
        DateTime? end,
        bool allDay = false,
        String location = '',
        bool coordinates = true}) =>
    CalendarEvent(
        id: planCastId(id),
        nativeId: id,
        calendarId: 'work',
        title: 'Private medical appointment',
        startUtc: start ?? now.add(const Duration(hours: 2)),
        endUtc: end ?? now.add(const Duration(hours: 5)),
        timeZone: 'America/Chicago',
        locationText: location,
        latitude: coordinates ? 41 : null,
        longitude: coordinates ? -87 : null,
        isAllDay: allDay,
        allDayStart: allDay ? DateTime.utc(2026, 10, 15) : null,
        allDayEnd: allDay ? DateTime.utc(2026, 10, 17) : null);
WeatherBundle weather(
        {List<int?> rain = const [0, 70, 20],
        DateTime? first,
        bool stale = false,
        bool offline = false,
        bool temperatureKnown = true,
        double currentWindKph = 100,
        List<DailyForecast> daily = const [],
        List<WeatherAlert> alerts = const [],
        bool verifiedAlerts = false,
        String condition = 'Clouds',
        List<TimelineWeatherPoint> timeline = const []}) =>
    WeatherBundle(
        current: CurrentWeather(
            temperatureC: 20,
            condition: 'Clear',
            feelsLikeC: 20,
            windKph: currentWindKph,
            humidity: 40,
            precipitationChance: 0,
            aqi: 1,
            sunrise: now,
            sunset: now.add(const Duration(hours: 12)),
            moonrise: now,
            moonset: now,
            uvIndex: 2,
            timezone: 'America/Chicago',
            lastUpdated: stale ? now.subtract(const Duration(hours: 7)) : now),
        hourly: [
          for (var i = 0; i < rain.length; i++)
            HourlyForecast(
                time: (first ?? now.add(const Duration(hours: 2)))
                    .add(Duration(hours: i)),
                temperatureC: 20 + i.toDouble(),
                temperatureKnown: temperatureKnown,
                condition: condition,
                precipitationChance: rain[i] ?? 0,
                precipitationChanceKnown: rain[i] != null,
                weatherIcon: '04d')
        ],
        daily: daily,
        alerts: alerts,
        alertCoverageVerified: verifiedAlerts,
        timeline: timeline,
        isOfflineCache: offline);
const evaluator = EventWeatherEvaluator();

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => SharedPreferences.setMockInitialValues({}));
  group('normalization and calendar boundaries', () {
    Map<String, dynamic> raw(
            {String id = 'one', String status = 'confirmed', int offset = 0}) =>
        {
          'id': id,
          'nativeEventId': 'provider-$id',
          'calendarId': 'work',
          'title': 'Private medical appointment',
          'startMs':
              now.add(Duration(hours: 2 + offset)).millisecondsSinceEpoch,
          'endMs': now.add(Duration(hours: 5 + offset)).millisecondsSinceEpoch,
          'timeZone': 'America/Chicago',
          'status': status
        };
    test(
        'UTC instants, IANA context, opaque instance identity, native validation id',
        () {
      final first = CalendarEvent.fromMap(raw())!;
      expect(first.startUtc.isUtc, isTrue);
      expect(first.timeZone, 'America/Chicago');
      expect(first.nativeId, 'provider-one');
      expect(first.id, isNot(contains('Private')));
      expect(first.id, isNot(CalendarEvent.fromMap(raw(offset: 1))!.id));
    });
    test('canceled and declined excluded, tentative retained', () {
      expect(CalendarEvent.fromMap(raw(status: 'cancelled')), isNull);
      expect(CalendarEvent.fromMap(raw(status: 'declined')), isNull);
      expect(
          CalendarEvent.fromMap(raw(status: 'tentative'))!.tentative, isTrue);
    });
    test('all-day dates retain floating date and exclusive end', () {
      final e = CalendarEvent.fromMap({
        ...raw(),
        'isAllDay': true,
        'allDayStart': '2026-10-15',
        'allDayEnd': '2026-10-17'
      })!;
      expect(e.allDayStart, DateTime.utc(2026, 10, 15));
      expect(e.allDayEnd, DateTime.utc(2026, 10, 17));
      expect(CalendarEvent.fromMap({...raw(), 'isAllDay': true}), isNull);
    });
    test(
        'same-title overlapping events retained, true duplicate removed, selection enforced',
        () async {
      final p = FakePlatform()
        ..records = [
          raw(),
          raw(),
          raw(id: 'two'),
          {...raw(id: 'third'), 'calendarId': 'other'}
        ];
      final result = await DeviceCalendarRepository(p).events(
          calendarIds: {'work'},
          start: now,
          end: now.add(const Duration(days: 14)));
      expect(result.length, 2);
    });
    test('moved recurring venue invalidates confirmed mapping', () {
      expect(event(location: '123 Old St').recurringKey,
          isNot(event(location: '555 New St').recurringKey));
      expect(event(location: '123 Old St').recurringKey,
          event(location: ' 123  old st ').recurringKey);
    });
    test('fall-back duplicate clock hours keep distinct UTC instants', () {
      final first = roastLocalTime(
          DateTime.utc(2026, 11, 1, 6, 30), 'America/Chicago', null,
          forecast: true)!;
      final second = roastLocalTime(
          DateTime.utc(2026, 11, 1, 7, 30), 'America/Chicago', null,
          forecast: true)!;
      expect(first.hour, 1);
      expect(second.hour, 1);
      expect(first.timeZoneOffset, isNot(second.timeZoneOffset));
    });
  });
  group('deterministic interval evaluation', () {
    test('daily unknown metrics cannot claim low impact', () {
      final result = evaluator.evaluate(
          event: event(
              start: DateTime.utc(2026, 10, 16, 18),
              end: DateTime.utc(2026, 10, 16, 19)),
          weather: weather(daily: [
            DailyForecast(
                date: DateTime.utc(2026, 10, 16),
                minTempC: double.nan,
                maxTempC: double.nan,
                temperatureKnown: false,
                condition: 'Unknown',
                precipitationChanceKnown: false)
          ]),
          now: now);
      expect(result.impact, WeatherImpact.unavailable);
      expect(result.usable, isFalse);
      expect(result.minTemperatureC, isNull);
    });
    test('indoor guidance uses buffers, not rain during activity', () {
      final result = evaluator.evaluate(
          event: event(),
          weather: weather(
              rain: [0, 90, 90, 90, 0],
              first: now.add(const Duration(hours: 1))),
          now: now,
          environment: EventEnvironment.indoor);
      expect(result.peakPrecipitationChance, 90);
      expect(result.impact, WeatherImpact.low);
      expect(result.arrival!.peakPrecipitationChance, 0);
      expect(result.leaving!.peakPrecipitationChance, 0);
    });
    test('whole interval reports peak hourly chance, never sum or average', () {
      final result =
          evaluator.evaluate(event: event(), weather: weather(), now: now);
      expect(result.peakPrecipitationChance, 70);
      expect(result.coverage, ForecastCoverage.hourly);
      expect(result.impact, WeatherImpact.watch);
      expect(result.precipitationLabel, contains('Peak hourly'));
      expect(result.maxWindKph, isNull,
          reason: 'current observation is not an event forecast');
    });
    test('unknown is distinct from true zero; no fabricated zero temperature',
        () {
      final missing = evaluator.evaluate(
          event: event(),
          weather: weather(rain: [null, null, null], temperatureKnown: false),
          now: now);
      final zero = evaluator.evaluate(
          event: event(), weather: weather(rain: [0, 0, 0]), now: now);
      expect(missing.peakPrecipitationChance, isNull);
      expect(missing.minTemperatureC, isNull);
      expect(zero.peakPrecipitationChance, 0);
    });
    test('gap and missing trailing interval remain partial', () {
      final result = evaluator.evaluate(
          event: event(), weather: weather(rain: [20]), now: now);
      expect(result.coverage, ForecastCoverage.partial);
      expect(result.explanation, contains('part'));
    });
    test('stale and offline data are unavailable assessments', () {
      for (final w in [weather(stale: true), weather(offline: true)]) {
        final result = evaluator.evaluate(event: event(), weather: w, now: now);
        expect(result.coverage, ForecastCoverage.stale);
        expect(result.impact, WeatherImpact.unavailable);
      }
    });
    test('online skips location requirement and no fictitious duration', () {
      expect(
          evaluator
              .evaluate(
                  event: event(coordinates: false),
                  weather: null,
                  now: now,
                  hasLocation: false,
                  environment: EventEnvironment.online)
              .coverage,
          ForecastCoverage.online);
      expect(
          evaluator
              .evaluate(
                  event: event(start: now, end: now),
                  weather: weather(),
                  now: now)
              .coverage,
          ForecastCoverage.unavailable);
    });
    test('future daily outlook is clearly daily, beyond horizon too early', () {
      final w = weather(daily: [
        DailyForecast(
            date: DateTime.utc(2026, 10, 16),
            minTempC: 10,
            maxTempC: 20,
            condition: 'Rain',
            precipitationChance: 60)
      ]);
      final day = evaluator.evaluate(
          event: event(
              start: DateTime.utc(2026, 10, 16, 18),
              end: DateTime.utc(2026, 10, 16, 19)),
          weather: w,
          now: now);
      expect(day.coverage, ForecastCoverage.daily);
      expect(day.precipitationLabel, contains('daily'));
      final far = evaluator.evaluate(
          event: event(
              start: DateTime.utc(2026, 10, 25, 18),
              end: DateTime.utc(2026, 10, 25, 19)),
          weather: w,
          now: now);
      expect(far.coverage, ForecastCoverage.tooEarly);
    });
    test('all-day exclusive date does not consume next day rain', () {
      final w = weather(daily: [
        for (var d = 15; d <= 17; d++)
          DailyForecast(
              date: DateTime.utc(2026, 10, d),
              minTempC: 10,
              maxTempC: 20,
              condition: 'Clouds',
              precipitationChance: d == 17 ? 100 : 10)
      ]);
      final result =
          evaluator.evaluate(event: event(allDay: true), weather: w, now: now);
      expect(result.coverage, ForecastCoverage.daily);
      expect(result.peakPrecipitationChance, 10);
    });
    test(
        'official alert requires verified area response and overlapping validity',
        () {
      final a = WeatherAlert(
          senderName: 'NWS',
          event: 'Wind warning',
          start: now,
          end: now.add(const Duration(hours: 6)),
          description: 'Original authority');
      expect(
          evaluator
              .evaluate(event: event(), weather: weather(alerts: [a]), now: now)
              .alerts,
          isEmpty);
      final valid = evaluator.evaluate(
          event: event(),
          weather: weather(alerts: [a], verifiedAlerts: true),
          now: now);
      expect(valid.alerts.single.senderName, 'NWS');
      expect(valid.serious, isTrue);
      final later = WeatherAlert(
          senderName: 'NWS',
          event: 'Wind warning',
          start: now.add(const Duration(hours: 9)),
          end: now.add(const Duration(hours: 10)),
          description: 'Later');
      expect(
          evaluator
              .evaluate(
                  event: event(),
                  weather: weather(alerts: [later], verifiedAlerts: true),
                  now: now)
              .alerts,
          isEmpty);
    });
    test('buffer represents supplied forecast intervals, not travel time', () {
      final result = evaluator.evaluate(
          event: event(),
          weather: weather(
              rain: [80, 10, 10, 10, 0],
              first: now.add(const Duration(hours: 1))),
          now: now,
          bufferMinutes: 30,
          environment: EventEnvironment.indoor);
      expect(result.arrival!.peakPrecipitationChance, 80);
      expect(result.leaving!.peakPrecipitationChance, 0);
      expect(result.explanation, contains('Indoor'));
    });
  });
  group('venue isolation and economy', () {
    test('request budget defers after 12 uncached venue forecasts in an hour',
        () async {
      final source = FakeWeather();
      final repo = VenueWeatherRepository(source, clock: () => now);
      for (var i = 0; i < 12; i++) {
        await repo.get(LocationCandidate(
            name: 'venue',
            country: '',
            lat: i.toDouble(),
            lon: 0,
            source: 'calendar'));
      }
      await expectLater(
          repo.get(const LocationCandidate(
              name: 'venue', country: '', lat: 20, lon: 0, source: 'calendar')),
          throwsA(isA<VenueWeatherDeferred>()));
      expect(source.requests, 12);
    });
    test(
        'same venue requests coalesce and reuse memory cache with coordinates only',
        () async {
      final source = FakeWeather()..gate = Completer<WeatherBundle>();
      final repo = VenueWeatherRepository(source, clock: () => now);
      const place = LocationCandidate(
          name: 'Private appointment address',
          country: '',
          lat: 41,
          lon: -87,
          source: 'user');
      final first = repo.get(place);
      final second = repo.get(place);
      await Future<void>.delayed(Duration.zero);
      expect(source.requests, 1);
      expect(source.lastLocation, isNull);
      source.gate!.complete(weather());
      await Future.wait([first, second]);
      await repo.get(place);
      expect(source.requests, 1);
    });
    test('video links and rooms never reach geocoder', () async {
      final source = FakeWeather();
      final repo = VenueWeatherRepository(source);
      for (final text in [
        'https://meet.google.com/private',
        'Room 42',
        'TBD',
        'online'
      ]) {
        expect(await repo.search(text), isEmpty);
      }
      expect(source.queries, isEmpty);
      await repo.search('Chicago');
      expect(source.queries, ['Chicago']);
    });
  });
  group('local notification plan', () {
    test('generic heads-up expiry never extends beyond the event start', () {
      final item = PlanCastEventWeather(
          event: event(),
          assessment:
              evaluator.evaluate(event: event(), weather: weather(), now: now));
      final notices = const PlanCastNotificationPlanner().plan(
          now: now,
          calendarSyncedAt: now,
          events: [item],
          preferences: const PlanCastPreferences(
              notifications: true,
              eventLeadMinutes: 30,
              quietStartMinute: 0,
              quietEndMinute: 0));
      expect(
          notices
              .where((n) => n['nativeEventId'] != null)
              .single['expiresAtMs'],
          item.event.startUtc.millisecondsSinceEpoch);
    });
    test('new change deliveries have distinct ids and count toward daily cap',
        () {
      final e = event(
          start: now.add(const Duration(hours: 10)),
          end: now.add(const Duration(hours: 11)));
      final item = PlanCastEventWeather(
          event: e,
          assessment: EventWeatherAssessment(
              coverage: ForecastCoverage.hourly,
              impact: WeatherImpact.watch,
              explanation: 'Rain',
              forecastUpdatedAt: now,
              validUntil: now.add(const Duration(hours: 6))));
      const prefs = PlanCastPreferences(
          notifications: true,
          eventHeadsUp: false,
          quietStartMinute: 0,
          quietEndMinute: 0);
      final history = <String, Set<String>>{};
      final ids = <String>[];
      for (var i = 0; i < 3; i++) {
        final sampleTime = now.add(Duration(hours: i * 3));
        final planned = sampleTime.add(const Duration(minutes: 1));
        final results = const PlanCastNotificationPlanner().plan(
            now: sampleTime,
            calendarSyncedAt: sampleTime,
            events: [item],
            preferences: prefs,
            forecastChanges: {e.id: planned},
            routineReservations: history);
        final eventNotices =
            results.where((n) => n['nativeEventId'] != null).toList();
        if (i == 2) {
          expect(eventNotices, isEmpty);
          break;
        }
        final notification = eventNotices.single;
        ids.add(notification['id'] as String);
        final at = planned.toLocal();
        final day =
            '${at.year.toString().padLeft(4, '0')}-${at.month.toString().padLeft(2, '0')}-${at.day.toString().padLeft(2, '0')}';
        history.putIfAbsent(day, () => {}).add(notification['id'] as String);
      }
      expect(ids.toSet().length, 2);
    });
    test(
        'genuine comparable forecast change only; first sample and same data are not changes',
        () {
      const venue = LocationCandidate(
          name: 'venue', country: '', lat: 41, lon: -87, source: 'calendar');
      PlanCastEventWeather sample(int rain, DateTime updated) =>
          PlanCastEventWeather(
              event: event(),
              venue: venue,
              assessment: EventWeatherAssessment(
                  coverage: ForecastCoverage.hourly,
                  impact: WeatherImpact.watch,
                  explanation: 'Rain',
                  peakPrecipitationChance: rain,
                  forecastUpdatedAt: updated,
                  validUntil: updated.add(const Duration(hours: 6))));
      const detector = ForecastChangeDetector();
      final old = sample(40, now.subtract(const Duration(hours: 1)));
      final newer = sample(80, now);
      expect(detector.materiallyChanged(null, newer, now), isFalse);
      expect(detector.materiallyChanged(old, old, now), isFalse);
      expect(detector.materiallyChanged(old, newer, now), isTrue);
      expect(
          detector.materiallyChanged(
              sample(40, now.subtract(const Duration(hours: 7))), newer, now),
          isFalse);
    });
    test(
        'previous daily reservations prevent more notices after repeated refresh',
        () {
      final at = now.add(const Duration(hours: 1)).toLocal();
      final day =
          '${at.year.toString().padLeft(4, '0')}-${at.month.toString().padLeft(2, '0')}-${at.day.toString().padLeft(2, '0')}';
      final current = PlanCastEventWeather(
          event: event(),
          assessment:
              evaluator.evaluate(event: event(), weather: weather(), now: now));
      final result = const PlanCastNotificationPlanner().plan(
          now: now,
          calendarSyncedAt: now,
          events: [current],
          preferences: const PlanCastPreferences(
              notifications: true,
              eventLeadMinutes: 60,
              quietStartMinute: 0,
              quietEndMinute: 0),
          routineReservations: {
            day: {'delivered-one', 'delivered-two'}
          });
      expect(result.where((n) => n['nativeEventId'] != null), isEmpty);
    });
    final item = PlanCastEventWeather(
        event: event(),
        assessment:
            evaluator.evaluate(event: event(), weather: weather(), now: now));
    test('opt-out empty; private default has no title or address', () {
      const planner = PlanCastNotificationPlanner();
      expect(
          planner.plan(
              now: now,
              calendarSyncedAt: now,
              events: [item],
              preferences: const PlanCastPreferences()),
          isEmpty);
      final plan = planner.plan(
          now: now,
          calendarSyncedAt: now,
          events: [item],
          preferences: const PlanCastPreferences(
              notifications: true, eventLeadMinutes: 60));
      expect(plan, isNotEmpty);
      expect(jsonEncode(plan), isNot(contains('Private medical')));
      expect(plan.every((n) => n['detailed'] == false), isTrue);
    });
    test(
        'fresh detailed opt-in expires within six hours, old sync falls back generic',
        () {
      const planner = PlanCastNotificationPlanner();
      const prefs = PlanCastPreferences(
          notifications: true,
          eventLeadMinutes: 60,
          detailedNotificationPreviews: true,
          quietStartMinute: 0,
          quietEndMinute: 0);
      final fresh = planner
          .plan(
              now: now,
              calendarSyncedAt: now,
              events: [item],
              preferences: prefs)
          .where((n) => n['nativeEventId'] != null)
          .single;
      expect(fresh['detailed'], isTrue);
      expect(fresh['body'], contains('Last checked'));
      final stale = planner
          .plan(
              now: now,
              calendarSyncedAt: now.subtract(const Duration(hours: 6)),
              events: [item],
              preferences: prefs)
          .where((n) => n['nativeEventId'] != null)
          .single;
      expect(stale['detailed'], isFalse);
    });
    test(
        'stable opaque identifiers, bounded queue, one morning plus two routine max',
        () {
      final many = [
        for (var i = 0; i < 20; i++)
          PlanCastEventWeather(
              event: event(
                  id: 'e$i',
                  start: now.add(Duration(hours: 2 + i * 2)),
                  end: now.add(Duration(hours: 3 + i * 2))),
              assessment: item.assessment)
      ];
      const prefs = PlanCastPreferences(
          notifications: true,
          eventLeadMinutes: 60,
          evening: true,
          dayBefore: true,
          quietStartMinute: 0,
          quietEndMinute: 0);
      const planner = PlanCastNotificationPlanner();
      final result = planner.plan(
          now: now,
          calendarSyncedAt: now,
          events: many,
          preferences: prefs,
          pendingBudget: 10);
      expect(result.length, lessThanOrEqualTo(10));
      expect(result.map((n) => n['id']).toSet().length, result.length);
      final counts = <String, int>{};
      for (final notice in result) {
        final d = DateTime.fromMillisecondsSinceEpoch(notice['fireAtMs'] as int)
            .toLocal();
        final key = '${d.year}-${d.month}-${d.day}';
        counts[key] = (counts[key] ?? 0) + 1;
      }
      expect(counts.values.every((n) => n <= 3), isTrue);
      expect(
          result,
          planner.plan(
              now: now,
              calendarSyncedAt: now,
              events: many,
              preferences: prefs,
              pendingBudget: 10));
    });
    test('quiet hours shift; notices shifted after event start are omitted',
        () {
      final n = DateTime(2026, 10, 15, 21);
      final e = event(
          start: DateTime(2026, 10, 15, 23).toUtc(),
          end: DateTime(2026, 10, 16, 1).toUtc());
      final plan = const PlanCastNotificationPlanner().plan(
          now: n,
          calendarSyncedAt: n,
          events: [PlanCastEventWeather(event: e, assessment: item.assessment)],
          preferences: const PlanCastPreferences(
              notifications: true, eventLeadMinutes: 30));
      expect(plan.where((p) => p['nativeEventId'] != null), isEmpty);
    });
  });
  group('briefing and controller privacy', () {
    test('all event views reevaluate freshness without additional requests',
        () async {
      var time = now;
      final p = FakePlatform()
        ..records = [
          {
            ...rawEvent('long'),
            'endMs': now.add(const Duration(hours: 9)).millisecondsSinceEpoch,
          }
        ];
      final w = FakeWeather();
      final c = PlanCastController(
          weatherRepository: w, platform: p, clock: () => time);
      addTearDown(c.dispose);
      await c.connect();
      await c.selectCalendars({'work'});
      expect(c.previews.single.assessment.usable, isTrue);
      time = now.add(const Duration(hours: 6, minutes: 1));
      expect(
          c.currentEvents.single.assessment.coverage, ForecastCoverage.stale);
      expect(c.previews.single.assessment.coverage, ForecastCoverage.stale);
      expect(c.eventsForDay(time.toLocal()).single.assessment.coverage,
          ForecastCoverage.stale);
      expect(c.briefingForDay(time.toLocal()).usableWeatherCount, 0);
      expect(w.requests, 1);
    });
    test('ended plans leave current readouts while future days stay available',
        () async {
      var time = now;
      final local = time.toLocal();
      final tomorrow = DateTime(local.year, local.month, local.day + 1, 12);
      final p = FakePlatform()
        ..records = [
          rawEvent('today'),
          {
            ...rawEvent('tomorrow'),
            'startMs': tomorrow.toUtc().millisecondsSinceEpoch,
            'endMs': tomorrow
                .add(const Duration(hours: 1))
                .toUtc()
                .millisecondsSinceEpoch,
          }
        ];
      final w = FakeWeather();
      final c = PlanCastController(
          weatherRepository: w, platform: p, clock: () => time);
      addTearDown(c.dispose);
      await c.connect();
      await c.selectCalendars({'work'});
      expect(c.eventsForDay(local), hasLength(1));
      time = now.add(const Duration(hours: 5));
      expect(c.eventsForDay(local), isEmpty);
      expect(c.briefingForDay(local).yourDay, startsWith('No plans'));
      expect(c.eventsForDay(tomorrow), hasLength(1));
      expect(c.previews, isEmpty,
          reason: 'Today previews must share Today counts.');
      expect(c.eventsForDay(tomorrow).single.event.nativeId, 'tomorrow');
      expect(w.requests, 1);
    });
    test('persona units rerender locally and never expose private venue names',
        () async {
      final p = FakePlatform()
        ..records = [
          {
            ...rawEvent('a'),
            'endMs': now.add(const Duration(hours: 3)).millisecondsSinceEpoch,
            'location': 'Private medical office'
          }
        ];
      // The shared evaluator fixture has deliberately severe current wind;
      // use benign current conditions when testing optional persona rendering.
      final w = FakeWeather()..result = weather(currentWindKph: 10);
      final c = PlanCastController(
          weatherRepository: w,
          platform: p,
          roastPackRepository: FakeRoastPackRepository(),
          clock: () => now);
      addTearDown(c.dispose);
      await c.connect();
      await c.selectCalendars({'work'});
      await Future<void>.delayed(Duration.zero);
      final fahrenheit = c.briefingForDay(now, persona: 'karen');
      final celsius = c.briefingForDay(now,
          persona: 'karen', temperatureUnit: TemperatureUnit.celsius);
      expect(fahrenheit.personaLine, 'At this area: 68°F. Same opinion.');
      expect(celsius.personaLine, 'At this area: 20°C. Same opinion.');
      expect(celsius.text, isNot(contains('Private medical')));
      expect(
          identical(
              celsius,
              c.briefingForDay(now,
                  persona: 'karen', temperatureUnit: TemperatureUnit.celsius)),
          isTrue);
      expect(identical(fahrenheit, c.briefingForDay(now, persona: 'karen')),
          isTrue);
      expect(w.requests, 1);
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getKeys().where((key) => key.contains('roast')), isEmpty);
      expect(p.stored, isNot(contains('Same opinion')));
    });
    test('newer local roast safety gate suppresses optional PlanCast humor',
        () async {
      final p = FakePlatform()
        ..records = [
          {
            ...rawEvent('a'),
            'endMs': now.add(const Duration(hours: 3)).millisecondsSinceEpoch,
          }
        ];
      final c = PlanCastController(
          weatherRepository: FakeWeather(),
          platform: p,
          roastPackRepository: FakeRoastPackRepository(),
          clock: () => now);
      addTearDown(c.dispose);
      await c.connect();
      await c.selectCalendars({'work'});
      await Future<void>.delayed(Duration.zero);
      // Future event facts do not borrow the current 100 km/h observation,
      // while the existing roast system conservatively suppresses its humor.
      expect(c.currentEvents.single.assessment.serious, isFalse);
      expect(c.briefingForDay(now, persona: 'karen').personaLine, isNull);
    });
    test(
        'permission revoked during calendar read purges before publication or persistence',
        () async {
      final p = FakePlatform()
        ..records = [rawEvent('a')]
        ..permissionAfterRead = 'denied';
      final w = FakeWeather();
      final c = PlanCastController(
          weatherRepository: w, platform: p, clock: () => now);
      await c.connect();
      await c.selectCalendars({'work'});
      expect(c.connected, isFalse);
      expect(c.events, isEmpty);
      expect(p.stored, isNull);
      expect(w.requests, 0);
      c.dispose();
    });
    test(
        'permission revoked during venue lookup cannot recreate protected calendar state',
        () async {
      final p = FakePlatform()..records = [rawEvent('a')];
      final w = FakeWeather()..gate = Completer<WeatherBundle>();
      final c = PlanCastController(
          weatherRepository: w, platform: p, clock: () => now);
      await c.connect();
      final loading = c.selectCalendars({'work'});
      while (w.requests == 0) {
        await Future<void>.delayed(Duration.zero);
      }
      p.permission = 'denied';
      w.gate!.complete(weather());
      await loading;
      expect(c.connected, isFalse);
      expect(c.events, isEmpty);
      expect(p.stored, isNull);
      expect(p.notices, isEmpty);
      c.dispose();
    });
    test(
        'failed venue correction cannot reuse old-location weather in day views',
        () async {
      final p = FakePlatform()..records = [rawEvent('a')];
      final w = FakeWeather();
      final c = PlanCastController(
          weatherRepository: w, platform: p, clock: () => now);
      await c.connect();
      await c.selectCalendars({'work'});
      expect(
          c
              .eventsForDay(now.toLocal())
              .single
              .assessment
              .peakPrecipitationChance,
          70);
      w.failureLatitude = 45;
      await c.setEventOverride(c.events.single.event,
          venue: const LocationCandidate(
              name: 'New private venue',
              country: '',
              lat: 45,
              lon: -80,
              source: 'user'));
      final result = c.eventsForDay(now.toLocal()).single;
      expect(result.venue!.lat, 45);
      expect(result.assessment.usable, isFalse);
      expect(result.assessment.peakPrecipitationChance, isNull);
      expect(c.briefingForDay(now.toLocal()).usableWeatherCount, 0);
      c.dispose();
    });
    test(
        'source coordinate change with stable event id cannot reuse earlier venue forecast',
        () async {
      final p = FakePlatform()..records = [rawEvent('a')];
      final w = FakeWeather();
      final c = PlanCastController(
          weatherRepository: w, platform: p, clock: () => now);
      await c.connect();
      await c.selectCalendars({'work'});
      final id = c.events.single.event.id;
      p.records = [
        {...rawEvent('a'), 'latitude': 45}
      ];
      w.failureLatitude = 45;
      await c.refresh();
      expect(c.events.single.event.id, id);
      expect(c.eventsForDay(now.toLocal()).single.assessment.usable, isFalse);
      c.dispose();
    });
    test(
        'failed same-venue refresh marks retained weather offline in recomputed day views',
        () async {
      var time = now;
      final p = FakePlatform()..records = [rawEvent('a')];
      final w = FakeWeather();
      final c = PlanCastController(
          weatherRepository: w, platform: p, clock: () => time);
      await c.connect();
      await c.selectCalendars({'work'});
      time = now.add(const Duration(minutes: 11));
      w.failureLatitude = 41;
      await c.refresh();
      expect(c.eventsForDay(time.toLocal()).single.assessment.coverage,
          ForecastCoverage.stale);
      c.dispose();
    });
    test(
        'floating all-day event remains after its raw UTC end but before civil end',
        () async {
      final local = now.toLocal();
      final today = DateTime.utc(local.year, local.month, local.day);
      final p = FakePlatform()
        ..records = [
          {
            ...rawEvent('allDay'),
            'isAllDay': true,
            'startMs':
                now.subtract(const Duration(hours: 12)).millisecondsSinceEpoch,
            'endMs':
                now.subtract(const Duration(hours: 1)).millisecondsSinceEpoch,
            'allDayStart': today.toIso8601String().substring(0, 10),
            'allDayEnd': today
                .add(const Duration(days: 1))
                .toIso8601String()
                .substring(0, 10)
          }
        ];
      final c = PlanCastController(
          weatherRepository: FakeWeather(), platform: p, clock: () => now);
      await c.connect();
      await c.selectCalendars({'work'});
      expect(c.events.length, 1);
      expect(c.eventsForDay(local).length, 1);
      expect(c.previews.length, 1);
      c.dispose();
    });
    test(
        'moving a future event repeatedly releases canceled notification reservations',
        () async {
      final p = FakePlatform()..records = [rawEvent('a')];
      final c = PlanCastController(
          weatherRepository: FakeWeather(), platform: p, clock: () => now);
      await c.connect();
      await c.selectCalendars({'work'});
      await c.updatePreferences(const PlanCastPreferences(
          notifications: true,
          eventLeadMinutes: 60,
          quietStartMinute: 0,
          quietEndMinute: 0));
      final first =
          p.notices.where((n) => n['nativeEventId'] != null).single['id'];
      for (var i = 1; i <= 3; i++) {
        p.records = [
          {
            ...rawEvent('a'),
            'startMs': now
                .add(Duration(hours: 2, minutes: i * 5))
                .millisecondsSinceEpoch,
            'endMs': now
                .add(Duration(hours: 5, minutes: i * 5))
                .millisecondsSinceEpoch
          }
        ];
        await c.refresh();
        final current =
            p.notices.where((n) => n['nativeEventId'] != null).single;
        expect(current['id'], isNot(first));
        expect(current['fireAtMs'],
            now.add(Duration(hours: 1, minutes: i * 5)).millisecondsSinceEpoch);
      }
      c.dispose();
    });
    test('user venue correction overrides stale structured source coordinates',
        () async {
      final p = FakePlatform()..records = [rawEvent('a')];
      final w = FakeWeather();
      final c = PlanCastController(
          weatherRepository: w, platform: p, clock: () => now);
      await c.initialize();
      await c.connect();
      await c.selectCalendars({'work'});
      await c.setEventOverride(c.events.single.event,
          venue: const LocationCandidate(
              name: 'Corrected venue',
              country: '',
              lat: 45,
              lon: -80,
              source: 'user'));
      expect(c.events.single.venue!.lat, 45);
      expect(w.lastLatitude, 45);
      c.dispose();
    });
    test('each refresh loads at most six new venues and labels deferred events',
        () async {
      final p = FakePlatform()
        ..records = [
          for (var i = 0; i < 20; i++)
            {...rawEvent('$i'), 'latitude': i.toDouble()}
        ];
      final w = FakeWeather();
      final c = PlanCastController(
          weatherRepository: w, platform: p, clock: () => now);
      await c.initialize();
      await c.connect();
      await c.selectCalendars({'work'});
      expect(w.requests, 6);
      expect(
          c.events
              .where((e) => e.assessment.explanation.contains('deferred'))
              .length,
          14);
      await c.refresh();
      expect(w.requests, 12);
      await c.refresh();
      expect(w.requests, 12);
      c.dispose();
    });
    test(
        'factual coverage gaps retained; no sensitive titles or serious-weather joke',
        () {
      final e = event();
      final severe = PlanCastEventWeather(
          event: e,
          assessment: evaluator.evaluate(
              event: e, weather: weather(condition: 'Thunderstorm'), now: now));
      final missing = PlanCastEventWeather(
          event: event(id: 'missing'),
          assessment: evaluator.evaluate(
              event: event(id: 'missing'),
              weather: null,
              now: now,
              hasLocation: false));
      final briefing = const PlanCastBriefingComposer().compose(
          today: [severe, missing],
          tomorrow: [],
          now: now,
          personaLine: 'A joke');
      expect(briefing.needsLocationCount, 1);
      expect(briefing.usableWeatherCount, 1);
      expect(briefing.text, isNot(contains('Private medical')));
      expect(briefing.personaLine, isNull);
    });
    test(
        'initialization never requests permission; connect never selects calendars',
        () async {
      final p = FakePlatform();
      final c = PlanCastController(
          weatherRepository: FakeWeather(), platform: p, clock: () => now);
      await c.initialize();
      expect(p.permissionRequests, 0);
      expect(c.connected, isFalse);
      await c.connect();
      expect(c.selectedCalendarIds, isEmpty);
      expect(p.permissionRequests, 1);
      c.dispose();
    });
    test(
        'shared venue requests once; only minimal protected settings persisted; disconnect purges',
        () async {
      final p = FakePlatform()..records = [rawEvent('a'), rawEvent('b')];
      final w = FakeWeather();
      final c = PlanCastController(
          weatherRepository: w, platform: p, clock: () => now);
      await c.initialize();
      await c.connect();
      await c.selectCalendars({'work'});
      expect(c.events.length, 2);
      expect(w.requests, 1);
      expect(p.stored, isNot(contains('Private medical')));
      expect(p.stored, isNot(contains('startMs')));
      expect(
          c.previews.map((e) => e.event.id).toSet().length, c.previews.length);
      await c.disconnect();
      expect(c.events, isEmpty);
      expect(p.stored, isNull);
      expect(p.notices, isEmpty);
      c.dispose();
    });
    test('revocation on resume performs cleanup', () async {
      final p = FakePlatform()..records = [rawEvent('a')];
      final c = PlanCastController(
          weatherRepository: FakeWeather(), platform: p, clock: () => now);
      await c.initialize();
      await c.connect();
      await c.selectCalendars({'work'});
      p.permission = 'denied';
      await c.onResume();
      expect(c.connected, isFalse);
      expect(c.events, isEmpty);
      expect(p.disconnected, isTrue);
      c.dispose();
    });
    test('late venue result cannot resurrect events after disconnect',
        () async {
      final p = FakePlatform()..records = [rawEvent('a')];
      final w = FakeWeather()..gate = Completer<WeatherBundle>();
      final c = PlanCastController(
          weatherRepository: w, platform: p, clock: () => now);
      await c.initialize();
      await c.connect();
      final loading = c.selectCalendars({'work'});
      while (w.requests == 0) {
        await Future<void>.delayed(Duration.zero);
      }
      await c.disconnect();
      w.gate!.complete(weather());
      await loading;
      expect(c.events, isEmpty);
      expect(p.stored, isNull);
      c.dispose();
    });
  });
}

Map<String, dynamic> rawEvent(String id) => {
      'id': id,
      'calendarId': 'work',
      'title': 'Private medical appointment',
      'startMs': now.add(const Duration(hours: 2)).millisecondsSinceEpoch,
      'endMs': now.add(const Duration(hours: 5)).millisecondsSinceEpoch,
      'timeZone': 'America/Chicago',
      'latitude': 41,
      'longitude': -87
    };

class FakePlatform extends PlanCastPlatform {
  FakePlatform() : super(supported: true);
  String permission = 'authorized';
  String? permissionAfterRead;
  int permissionRequests = 0;
  bool disconnected = false;
  String? stored;
  List<Map<String, dynamic>> records = [];
  List<Map<String, dynamic>> notices = [];
  @override
  Stream<String> get changes => const Stream.empty();
  @override
  Future<String> calendarPermission() async => permission;
  @override
  Future<String> requestCalendarPermission() async {
    permissionRequests++;
    return permission;
  }

  @override
  Future<List<Map<String, dynamic>>> calendars() async => [
        {'id': 'work', 'name': 'Work'}
      ];
  @override
  Future<List<Map<String, dynamic>>> events(
      {required List<String> calendarIds,
      required DateTime start,
      required DateTime end}) async {
    if (permissionAfterRead != null) permission = permissionAfterRead!;
    return records;
  }

  @override
  Future<void> startObserving() async {}
  @override
  Future<void> stopObserving() async {}
  @override
  Future<String?> secureRead() async => stored;
  @override
  Future<void> secureWrite(String value) async {
    stored = value;
  }

  @override
  Future<void> disconnect() async {
    disconnected = true;
    stored = null;
    notices = [];
  }

  @override
  Future<String> notificationPermission() async => 'authorized';
  @override
  Future<void> replaceNotifications(List<Map<String, dynamic>> value) async {
    notices = value;
  }

  @override
  Future<void> stopSpeaking() async {}
}

class FakeWeather extends WeatherRepository {
  int requests = 0;
  final List<String> queries = [];
  LocationCandidate? lastLocation;
  double? lastLatitude;
  double? failureLatitude;
  Completer<WeatherBundle>? gate;
  WeatherBundle? result;
  @override
  Future<WeatherBundle> getWeather(
      {required double latitude,
      required double longitude,
      bool forceRefresh = false,
      LocationCandidate? location}) async {
    requests++;
    lastLocation = location;
    lastLatitude = latitude;
    if (latitude == failureLatitude) {
      throw StateError('Venue lookup unavailable');
    }
    if (gate != null) return gate!.future;
    return result ?? weather();
  }

  @override
  Future<List<LocationCandidate>> searchLocations(
      {required String query, int limit = 5}) async {
    queries.add(query);
    return [];
  }

  @override
  Future<WeatherSnapshot> getSnapshot(
          {required double latitude,
          required double longitude,
          bool forceRefresh = false}) =>
      throw UnimplementedError();
  @override
  Future<List<RadarAlert>> getRadarAlerts(
          {required double latitude, required double longitude}) async =>
      [];
}

class FakeRoastPackRepository extends RoastPackRepository {
  @override
  Future<RoastPack> loadPack({
    RoastRemoteConfig remoteConfig = RoastRemoteConfig.disabled,
    int appBuildNumber = 1,
  }) async =>
      RoastPack(
          schemaVersion: 1,
          packVersion: 'plancast-test',
          generatedAt: now,
          personas: const [
            'karen'
          ],
          roasts: const [
            RoastLine(
                id: 'plancast-unit-line',
                persona: 'karen',
                type: RoastType.hourly,
                tags: [WeatherRoastTag.fallback],
                dayparts: [Daypart.any],
                level: RoastLevel.mild,
                weight: 1,
                text: 'At {city}: {temp}{temp_unit}. Same opinion.')
          ]);
}
