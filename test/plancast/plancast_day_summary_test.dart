import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:grumpy_skies/features/plancast/plancast_controller.dart';
import 'package:grumpy_skies/features/roasts/models/roast_persona.dart';
import 'package:grumpy_skies/models/temperature_unit.dart';
import 'package:grumpy_skies/models/weather_models.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'plancast_core_test.dart' as fixtures;

final _now = DateTime(2026, 10, 15, 10);
const _dry = EventWeatherAssessment(
    coverage: ForecastCoverage.hourly,
    impact: WeatherImpact.low,
    explanation: 'Clear during the event.',
    condition: 'Clear',
    peakPrecipitationChance: 5,
    minTemperatureC: 18,
    maxTemperatureC: 20);
const _rain = EventWeatherAssessment(
    coverage: ForecastCoverage.hourly,
    impact: WeatherImpact.watch,
    explanation: 'Rain during the event.',
    condition: 'Rain',
    peakPrecipitationChance: 70,
    minTemperatureC: 17,
    maxTemperatureC: 19);
const _unavailable = EventWeatherAssessment(
    coverage: ForecastCoverage.unavailable,
    impact: WeatherImpact.unavailable,
    explanation: 'No forecast.');

PlanCastEventWeather _item(String id,
    {String calendar = 'work',
    DateTime? start,
    DateTime? end,
    String title = 'Private medical appointment',
    bool online = false,
    bool allDay = false,
    EventWeatherAssessment assessment = _dry,
    String? city,
    LocationPrecision precision = LocationPrecision.city}) {
  final at = start ?? _now.add(const Duration(hours: 2));
  final until = end ?? at.add(const Duration(hours: 1));
  final venue = city == null
      ? null
      : LocationCandidate(
          name: city,
          country: 'US',
          lat: city == 'Miami Beach' ? 25.79 : 41.88,
          lon: city == 'Miami Beach' ? -80.13 : -87.63,
          source: 'city');
  return PlanCastEventWeather(
      event: CalendarEvent(
          id: id,
          nativeId: id,
          calendarId: calendar,
          title: title,
          startUtc: at.toUtc(),
          endUtc: until.toUtc(),
          timeZone: 'America/Chicago',
          isAllDay: allDay,
          allDayStart: allDay ? DateTime.utc(at.year, at.month, at.day) : null,
          allDayEnd:
              allDay ? DateTime.utc(until.year, until.month, until.day) : null),
      venue: venue,
      resolvedLocation: venue == null
          ? null
          : ResolvedLocation(
              candidate: venue,
              source: LocationSource.currentArea,
              precision: precision,
              evidenceQuality: LocationEvidenceQuality.assumed,
              reason: 'Current area',
              resolvedAt: _now),
      environment: online ? EventEnvironment.online : EventEnvironment.unknown,
      participation:
          online ? EventParticipation.online : EventParticipation.unknown,
      assessment: online
          ? const EventWeatherAssessment(
              coverage: ForecastCoverage.online,
              impact: WeatherImpact.unavailable,
              explanation: 'Online')
          : assessment);
}

PlanCastDaySummary _summary(List<PlanCastEventWeather> events,
        {DateTime? day,
        DateTime? now,
        Set<String>? filter,
        bool loading = false,
        bool connected = true,
        Set<String> calendars = const {
          'work',
          'personal',
          'family',
          'travel'
        }}) =>
    PlanCastDaySummary.build(
        day: day ?? _now,
        now: now ?? _now,
        events: events,
        connected: connected,
        selectedCalendarIds: calendars,
        calendarFilter: filter,
        loading: loading);

PlanCastReadout _read(PlanCastDaySummary summary,
        {String persona = 'karen',
        bool privateTitles = true,
        TemperatureUnit unit = TemperatureUnit.fahrenheit}) =>
    const PlanCastReadoutComposer().compose(
        summary: summary,
        personaId: persona,
        now: _now,
        temperatureUnit: unit,
        privateTitles: privateTitles);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('four imported calendars remain independent from the feed filter', () {
    final input = [
      for (final c in ['work', 'personal', 'family', 'travel'])
        _item(c, calendar: c)
    ];
    final ids = {'work', 'personal', 'family', 'travel'};
    final all = _summary(input, calendars: ids);
    final filtered =
        _summary(input, calendars: ids, filter: {'personal', 'travel'});
    expect(all.planCount, 4);
    expect(filtered.planCount, 2);
    expect(
        filtered.events.map((e) => e.event.calendarId), ['personal', 'travel']);
    expect(ids, {'work', 'personal', 'family', 'travel'});
    expect(all.signature, isNot(filtered.signature));
  });

  test(
      'similar titles remain distinct while a multi-day occurrence counts once',
      () {
    final stay =
        _item('stay', start: _now, end: _now.add(const Duration(days: 3)));
    final duplicateTitle = _item('second', calendar: 'personal');
    final source = [stay, duplicateTitle];
    final days = [
      for (var i = 0; i < 3; i++)
        _summary(source, day: DateTime(2026, 10, 15 + i))
    ];
    final range = PlanCastAgendaSummary(start: _now, days: days);
    expect(days.map((d) => d.planCount), [2, 1, 1]);
    expect(range.planCount, 2);
    expect(range.events.map((e) => e.event.id).toSet(), {'stay', 'second'});
  });

  test('loading, completed, empty, filtered and disconnected are distinct', () {
    final ended = _item('ended',
        start: _now.subtract(const Duration(hours: 2)), end: _now);
    expect(_summary([], loading: true).state, PlanCastDayState.loading);
    expect(_summary([]).state, PlanCastDayState.empty);
    expect(_summary([ended]).state, PlanCastDayState.completed);
    expect(_summary([ended]).completedCount, 1);
    expect(_summary([_item('later')], filter: {'personal'}).state,
        PlanCastDayState.filteredEmpty);
    expect(_summary([], connected: false).state, PlanCastDayState.disconnected);
    expect(_summary([], calendars: {}).state, PlanCastDayState.noCalendars);
    expect(_summary([_item('later')], loading: true).state,
        PlanCastDayState.ready);
  });

  test(
      'all-day civil dates preserve exclusive ends, in-progress timed stays remain',
      () {
    final allDay = _item('all',
        allDay: true,
        start: DateTime(2026, 10, 15),
        end: DateTime(2026, 10, 17));
    final ongoing = _item('ongoing',
        start: _now.subtract(const Duration(hours: 3)),
        end: _now.add(const Duration(hours: 1)));
    expect(_summary([allDay, ongoing]).planCount, 2);
    expect(_summary([allDay], day: DateTime(2026, 10, 16)).planCount, 1);
    expect(_summary([allDay], day: DateTime(2026, 10, 17)).planCount, 0);
    expect(_summary([ongoing], now: _now.add(const Duration(hours: 2))).state,
        PlanCastDayState.completed);
  });

  test('dated stay summary does not carry arrival rain into following dry day',
      () {
    final stay = _item('hotel',
        start: _now,
        end: DateTime(2026, 10, 18),
        assessment: EventWeatherAssessment(
            coverage: ForecastCoverage.partial,
            impact: WeatherImpact.watch,
            explanation: 'Stay',
            condition: 'Rain',
            segments: [
              EventWeatherSegment(
                  label: 'Arrival',
                  startUtc: _now.toUtc(),
                  endUtc: DateTime(2026, 10, 16).toUtc(),
                  assessment: _rain),
              EventWeatherSegment(
                  label: 'Full day',
                  startUtc: DateTime(2026, 10, 16).toUtc(),
                  endUtc: DateTime(2026, 10, 17).toUtc(),
                  assessment: _dry),
            ]));
    final arrival = _summary([stay]);
    final tomorrow = _summary([stay], day: DateTime(2026, 10, 16));
    final later = _summary([stay], day: DateTime(2026, 10, 17));
    expect(arrival.events.single.assessment.condition, 'Rain');
    expect(tomorrow.events.single.assessment.condition, 'Clear');
    expect(tomorrow.events.single.assessment.segments.single.label, 'Full day');
    expect(later.weatherCount, 0);
    expect(_read(tomorrow).text, contains('Rain chances stay low'));
  });

  test(
      'partial projected stay day retains daily-only granularity with unknown segment',
      () {
    final stay = _item('stay',
        start: _now,
        end: DateTime(2026, 10, 18),
        assessment: EventWeatherAssessment(
            coverage: ForecastCoverage.partial,
            impact: WeatherImpact.low,
            explanation: 'Stay',
            segments: [
              EventWeatherSegment(
                  label: 'Day outlook',
                  startUtc: DateTime(2026, 10, 15, 12).toUtc(),
                  endUtc: DateTime(2026, 10, 16, 12).toUtc(),
                  assessment: const EventWeatherAssessment(
                      coverage: ForecastCoverage.daily,
                      impact: WeatherImpact.low,
                      explanation: 'Broad day outlook',
                      condition: 'Clear',
                      peakPrecipitationChance: 5)),
              EventWeatherSegment(
                  label: 'Later day',
                  startUtc: DateTime(2026, 10, 16, 12).toUtc(),
                  endUtc: DateTime(2026, 10, 17, 12).toUtc(),
                  assessment: _unavailable),
            ]));
    final projected =
        _summary([stay], day: DateTime(2026, 10, 16)).events.single.assessment;
    expect(projected.coverage, ForecastCoverage.partial);
    expect(projected.isDaily, isTrue);
    expect(projected.precipitationLabel, contains('daily'));
  });

  test(
      'heat, cold and wind take priority over low rain in full and compact readouts',
      () {
    for (final input in [
      (
        'Heat',
        const EventWeatherAssessment(
            coverage: ForecastCoverage.hourly,
            impact: WeatherImpact.watch,
            explanation: 'Hot',
            condition: 'Clear',
            peakPrecipitationChance: 0,
            minTemperatureC: 30,
            maxTemperatureC: 34)
      ),
      (
        'Freezing temperatures',
        const EventWeatherAssessment(
            coverage: ForecastCoverage.hourly,
            impact: WeatherImpact.watch,
            explanation: 'Cold',
            condition: 'Clear',
            peakPrecipitationChance: 0,
            minTemperatureC: -2,
            maxTemperatureC: 4)
      ),
      (
        'Wind',
        const EventWeatherAssessment(
            coverage: ForecastCoverage.hourly,
            impact: WeatherImpact.watch,
            explanation: 'Windy',
            condition: 'Clear',
            peakPrecipitationChance: 0,
            maxWindKph: 40)
      ),
    ]) {
      final result = _read(_summary([_item('extreme', assessment: input.$2)]));
      expect(result.text, startsWith(input.$1));
      expect(result.compactText, startsWith(input.$1));
      expect(result.text, isNot(contains('Rain chances stay low')));
    }
  });

  test('summary hashes all facts, location, event revisions and scope', () {
    final original = _summary([_item('one', city: 'Chicago')]);
    final changes = [
      _summary([_item('one', city: 'Miami Beach')]),
      _summary([_item('one', city: 'Chicago', assessment: _rain)]),
      _summary([_item('one', city: 'Chicago', title: 'Changed private title')]),
      _summary([
        _item('one', city: 'Chicago', end: _now.add(const Duration(hours: 4)))
      ]),
      _summary([_item('one', city: 'Chicago')], filter: {'work'}),
    ];
    expect(changes.every((s) => s.signature != original.signature), isTrue);
    expect(_summary([_item('one', city: 'Chicago')]).signature,
        original.signature);
  });

  test(
      'later rainy event contributes even when first event is dry in another city',
      () {
    final summary = _summary([
      _item('first', city: 'Chicago'),
      _item('second',
          start: _now.add(const Duration(hours: 6)),
          city: 'Miami Beach',
          assessment: _rain)
    ]);
    final readout = _read(summary);
    expect(readout.text, contains('Miami Beach'));
    expect(readout.text.toLowerCase(), contains('rain'));
    expect(readout.text, isNot(contains('Private medical')));
    expect(readout.text, isNot(contains('Chicago')));
    expect(readout.mood, RoastMood.complaining);
    expect(readout.text.split(RegExp(r'\s+')).length, lessThanOrEqualTo(35));
    expect(readout.compactText.split(RegExp(r'\s+')).length,
        lessThanOrEqualTo(16));
  });

  test(
      'precise venue and private medical title never enter primary persona copy',
      () {
    final day = _summary([
      _item('private',
          city: 'Oncology treatment center',
          precision: LocationPrecision.venue,
          assessment: _rain)
    ]);
    final private = _read(day);
    final optedIn = _read(day, privateTitles: false);
    for (final value in [
      private.text,
      private.compactText,
      private.fullText,
      optedIn.text
    ]) {
      expect(value, isNot(contains('Oncology')));
      expect(value, isNot(contains('Private medical')));
    }
    expect(optedIn.fullText, contains('Private medical appointment'));
    expect(optedIn.signature, isNot(private.signature));
  });

  test('serious alert leads every readout and suppresses persona jokes', () {
    final day = _summary([
      _item('warning',
          assessment: const EventWeatherAssessment(
              coverage: ForecastCoverage.hourly,
              impact: WeatherImpact.disruption,
              explanation: 'Wind hazard',
              alerts: [
                WeatherAlert(
                    senderName: 'Weather authority',
                    event: 'Severe Thunderstorm Warning',
                    description: 'Seek shelter')
              ]))
    ]);
    final readout = _read(day);
    expect(readout.serious, isTrue);
    expect(readout.mood, RoastMood.worried);
    expect(readout.text, startsWith('Severe Thunderstorm Warning'));
    expect(readout.fullText, startsWith('Severe Thunderstorm Warning'));
    expect(readout.text, contains('official guidance'));
    expect(readout.text, isNot(contains('scheduling department')));
  });

  test('unknown and online weather never become dry-event promises', () {
    final unknown =
        _read(_summary([_item('unknown', assessment: _unavailable)]));
    expect(unknown.text, contains('not available'));
    expect(unknown.text, isNot(contains('stay low')));
    final online = _summary([_item('video', online: true)]);
    expect(online.weatherCount, 0);
    expect(online.onlineCount, 1);
    expect(_read(online).text, contains('online'));
  });

  test(
      'all selectable personas get stable matching selection without repeated empty week',
      () {
    for (final persona in RoastPersonas.supportedIds) {
      final texts = <String>{};
      final compactTexts = <String>{};
      for (var i = 0; i < 7; i++) {
        final day = _summary([], day: DateTime(2026, 10, 15 + i));
        final first = _read(day, persona: persona);
        final again = _read(day, persona: persona);
        expect(first.personaId, persona);
        expect(first.text, again.text);
        expect(first.mood, RoastMood.cozy);
        expect(first.signature, again.signature);
        texts.add(first.text);
        compactTexts.add(first.compactText);
      }
      expect(texts, hasLength(7));
      expect(compactTexts, hasLength(7));
    }
  });

  test('unit changes invalidate cache identity without fabricated temperatures',
      () {
    final day = _summary([_item('one')]);
    final f = _read(day);
    final c = _read(day, unit: TemperatureUnit.celsius);
    expect(f.signature, isNot(c.signature));
    expect(c.text, isNot(contains('°F')));
  });

  test('calendar metadata is optional and only accepted when supplied', () {
    final named = DeviceCalendar.fromMap({
      'id': 'work',
      'name': 'Work',
      'colorArgb': 0xff123456,
      'accountName': 'Real account'
    });
    expect(named.colorArgb, 0xff123456);
    expect(named.accountName, 'Real account');
    expect(DeviceCalendar.fromMap({'id': 'plain', 'name': 'Plain'}).accountName,
        isNull);
  });

  test('controller cached presentation changes make no weather or search calls',
      () async {
    final platform = fixtures.FakePlatform()..records = [_record('one')];
    final weather = fixtures.FakeWeather();
    final controller = PlanCastController(
        platform: platform,
        weatherRepository: weather,
        roastPackRepository: fixtures.FakeRoastPackRepository(),
        clock: () => fixtures.now);
    addTearDown(controller.dispose);
    await controller.connect();
    await controller.selectCalendars({'work'});
    final requests = weather.requests;
    final item = controller.currentEvents.single;
    for (final persona in RoastPersonas.supportedIds) {
      final summary = controller.summaryForDay(fixtures.now);
      controller.summaryForRange(fixtures.now);
      controller.readoutForDay(fixtures.now,
          personaId: persona, summary: summary);
      controller.summaryForDay(fixtures.now, calendarFilter: {});
      expect(controller.cachedHoursForEvent(item), hasLength(3));
    }
    expect(weather.requests, requests);
    expect(weather.queries, isEmpty);
    expect(controller.selectedCalendarIds, {'work'});
    final first = controller.readoutForDay(fixtures.now, personaId: 'karen');
    expect(
        identical(
            first, controller.readoutForDay(fixtures.now, personaId: 'karen')),
        isTrue);
  });

  test(
      'completed state survives a refresh, then disconnect clears its private snapshot',
      () async {
    final platform = fixtures.FakePlatform()
      ..records = [
        _record('done',
            start: fixtures.now.subtract(const Duration(hours: 2)),
            end: fixtures.now.subtract(const Duration(minutes: 5)))
      ];
    final weather = fixtures.FakeWeather();
    final controller = PlanCastController(
        platform: platform,
        weatherRepository: weather,
        roastPackRepository: fixtures.FakeRoastPackRepository(),
        clock: () => fixtures.now);
    addTearDown(controller.dispose);
    await controller.connect();
    await controller.selectCalendars({'work'});
    final summary = controller.summaryForDay(fixtures.now);
    expect(summary.state, PlanCastDayState.completed);
    expect(summary.planCount, 0);
    expect(summary.completedCount, 1);
    expect(weather.requests, 0);
    expect(platform.stored, isNot(contains('Private medical appointment')));
    await controller.disconnect();
    expect(controller.summaryForDay(fixtures.now).completedCount, 0);
    expect(controller.summaryForDay(fixtures.now).state,
        PlanCastDayState.disconnected);
  });

  test(
      'four selected calendar IDs survive save, filtering and controller relaunch',
      () async {
    final platform = _FourCalendars();
    final weather = fixtures.FakeWeather();
    final first = PlanCastController(
        platform: platform,
        weatherRepository: weather,
        roastPackRepository: fixtures.FakeRoastPackRepository(),
        clock: () => fixtures.now);
    await first.connect();
    await first.selectCalendars({'work', 'personal', 'family', 'travel'});
    first.summaryForDay(fixtures.now, calendarFilter: {'personal'});
    final saved = jsonDecode(platform.stored!) as Map;
    expect((saved['calendarIds'] as List).toSet(),
        {'work', 'personal', 'family', 'travel'});
    first.dispose();
    final restored = PlanCastController(
        platform: platform,
        weatherRepository: weather,
        roastPackRepository: fixtures.FakeRoastPackRepository(),
        clock: () => fixtures.now);
    addTearDown(restored.dispose);
    await restored.initialize();
    expect(
        restored.selectedCalendarIds, {'work', 'personal', 'family', 'travel'});
  });

  test('weekly unique weather count retains usable later stay outlook', () {
    final stay = _item('stay',
        start: _now,
        end: DateTime(2026, 10, 18),
        assessment: EventWeatherAssessment(
            coverage: ForecastCoverage.partial,
            impact: WeatherImpact.low,
            explanation: 'Stay',
            segments: [
              EventWeatherSegment(
                  label: 'Arrival',
                  startUtc: _now.toUtc(),
                  endUtc: DateTime(2026, 10, 16).toUtc(),
                  assessment: _unavailable),
              EventWeatherSegment(
                  label: 'Full day',
                  startUtc: DateTime(2026, 10, 16).toUtc(),
                  endUtc: DateTime(2026, 10, 17).toUtc(),
                  assessment: _dry),
              EventWeatherSegment(
                  label: 'Departure',
                  startUtc: DateTime(2026, 10, 17).toUtc(),
                  endUtc: DateTime(2026, 10, 18).toUtc(),
                  assessment: _unavailable),
            ]));
    final range = PlanCastAgendaSummary(start: _now, days: [
      for (var i = 0; i < 3; i++)
        _summary([stay], day: DateTime(2026, 10, 15 + i))
    ]);
    expect(range.planCount, 1);
    expect(range.weatherCount, 1);
    expect(range.events.single.assessment.usable, isTrue);
  });

  test(
      'occurrence automatic reset preserves migrated series choice for siblings and relaunch',
      () async {
    final firstRecord = {
      ..._record('first'),
      'recurringId': 'legacy-series',
      'isRecurring': true,
      'location': 'Unchanged invite venue'
    };
    final secondRecord = {
      ..._record('second'),
      'recurringId': 'legacy-series',
      'isRecurring': true,
      'location': 'Unchanged invite venue'
    };
    final firstEvent = CalendarEvent.fromMap(firstRecord)!;
    const miami = LocationCandidate(
        name: 'Miami Beach',
        country: 'US',
        lat: 25.79,
        lon: -80.13,
        source: 'city');
    final legacy = EventOverride(
        venue: miami,
        environment: EventEnvironment.indoor,
        remindersEnabled: false,
        expiresAt: fixtures.now.add(const Duration(days: 20)));
    final platform = fixtures.FakePlatform()
      ..records = [firstRecord, secondRecord]
      ..stored = jsonEncode({
        'connected': true,
        'calendarIds': ['work'],
        'overrides': {firstEvent.recurringKey: legacy.toJson()}
      });
    final first = PlanCastController(
        platform: platform,
        weatherRepository: fixtures.FakeWeather(),
        roastPackRepository: fixtures.FakeRoastPackRepository(),
        clock: () => fixtures.now);
    await first.initialize();
    expect(first.currentEvents.every((e) => e.venue?.lat == miami.lat), isTrue);
    await first.resetEventLocation(firstEvent);
    final reset =
        first.currentEvents.singleWhere((e) => e.event.nativeId == 'first');
    final sibling =
        first.currentEvents.singleWhere((e) => e.event.nativeId == 'second');
    expect(reset.venue?.lat, 41);
    expect(reset.environment, EventEnvironment.indoor);
    expect(reset.remindersEnabled, isFalse);
    expect(sibling.venue?.lat, miami.lat);
    expect(sibling.remindersEnabled, isFalse);
    expect(
        first.smartLocations.rules
            .where((r) => r.scope == LocationRuleScope.legacy),
        hasLength(1));
    expect(
        first.smartLocations.rules
            .singleWhere((r) => r.targetId == firstEvent.id)
            .useAutomatic,
        isTrue);
    first.dispose();
    final restored = PlanCastController(
        platform: platform,
        weatherRepository: fixtures.FakeWeather(),
        roastPackRepository: fixtures.FakeRoastPackRepository(),
        clock: () => fixtures.now);
    addTearDown(restored.dispose);
    await restored.initialize();
    expect(
        restored.currentEvents
            .singleWhere((e) => e.event.nativeId == 'first')
            .venue
            ?.lat,
        41);
    expect(
        restored.currentEvents
            .singleWhere((e) => e.event.nativeId == 'second')
            .venue
            ?.lat,
        miami.lat);
  });

  test('automatic reset preserves reminders and modern scoped rules', () async {
    final platform = fixtures.FakePlatform()..records = [_record('one')];
    final controller = PlanCastController(
        platform: platform,
        weatherRepository: fixtures.FakeWeather(),
        roastPackRepository: fixtures.FakeRoastPackRepository(),
        clock: () => fixtures.now);
    addTearDown(controller.dispose);
    await controller.connect();
    await controller.selectCalendars({'work'});
    final event = controller.currentEvents.single.event;
    await controller.setEventOverride(event,
        environment: EventEnvironment.indoor, remindersEnabled: false);
    await controller.setLocationChoice(event, const LocationChoice.online(),
        scope: LocationRuleScope.calendarDefault);
    await controller.setLocationChoice(event, const LocationChoice.online());
    expect(controller.currentEvents.single.isOnline, isTrue);
    await controller.resetEventLocation(event);
    final current = controller.currentEvents.single;
    expect(current.isOnline, isFalse,
        reason:
            'Explicit invite coordinates beat calendar fill-missing rules.');
    expect(current.environment, EventEnvironment.indoor);
    expect(current.remindersEnabled, isFalse);
    expect(controller.smartLocations.rules.single.scope,
        LocationRuleScope.calendarDefault);
    final stored = jsonDecode(platform.stored!) as Map;
    expect(stored['calendarIds'], ['work']);
  });
}

Map<String, dynamic> _record(String id, {DateTime? start, DateTime? end}) => {
      'id': id,
      'nativeEventId': id,
      'calendarId': 'work',
      'title': 'Private medical appointment',
      'startMs': (start ?? fixtures.now.add(const Duration(hours: 2)))
          .millisecondsSinceEpoch,
      'endMs': (end ?? fixtures.now.add(const Duration(hours: 5)))
          .millisecondsSinceEpoch,
      'timeZone': 'America/Chicago',
      'latitude': 41.0,
      'longitude': -87.0,
    };

class _FourCalendars extends fixtures.FakePlatform {
  @override
  Future<List<Map<String, dynamic>>> calendars() async => [
        for (final name in ['work', 'personal', 'family', 'travel'])
          {'id': name, 'name': name}
      ];
}
