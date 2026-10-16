import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:grumpy_skies/features/plancast/location_resolver.dart';
import 'package:grumpy_skies/features/plancast/smart_location_lookup.dart';
import 'package:grumpy_skies/features/plancast/plancast_models.dart';
import 'package:grumpy_skies/models/weather_models.dart';
import 'package:grumpy_skies/repositories/weather_repository.dart';

import 'smart_location_resolver_test.dart' show reference, miami, smartEvent;

class LookupRepository extends WeatherRepository {
  final queries = <String>[];
  final gates = <Completer<List<LocationCandidate>>>[];
  List<LocationCandidate> results = [miami];
  bool fail = false, gated = false;
  int active = 0, maximumActive = 0;
  @override
  Future<List<LocationCandidate>> searchLocations(
      {required String query, int limit = 5}) async {
    queries.add(query);
    active++;
    if (active > maximumActive) maximumActive = active;
    try {
      if (fail) throw StateError('Provider unavailable');
      if (gated) {
        final gate = Completer<List<LocationCandidate>>();
        gates.add(gate);
        return await gate.future;
      }
      return results;
    } finally {
      active--;
    }
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

LocationLookupRequest city(String value) =>
    LocationLookupRequest(kind: LocationLookupKind.city, query: value);

void main() {
  test(
      'lookup remains off by default and does not misrepresent city search as venues',
      () async {
    final source = LookupRepository();
    final lookup = SmartLocationLookup(source, clock: () => reference);
    expect((await lookup.lookup(city('Miami Beach'), enabled: false)).status,
        LocationLookupStatus.unavailable);
    expect(
        (await lookup.lookup(
                LocationLookupRequest(
                    kind: LocationLookupKind.venue, query: 'UNFRAMED'),
                enabled: true))
            .status,
        LocationLookupStatus.unsupported);
    expect(
        (await lookup.lookup(
                LocationLookupRequest(
                    kind: LocationLookupKind.address,
                    query: '123 Private Street'),
                enabled: true))
            .status,
        LocationLookupStatus.unsupported);
    expect(lookup.supportsVenueAddress, isFalse);
    expect(source.queries, isEmpty);
  });
  test(
      'only extracted city is uploaded, never hotel title, calendar id, or schedule',
      () async {
    final source = LookupRepository();
    final lookup = SmartLocationLookup(source, clock: () => reference);
    final event = smartEvent(
        title: 'Reservation at UNFRAMED, Miami Beach, Autograph Collection',
        calendar: 'private-calendar');
    final evidence = const EventLocationExtractor().extract(event);
    for (final request in evidence.requests) {
      await lookup.lookup(request, enabled: true);
    }
    expect(source.queries, ['Miami Beach']);
    expect(lookup.cachedResults.length, 1);
  });
  test('URLs and full street addresses cannot use the city adapter', () async {
    final source = LookupRepository();
    final lookup = SmartLocationLookup(source, clock: () => reference);
    for (final query in [
      'https://private.example',
      '123 Private Street',
      'Miami Beach\nPrivate appointment'
    ]) {
      expect((await lookup.lookup(city(query), enabled: true)).status,
          LocationLookupStatus.unsupported);
    }
    expect(source.queries, isEmpty);
  });
  test('coalescing and normalized memory cache share one request', () async {
    final source = LookupRepository()..gated = true;
    final lookup = SmartLocationLookup(source, clock: () => reference);
    final a = lookup.lookup(city('Miami Beach'), enabled: true);
    final b = lookup.lookup(city('  MIAMI BEACH  '), enabled: true);
    await Future<void>.delayed(Duration.zero);
    expect(source.queries, ['Miami Beach']);
    source.gates.single.complete([miami]);
    expect((await a).status, LocationLookupStatus.matched);
    expect((await b).status, LocationLookupStatus.matched);
    await lookup.lookup(city('Miami Beach'), enabled: true);
    expect(source.queries.length, 1);
  });
  test('ambiguous same-name places never pick the first provider result',
      () async {
    final source = LookupRepository()
      ..results = [
        miami,
        const LocationCandidate(
            name: 'Miami Beach',
            country: 'Elsewhere',
            lat: 35,
            lon: -75,
            source: 'city')
      ];
    final result = await SmartLocationLookup(source, clock: () => reference)
        .lookup(city('Miami Beach'), enabled: true);
    expect(result.status, LocationLookupStatus.ambiguous);
    expect(result.usableAt(reference), isFalse);
  });
  test('failure cache backs off and an hourly budget limits unique queries',
      () async {
    var time = reference;
    final source = LookupRepository()..fail = true;
    final lookup =
        SmartLocationLookup(source, clock: () => time, maxRequestsPerHour: 2);
    expect((await lookup.lookup(city('Miami Beach'), enabled: true)).status,
        LocationLookupStatus.failed);
    await lookup.lookup(city('Miami Beach'), enabled: true);
    expect(source.queries.length, 1);
    await lookup.lookup(city('Chicago'), enabled: true);
    final deferred = await lookup.lookup(city('Kansas City'), enabled: true);
    expect(deferred.reason, contains('deferred'));
    expect(source.queries.length, 2);
    time = time.add(const Duration(hours: 1));
    await lookup.lookup(city('Miami Beach'), enabled: true);
    expect(source.queries.length, 3);
  });
  test('concurrency is bounded independently of the unique-query budget',
      () async {
    final source = LookupRepository()..gated = true;
    final lookup =
        SmartLocationLookup(source, clock: () => reference, maxConcurrent: 2);
    final operations = [
      for (final name in ['Miami Beach', 'Chicago', 'Kansas City'])
        lookup.lookup(city(name), enabled: true)
    ];
    await Future<void>.delayed(Duration.zero);
    expect(source.queries.length, 2);
    source.gates[0].complete([]);
    await Future<void>.delayed(Duration.zero);
    expect(source.queries.length, 3);
    source.gates[1].complete([]);
    source.gates[2].complete([]);
    await Future.wait(operations);
    expect(source.maximumActive, 2);
  });
  test(
      'clearing rejects queued lookups and late results cannot resurrect private cache',
      () async {
    final source = LookupRepository()..gated = true;
    final lookup =
        SmartLocationLookup(source, clock: () => reference, maxConcurrent: 1);
    final first = lookup.lookup(city('Miami Beach'), enabled: true);
    final queued = lookup.lookup(city('Chicago'), enabled: true);
    await Future<void>.delayed(Duration.zero);
    lookup.clear();
    source.gates.single.complete([miami]);
    await first;
    expect((await queued).status, LocationLookupStatus.unavailable);
    expect(source.queries, ['Miami Beach']);
    expect(lookup.cachedResults, isEmpty);
  });
  test('fresh cache expires independently of persistent user location choices',
      () async {
    var time = reference;
    final source = LookupRepository();
    final lookup = SmartLocationLookup(source,
        clock: () => time,
        successLifetime: const Duration(minutes: 1),
        maxEntries: 1);
    await lookup.lookup(city('Miami Beach'), enabled: true);
    expect(lookup.cachedResults.length, 1);
    time = time.add(const Duration(minutes: 2));
    expect(lookup.cachedResults, isEmpty);
    await lookup.lookup(city('Miami Beach'), enabled: true);
    expect(source.queries.length, 2);
  });
}
