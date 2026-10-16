import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:grumpy_skies/features/plancast/platform/plancast_platform.dart';
import 'package:grumpy_skies/main.dart' as app;

/// Run only on a dedicated simulator/emulator. This test does not request any
/// permission, read or seed personal events, schedule notices, or start speech.
/// With PLANCAST_VERIFY_EMPTY_CALENDAR=true, it reads the dedicated empty native
/// calendar store after access is granted externally; it never writes events.
/// The ordinary app launch can update its normal local preferences, and a denied
/// calendar status purges PlanCast state, so never run against a personal install.
/// Without read access, a synthetic protected-write attempt must be rejected
/// natively and leave PlanCast preferences absent.
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  testWidgets('native PlanCast bridge and normal launch do not request access',
      (tester) async {
    expect(kIsWeb, isFalse);
    final bridge = PlanCastPlatform();
    expect(bridge.supported, isTrue);
    final before = await bridge.calendarPermission();
    const expectedPermission =
        String.fromEnvironment('PLANCAST_EXPECTED_CALENDAR_PERMISSION');
    if (expectedPermission.isNotEmpty) {
      expect(before, expectedPermission,
          reason: 'Native status must match the isolated test device grant.');
    }
    expect(
        before,
        isIn([
          'notDetermined',
          'denied',
          'restricted',
          'writeOnly',
          'authorized'
        ]));
    expect(await bridge.notificationPermission(),
        isIn(['notDetermined', 'denied', 'authorized']));
    expect(await bridge.speechStatus(), isIn(['available', 'unavailable']));
    if (before != 'authorized') {
      await expectLater(bridge.secureWrite('{"nativeBoundaryProbe":true}'),
          throwsA(isA<PlatformException>()));
      expect(await bridge.secureRead(), isNull,
          reason: 'A denied native write must not resurrect PlanCast state.');
    }
    final now = DateTime.now().toUtc();
    expect(
        await bridge.events(
            calendarIds: [],
            start: now,
            end: now.add(const Duration(days: 14))),
        isEmpty);
    await expectLater(
        bridge.events(
            calendarIds: ['test-never-queried'],
            start: now,
            end: now.add(const Duration(days: 365))),
        throwsArgumentError);
    const verifyEmptyCalendar =
        bool.fromEnvironment('PLANCAST_VERIFY_EMPTY_CALENDAR');
    if (verifyEmptyCalendar) {
      expect(before, 'authorized',
          reason: 'Empty-store verification requires an external test grant.');
      final calendars = await bridge.calendars();
      final selectedIds = calendars
          .map((calendar) => calendar['id'])
          .whereType<String>()
          .toList(growable: false);
      final events = await bridge.events(
          calendarIds: selectedIds,
          start: now.subtract(const Duration(days: 1)),
          end: now.add(const Duration(days: 14)));
      expect(events, isEmpty,
          reason: 'This explicit check is only for a new empty test device.');
      debugPrint(
          'PLANCAST_NATIVE_EMPTY_STORE calendars=${selectedIds.length}; zero instances.');
    }
    // Launch this checkout's ordinary production dependency/routing graph.
    app.main();
    for (var i = 0;
        i < 100 && find.byType(MaterialApp).evaluate().isEmpty;
        i++) {
      await tester.pump(const Duration(milliseconds: 100));
      await Future<void>.delayed(const Duration(milliseconds: 100));
    }
    expect(find.byType(MaterialApp), findsOneWidget);
    expect(await bridge.calendarPermission(), before,
        reason:
            'Opening the normal app must not prompt for calendar permission.');
    debugPrint(
        'PLANCAST_NATIVE_SMOKE permission=$before unchanged; native speech capability and notification status readable. No permission requested.');
    // Brief window for an external simulator screenshot of the real app.
    for (var i = 0; i < 30; i++) {
      await Future<void>.delayed(const Duration(milliseconds: 250));
      await tester.pump();
    }
  }, timeout: const Timeout(Duration(minutes: 2)));
}
