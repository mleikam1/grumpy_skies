import 'package:flutter_test/flutter_test.dart';
import 'package:grumpy_skies/monetization/interstitial_policy.dart';

import 'monetization_test_helpers.dart';

void main() {
  test('first session and quick process restart cannot show', () async {
    final fixture = PolicyFixture();
    await fixture.policy.initialize();
    await fixture.completeThree();
    fixture.time.advance(const Duration(minutes: 4));
    expect(fixture.policy.eligibility(allowedGates), 'first_session');
    await fixture.policy.checkpoint();
    fixture.time.advance(const Duration(minutes: 5));
    final restored = fixture.restore();
    await restored.initialize();
    expect(restored.sessionId, fixture.policy.sessionId);
    expect(restored.eligibility(allowedGates), 'first_session');
  });

  test('requires real foreground engagement and three durable revisions',
      () async {
    final f = PolicyFixture();
    await f.startSecondSession();
    await f.completeThree();
    f.time.advance(const Duration(seconds: 179));
    expect(f.policy.eligibility(allowedGates), 'engagement');
    f.time.advance(const Duration(seconds: 1));
    expect(f.policy.eligibility(allowedGates), isNull);
  });

  test('background and external operation time do not count as engagement',
      () async {
    final f = PolicyFixture();
    await f.startSecondSession();
    final session = f.policy.sessionId;
    await f.policy.setForeground(false, externalOperation: true);
    f.time.advance(const Duration(hours: 1));
    await f.policy.setForeground(true);
    expect(f.policy.sessionId, session);
    expect(f.policy.foregroundEngagement, Duration.zero);
  });

  test('ordinary 30-minute inactivity starts a new session', () async {
    final f = PolicyFixture();
    await f.policy.initialize();
    await f.policy.setForeground(false);
    f.time.advance(const Duration(minutes: 29, seconds: 59));
    await f.policy.setForeground(true);
    expect(f.policy.sessionId, 'session-1');
    await f.policy.setForeground(false);
    f.time.advance(const Duration(minutes: 30));
    await f.policy.setForeground(true);
    expect(f.policy.sessionId, 'session-2');
  });

  test('duplicate documents/revisions stay deduplicated across ads and restart',
      () async {
    final f = PolicyFixture();
    await f.makeEligible();
    expect(
        await f.policy.recordCompletion(
            documentId: 'doc0', revisionId: 'rev1', safelyPersisted: true),
        isFalse);
    expect(
        await f.policy.recordCompletion(
            documentId: 'doc0', revisionId: 'rev2', safelyPersisted: false),
        isFalse);
    expect(f.policy.completedTaskCount, 3);
    await f.policy.markShown(f.policy.reserve(allowedGates)!);
    final restored = f.restore();
    await restored.initialize();
    expect(
        await restored.recordCompletion(
            documentId: 'doc0', revisionId: 'rev1', safelyPersisted: true),
        isFalse);
    expect(restored.completedTaskCount, 0);
    expect(
        await restored.recordCompletion(
            documentId: 'doc0', revisionId: 'rev2', safelyPersisted: true),
        isTrue);
    expect(restored.completedTaskCount, 1);
  });

  test('reservation is atomic and failures consume no caps or tasks', () async {
    final f = PolicyFixture();
    await f.makeEligible();
    final reserved = f.policy.reserve(allowedGates)!;
    expect(f.policy.reserve(allowedGates), isNull);
    expect(f.policy.eligibility(allowedGates, reservation: reserved), isNull);
    expect(f.policy.sessionShownCount, 0);
    await f.policy.release(reserved);
    expect(f.policy.completedTaskCount, 3);
    expect(f.policy.eligibility(allowedGates), isNull);
  });

  test('only one shown callback consumes caps, which survive restart',
      () async {
    final f = PolicyFixture();
    await f.makeEligible();
    final reserved = f.policy.reserve(allowedGates)!;
    await f.policy.markShown(reserved);
    await f.policy.markShown(reserved);
    expect(f.policy.shownHistory, hasLength(1));
    await f.completeThree(offset: 3);
    final restored = f.restore();
    await restored.initialize();
    expect(restored.sessionShownCount, 1);
    expect(restored.eligibility(allowedGates), 'session_cap');
  });

  test('three shown in rolling 24 hours blocks next session across restart',
      () async {
    final f = PolicyFixture();
    await f.makeEligible();
    for (var i = 0; i < 3; i++) {
      if (i > 0) {
        await f.nextSession();
        await f.completeThree(offset: i * 3);
        f.time.advance(const Duration(minutes: 3));
      }
      expect(f.policy.eligibility(allowedGates), isNull);
      await f.policy.markShown(f.policy.reserve(allowedGates)!);
    }
    await f.nextSession();
    await f.completeThree(offset: 12);
    f.time.advance(const Duration(minutes: 3));
    await f.policy.checkpoint();
    final restored = f.restore();
    await restored.initialize();
    expect(restored.eligibility(allowedGates), 'daily_cap');
    f.time.advance(const Duration(hours: 24));
    expect(restored.eligibility(allowedGates), isNull);
  });

  test('configuration can only tighten immutable limits', () {
    final limits = InterstitialLimits(
        foregroundEngagement: Duration.zero,
        meaningfulCompletions: 0,
        cooldown: Duration.zero,
        perSession: 5,
        perRollingDay: 100);
    expect(limits.foregroundEngagement.inSeconds, 180);
    expect(limits.meaningfulCompletions, 3);
    expect(limits.cooldown.inSeconds, 300);
    expect(limits.perSession, 1);
    expect(limits.perRollingDay, 3);
  });

  test('backward and forward runtime clock changes suppress conservatively',
      () async {
    for (final shift in [const Duration(hours: -1), const Duration(days: 2)]) {
      final f = PolicyFixture();
      await f.makeEligible();
      f.time.wall = f.time.wall.add(shift);
      expect(f.policy.eligibility(allowedGates), 'clock');
      await f.policy.checkpoint();
      final restored = f.restore();
      await restored.initialize();
      expect(restored.eligibility(allowedGates), 'clock');
    }
  });

  test('clock rollback between processes cannot grant caps', () async {
    final f = PolicyFixture();
    await f.makeEligible();
    await f.policy.checkpoint();
    f.time.wall = f.time.wall.subtract(const Duration(days: 2));
    final restored = f.restore();
    await restored.initialize();
    expect(restored.eligibility(allowedGates), 'clock');
  });

  test('corrupt or unwritable persistence fails closed', () async {
    final f = PolicyFixture();
    f.storage.values[InterstitialPolicy.storageKey] = '{corrupt';
    await f.policy.initialize();
    expect(f.policy.eligibility(allowedGates), 'persistence');
    final other = PolicyFixture();
    await other.makeEligible();
    other.storage.failWrites = true;
    await other.policy.checkpoint();
    expect(other.policy.eligibility(allowedGates), 'persistence');
  });

  test('interrupted presentation is uncertain, never recorded as an impression',
      () async {
    final f = PolicyFixture();
    await f.makeEligible();
    final reservation = f.policy.reserve(allowedGates)!;
    await f.policy.persistReservation(reservation);
    final restored = f.restore();
    await restored.initialize();
    expect(restored.shownHistory, isEmpty);
    expect(
        restored.eligibility(allowedGates), 'uncertain_previous_presentation');
  });

  test('every safety and privacy gate is checked at eligibility', () async {
    final f = PolicyFixture();
    await f.makeEligible();
    for (final entry in <String, InterstitialGates>{
      'platform': testGates(nativePlatform: false),
      'configuration': testGates(configEnabled: false),
      'consent': testGates(consentAllowed: false),
      'ad_free': testGates(adFree: true),
      'holdout': testGates(holdout: true),
      'onboarding': testGates(onboarding: true),
      'background': testGates(foreground: false),
      'modal': testGates(modalActive: true),
      'safety_unknown': testGates(safetyKnown: false),
      'safety_stale': testGates(safetyFresh: false),
      'severe_warning': testGates(severeWarning: true),
    }.entries) {
      expect(f.policy.eligibility(entry.value), entry.key);
    }
  });
}
