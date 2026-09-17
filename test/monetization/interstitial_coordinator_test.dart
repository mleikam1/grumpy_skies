import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:grumpy_skies/monetization/interstitial_coordinator.dart';
import 'package:grumpy_skies/monetization/interstitial_policy.dart';

import 'monetization_test_helpers.dart';

class FakeInterstitial implements LoadedInterstitial {
  int shows = 0;
  int disposals = 0;
  bool throwOnShow = false;
  void Function()? shown;
  void Function()? dismissed;
  void Function(Object)? failed;

  @override
  Future<void> show(
      {required void Function() onShown,
      required void Function() onDismissed,
      required void Function(Object error) onFailed}) async {
    shows++;
    if (throwOnShow) throw StateError('SDK presentation failed');
    shown = onShown;
    dismissed = onDismissed;
    failed = onFailed;
  }

  @override
  Future<void> dispose() async {
    disposals++;
  }
}

class FakeLoader implements InterstitialLoader {
  final pending = <Completer<LoadedInterstitial>>[];
  @override
  Future<LoadedInterstitial> load() {
    final completer = Completer<LoadedInterstitial>();
    pending.add(completer);
    return completer.future;
  }
}

Future<void> callbacks() => Future<void>.delayed(Duration.zero);

void main() {
  late PolicyFixture f;
  late FakeLoader loader;
  late InterstitialCoordinator coordinator;
  late InterstitialGates gates;
  late List<String> events;
  late int navigations;
  late int safetyNotifications;

  setUp(() async {
    f = PolicyFixture();
    await f.makeEligible();
    loader = FakeLoader();
    gates = allowedGates;
    events = [];
    navigations = 0;
    safetyNotifications = 0;
    coordinator = InterstitialCoordinator(
        policy: f.policy,
        loader: loader,
        gates: () => gates,
        report: (event, reason) => events.add('$event:${reason ?? ''}'),
        onAfterDismissal: () => safetyNotifications++);
  });

  Future<FakeInterstitial> ready() async {
    final loading = coordinator.preload();
    final ad = FakeInterstitial();
    loader.pending.last.complete(ad);
    await loading;
    return ad;
  }

  test(
      'duplicate preloads issue one request; loaded is never shown or an impression',
      () async {
    final first = coordinator.preload();
    await coordinator.preload();
    expect(loader.pending, hasLength(1));
    final ad = FakeInterstitial();
    loader.pending.single.complete(ad);
    await first;
    await coordinator.preload();
    expect(loader.pending, hasLength(1));
    expect(ad.shows, 0);
    expect(events, ['request:', 'loaded:']);
    expect(f.policy.sessionShownCount, 0);
  });

  test('missing inventory continues immediately and late load is disposed',
      () async {
    final loading = coordinator.preload();
    await coordinator.completeTransition(
        continueNavigation: () => navigations++);
    expect(navigations, 1);
    final ad = FakeInterstitial();
    loader.pending.single.complete(ad);
    await loading;
    expect(ad.disposals, 1);
    expect(ad.shows, 0);
    expect(coordinator.isReady, isFalse);
  });

  test('double taps and overlapping callbacks show once and continue once',
      () async {
    final ad = await ready();
    final first =
        coordinator.completeTransition(continueNavigation: () => navigations++);
    final second =
        coordinator.completeTransition(continueNavigation: () => navigations++);
    expect(identical(first, second), isTrue);
    await callbacks();
    expect(ad.shows, 1);
    expect(navigations, 0);
    ad.shown!();
    ad.shown!();
    ad.dismissed!();
    ad.failed!(StateError('late duplicate failure'));
    ad.dismissed!();
    await first;
    expect(f.policy.sessionShownCount, 1);
    expect(f.policy.shownHistory, hasLength(1));
    expect(navigations, 1);
    expect(ad.disposals, 1);
    expect(safetyNotifications, 1);
  });

  test('failure releases reservation and preserves task count and caps',
      () async {
    final ad = await ready();
    final result =
        coordinator.completeTransition(continueNavigation: () => navigations++);
    await callbacks();
    ad.failed!(StateError('could not show'));
    ad.dismissed!();
    await result;
    expect(navigations, 1);
    expect(ad.disposals, 1);
    expect(f.policy.shownHistory, isEmpty);
    expect(f.policy.completedTaskCount, 3);
    expect(f.policy.eligibility(allowedGates), isNull);
  });

  test('synchronous SDK failure cannot strand navigation', () async {
    final ad = await ready();
    ad.throwOnShow = true;
    await coordinator.completeTransition(
        continueNavigation: () => navigations++);
    expect(navigations, 1);
    expect(ad.disposals, 1);
    expect(f.policy.sessionShownCount, 0);
  });

  test('consent revocation before transition discards ready inventory',
      () async {
    final ad = await ready();
    gates = testGates(consentAllowed: false);
    await coordinator.completeTransition(
        continueNavigation: () => navigations++);
    expect(ad.shows, 0);
    expect(ad.disposals, 1);
    expect(navigations, 1);
  });

  test('all mutable gates are rechecked after reservation persistence',
      () async {
    for (final changed in [
      testGates(consentAllowed: false),
      testGates(modalActive: true),
      testGates(foreground: false),
      testGates(safetyKnown: false),
      testGates(safetyFresh: false),
      testGates(severeWarning: true),
      testGates(configEnabled: false),
      testGates(adFree: true),
      testGates(holdout: true)
    ]) {
      gates = allowedGates;
      coordinator = InterstitialCoordinator(
          policy: f.policy, loader: loader, gates: () => gates);
      final ad = await ready();
      final result = coordinator.completeTransition(
          continueNavigation: () => navigations++);
      gates = changed;
      await result;
      expect(ad.shows, 0);
      expect(ad.disposals, 1);
    }
    expect(navigations, 9);
    expect(f.policy.shownHistory, isEmpty);
  });

  test('route invalidation while persisting cancels the reserved show',
      () async {
    final ad = await ready();
    final result =
        coordinator.completeTransition(continueNavigation: () => navigations++);
    coordinator.invalidate();
    await result;
    expect(ad.shows, 0);
    expect(ad.disposals, 1);
    expect(navigations, 1);
  });

  test('location/consent changes during a load discard its callback', () async {
    final loading = coordinator.preload();
    gates = testGates(safetyKnown: false);
    coordinator.invalidate();
    final ad = FakeInterstitial();
    loader.pending.single.complete(ad);
    await loading;
    expect(ad.disposals, 1);
    expect(coordinator.isReady, isFalse);
  });

  test('preloaded expiry cannot show, and failures obey request backoff',
      () async {
    final ad = await ready();
    f.time.advance(const Duration(minutes: 55));
    await coordinator.completeTransition(
        continueNavigation: () => navigations++);
    expect(ad.shows, 0);
    expect(ad.disposals, 1);
    final failure = coordinator.preload();
    loader.pending.last.completeError(StateError('no inventory'));
    await failure;
    final count = loader.pending.length;
    await coordinator.preload();
    expect(loader.pending.length, count);
    f.time.advance(const Duration(minutes: 1));
    final retry = coordinator.preload();
    expect(loader.pending.length, count + 1);
    loader.pending.last.complete(FakeInterstitial());
    await retry;
  });

  test('warning arriving during shown ad is surfaced after dismissal',
      () async {
    final ad = await ready();
    final result =
        coordinator.completeTransition(continueNavigation: () => navigations++);
    await callbacks();
    ad.shown!();
    gates = testGates(severeWarning: true);
    coordinator.invalidate();
    expect(ad.disposals, 0);
    expect(safetyNotifications, 0);
    ad.dismissed!();
    await result;
    expect(safetyNotifications, 1);
    expect(navigations, 1);
  });
}
