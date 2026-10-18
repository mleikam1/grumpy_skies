import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:grumpy_skies/config/app_routes.dart';
import 'package:grumpy_skies/features/radar/radar_screen.dart';
import 'package:grumpy_skies/models/weather_models.dart';
import 'package:grumpy_skies/shared/widgets/dm_bottom_nav.dart';

import 'helpers/radar_test_harness.dart';

Future<void> _tab(WidgetTester tester, String label) async {
  await tester.tap(find.descendant(
      of: find.byType(DmBottomNav), matching: find.text(label)));
  await RadarTestHarness.settle(tester);
  // Navigator keeps outgoing pages mounted through its route transition.
  // Assert offscreen ownership only after that transition has actually ended.
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('shell creates no radar work before the first Radar visit',
      (tester) async {
    final h = RadarTestHarness(productionOwnership: true);
    await h.pump(tester, initialRoute: AppRoutes.forecast);
    expect(find.byType(RadarScreen), findsNothing);
    expect(h.session!.controller, isNull);
    expect(h.counts, isEmpty);
    await tester.pump(const Duration(minutes: 2));
    expect(h.session!.controller, isNull);
    expect(h.counts, isEmpty);
    await _tab(tester, 'Radar');
    final owner = h.radar;
    expect(h.metadataRequests, 1);
    expect(owner.hasRefreshTimer, isTrue);
    await h.dispose(tester);
    expect(h.session!.controller, isNull);
    expect(owner.hasRefreshTimer, isFalse);
    expect(owner.hasPlaybackTimer, isFalse);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
      'real tab navigation retains per-mode selection with one inactive owner',
      (tester) async {
    final h = RadarTestHarness(productionOwnership: true);
    await h.pump(tester);
    final session = h.session;
    final owner = h.radar;
    owner.selectIndex(1);
    await tester.pump();
    final observed = owner.selectedFrame!.timestamp;
    await tester.tap(find.bySemanticsLabel('Show FutureCast'));
    await RadarTestHarness.settle(tester);
    owner.selectIndex(2);
    await RadarTestHarness.settle(tester);
    final forecast = owner.selectedFrame!.timestamp;
    expect(owner.mode, RadarMode.futureCast);
    expect(h.metadataRequests, 2);
    owner.togglePlayback();
    await tester.pump();
    expect(owner.playing, isTrue);

    for (final destination in ['Today', 'PlanCast', 'Fun', 'Today']) {
      await _tab(tester, destination);
      expect(find.byType(RadarScreen), findsNothing);
      expect(identical(h.session, session), isTrue);
      expect(identical(h.session!.controller, owner), isTrue);
      expect(owner.active, isFalse);
      expect(owner.playing, isFalse);
      expect(owner.hasPlaybackTimer, isFalse);
      expect(owner.hasRefreshTimer, isFalse);
      final requests = Map<String, int>.of(h.counts);
      await tester.pump(const Duration(minutes: 2));
      expect(h.counts, requests);
      expect(owner.selectedFrame!.timestamp, forecast);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pump();
      expect(owner.hasRefreshTimer, isFalse);
      expect(owner.hasPlaybackTimer, isFalse);

      await _tab(tester, 'Radar');
      expect(identical(h.session!.controller, owner), isTrue);
      expect(owner.mode, RadarMode.futureCast);
      expect(owner.selectedFrame!.timestamp, forecast);
      expect(owner.playing, isFalse);
      expect(owner.hasPlaybackTimer, isFalse);
      expect(owner.hasRefreshTimer, isTrue);
      // Fixed source clock and still-usable cached metadata: returning to a tab
      // must not itself request weather or reconstruct a fresh timeline owner.
      expect(h.metadataRequests, 2);
    }
    await tester.tap(find.bySemanticsLabel('Show Live Radar'));
    await RadarTestHarness.settle(tester);
    expect(owner.selectedFrame!.timestamp, observed);
    expect(owner.mode, RadarMode.usForecast);
    expect(h.metadataRequests, 2);
    owner.togglePlayback();
    await tester.pump(const Duration(milliseconds: 901));
    expect(owner.selectedIndex, 2,
        reason: 'Exactly one scheduler advances one frame after returning.');
    expect(tester.takeException(), isNull);
    await h.dispose(tester);
    expect(owner.hasPlaybackTimer, isFalse);
    expect(owner.hasRefreshTimer, isFalse);
  });
}
