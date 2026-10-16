import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:grumpy_skies/features/plancast/location_resolver.dart';
import 'package:grumpy_skies/features/plancast/plancast_models.dart';
import 'package:grumpy_skies/models/weather_models.dart';

final reference = DateTime.utc(2026, 10, 16, 12);
const kansas = LocationCandidate(
    name: 'Kansas City', country: 'US', lat: 39.1, lon: -94.58, source: 'city');
const miami = LocationCandidate(
    name: 'Miami Beach',
    country: 'US',
    lat: 25.79,
    lon: -80.13,
    source: 'city');
const home = LocationCandidate(
    name: 'Home', country: '', lat: 39.09, lon: -94.59, source: 'coordinates');

CalendarEvent smartEvent(
        {String id = 'event',
        String title = 'Tree trimming',
        String location = '',
        String calendar = 'personal',
        DateTime? start,
        DateTime? end,
        double? lat,
        double? lon,
        bool recurring = false,
        String? series,
        String zone = 'America/Chicago',
        String? mapUrl}) =>
    CalendarEvent(
        id: id,
        nativeId: id,
        calendarId: calendar,
        title: title,
        startUtc: start ?? reference.add(const Duration(hours: 2)),
        endUtc: end ?? reference.add(const Duration(hours: 3)),
        timeZone: zone,
        locationText: location,
        latitude: lat,
        longitude: lon,
        isRecurring: recurring,
        recurringId: series,
        mapUrl: mapUrl);
DeviceAreaSample sample(
        {LocationCandidate area = kansas,
        DateTime? observedAt,
        double accuracy = 100,
        bool permission = true,
        bool approximate = false}) =>
    DeviceAreaSample(
        candidate: area,
        observedAt: observedAt ?? reference,
        accuracyMeters: accuracy,
        permissionGranted: permission,
        approximate: approximate,
        locality: area.name);
ScopedLocationRule rule(CalendarEvent event, LocationChoice choice,
        {LocationRuleScope scope = LocationRuleScope.occurrence,
        DateTime? expires}) =>
    ScopedLocationRule(
        id: 'rule-${scope.name}',
        scope: scope,
        targetId: scope == LocationRuleScope.seriesMissing
            ? event.seriesKey
            : scope == LocationRuleScope.calendarDefault
                ? event.calendarId
                : event.id,
        choice: choice,
        createdAt: reference,
        providerExpiresAt: expires);
LocationResolution resolve(CalendarEvent event,
        {SmartLocationState state = const SmartLocationState(),
        DeviceAreaSample? current,
        DeviceAreaSample? previous,
        EventOverride? override,
        Map<String, LocationLookupResult> results = const {},
        DateTime? at}) =>
    const SmartLocationResolver().resolve(
        event: event,
        now: at ?? reference,
        state: state,
        deviceArea: current,
        lastKnownArea: previous,
        occurrenceOverride: override,
        lookupResults: results);

void main() {
  group('actual area and precise precedence', () {
    test('locationless tree trimming works automatically with an assumed area',
        () {
      final result = resolve(smartEvent(title: 'Tree trimming with John'),
          current: sample());
      expect(result.location.source, LocationSource.currentArea);
      expect(result.location.hasWeatherBasis, isTrue);
      expect(result.location.areaAssumed, isTrue);
      expect(result.location.venueConfirmed, isFalse);
      expect(result.lookupRequests, isEmpty);
    });
    test('explicit occurrence choice outranks changed calendar coordinates',
        () {
      final event = smartEvent(lat: miami.lat, lon: miami.lon);
      final result = resolve(event,
          state: SmartLocationState(
              rules: [rule(event, const LocationChoice.place(home))]),
          current: sample());
      expect(result.location.source, LocationSource.userOverride);
      expect(result.location.candidate, home);
    });
    test('structured calendar coordinates beat the actual device area', () {
      final result = resolve(smartEvent(lat: miami.lat, lon: miami.lon),
          current: sample());
      expect(result.location.source, LocationSource.calendarCoordinates);
      expect(result.location.candidate!.lat, miami.lat);
      expect(result.location.venueConfirmed, isTrue);
    });
    test(
        'city search selection confirms intent without claiming an exact venue',
        () {
      final event = smartEvent();
      final result = resolve(event,
          state: SmartLocationState(
              rules: [rule(event, const LocationChoice.place(miami))]));
      expect(result.location.precision, LocationPrecision.city);
      expect(result.location.hasWeatherBasis, isTrue);
      expect(result.location.venueConfirmed, isFalse);
    });
    test('approximate permission provides useful area weather', () {
      final result = resolve(smartEvent(),
          current: sample(accuracy: 9000, approximate: true));
      expect(result.location.hasWeatherBasis, isTrue);
      expect(result.location.reason, contains('approximate'));
    });
    test('denied sample can only be a labelled acceptable last-known area', () {
      final result = resolve(smartEvent(), current: sample(permission: false));
      expect(result.location.source, LocationSource.lastKnownArea);
      expect(result.location.reviewSuggested, isTrue);
    });
    test('stale and excessively uncertain samples cannot claim current weather',
        () {
      final old =
          sample(observedAt: reference.subtract(const Duration(days: 2)));
      expect(resolve(smartEvent(), current: old).location.hasWeatherBasis,
          isFalse);
      expect(
          resolve(smartEvent(), current: sample(accuracy: 50000))
              .location
              .hasWeatherBasis,
          isFalse);
      expect(
          resolve(smartEvent(), current: sample(accuracy: double.nan))
              .location
              .hasWeatherBasis,
          isFalse);
    });
    test('recent last-known area is labelled after current sample ages out',
        () {
      final result = resolve(smartEvent(),
          current:
              sample(observedAt: reference.subtract(const Duration(hours: 2))));
      expect(result.location.source, LocationSource.lastKnownArea);
      expect(result.location.sourceLabel, 'Last known area');
    });
    test('one explicit default supports all missing-location plans when denied',
        () {
      const state = SmartLocationState(defaultArea: miami);
      expect(resolve(smartEvent(), state: state).location.source,
          LocationSource.defaultArea);
      expect(resolve(smartEvent(id: 'second'), state: state).location.candidate,
          miami);
      expect(resolve(smartEvent()).location.hasWeatherBasis, isFalse);
    });
    test('farther future current and default assumptions are provisional', () {
      final event = smartEvent(
          start: reference.add(const Duration(days: 5)),
          end: reference.add(const Duration(days: 5, hours: 1)));
      expect(resolve(event, current: sample()).location.provisional, isTrue);
      expect(
          resolve(event, state: const SmartLocationState(defaultArea: miami))
              .location
              .provisional,
          isTrue);
      expect(
          resolve(event,
                  state: const SmartLocationState(
                      defaultArea: miami, currentAreaFallbackEnabled: false))
              .location
              .provisional,
          isTrue);
    });
    test('a browsed default city cannot override a usable device sample', () {
      final result = resolve(smartEvent(),
          state: const SmartLocationState(defaultArea: miami),
          current: sample());
      expect(result.location.source, LocationSource.currentArea);
      expect(result.location.candidate, kansas);
    });
    test('stale provider metadata does not erase a retained user rule', () {
      final event = smartEvent();
      final result = resolve(event,
          state: SmartLocationState(rules: [
            rule(event, const LocationChoice.place(home),
                expires: reference.subtract(const Duration(days: 10)))
          ]));
      expect(result.location.candidate, home);
      expect(result.location.reviewSuggested, isTrue);
    });
  });

  group('destination extraction and privacy', () {
    test(
        'hotel title produces local venue and city, with city-only forecast useful',
        () {
      final event = smartEvent(
          title: 'Reservation at UNFRAMED, Miami Beach, Autograph Collection');
      final evidence = const EventLocationExtractor().extract(event);
      expect(evidence.venueQuery, 'UNFRAMED');
      expect(evidence.cityQuery, 'Miami Beach');
      expect(evidence.isStay, isTrue);
      final request = evidence.requests
          .singleWhere((r) => r.kind == LocationLookupKind.city);
      final result = resolve(event,
          current: sample(),
          state: const SmartLocationState(onlineMatchingEnabled: true),
          results: {
            request.key: LocationLookupResult(
                status: LocationLookupStatus.matched,
                provider: 'OpenWeather geocoding',
                observedAt: reference,
                expiresAt: reference.add(const Duration(hours: 6)),
                candidates: const [miami],
                precision: LocationPrecision.city),
          });
      expect(result.location.source, LocationSource.inferredCity);
      expect(result.location.candidate, miami);
      expect(result.location.venueConfirmed, isFalse);
      expect(result.location.reviewSuggested, isTrue);
    });
    test('unresolved hotel destination never silently becomes local weather',
        () {
      final event = smartEvent(
          title: 'Reservation at UNFRAMED, Miami Beach, Autograph Collection');
      final result = resolve(event, current: sample());
      expect(result.location.hasWeatherBasis, isFalse);
      expect(result.lookupRequests, isEmpty);
      final optedIn = resolve(event,
          current: sample(),
          state: const SmartLocationState(onlineMatchingEnabled: true));
      expect(optedIn.lookupRequests.map((r) => r.query),
          ['UNFRAMED', 'Miami Beach']);
      expect(
          optedIn.lookupRequests.every((r) =>
              !r.query.contains('Reservation') &&
              !r.query.contains('Autograph')),
          isTrue);
    });
    test(
        'ambiguous and conflicting destinations are distinct from missing context',
        () {
      final event = smartEvent(location: 'Springfield');
      final request =
          const EventLocationExtractor().extract(event).requests.first;
      final result = resolve(event, current: sample(), results: {
        request.key: LocationLookupResult(
            status: LocationLookupStatus.ambiguous,
            provider: 'provider',
            observedAt: reference,
            expiresAt: reference.add(const Duration(hours: 1)))
      });
      expect(result.location.evidenceQuality, LocationEvidenceQuality.conflict);
      expect(
          resolve(smartEvent(location: 'Miami or Chicago'), current: sample())
              .location
              .hasWeatherBasis,
          isFalse);
    });
    test('sports, people and incidental cities never become title destinations',
        () {
      for (final title in [
        'Watch Miami Heat',
        'Call Paris about work',
        'Chicago office budget discussion',
        'Tree trimming with Miami Landscaping',
        'Meeting in John Smith',
        'Meeting in Paris Hilton',
        'Dinner in Miami Landscaping'
      ]) {
        expect(
            resolve(smartEvent(title: title), current: sample())
                .location
                .source,
            LocationSource.currentArea,
            reason: title);
      }
    });
    test('map text retains destination intent without fetching a link', () {
      final event =
          smartEvent(location: 'https://maps.google.com/?q=Miami%20Beach');
      final result = resolve(event,
          current: sample(),
          state: const SmartLocationState(onlineMatchingEnabled: true));
      expect(result.location.hasWeatherBasis, isFalse);
      expect(result.evidence.cityQuery, 'Miami Beach');
      expect(result.lookupRequests.single.query, 'Miami Beach');
      expect(result.lookupRequests.single.kind, LocationLookupKind.city);
      for (final link in [
        'https://maps.app.goo.gl/privateToken',
        'https://goo.gl/maps/privateToken',
        'https://www.google.com/maps/@25.79,-80.13,9z'
      ]) {
        final unresolved = resolve(smartEvent(location: link),
            current: sample(),
            state: const SmartLocationState(onlineMatchingEnabled: true));
        expect(unresolved.location.hasWeatherBasis, isFalse, reason: link);
        expect(unresolved.evidence.unresolvedMapDestination, isTrue);
        expect(unresolved.lookupRequests, isEmpty);
      }
    });
    test('conflicting map pins never select the first destination', () {
      final result = resolve(
          smartEvent(location: 'geo:25.79,-80.13 geo:39.1,-94.58'),
          current: sample());
      expect(result.location.evidenceQuality, LocationEvidenceQuality.conflict);
      expect(result.location.hasWeatherBasis, isFalse);
    });
    test('OpenStreetMap marker coordinates are distinct from map viewport', () {
      expect(
          EventLocationExtractor.coordinatesFromMapLink(
                  'https://www.openstreetmap.org/?mlat=25.79&mlon=-80.13')!
              .lat,
          25.79);
      expect(
          EventLocationExtractor.coordinatesFromMapLink(
              'https://www.openstreetmap.org/#map=12/25.79/-80.13'),
          isNull);
    });
    test(
        'conflicting or unfamiliar explicit travel destinations do not become local weather',
        () {
      final conflict = resolve(smartEvent(title: 'Flight to Miami or Chicago'),
          current: sample(),
          state: const SmartLocationState(onlineMatchingEnabled: true));
      expect(
          conflict.location.evidenceQuality, LocationEvidenceQuality.conflict);
      expect(conflict.lookupRequests, isEmpty);
      final unknown = resolve(smartEvent(title: 'Trip to Kathmandu'),
          current: sample(),
          state: const SmartLocationState(onlineMatchingEnabled: true));
      expect(unknown.location.hasWeatherBasis, isFalse);
      expect(
          unknown.lookupRequests
              .every((query) => query.kind != LocationLookupKind.city),
          isTrue);
    });
    test('event timezone never becomes location evidence', () {
      final result = resolve(smartEvent(zone: 'Asia/Tokyo'), current: sample());
      expect(result.location.candidate, kansas);
      expect(result.evidence.hasDestinationEvidence, isFalse);
    });
    test('expired or malformed lookup results cannot provide a destination',
        () {
      final event = smartEvent(location: 'Miami Beach');
      final key =
          const EventLocationExtractor().extract(event).requests.single.key;
      final result = resolve(event, current: sample(), results: {
        key: LocationLookupResult(
            status: LocationLookupStatus.matched,
            provider: 'provider',
            observedAt: reference.subtract(const Duration(days: 1)),
            expiresAt: reference,
            candidates: const [miami],
            precision: LocationPrecision.city)
      });
      expect(result.location.hasWeatherBasis, isFalse);
    });
    test(
        'map destination coordinates parse locally; arbitrary and camera links do not',
        () {
      for (final link in [
        'geo:25.79,-80.13',
        'https://maps.google.com/?q=25.79,-80.13',
        'https://maps.apple.com/?q=Hotel&ll=25.79,-80.13'
      ]) {
        final result = resolve(smartEvent(location: link), current: sample());
        expect(result.location.source, LocationSource.calendarCoordinates,
            reason: link);
        expect(result.location.candidate!.lat, 25.79);
      }
      expect(
          EventLocationExtractor.coordinatesFromMapLink(
              'https://private.example/path?q=25.79,-80.13'),
          isNull);
      expect(
          EventLocationExtractor.coordinatesFromMapLink(
              'https://www.google.com/maps/@25.79,-80.13,9z'),
          isNull);
      expect(
          EventLocationExtractor.coordinatesFromMapLink('geo:91,181'), isNull);
    });
  });

  group('participation and scoped recurring rules', () {
    test(
        'virtual-only has no location failure and hybrid retains physical weather',
        () {
      expect(
          resolve(smartEvent(location: 'https://zoom.us/j/private'),
                  current: sample())
              .isOnline,
          isTrue);
      final hybrid = resolve(
          smartEvent(
              location: 'https://zoom.us/j/private',
              lat: miami.lat,
              lon: miami.lon),
          current: sample());
      expect(hybrid.isOnline, isFalse);
      expect(hybrid.participation, EventParticipation.hybrid);
      expect(hybrid.location.hasWeatherBasis, isTrue);
      final address = resolve(
          smartEvent(
              location:
                  '123 Main Street, Miami Beach https://zoom.us/j/private'),
          current: sample());
      expect(address.participation, EventParticipation.hybrid);
      expect(address.isOnline, isFalse);
    });
    test('explicit Online and explicit physical participation take precedence',
        () {
      final online = EventOverride(
          environment: EventEnvironment.online,
          expiresAt: reference.add(const Duration(days: 1)));
      expect(
          resolve(smartEvent(lat: miami.lat, lon: miami.lon), override: online)
              .isOnline,
          isTrue);
      final physical = EventOverride(
          environment: EventEnvironment.outdoor,
          expiresAt: reference.add(const Duration(days: 1)));
      expect(
          resolve(smartEvent(location: 'Zoom'),
                  override: physical, current: sample())
              .isOnline,
          isFalse);
    });
    test(
        'series fill-missing rule precedes title inference but never a new calendar venue',
        () {
      final base = smartEvent(
          recurring: true, series: 'weekly', title: 'Meeting in Miami Beach');
      final state = SmartLocationState(rules: [
        rule(base, const LocationChoice.place(home),
            scope: LocationRuleScope.seriesMissing)
      ]);
      expect(resolve(base, state: state, current: sample()).location.source,
          LocationSource.recurringRule);
      final moved = smartEvent(
          recurring: true, series: 'weekly', location: 'Unknown new venue');
      expect(
          resolve(moved, state: state, current: sample())
              .location
              .hasWeatherBasis,
          isFalse);
      final coordinates = smartEvent(
          recurring: true, series: 'weekly', lat: miami.lat, lon: miami.lon);
      expect(resolve(coordinates, state: state).location.source,
          LocationSource.calendarCoordinates);
    });
    test('explicit physical participation beats lower-scope Online defaults',
        () {
      final event = smartEvent(recurring: true, series: 'weekly');
      final physical = EventOverride(
          environment: EventEnvironment.outdoor,
          expiresAt: reference.add(const Duration(days: 1)));
      for (final scope in [
        LocationRuleScope.seriesMissing,
        LocationRuleScope.calendarDefault
      ]) {
        final state = SmartLocationState(
            rules: [rule(event, const LocationChoice.online(), scope: scope)]);
        final result =
            resolve(event, state: state, override: physical, current: sample());
        expect(result.isOnline, isFalse, reason: scope.name);
        expect(result.participation, EventParticipation.physical);
        expect(result.location.source, LocationSource.currentArea);
      }
    });
    test('series rules do not join unrelated titles or calendars', () {
      final base = smartEvent(recurring: true, series: 'weekly');
      final state = SmartLocationState(rules: [
        rule(base, const LocationChoice.place(home),
            scope: LocationRuleScope.seriesMissing)
      ]);
      expect(
          resolve(smartEvent(id: 'unrelated', title: base.title),
                  state: state, current: sample())
              .location
              .source,
          LocationSource.currentArea);
      expect(
          resolve(
                  smartEvent(
                      recurring: true, series: 'weekly', calendar: 'shared'),
                  state: state,
                  current: sample())
              .location
              .source,
          LocationSource.currentArea);
    });
    test('saved aliases are exact intentional matches, not broad title matches',
        () {
      final state = SmartLocationState(savedPlaces: [
        SavedPlanCastPlace(
            id: 'home',
            label: 'Home',
            candidate: home,
            createdAt: reference,
            aliases: const ['Our house'])
      ]);
      expect(
          resolve(smartEvent(location: 'Our house'), state: state)
              .location
              .source,
          LocationSource.savedPlace);
      expect(
          resolve(smartEvent(title: 'Home budget'),
                  state: state, current: sample())
              .location
              .source,
          LocationSource.currentArea);
    });
    test('calendar default is an assumption and applies only to its calendar',
        () {
      final event = smartEvent();
      final state = SmartLocationState(rules: [
        rule(event, const LocationChoice.place(home),
            scope: LocationRuleScope.calendarDefault)
      ]);
      final result = resolve(event, state: state, current: sample());
      expect(result.location.source, LocationSource.calendarDefault);
      expect(result.location.areaAssumed, isTrue);
      expect(result.location.venueConfirmed, isFalse);
      expect(
          resolve(smartEvent(calendar: 'shared'),
                  state: state, current: sample())
              .location
              .source,
          LocationSource.currentArea);
    });
  });

  group('migration, signatures, and event normalization', () {
    CalendarEvent iosEvent(
            {String rawLocation = '  Clinic   Entrance ',
            String? visibleLocation,
            String calendar = 'personal',
            bool recurring = true}) =>
        CalendarEvent.fromMap({
          'id': 'old-calendar-item_1792159200000',
          'nativeEventId': 'distinct-event-identifier',
          'calendarId': calendar,
          'title': 'Private appointment',
          'startMs':
              reference.add(const Duration(hours: 2)).millisecondsSinceEpoch,
          'endMs':
              reference.add(const Duration(hours: 3)).millisecondsSinceEpoch,
          'location': visibleLocation ?? rawLocation,
          'latitude': miami.lat,
          'longitude': miami.lon,
          'isRecurring': recurring,
          if (recurring) 'recurringId': 'new-external-series-hash',
          'legacyRecurringId': 'old-calendar-item',
          'legacyLocation': rawLocation
        })!;

    test(
        'iOS migrated recurring correction retains its historical identity and unchanged location',
        () {
      final event = iosEvent();
      final oldKey = planCastId('personal|old-calendar-item|clinic entrance');
      final state = SmartLocationState.fromStorage({
        'version': 1,
        'overrides': {
          oldKey: EventOverride(
                  venue: home,
                  expiresAt: reference.subtract(const Duration(days: 2)))
              .toJson()
        }
      });
      expect(event.legacyRecurringKey, oldKey);
      expect(event.recurringKey, isNot(oldKey));
      expect(event.seriesKey, planCastId('personal|new-external-series-hash'));
      final result = resolve(event, state: state, current: sample());
      expect(result.location.source, LocationSource.recurringRule);
      expect(result.location.candidate?.toJson(), home.toJson());
      expect(result.location.reviewSuggested, isTrue);
      // A changed source location/calendar must never inherit the old correction.
      expect(
          resolve(iosEvent(rawLocation: 'Different venue'), state: state)
              .location
              .source,
          LocationSource.calendarCoordinates);
      expect(
          resolve(iosEvent(calendar: 'shared'), state: state).location.source,
          LocationSource.calendarCoordinates);
    });

    test(
        'iOS structured-title enrichment and nonrecurring identity keep legacy intent',
        () {
      final event = iosEvent(
          rawLocation: '',
          visibleLocation: 'Structured venue',
          recurring: false);
      final oldKey = planCastId('personal|old-calendar-item|');
      final state = SmartLocationState.fromStorage({
        'overrides': {
          oldKey: EventOverride(venue: home, expiresAt: reference).toJson()
        }
      });
      expect(event.isRecurring, isFalse);
      expect(event.legacyRecurringKey, oldKey);
      expect(resolve(event, state: state).location.candidate?.toJson(),
          home.toJson());
      expect(
          resolve(iosEvent(rawLocation: 'New explicit venue', recurring: false),
                  state: state)
              .location
              .source,
          LocationSource.calendarCoordinates);
    });

    test(
        'legacy identities never broaden new series rules and new explicit rules win',
        () {
      final event = CalendarEvent.fromMap({
        'id': 'old-calendar-item_1792159200000',
        'nativeEventId': 'distinct-event-identifier',
        'calendarId': 'personal',
        'startMs':
            reference.add(const Duration(hours: 2)).millisecondsSinceEpoch,
        'endMs': reference.add(const Duration(hours: 3)).millisecondsSinceEpoch,
        'isRecurring': true,
        'recurringId': 'new-external-series-hash',
        'legacyRecurringId': 'old-calendar-item',
        'legacyLocation': ''
      })!;
      final legacy = ScopedLocationRule(
          id: 'old',
          scope: LocationRuleScope.legacy,
          targetId: event.legacyRecurringKey,
          choice: const LocationChoice.place(home),
          createdAt: reference.subtract(const Duration(days: 10)));
      final wrongIdentity = ScopedLocationRule(
          id: 'not-legacy',
          scope: LocationRuleScope.seriesMissing,
          targetId: planCastId('personal|old-calendar-item'),
          choice: const LocationChoice.place(miami),
          createdAt: reference);
      expect(
          resolve(event,
                  state: SmartLocationState(rules: [wrongIdentity]),
                  current: sample())
              .location
              .source,
          LocationSource.currentArea);
      expect(
          resolve(event,
              state: SmartLocationState(rules: [
                legacy,
                rule(event, const LocationChoice.place(miami),
                    scope: LocationRuleScope.seriesMissing)
              ])).location.candidate?.toJson(),
          miami.toJson());
      expect(
          resolve(event,
              state: SmartLocationState(rules: [
                legacy,
                rule(event, const LocationChoice.place(miami))
              ])).location.source,
          LocationSource.userOverride);
    });

    test(
        'migration preserves hashed occurrence and old series intent after cache expiry',
        () {
      final event = smartEvent();
      final state = SmartLocationState.fromStorage({
        'overrides': {
          event.id: EventOverride(
                  venue: home,
                  expiresAt: reference.subtract(const Duration(days: 10)))
              .toJson()
        },
        'selectedCalendars': ['personal']
      });
      expect(state.rules.single.scope, LocationRuleScope.legacy);
      expect(resolve(event, state: state).location.candidate!.toJson(),
          home.toJson());
      final roundTrip = SmartLocationState.fromStorage({
        'stateVersion': 2,
        'smartLocations': jsonDecode(jsonEncode(state.toJson()))
      });
      expect(roundTrip.rules.single.targetId, event.id);
      expect(roundTrip.currentAreaFallbackEnabled, isTrue);
      expect(roundTrip.onlineMatchingEnabled, isFalse);
    });
    test(
        'signature is stable on rebuild but changes with meaningful location or time context',
        () {
      final event = smartEvent();
      final first = resolve(event, current: sample());
      final rebuilt = resolve(event,
          current: sample(), at: reference.add(const Duration(minutes: 1)));
      expect(first.location.signature, rebuilt.location.signature);
      expect(resolve(event, current: sample(area: miami)).location.signature,
          isNot(first.location.signature));
      expect(
          resolve(smartEvent(zone: 'Asia/Tokyo'), current: sample())
              .location
              .signature,
          isNot(first.location.signature));
      expect(event.startUtc, reference.add(const Duration(hours: 2)));
    });
    test(
        'cancelled, declined, deleted and malformed native records are excluded',
        () {
      final base = {
        'id': 'native',
        'calendarId': 'personal',
        'title': 'Private',
        'startMs': reference.millisecondsSinceEpoch,
        'endMs': reference.add(const Duration(hours: 1)).millisecondsSinceEpoch
      };
      for (final status in ['cancelled', 'canceled', 'declined', 'deleted']) {
        expect(CalendarEvent.fromMap({...base, 'status': status}), isNull);
      }
      expect(CalendarEvent.fromMap({...base, 'deleted': true}), isNull);
      expect(CalendarEvent.fromMap({...base, 'startMs': double.nan}), isNull);
      expect(
          CalendarEvent.fromMap({
            ...base,
            'isAllDay': true,
            'allDayStart': '2026-02-30',
            'allDayEnd': '2026-03-03'
          }),
          isNull);
      final normalized = CalendarEvent.fromMap({
        ...base,
        'isRecurring': true,
        'isDetached': true,
        'recurringId': 'parent',
        'originalStartMs':
            reference.subtract(const Duration(days: 7)).millisecondsSinceEpoch
      });
      expect(normalized!.isDetached, isTrue);
      expect(normalized.recurringId, 'parent');
      expect(normalized.originalStartUtc,
          reference.subtract(const Duration(days: 7)));
    });
    test('DST instants and exclusive all-day civil dates remain unchanged', () {
      final start = DateTime.utc(2026, 11, 1, 6, 30),
          end = DateTime.utc(2026, 11, 1, 7, 30);
      final event = smartEvent(start: start, end: end, zone: 'America/Chicago');
      final result = resolve(event, current: sample());
      expect(result.location.validFrom, start);
      expect(event.endUtc.difference(event.startUtc), const Duration(hours: 1));
      final allDay = CalendarEvent.fromMap({
        'id': 'day',
        'calendarId': 'personal',
        'startMs': start.millisecondsSinceEpoch,
        'endMs': end.millisecondsSinceEpoch,
        'isAllDay': true,
        'allDayStart': '2026-11-01',
        'allDayEnd': '2026-11-03'
      });
      expect(allDay!.allDayEnd, DateTime.utc(2026, 11, 3));
      expect(allDay.allDayEnd!.difference(allDay.allDayStart!),
          const Duration(days: 2));
    });
  });
}
