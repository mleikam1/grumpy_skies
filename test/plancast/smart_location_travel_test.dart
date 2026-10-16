import 'package:flutter_test/flutter_test.dart';
import 'package:grumpy_skies/features/plancast/plancast_models.dart';
import 'package:grumpy_skies/features/plancast/smart_location_travel.dart';
import 'package:grumpy_skies/models/weather_models.dart';

import 'smart_location_resolver_test.dart'
    show reference, kansas, miami, home, sample, smartEvent, resolve;

PlanCastEventWeather item(CalendarEvent event,
        {LocationSource source = LocationSource.currentArea,
        LocationCandidate area = kansas,
        bool online = false}) =>
    PlanCastEventWeather(
        event: event,
        participation:
            online ? EventParticipation.online : EventParticipation.unknown,
        resolvedLocation: ResolvedLocation(
            candidate: area,
            source: source,
            precision: LocationPrecision.area,
            evidenceQuality: LocationEvidenceQuality.assumed,
            reason: 'Area context',
            resolvedAt: reference),
        assessment: const EventWeatherAssessment(
            coverage: ForecastCoverage.loading,
            impact: WeatherImpact.unavailable,
            explanation: 'Loading'));
ConfirmedTripContext trip(
        {String id = 'trip',
        Set<String> calendars = const {'personal'},
        DateTime? start,
        DateTime? end,
        Set<String> eventIds = const {},
        LocationCandidate area = miami}) =>
    ConfirmedTripContext(
        id: id,
        label: 'Confirmed trip',
        candidate: area,
        startUtc: start ?? reference,
        endUtc: end ?? reference.add(const Duration(hours: 48)),
        calendarIds: calendars,
        eventIds: eventIds,
        createdAt: reference);

void main() {
  group('accuracy-aware foreground travel', () {
    test(
        'first fix refreshes, real corroborated travel refreshes and groups once',
        () {
      final tracker = SmartTravelTracker();
      expect(tracker.observe(sample(), now: reference).refreshNeeded, isTrue);
      final firstAt = reference.add(const Duration(hours: 1));
      final first = tracker.observe(sample(area: miami, observedAt: firstAt),
          now: firstAt);
      expect(first.refreshNeeded, isTrue);
      expect(first.travelConfirmed, isFalse);
      final later = firstAt.add(const Duration(minutes: 6));
      final second =
          tracker.observe(sample(area: miami, observedAt: later), now: later);
      expect(second.travelConfirmed, isTrue);
      expect(second.distanceMeters, greaterThan(50000));
      final repeat = tracker.observe(
          sample(
              area: miami, observedAt: later.add(const Duration(minutes: 6))),
          now: later.add(const Duration(minutes: 6)));
      expect(repeat.travelConfirmed, isFalse);
    });
    test('adjacent municipality and GPS jitter do not prompt', () {
      final tracker = SmartTravelTracker();
      tracker.observe(sample(accuracy: 2000), now: reference);
      const adjacent = LocationCandidate(
          name: 'Neighbor city',
          country: 'US',
          lat: 39.105,
          lon: -94.58,
          source: 'device');
      final at = reference.add(const Duration(minutes: 6));
      final change = tracker.observe(
          sample(area: adjacent, accuracy: 2000, observedAt: at),
          now: at);
      expect(change.travelConfirmed, isFalse);
      expect(change.refreshNeeded, isFalse);
    });
    test('smaller material movement refreshes without a banner', () {
      final tracker = SmartTravelTracker();
      tracker.observe(sample(), now: reference);
      const nearby = LocationCandidate(
          name: 'Neighbor city',
          country: 'US',
          lat: 39.15,
          lon: -94.58,
          source: 'device');
      final at = reference.add(const Duration(minutes: 6));
      final change =
          tracker.observe(sample(area: nearby, observedAt: at), now: at);
      expect(change.refreshNeeded, isTrue);
      expect(change.travelConfirmed, isFalse);
    });
    test('uncertainty is subtracted from the travel displacement threshold',
        () {
      final tracker = SmartTravelTracker();
      tracker.observe(sample(accuracy: 20000), now: reference);
      const distant = LocationCandidate(
          name: 'Different area',
          country: 'US',
          lat: 39.65,
          lon: -94.58,
          source: 'device');
      for (final minute in [6, 12]) {
        final at = reference.add(Duration(minutes: minute));
        expect(
            tracker
                .observe(sample(area: distant, accuracy: 20000, observedAt: at),
                    now: at)
                .travelConfirmed,
            isFalse);
      }
    });
    test('same timestamp raw and enriched emissions cannot corroborate travel',
        () {
      final tracker = SmartTravelTracker();
      tracker.observe(sample(), now: reference);
      final firstAt = reference.add(const Duration(hours: 1));
      final raw = DeviceAreaSample(
          candidate: LocationCandidate(
              name: 'Your area',
              country: '',
              lat: miami.lat,
              lon: miami.lon,
              source: 'device'),
          observedAt: firstAt,
          accuracyMeters: 100);
      expect(tracker.observe(raw, now: firstAt).travelConfirmed, isFalse);
      final enriched = sample(area: miami, observedAt: firstAt);
      expect(tracker.observe(enriched, now: firstAt).travelConfirmed, isFalse);
      expect(
          tracker
              .observe(enriched, now: firstAt.add(const Duration(minutes: 6)))
              .travelConfirmed,
          isFalse);
      final nextAt = firstAt.add(const Duration(minutes: 6));
      final nextRaw = DeviceAreaSample(
          candidate: raw.candidate, observedAt: nextAt, accuracyMeters: 100);
      final corroborated = tracker.observe(nextRaw, now: nextAt);
      expect(corroborated.travelConfirmed, isTrue);
      expect(corroborated.current.candidate.name, 'Miami Beach');
    });
    test(
        'denied, stale, duplicate and out-of-order observations never announce travel',
        () {
      final tracker = SmartTravelTracker();
      tracker.observe(sample(), now: reference);
      expect(
          tracker
              .observe(sample(area: miami, permission: false), now: reference)
              .travelConfirmed,
          isFalse);
      expect(
          tracker
              .observe(
                  sample(
                      area: miami,
                      observedAt: reference.subtract(const Duration(hours: 1))),
                  now: reference)
              .refreshNeeded,
          isFalse);
      final future = reference.add(const Duration(minutes: 10));
      tracker.observe(sample(area: miami, observedAt: future), now: future);
      expect(
          tracker
              .observe(
                  sample(
                      area: miami,
                      observedAt: reference.add(const Duration(minutes: 5))),
                  now: future)
              .travelConfirmed,
          isFalse);
    });
    test('return movement can be corroborated without inventing a return date',
        () {
      final tracker = SmartTravelTracker();
      tracker.observe(sample(), now: reference);
      for (final minute in [60, 66]) {
        final at = reference.add(Duration(minutes: minute));
        tracker.observe(sample(area: miami, observedAt: at), now: at);
      }
      var at = reference.add(const Duration(days: 2));
      expect(tracker.observe(sample(observedAt: at), now: at).travelConfirmed,
          isFalse);
      at = at.add(const Duration(minutes: 6));
      expect(tracker.observe(sample(observedAt: at), now: at).travelConfirmed,
          isTrue);
    });
  });
  group('grouped notices and bounded scopes', () {
    final movement = DeviceAreaMovement(
        current: sample(area: miami),
        previous: sample(),
        travelConfirmed: true,
        refreshNeeded: true);
    test(
        'one notice counts only near-term automatic plans, never fixed or shared exclusions',
        () {
      final events = [
        item(smartEvent()),
        item(smartEvent(id: 'second')),
        item(smartEvent(id: 'home'),
            source: LocationSource.savedPlace, area: home),
        item(smartEvent(id: 'work'), source: LocationSource.calendarDefault),
        item(smartEvent(id: 'venue'),
            source: LocationSource.calendarCoordinates),
        item(smartEvent(id: 'pinned'), source: LocationSource.userOverride),
        item(smartEvent(id: 'shared', calendar: 'shared')),
        item(smartEvent(id: 'online'), online: true),
        item(smartEvent(
            id: 'future',
            start: reference.add(const Duration(days: 5)),
            end: reference.add(const Duration(days: 5, hours: 1))))
      ];
      final notice = const SmartTravelNotices().build(
          movement: movement,
          events: events,
          state: const SmartLocationState(),
          now: reference,
          calendarIds: {'personal'});
      expect(notice!.affectedCount, 2);
      expect(notice.windowEnd.difference(notice.windowStart),
          const Duration(hours: 48));
      expect(notice.message,
          'Now using Miami Beach for 2 plans without a location.');
      final dismissed = SmartLocationState(dismissedTravelNotices: {notice.id});
      expect(
          const SmartTravelNotices().build(
              movement: movement,
              events: events,
              state: dismissed,
              now: reference.add(const Duration(minutes: 10)),
              calendarIds: {'personal'}),
          isNull);
    });
    test('ignoring a notice leaves new current-area weather already working',
        () {
      final result = resolve(smartEvent(), current: sample(area: miami));
      expect(result.location.candidate, miami);
      expect(result.location.areaAssumed, isTrue);
      expect(const SmartLocationState().rules, isEmpty);
      expect(const SmartLocationState().trips, isEmpty);
    });
    test('custom date window and selected calendars restrict affected events',
        () {
      final events = [
        item(smartEvent()),
        item(smartEvent(id: 'shared', calendar: 'shared'))
      ];
      final notice = const SmartTravelNotices().build(
          movement: movement,
          events: events,
          state: const SmartLocationState(),
          now: reference,
          windowStart: reference.add(const Duration(hours: 1)),
          windowEnd: reference.add(const Duration(hours: 4)),
          calendarIds: {'shared'});
      expect(notice!.eventIds, {'shared'});
      expect(notice.calendarIds, {'shared'});
    });
    test(
        'all-day notices use exclusive civil dates instead of midnight appointment instants',
        () {
      final localNow = reference.toLocal();
      final first = DateTime.utc(localNow.year, localNow.month, localNow.day);
      final event = CalendarEvent(
          id: 'all-day',
          nativeId: 'all-day',
          calendarId: 'personal',
          title: 'Day plan',
          startUtc: reference.subtract(const Duration(days: 2)),
          endUtc: reference.subtract(const Duration(days: 1)),
          timeZone: 'UTC',
          isAllDay: true,
          allDayStart: first,
          allDayEnd: first.add(const Duration(days: 1)));
      final notice = const SmartTravelNotices().build(
          movement: movement,
          events: [item(event)],
          state: const SmartLocationState(),
          now: reference);
      expect(notice!.eventIds, {'all-day'});
    });
    test(
        'confirmed trip is calendar and date bounded, with fixed evidence winning',
        () {
      final state = SmartLocationState(trips: [trip()]);
      expect(
          resolve(smartEvent(), state: state, current: sample())
              .location
              .source,
          LocationSource.confirmedTrip);
      expect(
          resolve(smartEvent(calendar: 'shared'),
                  state: state, current: sample())
              .location
              .source,
          LocationSource.currentArea);
      expect(
          resolve(
                  smartEvent(
                      start: reference.add(const Duration(days: 3)),
                      end: reference.add(const Duration(days: 3, hours: 1))),
                  state: state,
                  current: sample())
              .location
              .source,
          LocationSource.currentArea);
      expect(
          resolve(smartEvent(lat: home.lat, lon: home.lon),
                  state: state, current: sample())
              .location
              .source,
          LocationSource.calendarCoordinates);
      expect(
          state.prune(reference.add(const Duration(days: 3))).trips, isEmpty);
    });
    test(
        'explicit event selection prevents other shared-calendar plans being relocated',
        () {
      final state = SmartLocationState(trips: [
        trip(calendars: {'shared'}, eventIds: {'selected'})
      ]);
      expect(
          resolve(smartEvent(id: 'selected', calendar: 'shared'), state: state)
              .location
              .source,
          LocationSource.confirmedTrip);
      expect(
          resolve(smartEvent(id: 'unselected', calendar: 'shared'),
                  state: state, current: sample())
              .location
              .source,
          LocationSource.currentArea);
    });
    test('batch undo restores prior trip and preserves unrelated later edits',
        () {
      final previous = trip(area: kansas);
      final before = SmartLocationState(trips: [previous]);
      final changed = applyConfirmedTrip(before, trip());
      expect(changed.state.trips.single.candidate, miami);
      final edited = changed.state.copyWith(
          defaultArea: home,
          onlineMatchingEnabled: true,
          trips: [...changed.state.trips, trip(id: 'unrelated')]);
      final undone = changed.undo.apply(edited);
      expect(undone.trips.singleWhere((t) => t.id == 'trip').candidate, kansas);
      expect(undone.trips.any((t) => t.id == 'unrelated'), isTrue);
      expect(undone.defaultArea, home);
      expect(undone.onlineMatchingEnabled, isTrue);
    });
    test('one scope helper keeps timed notice and batch containment exact', () {
      final start = reference, end = reference.add(const Duration(hours: 48));
      expect(
          locationIntervalFits(
              start: start, end: end, windowStart: start, windowEnd: end),
          isTrue);
      expect(
          locationIntervalFits(
              start: start.subtract(const Duration(minutes: 1)),
              end: start.add(const Duration(hours: 1)),
              windowStart: start,
              windowEnd: end),
          isFalse);
      expect(
          locationIntervalFits(
              start: end.subtract(const Duration(hours: 1)),
              end: end.add(const Duration(minutes: 1)),
              windowStart: start,
              windowEnd: end),
          isFalse);
      final events = [
        item(smartEvent()),
        item(smartEvent(
            id: 'in-progress',
            start: reference.subtract(const Duration(hours: 1))))
      ];
      final notice = const SmartTravelNotices().build(
          movement: movement,
          events: events,
          state: const SmartLocationState(),
          now: reference);
      expect(notice!.eventIds, {'event'});
    });
    test(
        'all-day scope follows displayed local civil dates across DST and exclusive end',
        () {
      final windowStart = DateTime(2026, 11, 1, 12);
      final midnightEnd = DateTime(2026, 11, 3);
      final irrelevantStart = DateTime.utc(2026, 10, 31, 22),
          irrelevantEnd = DateTime.utc(2026, 11, 1, 23);
      bool fits(DateTime dayEnd, DateTime windowEnd) => locationIntervalFits(
          start: irrelevantStart,
          end: irrelevantEnd,
          windowStart: windowStart,
          windowEnd: windowEnd,
          allDayStart: DateTime.utc(2026, 11, 1),
          allDayEnd: dayEnd);
      expect(fits(DateTime.utc(2026, 11, 3), midnightEnd), isTrue);
      expect(fits(DateTime.utc(2026, 11, 4), midnightEnd), isFalse);
      expect(
          fits(DateTime.utc(2026, 11, 4), DateTime(2026, 11, 3, 12)), isTrue);
      final context =
          trip(start: windowStart.toUtc(), end: midnightEnd.toUtc());
      expect(
          context.applies(
              calendarId: 'personal',
              eventId: 'all-day',
              start: irrelevantStart,
              end: irrelevantEnd,
              now: windowStart,
              allDayStart: DateTime.utc(2026, 11, 1),
              allDayEnd: DateTime.utc(2026, 11, 3)),
          isTrue);
      expect(
          context.applies(
              calendarId: 'personal',
              eventId: 'all-day',
              start: irrelevantStart,
              end: irrelevantEnd,
              now: midnightEnd,
              allDayStart: DateTime.utc(2026, 11, 1),
              allDayEnd: DateTime.utc(2026, 11, 3)),
          isFalse);
    });
    test('invalid unbounded or calendar-free trip choices are rejected', () {
      expect(
          () => applyConfirmedTrip(
              const SmartLocationState(), trip(calendars: {})),
          throwsArgumentError);
      expect(
          () => applyConfirmedTrip(
              const SmartLocationState(), trip(end: reference)),
          throwsArgumentError);
    });
    test('dated hotel suggests an optional trip without modifying other plans',
        () {
      final event = smartEvent(
          title: 'Reservation at UNFRAMED, Miami Beach, Autograph Collection',
          lat: miami.lat,
          lon: miami.lon,
          end: reference.add(const Duration(days: 4)));
      final resolution = resolve(event);
      final suggestion = TripSuggestion.fromEvent(PlanCastEventWeather(
          event: event,
          resolvedLocation: resolution.location,
          assessment: const EventWeatherAssessment(
              coverage: ForecastCoverage.tooEarly,
              impact: WeatherImpact.unavailable,
              explanation: 'Later')));
      expect(suggestion!.startUtc, event.startUtc);
      expect(suggestion.endUtc, event.endUtc);
      expect(suggestion.calendarIds, {'personal'});
      expect(
          resolve(smartEvent(id: 'other'), current: sample()).location.source,
          LocationSource.currentArea);
    });
  });
}
