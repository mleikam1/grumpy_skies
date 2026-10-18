import 'dart:io';
import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:grumpy_skies/monetization/sponsor_copy.dart';

import 'monetization_test_helpers.dart';

class AlwaysSelectRandom implements Random {
  int doubles = 0;
  @override
  bool nextBool() => true;
  @override
  double nextDouble() {
    doubles++;
    return 0;
  }

  @override
  int nextInt(int max) => 0;
}

void main() {
  late List<EditorialAside> catalog;
  late MemoryMonetizationStorage storage;
  late AlwaysSelectRandom random;
  late SponsorCopySelector selector;

  setUp(() async {
    catalog = EditorialAside.parseCatalog(
        File(SponsorCopySelector.assetPath).readAsStringSync());
    storage = MemoryMonetizationStorage();
    random = AlwaysSelectRandom();
    selector =
        SponsorCopySelector(storage: storage, catalog: catalog, random: random);
    await selector.initialize(sessionId: 'session-2');
  });

  Future<EditorialAside?> choose(String visit,
          {bool enabled = true,
          bool web = false,
          bool severe = false,
          bool fresh = true,
          bool known = true}) =>
      selector.chooseForVisit(
          visitId: visit,
          enabled: enabled,
          isWeb: web,
          severeWarning: severe,
          safetyFresh: fresh,
          safetyKnown: known);

  test('bundled catalog retains ten neutral lines without persona attribution',
      () {
    expect(catalog, hasLength(10));
    expect(catalog.map((line) => line.text).toSet(), hasLength(10));
    expect(
        catalog.any((line) =>
            RegExp(r'Karen|Frat Bro|Grandpa|Politician|2-Year-Old')
                .hasMatch(line.text)),
        isFalse);
  });

  test('choose only once per visit; cap two persists across a process restart',
      () async {
    final first = await choose('visit1');
    expect(first, isNotNull);
    expect(identical(await choose('visit1'), first), isTrue);
    expect(random.doubles, 1);
    final second = await choose('visit2');
    expect(second, isNotNull);
    expect(first!.id, isNot(second!.id));
    expect(await choose('visit3'), isNull);
    selector =
        SponsorCopySelector(storage: storage, catalog: catalog, random: random);
    await selector.initialize(sessionId: 'session-2');
    expect(await choose('visit4'), isNull);
    await selector.setSession('session-3');
    final next = await choose('visit5');
    expect(next, isNotNull);
    expect(next!.id, isNot(first.id));
    expect(next.id, isNot(second.id));
  });

  test('kill switch, web, severe and unknown/stale safety suppress cached copy',
      () async {
    expect(await choose('visit'), isNotNull);
    expect(await choose('visit', enabled: false), isNull);
    expect(await choose('visit', web: true), isNull);
    expect(await choose('visit', severe: true), isNull);
    expect(await choose('visit', fresh: false), isNull);
    expect(await choose('visit', known: false), isNull);
  });

  test('frequency and session cap cannot be configured above baseline', () {
    final other = SponsorCopySelector(
        storage: storage, catalog: catalog, probability: 1, maxPerSession: 100);
    expect(other.probability, .25);
    expect(other.maxPerSession, 2);
  });

  test('neutral catalog cycles without exhausting or repeating consecutively',
      () async {
    final selected = <String>[];
    for (var visit = 0; visit < 24; visit++) {
      await selector.setSession('session-${100 + visit ~/ 2}');
      final choice = await choose('visit-$visit');
      expect(choice, isNotNull);
      selected.add(choice!.id);
    }
    // The retained ten shared lines are used before recycling.
    expect(selected.take(10).toSet(), hasLength(10));
    expect(selected[10], selected.first);
    for (var index = 1; index < selected.length; index++) {
      expect(selected[index], isNot(selected[index - 1]));
    }
  });

  test('unwritable history suppresses asides instead of repeating on restart',
      () async {
    storage.failWrites = true;
    expect(await choose('visit'), isNull);
    expect(await choose('visit'), isNull);
  });
}
