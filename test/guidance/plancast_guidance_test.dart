import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:grumpy_skies/features/guidance/domain/guidance.dart';
import 'package:grumpy_skies/features/guidance/guidance_controller.dart';
import 'package:grumpy_skies/features/guidance/plancast_guidance_adapter.dart';
import 'package:grumpy_skies/features/plancast/device_area_service.dart';
import 'package:grumpy_skies/features/plancast/event_weather_evaluator.dart';
import 'package:grumpy_skies/features/plancast/plancast_controller.dart';
import 'package:grumpy_skies/models/guidance_preferences.dart';
import 'package:grumpy_skies/models/weather_models.dart';
import 'package:grumpy_skies/services/location_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../plancast/plancast_core_test.dart' as fixtures;

final guidanceNow = DateTime.utc(2026, 10, 15, 10);
const guidanceVenue = LocationCandidate(
    name: 'Private event venue',
    country: 'US',
    lat: 41,
    lon: -87,
    source: 'user');
const guidanceRemote = LocationCandidate(
    name: 'Remote venue',
    country: 'US',
    lat: 42.36,
    lon: -71.06,
    source: 'user');

GuidanceCatalog guidanceCatalog() => GuidanceCatalog.fromJson(
    (jsonDecode(File('assets/guidance/wingman_tips.en-US.json')
            .readAsStringSync()) as Map)
        .cast<String, dynamic>(),
    (jsonDecode(File('assets/guidance/wingman_tip_family_contracts.json')
            .readAsStringSync()) as Map)
        .cast<String, dynamic>());

WeatherBundle guidanceWeather({
  LocationCandidate venue = guidanceVenue,
  DateTime? now,
  DateTime? start,
  String timezone = 'America/Chicago',
  int hours = 12,
  bool stale = false,
  bool dailyOnly = false,
}) {
  final time = now ?? guidanceNow;
  final first = start ?? time;
  final current = CurrentWeather.fromJson({
    ...fixtures.weather().current.toJson(),
    'latitude': venue.lat,
    'longitude': venue.lon,
    'timezone': timezone,
    'windKph': 8,
    'weatherId': 501,
    'weatherIcon': '10d',
    'sourceUpdatedAt': (stale ? time.subtract(const Duration(hours: 7)) : time)
        .toIso8601String(),
    'lastUpdated': time.toIso8601String(),
    'fetchedAt': time.toIso8601String(),
  });
  return WeatherBundle(
      current: current,
      location: venue,
      forecastSource: 'openweather_onecall_3',
      hourly: dailyOnly
          ? const []
          : [
              for (var i = 0; i < hours; i++)
                HourlyForecast(
                    time: first.add(Duration(hours: i)),
                    temperatureC: 18,
                    condition: 'Moderate rain',
                    precipitationChance: 70,
                    weatherId: 501,
                    weatherIcon: '10d')
            ],
      timeline: [
        for (var i = 0; i < hours; i++)
          TimelineWeatherPoint(
              time: first.add(Duration(hours: i)), windMph: 5, weatherId: 501)
      ],
      daily: [
        for (var i = 0; i < 3; i++)
          DailyForecast(
              date: DateTime.utc(first.year, first.month, first.day + i),
              minTempC: 15,
              maxTempC: 22,
              condition: 'Moderate rain',
              precipitationChance: 70,
              weatherId: 501,
              weatherIcon: '10d')
      ]);
}

CalendarEvent guidanceEvent({
  String id = 'outdoor',
  String title = 'Private calendar title',
  DateTime? start,
  DateTime? end,
  DateTime? allDayStart,
  DateTime? allDayEnd,
  String timezone = 'America/Chicago',
}) =>
    CalendarEvent(
        id: planCastId(id),
        nativeId: id,
        calendarId: 'work',
        title: title,
        startUtc: start ?? guidanceNow.add(const Duration(hours: 2)),
        endUtc: end ?? guidanceNow.add(const Duration(hours: 5)),
        timeZone: timezone,
        isAllDay: allDayStart != null,
        allDayStart: allDayStart,
        allDayEnd: allDayEnd,
        latitude: guidanceVenue.lat,
        longitude: guidanceVenue.lon,
        locationText: 'Private address');

PlanCastEventWeather guidanceItem({
  CalendarEvent? event,
  WeatherBundle? weather,
  LocationCandidate venue = guidanceVenue,
  LocationSource source = LocationSource.calendarCoordinates,
  LocationEvidenceQuality quality = LocationEvidenceQuality.confirmed,
  LocationPrecision precision = LocationPrecision.coordinates,
  EventEnvironment environment = EventEnvironment.outdoor,
  DateTime? now,
  DateTime? observedAt,
  DateTime? expiresAt,
  EventWeatherAssessment? assessment,
}) {
  final time = now ?? guidanceNow;
  final plan = event ?? guidanceEvent();
  final bundle = weather ?? guidanceWeather(venue: venue, now: time);
  return PlanCastEventWeather(
      event: plan,
      venue: venue,
      venueTimeZone: bundle.current.timezone,
      environment: environment,
      assessment: assessment ??
          const EventWeatherEvaluator().evaluate(
              event: plan,
              weather: bundle,
              now: time,
              environment: environment),
      resolvedLocation: ResolvedLocation(
          candidate: venue,
          source: source,
          precision: precision,
          evidenceQuality: quality,
          reason: 'Existing resolver evidence',
          resolvedAt: time,
          observedAt: observedAt,
          validFrom: plan.startUtc,
          validUntil: expiresAt ?? plan.endUtc));
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => SharedPreferences.setMockInitialValues({}));
  final catalog = guidanceCatalog();
  const engine = GuidanceEngine();
  List<GuidanceCandidate> evaluate(PlanCastGuidanceInput input,
          {DateTime? now}) =>
      engine.evaluate(
          weather: input.weather,
          context: input.context,
          now: now ?? guidanceNow,
          catalog: catalog);
  PlanCastGuidanceInput? adapt(PlanCastEventWeather item,
          {WeatherBundle? weather, DateTime? now, DateTime? day}) =>
      PlanCastGuidanceAdapter.fromEventSnapshot(
          item: item,
          bundle: weather ?? guidanceWeather(),
          now: now ?? guidanceNow,
          day: day);

  test('explicit remote venue retains event UTC interval and physical evidence',
      () {
    final bundle =
        guidanceWeather(venue: guidanceRemote, timezone: 'America/New_York');
    final item = guidanceItem(venue: guidanceRemote, weather: bundle);
    final input = adapt(item, weather: bundle)!;
    expect(input.context.window!.start, item.event.startUtc);
    expect(input.context.window!.end, item.event.endUtc);
    expect(input.context.location.latitude, guidanceRemote.lat);
    expect(input.context.location.assumed, isFalse);
    expect(input.context.knownActivity, isTrue);
    expect(evaluate(input).any((c) => c.familyId == 'event_rain'), isTrue);
    expect(evaluate(adapt(item, weather: guidanceWeather())!), isEmpty,
        reason: 'A local weather bundle cannot support a remote event.');
    expect(input.signature, isNot(contains('Private')));
  });

  test('current area is explicitly assumed and expires with actual observation',
      () {
    final item = guidanceItem(
        source: LocationSource.currentArea,
        quality: LocationEvidenceQuality.assumed,
        precision: LocationPrecision.area,
        observedAt: guidanceNow.subtract(const Duration(minutes: 5)),
        expiresAt: guidanceNow.add(const Duration(minutes: 15)));
    final input = adapt(item)!;
    expect(input.context.location.assumed, isTrue);
    expect(input.context.location.label, 'your current area');
    expect(
        evaluate(input).every((c) => !c.validUntil
            .isAfter(guidanceNow.add(const Duration(minutes: 15)))),
        isTrue);
    expect(
        adapt(item, now: guidanceNow.add(const Duration(minutes: 15))), isNull);
    expect(
        adapt(guidanceItem(
            source: LocationSource.currentArea,
            quality: LocationEvidenceQuality.assumed)),
        isNull);
  });

  test('unknown, conflicted, indoor and online context fail closed', () {
    for (final quality in [
      LocationEvidenceQuality.conflict,
      LocationEvidenceQuality.unresolved
    ]) {
      expect(adapt(guidanceItem(quality: quality)), isNull);
    }
    expect(adapt(guidanceItem(precision: LocationPrecision.unknown)), isNull);
    for (final environment in [
      EventEnvironment.indoor,
      EventEnvironment.online
    ]) {
      expect(adapt(guidanceItem(environment: environment)), isNull);
    }
    expect(adapt(guidanceItem(), weather: guidanceWeather().asOfflineCache()),
        isNull);
  });

  test(
      'event title and optional interests never invent an outdoor or cycling activity',
      () {
    final input = adapt(guidanceItem(
        event: guidanceEvent(title: 'Cycle review and dog budget'),
        environment: EventEnvironment.unknown))!;
    expect(input.context.knownActivity, isFalse);
    expect(input.context.activity, GuidanceActivity.outdoor);
    final selector =
        GuidanceController(catalog: catalog, clock: () => guidanceNow);
    addTearDown(selector.dispose);
    final chosen = selector.select(
        weather: input.weather,
        context: input.context,
        preferences:
            const GuidancePreferences(cycling: true, dogWalking: true));
    expect(chosen?.activity, isNot(GuidanceActivity.cycling));
    expect(chosen?.activity, isNot(GuidanceActivity.dogWalking));
    expect(chosen?.familyId, isNot('event_rain'));
  });

  for (final entry in [
    (DateTime.utc(2026, 3, 8), 23),
    (DateTime.utc(2026, 11, 1), 25)
  ]) {
    test('all-day ${entry.$1} preserves ${entry.$2}-hour IANA civil date', () {
      final day = entry.$1;
      final now = day;
      final bundle = guidanceWeather(now: now, start: day, dailyOnly: true);
      final event = guidanceEvent(
          start: day,
          end: day.add(const Duration(days: 1)),
          allDayStart: day,
          allDayEnd: day.add(const Duration(days: 1)));
      final input = adapt(guidanceItem(event: event, weather: bundle, now: now),
          weather: bundle, now: now, day: day)!;
      expect(input.context.allDay, isTrue);
      expect(
          input.context.window!.end
              .difference(input.context.window!.start)
              .inHours,
          entry.$2);
      expect(evaluate(input, now: now).every((c) => c.comparisonWindow == null),
          isTrue);
      expect(
          adapt(guidanceItem(event: event, weather: bundle, now: now),
              weather: bundle, now: now, day: day.add(const Duration(days: 1))),
          isNull);
    });
  }

  test('DST repeated clock hour keeps distinct appointment instants', () {
    final now = DateTime.utc(2026, 11, 1, 5);
    final start = DateTime.utc(2026, 11, 1, 6, 30);
    final end = DateTime.utc(2026, 11, 1, 7, 30);
    final bundle = guidanceWeather(now: now);
    final input = adapt(
        guidanceItem(
            event: guidanceEvent(start: start, end: end),
            weather: bundle,
            now: now),
        weather: bundle,
        now: now)!;
    expect(input.context.window!.end.difference(input.context.window!.start),
        const Duration(hours: 1));
    expect(input.context.location.localTime(start)!.hour, 1);
    expect(input.context.location.localTime(end)!.hour, 1);
  });

  test(
      'daily-only timed event keeps the existing day outlook without an hourly event claim',
      () {
    final bundle = guidanceWeather(dailyOnly: true);
    final item = guidanceItem(weather: bundle);
    expect(item.assessment.usable, isTrue);
    expect(item.assessment.isDaily, isTrue);
    expect(adapt(item, weather: bundle), isNull);
  });

  test('old weather and horizon beyond coverage produce no optional action',
      () {
    final stale = guidanceWeather(stale: true);
    expect(adapt(guidanceItem(weather: stale), weather: stale), isNull);
    final distant = guidanceEvent(
        start: guidanceNow.add(const Duration(days: 12)),
        end: guidanceNow.add(const Duration(days: 12, hours: 1)));
    expect(adapt(guidanceItem(event: distant)), isNull);
  });

  test(
      'nearby slots dedupe overlapping actions but keep a later event at the same venue',
      () {
    final selector =
        GuidanceController(catalog: catalog, clock: () => guidanceNow);
    addTearDown(selector.dispose);
    const preferences = GuidancePreferences();
    final first = adapt(guidanceItem())!;
    final candidate = selector.select(
        weather: first.weather,
        context: first.context,
        preferences: preferences,
        scopeKey: 'first-event')!;
    selector.recordVisible(candidate,
        selector.scopeFor(first.context, 'first-event', preferences));
    final overlap = adapt(guidanceItem(
        event: guidanceEvent(
            id: 'overlap',
            start: guidanceNow.add(const Duration(hours: 3)),
            end: guidanceNow.add(const Duration(hours: 4)))))!;
    expect(
        selector.select(
            weather: overlap.weather,
            context: overlap.context,
            preferences: preferences,
            scopeKey: 'overlap-event'),
        isNull);
    final later = adapt(guidanceItem(
        event: guidanceEvent(
            id: 'later',
            start: guidanceNow.add(const Duration(hours: 6)),
            end: guidanceNow.add(const Duration(hours: 7)))))!;
    expect(
        selector.select(
            weather: later.weather,
            context: later.context,
            preferences: preferences,
            scopeKey: 'later-event'),
        isNotNull);

    // Local restart preserves interval semantics without storing event titles.
    final encoded = selector.history.encode();
    expect(encoded, isNot(contains('Private')));
    final restored =
        GuidanceController(catalog: catalog, clock: () => guidanceNow);
    addTearDown(restored.dispose);
    restored.history.restore(encoded, guidanceNow);
    expect(restored.history.entries.single.actionStart,
        first.context.window!.start);
    expect(
        restored.select(
            weather: overlap.weather,
            context: overlap.context,
            preferences: preferences,
            scopeKey: 'overlap-event'),
        isNull);
    expect(
        restored.select(
            weather: later.weather,
            context: later.context,
            preferences: preferences,
            scopeKey: 'later-event'),
        isNotNull);
  });

  test(
      '1000 snapshot selections leave service, calendar, notification and storage counts unchanged',
      () async {
    final platform = CountingGuidancePlatform()
      ..records = [fixtures.rawEvent('a')];
    final weather = CountingGuidanceWeather();
    final area = CountingGuidanceArea();
    final controller = PlanCastController(
        weatherRepository: weather,
        platform: platform,
        deviceAreaService: area,
        clock: () => guidanceNow);
    final selector =
        GuidanceController(catalog: catalog, clock: () => guidanceNow);
    addTearDown(controller.dispose);
    addTearDown(selector.dispose);
    await controller.connect();
    await controller.selectCalendars({'work'});
    await controller.setEventOverride(controller.events.single.event,
        environment: EventEnvironment.outdoor);
    final before = serviceCounts(platform, weather, area);
    final records = jsonEncode(platform.records);
    final source = controller
        .cachedGuidanceWeatherForEvent(controller.currentEvents.single)!;
    for (var i = 0; i < 1000; i++) {
      final item = controller.currentEvents.single;
      final cached = controller.cachedGuidanceWeatherForEvent(item);
      expect(identical(cached, source), isTrue);
      final input = PlanCastGuidanceAdapter.fromEventSnapshot(
          item: item, bundle: cached, now: guidanceNow)!;
      expect(
          selector.select(
              weather: input.weather,
              context: input.context,
              preferences: const GuidancePreferences(),
              scopeKey: item.event.id),
          isNotNull);
      controller.readoutForDay(guidanceNow);
    }
    expect(selector.evaluationCount, 1000);
    expect(selector.localHistoryWrites, 0);
    expect(selector.history.entries, isEmpty);
    expect(serviceCounts(platform, weather, area), before);
    expect(jsonEncode(platform.records), records);
  });

  test(
      'cached accessor rejects removed occurrence, changed venue and deselected calendar',
      () async {
    final platform = CountingGuidancePlatform()
      ..records = [fixtures.rawEvent('a')];
    final weather = CountingGuidanceWeather();
    final controller = PlanCastController(
        weatherRepository: weather,
        platform: platform,
        deviceAreaService: CountingGuidanceArea(),
        clock: () => guidanceNow);
    addTearDown(controller.dispose);
    await controller.connect();
    await controller.selectCalendars({'work'});
    final first = controller.currentEvents.single;
    expect(controller.cachedGuidanceWeatherForEvent(first), isNotNull);
    await controller.setEventOverride(first.event, venue: guidanceRemote);
    expect(controller.cachedGuidanceWeatherForEvent(first), isNull);
    final changed = controller.currentEvents.single;
    expect(controller.cachedGuidanceWeatherForEvent(changed)!.current.latitude,
        guidanceRemote.lat);
    platform.records = [
      {...fixtures.rawEvent('a'), 'status': 'cancelled'}
    ];
    await controller.refresh();
    expect(controller.cachedGuidanceWeatherForEvent(changed), isNull);
    await controller.selectCalendars({});
    expect(controller.cachedGuidanceWeatherForEvent(changed), isNull);
  });

  test(
      'travel invalidates assumed old-area cache without moving explicit destination',
      () async {
    final platform = CountingGuidancePlatform()
      ..records = [
        {...fixtures.rawEvent('local'), 'latitude': null, 'longitude': null},
        {
          ...fixtures.rawEvent('remote'),
          'latitude': guidanceRemote.lat,
          'longitude': guidanceRemote.lon
        },
      ];
    final area = CountingGuidanceArea();
    final controller = PlanCastController(
        weatherRepository: CountingGuidanceWeather(),
        platform: platform,
        deviceAreaService: area,
        clock: () => guidanceNow);
    addTearDown(controller.dispose);
    await controller.initialize();
    await controller.connect();
    await controller.selectCalendars({'work'});
    final local = controller.currentEvents
        .singleWhere((e) => e.event.nativeId == 'local');
    final remote = controller.currentEvents
        .singleWhere((e) => e.event.nativeId == 'remote');
    area.emit(const LocationCandidate(
        name: 'New actual area',
        country: 'US',
        lat: 25.79,
        lon: -80.13,
        source: 'device'));
    expect(controller.cachedGuidanceWeatherForEvent(local), isNull);
    expect(controller.cachedGuidanceWeatherForEvent(remote)!.current.latitude,
        guidanceRemote.lat);
  });
}

List<int> serviceCounts(CountingGuidancePlatform p, CountingGuidanceWeather w,
        CountingGuidanceArea a) =>
    [
      w.requests,
      w.queries.length,
      w.reverseQueries,
      p.calendarReads,
      p.eventReads,
      p.storageReads,
      p.storageWrites,
      p.notificationWrites,
      p.permissionRequests,
      p.permissionChecks,
      p.changeSubscriptions,
      a.refreshes
    ];

class CountingGuidancePlatform extends fixtures.FakePlatform {
  int calendarReads = 0,
      eventReads = 0,
      storageReads = 0,
      storageWrites = 0,
      notificationWrites = 0,
      permissionChecks = 0,
      changeSubscriptions = 0;
  @override
  Stream<String> get changes {
    changeSubscriptions++;
    return super.changes;
  }

  @override
  Future<String> calendarPermission() {
    permissionChecks++;
    return super.calendarPermission();
  }

  @override
  Future<List<Map<String, dynamic>>> calendars() {
    calendarReads++;
    return super.calendars();
  }

  @override
  Future<List<Map<String, dynamic>>> events(
      {required List<String> calendarIds,
      required DateTime start,
      required DateTime end}) {
    eventReads++;
    return super.events(calendarIds: calendarIds, start: start, end: end);
  }

  @override
  Future<String?> secureRead() {
    storageReads++;
    return super.secureRead();
  }

  @override
  Future<void> secureWrite(String value) {
    storageWrites++;
    return super.secureWrite(value);
  }

  @override
  Future<void> replaceNotifications(List<Map<String, dynamic>> value) {
    notificationWrites++;
    return super.replaceNotifications(value);
  }
}

class CountingGuidanceWeather extends fixtures.FakeWeather {
  CountingGuidanceWeather({DateTime Function()? clock})
      : clock = clock ?? (() => guidanceNow);
  final DateTime Function() clock;
  int reverseQueries = 0;
  @override
  Future<WeatherBundle> getWeather(
      {required double latitude,
      required double longitude,
      bool forceRefresh = false,
      LocationCandidate? location}) async {
    requests++;
    return guidanceWeather(
        now: clock(),
        venue: LocationCandidate(
            name: '',
            country: 'US',
            lat: latitude,
            lon: longitude,
            source: 'provider'));
  }

  @override
  Future<LocationCandidate?> reverseGeocode(
      {required double latitude, required double longitude}) async {
    reverseQueries++;
    return null;
  }
}

class CountingGuidanceArea implements DeviceAreaService {
  CountingGuidanceArea({DateTime? now})
      : sample = DeviceAreaSample(
            candidate: guidanceVenue,
            observedAt: now ?? guidanceNow,
            accuracyMeters: 80);
  @override
  DeviceAreaSample? sample;
  @override
  DeviceLocationFailure? failure;
  final _stream = StreamController<DeviceAreaSample?>.broadcast(sync: true);
  int refreshes = 0;
  void emit(LocationCandidate venue) {
    sample = DeviceAreaSample(
        candidate: venue, observedAt: guidanceNow, accuracyMeters: 80);
    _stream.add(sample);
  }

  @override
  Stream<DeviceAreaSample?> get changes => _stream.stream;
  @override
  Future<DeviceAreaSample?> refresh(
      {bool requestPermission = false, bool force = false}) async {
    refreshes++;
    return sample;
  }

  @override
  Future<void> setActive(bool active) async {}
  @override
  Future<void> clear() async {
    sample = null;
  }

  @override
  void dispose() => unawaited(_stream.close());
}
