import 'dart:async';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:grumpy_skies/features/plancast/device_area_service.dart';
import 'package:grumpy_skies/features/plancast/plancast_controller.dart';
import 'package:grumpy_skies/features/plancast/venue_weather_repository.dart';
import 'package:grumpy_skies/models/weather_models.dart';
import 'package:grumpy_skies/services/location_service.dart';
import 'package:grumpy_skies/services/weather_location_controller.dart';
import 'package:shared_preferences/shared_preferences.dart';

// Reuse the established deterministic weather, platform and bundled-roast
// fixtures. Importing a test library does not execute its main().
import 'plancast_core_test.dart' as fixtures;

const _chicago = LocationCandidate(
    name: 'Chicago', country: 'US', lat: 41.88, lon: -87.63, source: 'device');
const _miami = LocationCandidate(
    name: 'Miami Beach',
    country: 'US',
    lat: 25.79,
    lon: -80.13,
    source: 'city');
const _boston = LocationCandidate(
    name: 'Boston', country: 'US', lat: 42.36, lon: -71.06, source: 'city');
const _denied = DeviceLocationFailure(
    type: DeviceLocationFailureType.permissionDenied,
    message: 'Location access is off. Choose a default area.');

DeviceAreaSample _sample(LocationCandidate candidate, {DateTime? observedAt}) =>
    DeviceAreaSample(
        candidate: candidate,
        observedAt: observedAt ?? fixtures.now,
        accuracyMeters: 80,
        locality: candidate.name);

Map<String, dynamic> _record(String id,
        {String title = 'Tree trimming',
        String calendar = 'work',
        String location = '',
        LocationCandidate? coordinates,
        int day = 0,
        String? series}) =>
    {
      'id': id,
      'nativeEventId': 'native-$id',
      'nativeFingerprint': 'fingerprint-$id',
      'calendarId': calendar,
      'title': title,
      'location': location,
      'startMs': fixtures.now
          .add(Duration(days: day, hours: 2))
          .millisecondsSinceEpoch,
      'endMs': fixtures.now
          .add(Duration(days: day, hours: 5))
          .millisecondsSinceEpoch,
      'timeZone': 'America/Chicago',
      if (coordinates != null) ...{
        'latitude': coordinates.lat,
        'longitude': coordinates.lon
      },
      if (series != null) ...{'isRecurring': true, 'recurringId': series}
    };

PlanCastEventWeather _item(PlanCastController controller, String nativeId) =>
    controller.currentEvents
        .singleWhere((e) => e.event.nativeId == 'native-$nativeId');

Future<void> _until(bool Function() condition) async {
  for (var attempt = 0; attempt < 100 && !condition(); attempt++) {
    await Future<void>.delayed(Duration.zero);
  }
  expect(condition(), isTrue,
      reason: 'Expected the controlled async boundary.');
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => SharedPreferences.setMockInitialValues({}));

  PlanCastController controller(
      {required _Platform platform,
      required _Area area,
      required _Weather weather}) {
    final value = PlanCastController(
        platform: platform,
        weatherRepository: weather,
        deviceAreaService: area,
        clock: () => fixtures.now);
    addTearDown(value.dispose);
    return value;
  }

  Future<void> connect(PlanCastController value,
      {Set<String> calendars = const {'work'}}) async {
    await value.connect();
    await value.selectCalendars(calendars);
    expect(value.error, isNull);
  }

  test(
      'missing-location plans share actual-area weather and the same briefing/notice evidence',
      () async {
    final platform = _Platform()
      ..records = [_record('tree'), _record('errand', title: 'Private errand')];
    final area = _Area(_sample(_chicago));
    final weather = _Weather();
    final value = controller(platform: platform, area: area, weather: weather);
    await connect(value);

    expect(weather.requests, 1);
    expect(weather.requested, [VenueWeatherRepository.keyFor(_chicago)]);
    expect(weather.locationArguments, everyElement(isNull));
    expect(weather.queries, isEmpty);
    expect(area.permissionRequests, 0);
    expect(value.currentEvents, hasLength(2));
    for (final item in value.currentEvents) {
      expect(item.needsLocation, isFalse);
      expect(item.resolvedLocation?.source, LocationSource.currentArea);
      expect(item.resolvedLocation?.evidenceQuality,
          LocationEvidenceQuality.assumed);
      expect(item.assessment.usable, isTrue);
      expect(item.assessment.peakPrecipitationChance, 70);
    }
    final briefing = value.briefingForDay(fixtures.now);
    expect(briefing.automaticLocationCount, 2);
    expect(briefing.needsLocationCount, 0);
    expect(briefing.text, contains('Chicago'));
    expect(briefing.text, contains('Using your area'));

    await value.updatePreferences(value.preferences.copyWith(
        notifications: true,
        detailedNotificationPreviews: true,
        eventLeadMinutes: 105,
        quietStartMinute: 0,
        quietEndMinute: 0));
    final notice = platform.notices.singleWhere((n) => n['detailed'] == true);
    expect(notice['body'], contains('Chicago'));
    expect(notice['body'], contains('Using your area'));
    expect(notice['route'], startsWith('/plancast?event='));
    expect(notice['route'], isNot(contains('Tree')));
    expect(platform.reads.single.calendarIds, {'work'});
    expect(platform.reads.single.start,
        fixtures.now.subtract(const Duration(days: 1)));
    expect(
        platform.reads.single.end, fixtures.now.add(const Duration(days: 14)));
  });

  test(
      'a structured destination survives device-area changes and reuses its own bundle',
      () async {
    final platform = _Platform()
      ..records = [_record('destination', coordinates: _miami)];
    final area = _Area(_sample(_chicago));
    final weather = _Weather();
    final value = controller(platform: platform, area: area, weather: weather);
    await connect(value);
    final before = _item(value, 'destination');
    area.emit(_sample(_boston));
    expect(_item(value, 'destination').resolvedLocation?.source,
        LocationSource.calendarCoordinates);
    expect(_item(value, 'destination').venue?.lat, _miami.lat);
    expect(_item(value, 'destination').assessment.peakPrecipitationChance,
        before.assessment.peakPrecipitationChance);
    await value.refresh();
    expect(weather.requests, 1);
    expect(weather.requested, [VenueWeatherRepository.keyFor(_miami)]);
  });

  test(
      'browsing Today changes only Today and cannot replace the actual device area',
      () async {
    final weather = _Weather();
    final today = WeatherLocationController(
        repository: weather,
        preferences: await SharedPreferences.getInstance(),
        clock: () => fixtures.now);
    addTearDown(today.dispose);
    await today.selectLocation(_miami);
    final platform = _Platform()..records = [_record('tree')];
    final value = controller(
        platform: platform, area: _Area(_sample(_chicago)), weather: weather);
    await connect(value);
    await today.selectLocation(_boston);
    await value.refresh();
    expect(today.selectedLocation?.lat, _boston.lat);
    expect(value.currentArea?.lat, _chicago.lat);
    expect(_item(value, 'tree').venue?.lat, _chicago.lat);
    expect(weather.requested, [VenueWeatherRepository.keyFor(_chicago)]);
  });

  test(
      'optional hotel matching sends only the extracted city and never guesses the current area',
      () async {
    const title = 'Reservation at UNFRAMED, Miami Beach, Autograph Collection';
    final platform = _Platform()..records = [_record('hotel', title: title)];
    final weather = _Weather()..searchResult = [_miami];
    final value = controller(
        platform: platform, area: _Area(_sample(_chicago)), weather: weather);
    await connect(value);
    expect(_item(value, 'hotel').needsLocation, isTrue);
    expect(weather.requests, 0);
    expect(weather.queries, isEmpty);

    await value.setOnlineLocationMatching(true);
    expect(weather.queries, ['Miami Beach']);
    expect(weather.requested, [VenueWeatherRepository.keyFor(_miami)]);
    expect(weather.locationArguments, everyElement(isNull));
    expect(_item(value, 'hotel').resolvedLocation?.source,
        LocationSource.inferredCity);
    expect(_item(value, 'hotel').resolvedLocation?.precision,
        LocationPrecision.city);
    expect(_item(value, 'hotel').resolvedLocation?.reviewSuggested, isTrue);
    expect(_item(value, 'hotel').venue?.lat, _miami.lat);
    await value.refresh();
    expect(weather.queries, ['Miami Beach']);
  });

  test(
      'denied area permission uses one default without repeated permission prompts',
      () async {
    final platform = _Platform()
      ..records = [_record('tree'), _record('second')];
    final area = _Area(null)..failure = _denied;
    final weather = _Weather();
    final value = controller(platform: platform, area: area, weather: weather);
    await connect(value);
    expect(value.currentEvents.every((item) => item.needsLocation), isTrue);
    expect(value.locationPermissionMessage, _denied.message);
    expect(weather.requests, 0);
    await value.setDefaultArea(_boston);
    await value.refresh();
    expect(value.currentEvents.every((item) => !item.needsLocation), isTrue);
    expect(value.currentEvents.map((item) => item.resolvedLocation?.source),
        everyElement(LocationSource.defaultArea));
    expect(weather.requests, 1);
    expect(area.permissionRequests, 0);
    await value.useCurrentArea();
    expect(area.permissionRequests, 1);
    expect(_item(value, 'tree').resolvedLocation?.source,
        LocationSource.defaultArea);
  });

  test(
      'a foreground area change removes old-city weather before its replacement finishes',
      () async {
    final platform = _Platform()..records = [_record('tree')];
    final area = _Area(_sample(_chicago));
    final weather = _Weather();
    final value = controller(platform: platform, area: area, weather: weather);
    await connect(value);
    expect(_item(value, 'tree').assessment.usable, isTrue);
    final replacement = weather.hold(_miami);
    area.emit(_sample(_miami));
    expect(_item(value, 'tree').venue?.lat, _miami.lat);
    expect(_item(value, 'tree').assessment.usable, isFalse);
    expect(_item(value, 'tree').assessment.peakPrecipitationChance, isNull);
    final refresh = value.refresh();
    await _until(() =>
        weather.requested.contains(VenueWeatherRepository.keyFor(_miami)));
    expect(_item(value, 'tree').assessment.coverage, ForecastCoverage.loading);
    replacement
        .complete(fixtures.weather(rain: [10, 10, 10], condition: 'Snow'));
    await refresh;
    expect(_item(value, 'tree').venue?.lat, _miami.lat);
    expect(_item(value, 'tree').assessment.peakPrecipitationChance, 10);
  });

  test(
      'paused area emissions cannot retarget plans; resume uses a passive fresh check',
      () async {
    final platform = _Platform()..records = [_record('tree')];
    final area = _Area(_sample(_chicago));
    final weather = _Weather();
    final value = controller(platform: platform, area: area, weather: weather);
    await connect(value);
    await value.onPause();
    area.emit(_sample(_miami));
    expect(_item(value, 'tree').venue?.lat, _chicago.lat);
    expect(weather.requests, 1);
    expect(area.active.last, isFalse);
    await value.onResume();
    expect(_item(value, 'tree').venue?.lat, _miami.lat);
    expect(weather.requests, 2);
    expect(area.active.last, isTrue);
    expect(area.permissionRequests, 0);
  });

  test('late old-area weather cannot overwrite a newer area or its briefing',
      () async {
    final platform = _Platform()..records = [_record('tree')];
    final area = _Area(_sample(_chicago));
    final weather = _Weather();
    final old = weather.hold(_chicago);
    final newer = weather.hold(_miami);
    final value = controller(platform: platform, area: area, weather: weather);
    await value.connect();
    final first = value.selectCalendars({'work'});
    await _until(() => weather.requests == 1);
    area.emit(_sample(_miami));
    final second = value.refresh();
    await _until(() => weather.requests == 2);
    newer.complete(fixtures.weather(rain: [10, 10, 10], condition: 'Snow'));
    await second;
    old.complete(fixtures.weather(rain: [90, 90, 90], condition: 'Rain'));
    await first;
    expect(_item(value, 'tree').venue?.lat, _miami.lat);
    expect(_item(value, 'tree').assessment.peakPrecipitationChance, 10);
    expect(value.briefingForDay(fixtures.now).text, contains('Miami Beach'));
    expect(value.briefingForDay(fixtures.now).text, isNot(contains('Chicago')));
  });

  test(
      'a stale native queue write completes before area cancellation and a fresh replan',
      () async {
    final platform = _Platform()..records = [_record('tree')];
    final area = _Area(_sample(_chicago));
    final weather = _Weather();
    final value = controller(platform: platform, area: area, weather: weather);
    await connect(value);
    final gate = platform.holdNextNonemptyQueue();
    final enabling = value.updatePreferences(value.preferences.copyWith(
        notifications: true,
        detailedNotificationPreviews: true,
        eventLeadMinutes: 105,
        quietStartMinute: 0,
        quietEndMinute: 0));
    await _until(() => platform.queueBlocked);
    area.emit(_sample(_miami));
    expect(_item(value, 'tree').assessment.usable, isFalse);
    gate.complete();
    await enabling;
    await _until(() => platform.completedQueues.last.isEmpty);
    expect(platform.notices, isEmpty);
    await value.refresh();
    final detailed =
        platform.notices.where((n) => n['detailed'] == true).toList();
    expect(detailed, hasLength(1));
    expect(detailed.single['body'], contains('Miami Beach'));
    expect(platform.notices.any((n) => '${n['body']}'.contains('Chicago')),
        isFalse);
  });

  test(
      'permission revocation during weather acquisition deletes state and rejects completion',
      () async {
    final platform = _Platform()..records = [_record('tree')];
    final area = _Area(_sample(_chicago));
    final weather = _Weather();
    final gate = weather.hold(_chicago);
    final value = controller(platform: platform, area: area, weather: weather);
    await value.connect();
    final selecting = value.selectCalendars({'work'});
    await _until(() => weather.requests == 1);
    platform.permission = 'denied';
    gate.complete(fixtures.weather());
    await selecting;
    expect(value.connected, isFalse);
    expect(value.currentEvents, isEmpty);
    expect(value.selectedCalendarIds, isEmpty);
    expect(platform.stored, isNull);
    expect(platform.notices, isEmpty);
    expect(area.clears, 1);
    expect(value.venueWeather.hasReusable(_chicago), isFalse);
  });

  test(
      'superseded cancellation still removes old-area notices while new weather is pending',
      () async {
    final platform = _Platform()..records = [_record('tree')];
    final area = _Area(_sample(_chicago));
    final weather = _Weather();
    final value = controller(platform: platform, area: area, weather: weather);
    await connect(value);
    final oldNativeWrite = platform.holdNextNonemptyQueue();
    final enabling = value.updatePreferences(value.preferences.copyWith(
        notifications: true,
        detailedNotificationPreviews: true,
        eventLeadMinutes: 105,
        quietStartMinute: 0,
        quietEndMinute: 0));
    await _until(() => platform.queueBlocked);
    final replacement = weather.hold(_miami);
    area.emit(_sample(_miami));
    // Let the real movement debounce begin another refresh/revision while the
    // old native write and the replacement area's weather both remain blocked.
    await Future<void>.delayed(const Duration(milliseconds: 400));
    await _until(() => weather.requests == 2);
    expect(value.loading, isTrue);
    oldNativeWrite.complete();
    await enabling;
    await _until(() => platform.completedQueues.last.isEmpty);
    expect(platform.notices, isEmpty);
    expect(replacement.isCompleted, isFalse);
    expect(_item(value, 'tree').assessment.usable, isFalse);
    replacement.complete(fixtures.weather());
    await _until(() => !value.loading);
    expect(platform.notices.where((n) => n['detailed'] == true).single['body'],
        contains('Miami Beach'));
  });

  test(
      'disconnect rejects late area/weather completions without restoring protected state',
      () async {
    final platform = _Platform()..records = [_record('tree')];
    final area = _Area(_sample(_chicago));
    final weather = _Weather();
    final gate = weather.hold(_chicago);
    final value = controller(platform: platform, area: area, weather: weather);
    await value.connect();
    final selecting = value.selectCalendars({'work'});
    await _until(() => weather.requests == 1);
    await value.disconnect();
    area.emit(_sample(_miami));
    gate.complete(fixtures.weather());
    await selecting;
    expect(value.connected, isFalse);
    expect(value.currentEvents, isEmpty);
    expect(value.currentArea, isNull);
    expect(value.smartLocations.rules, isEmpty);
    expect(platform.stored, isNull);
    expect(platform.notices, isEmpty);
    expect(value.venueWeather.hasReusable(_chicago), isFalse);
  });

  test(
      'an old refresh permission response cannot disconnect a newer connection',
      () async {
    final platform = _Platform()..records = [_record('tree')];
    final area = _Area(_sample(_chicago));
    final value =
        controller(platform: platform, area: area, weather: _Weather());
    await connect(value);
    final oldPermission = platform.holdNextPermission();
    final oldRefresh = value.refresh();
    await _until(() => platform.permissionBlocked);
    await value.disconnect();
    area.sample = _sample(_miami);
    await connect(value);
    expect(_item(value, 'tree').venue?.lat, _miami.lat);
    oldPermission.complete('denied');
    await oldRefresh;
    expect(value.connected, isTrue);
    expect(value.calendarPermission, 'authorized');
    expect(value.selectedCalendarIds, {'work'});
    expect(_item(value, 'tree').venue?.lat, _miami.lat);
    expect(platform.stored, isNotNull);
  });

  test(
      'disconnect waits for an in-flight native schedule before final cancellation',
      () async {
    final platform = _Platform()..records = [_record('tree')];
    final value = controller(
        platform: platform,
        area: _Area(_sample(_chicago)),
        weather: _Weather());
    await connect(value);
    final gate = platform.holdNextNonemptyQueue();
    final enable = value
        .updatePreferences(value.preferences.copyWith(notifications: true));
    await _until(() => platform.queueBlocked);
    final disconnecting = value.disconnect();
    expect(value.connected, isFalse);
    gate.complete();
    await Future.wait([enable, disconnecting]);
    expect(platform.disconnected, isTrue);
    expect(platform.notices, isEmpty);
    expect(platform.stored, isNull);
  });

  test(
      'migration retains selected calendars, preferences and intentional expired location choices',
      () async {
    final record = _record('tree');
    final id = CalendarEvent.fromMap(record)!.id;
    const preferences = PlanCastPreferences(
        bufferMinutes: 45,
        eventLeadMinutes: 90,
        quietStartMinute: 1200,
        quietEndMinute: 480,
        spokenPrivateTitles: true);
    final platform = _Platform()
      ..records = [record]
      ..stored = jsonEncode({
        'version': 1,
        'connected': true,
        'calendarIds': ['work'],
        'preferences': preferences.toJson(),
        'overrides': {
          id: EventOverride(
                  venue: _miami,
                  expiresAt: fixtures.now.subtract(const Duration(days: 1)))
              .toJson()
        }
      });
    final value = controller(
        platform: platform,
        area: _Area(_sample(_chicago)),
        weather: _Weather());
    await value.initialize();
    expect(value.connected, isTrue);
    expect(platform.permissionRequests, 0);
    expect(value.selectedCalendarIds, {'work'});
    expect(value.preferences.toJson(), preferences.toJson());
    expect(_item(value, 'tree').venue?.lat, _miami.lat);
    expect(_item(value, 'tree').resolvedLocation?.source,
        LocationSource.userOverride);
    expect(_item(value, 'tree').resolvedLocation?.reviewSuggested, isTrue);
    expect(value.locationRules.single.scope, LocationRuleScope.legacy);
    final stored = jsonDecode(platform.stored!) as Map<String, dynamic>;
    expect(stored['version'], SmartLocationState.version);
    expect(stored['calendarIds'], ['work']);
    expect((stored['smartLocations'] as Map)['rules'], hasLength(1));
    expect(platform.stored, isNot(contains('Tree trimming')));
    expect(stored.containsKey('events'), isFalse);
  });

  test(
      'recurring missing-location rules stay within their calendar and reset to automatic',
      () async {
    final platform = _Platform()
      ..records = [
        _record('one', series: 'same-provider-series'),
        _record('two', series: 'same-provider-series', day: 1),
        _record('shared', calendar: 'shared', series: 'same-provider-series'),
        _record('fixed', series: 'same-provider-series', coordinates: _boston)
      ];
    final value = controller(
        platform: platform,
        area: _Area(_sample(_chicago)),
        weather: _Weather());
    await connect(value, calendars: {'work', 'shared'});
    final event = _item(value, 'one').event;
    expect(
        value
            .locationChoiceAffected(event, LocationRuleScope.seriesMissing)
            .map((e) => e.event.nativeId)
            .toSet(),
        {'native-one', 'native-two'});
    await value.setLocationChoice(event, const LocationChoice.place(_miami),
        scope: LocationRuleScope.seriesMissing);
    expect(_item(value, 'one').resolvedLocation?.source,
        LocationSource.recurringRule);
    expect(_item(value, 'two').venue?.lat, _miami.lat);
    expect(_item(value, 'shared').venue?.lat, _chicago.lat);
    expect(_item(value, 'fixed').venue?.lat, _boston.lat);
    await value.removeLocationRule(value.locationRules.single.id);
    expect(_item(value, 'one').resolvedLocation?.source,
        LocationSource.currentArea);
    expect(_item(value, 'two').venue?.lat, _chicago.lat);
    expect(value.locationRules, isEmpty);
  });

  test(
      'iOS legacy recurring venue and reminder settings survive native series identity migration',
      () async {
    final oldKey = planCastId('work|old-calendar-item|');
    final platform = _Platform()
      ..records = [
        {
          ..._record('tree', series: 'new-external-series-hash'),
          'legacyRecurringId': 'old-calendar-item',
          'legacyLocation': ''
        }
      ]
      ..stored = jsonEncode({
        'version': 1,
        'connected': true,
        'calendarIds': ['work'],
        'overrides': {
          oldKey: EventOverride(
                  venue: _miami,
                  remindersEnabled: false,
                  environment: EventEnvironment.outdoor,
                  expiresAt: fixtures.now.add(const Duration(days: 20)))
              .toJson()
        }
      });
    final value = controller(
        platform: platform,
        area: _Area(_sample(_chicago)),
        weather: _Weather());
    await value.initialize();
    final item = _item(value, 'tree');
    expect(item.event.legacyRecurringKey, oldKey);
    expect(item.event.recurringKey, isNot(oldKey));
    expect(item.resolvedLocation?.source, LocationSource.recurringRule);
    expect(item.venue?.lat, _miami.lat);
    expect(item.remindersEnabled, isFalse);
    expect(item.environment, EventEnvironment.outdoor);
    expect(value.locationRules.single.targetId, oldKey);
    expect(value.selectedCalendarIds, {'work'});
  });

  test(
      'occurrence Online then reset affects only that instance of a recurring series',
      () async {
    final platform = _Platform()
      ..records = [
        _record('one', series: 'weekly'),
        _record('two', series: 'weekly', day: 1)
      ];
    final value = controller(
        platform: platform,
        area: _Area(_sample(_chicago)),
        weather: _Weather());
    await connect(value);
    await value.setLocationChoice(
        _item(value, 'one').event, const LocationChoice.online());
    expect(_item(value, 'one').isOnline, isTrue);
    expect(_item(value, 'one').needsLocation, isFalse);
    expect(_item(value, 'two').isOnline, isFalse);
    await value.removeLocationRule(value.locationRules.single.id);
    expect(_item(value, 'one').isOnline, isFalse);
    expect(_item(value, 'one').resolvedLocation?.source,
        LocationSource.currentArea);
  });

  test(
      'trip preview, application and Undo honor calendar/date bounds and stronger choices',
      () async {
    final platform = _Platform()
      ..records = [
        _record('local'),
        _record('shared', calendar: 'shared'),
        _record('outside', day: 1),
        _record('fixed', coordinates: _boston),
        _record('chosen'),
        _record('private', calendar: 'not-selected')
      ];
    final value = controller(
        platform: platform,
        area: _Area(_sample(_chicago)),
        weather: _Weather());
    await connect(value, calendars: {'work', 'shared'});
    await value.setLocationChoice(
        _item(value, 'chosen').event, const LocationChoice.place(_boston));
    final start = fixtures.now.add(const Duration(hours: 1));
    final end = fixtures.now.add(const Duration(hours: 6));
    expect(
        value.batchAffected(
            start: start,
            end: end,
            calendarIds: {'work'}).map((e) => e.event.nativeId),
        ['native-local']);
    await value.applyTripArea(_miami,
        start: start, end: end, calendarIds: {'work', 'not-selected'});
    expect(_item(value, 'local').resolvedLocation?.source,
        LocationSource.confirmedTrip);
    expect(_item(value, 'shared').venue?.lat, _chicago.lat);
    expect(_item(value, 'outside').venue?.lat, _chicago.lat);
    expect(_item(value, 'fixed').venue?.lat, _boston.lat);
    expect(_item(value, 'chosen').venue?.lat, _boston.lat);
    expect(value.smartLocations.trips.single.calendarIds, {'work'});
    expect(value.smartLocations.trips.single.eventIds,
        {_item(value, 'local').event.id});
    expect(value.canUndoLocationChange, isTrue);
    await value.setDefaultArea(
        _boston); // An unrelated intentional edit survives Undo.
    await value.undoLocationChange();
    expect(value.smartLocations.trips, isEmpty);
    expect(value.canUndoLocationChange, isFalse);
    expect(value.defaultArea?.lat, _boston.lat);
    expect(_item(value, 'local').resolvedLocation?.source,
        LocationSource.currentArea);
    expect(_item(value, 'chosen').venue?.lat, _boston.lat);
    expect(value.selectedCalendarIds, {'work', 'shared'});
    expect(value.currentEvents.any((e) => e.event.calendarId == 'not-selected'),
        isFalse);
    expect(
        platform.reads
            .every((r) => r.calendarIds.difference({'work', 'shared'}).isEmpty),
        isTrue);
  });
}

class _Area implements DeviceAreaService {
  _Area(this.sample);
  @override
  DeviceAreaSample? sample;
  @override
  DeviceLocationFailure? failure;
  final _stream = StreamController<DeviceAreaSample?>.broadcast(sync: true);
  int permissionRequests = 0, clears = 0;
  final active = <bool>[];
  @override
  Stream<DeviceAreaSample?> get changes => _stream.stream;
  void emit(DeviceAreaSample? value) {
    sample = value;
    _stream.add(value);
  }

  @override
  Future<DeviceAreaSample?> refresh(
      {bool requestPermission = false, bool force = false}) async {
    if (requestPermission) permissionRequests++;
    return sample;
  }

  @override
  Future<void> setActive(bool value) async => active.add(value);
  @override
  Future<void> clear() async {
    clears++;
    sample = null;
  }

  @override
  void dispose() => unawaited(_stream.close());
}

class _Platform extends fixtures.FakePlatform {
  final reads = <({Set<String> calendarIds, DateTime start, DateTime end})>[];
  final completedQueues = <List<Map<String, dynamic>>>[];
  Completer<void>? _queueGate;
  Completer<String>? _permissionGate;
  bool queueBlocked = false;
  bool permissionBlocked = false;
  Completer<void> holdNextNonemptyQueue() => _queueGate = Completer<void>();
  Completer<String> holdNextPermission() =>
      _permissionGate = Completer<String>();
  @override
  Future<String> calendarPermission() async {
    final gate = _permissionGate;
    if (gate == null) return super.calendarPermission();
    _permissionGate = null;
    permissionBlocked = true;
    try {
      return await gate.future;
    } finally {
      permissionBlocked = false;
    }
  }

  @override
  Future<List<Map<String, dynamic>>> calendars() async => [
        {'id': 'work', 'name': 'Work'},
        {'id': 'shared', 'name': 'Shared'},
        {'id': 'not-selected', 'name': 'Unselected'}
      ];
  @override
  Future<List<Map<String, dynamic>>> events(
      {required List<String> calendarIds,
      required DateTime start,
      required DateTime end}) async {
    reads.add((calendarIds: calendarIds.toSet(), start: start, end: end));
    // Return every fixture intentionally: the real repository/controller must
    // enforce selected calendars even if a provider returns excess records.
    return super.events(calendarIds: calendarIds, start: start, end: end);
  }

  @override
  Future<void> replaceNotifications(List<Map<String, dynamic>> value) async {
    final gate = _queueGate;
    if (value.isNotEmpty && gate != null) {
      _queueGate = null;
      queueBlocked = true;
      await gate.future;
      queueBlocked = false;
    }
    final snapshot = value.map((n) => Map<String, dynamic>.from(n)).toList();
    await super.replaceNotifications(snapshot);
    completedQueues.add(snapshot);
  }
}

class _Weather extends fixtures.FakeWeather {
  final requested = <String>[];
  final locationArguments = <LocationCandidate?>[];
  final _gates = <String, Completer<WeatherBundle>>{};
  List<LocationCandidate> searchResult = const [];
  Completer<WeatherBundle> hold(LocationCandidate candidate) =>
      _gates[VenueWeatherRepository.keyFor(candidate)] =
          Completer<WeatherBundle>();
  @override
  Future<WeatherBundle> getWeather(
      {required double latitude,
      required double longitude,
      bool forceRefresh = false,
      LocationCandidate? location}) async {
    requests++;
    final key =
        '${latitude.toStringAsFixed(5)},${longitude.toStringAsFixed(5)}';
    requested.add(key);
    locationArguments.add(location);
    return _gates[key]?.future ?? Future.value(fixtures.weather());
  }

  @override
  Future<List<LocationCandidate>> searchLocations(
      {required String query, int limit = 5}) async {
    queries.add(query);
    return searchResult;
  }
}
