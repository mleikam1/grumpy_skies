// Opt-in synthetic screenshots of production PlanCast widgets. No calendar or
// weather service is contacted. GUIDANCE_CAPTURE_ROOT enables PNG output only.
import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:grumpy_skies/config/app_routes.dart';
import 'package:grumpy_skies/features/guidance/guidance_controller.dart';
import 'package:grumpy_skies/features/guidance/widgets/guidance_view.dart';
import 'package:grumpy_skies/features/plancast/plancast_controller.dart';
import 'package:grumpy_skies/features/plancast/screens/plancast_screen.dart';
import 'package:grumpy_skies/features/plancast/widgets/plancast_guidance.dart';
import 'package:grumpy_skies/models/app_appearance.dart';
import 'package:grumpy_skies/preview/approved_fixture.dart';
import 'package:grumpy_skies/preview/approved_preview.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'plancast_guidance_test.dart';

const _captureRoot = String.fromEnvironment('GUIDANCE_CAPTURE_ROOT');
Future<void>? _fonts;
Future<void> _loadFonts() => _fonts ??= () async {
      final manifest =
          jsonDecode(await rootBundle.loadString('FontManifest.json')) as List;
      for (final entry in manifest.cast<Map<String, dynamic>>()) {
        final loader = FontLoader(entry['family'] as String);
        for (final font
            in (entry['fonts'] as List).cast<Map<String, dynamic>>()) {
          loader.addFont(rootBundle.load(font['asset'] as String));
        }
        await loader.load();
      }
    }();

Future<void> _frames(WidgetTester tester) async {
  for (var i = 0; i < 6; i++) {
    await tester.pump(const Duration(milliseconds: 80));
    await tester
        .runAsync(() => Future<void>.delayed(const Duration(milliseconds: 30)));
  }
}

Future<void> _save(WidgetTester tester, GlobalKey key, String name) async {
  expect(tester.takeException(), isNull);
  if (_captureRoot.isEmpty) return;
  await tester.runAsync(() async {
    final boundary =
        key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
    final image = await boundary.toImage(pixelRatio: 2);
    final data = await image.toByteData(format: ui.ImageByteFormat.png);
    final file = File('$_captureRoot/$name.png');
    await file.parent.create(recursive: true);
    await file.writeAsBytes(data!.buffer.asUint8List());
    image.dispose();
  });
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => SharedPreferences.setMockInitialValues({}));
  for (final dark in [false, true]) {
    for (final large in [false, true]) {
      testWidgets('PlanCast actionable guidance dark=$dark large=$large',
          (tester) async {
        final now = ApprovedFixture.now;
        tester.view.physicalSize = Size(large ? 360 : 390, 930);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        final session = ApprovedPreviewSession(
            initialLocation: AppRoutes.planCast,
            appearance: dark ? AppAppearance.dark : AppAppearance.light);
        final platform = CountingGuidancePlatform()
          ..records = [
            for (final plan in [
              ('garden', 'Garden volunteering', 2),
              ('market', 'Outdoor market visit', 4),
            ])
              {
                'id': plan.$1,
                'calendarId': 'work',
                'title': plan.$2,
                'startMs':
                    now.add(Duration(hours: plan.$3)).millisecondsSinceEpoch,
                'endMs': now
                    .add(Duration(hours: plan.$3 + 1))
                    .millisecondsSinceEpoch,
                'timeZone': 'America/Chicago',
                // No invite location: actual fresh device-area evidence is
                // intentionally shown as an assumption by the real resolver.
              }
          ];
        final weather = CountingGuidanceWeather(clock: () => now);
        final area = CountingGuidanceArea(now: now);
        final plans = PlanCastController(
            weatherRepository: weather,
            platform: platform,
            deviceAreaService: area,
            clock: () => now);
        await plans.initialize();
        await plans.connect();
        await plans.selectCalendars({'work'});
        for (final item in plans.currentEvents.toList()) {
          // This is an explicit setting, never inferred from the title.
          await plans.setEventOverride(item.event,
              environment: EventEnvironment.outdoor);
        }
        await session.initialize();
        final guidance =
            GuidanceController(catalog: guidanceCatalog(), clock: () => now);
        final key = GlobalKey();
        final counts = serviceCounts(platform, weather, area);
        await tester.runAsync(() async {
          await _loadFonts();
          await tester.pumpWidget(MultiProvider(
              providers: [
                ChangeNotifierProvider.value(value: plans),
                ChangeNotifierProvider.value(value: guidance),
              ],
              child: session.build(
                  captureKey: key,
                  reducedMotion: true,
                  textScale: large ? 2 : 1)));
        });
        await _frames(tester);
        final prefix =
            'plan_${dark ? 'dark' : 'light'}_${large ? 'large' : 'normal'}';
        expect(find.text('Your day ahead'), findsOneWidget);
        await _save(tester, key, '${prefix}_readout');

        final summary = find.byType(PlanCastSummaryGuidance);
        final summaryTip =
            find.descendant(of: summary, matching: find.byType(GuidanceView));
        await tester.ensureVisible(summaryTip);
        await _frames(tester);
        expect(
            find.descendant(
                of: summaryTip, matching: find.byTooltip('Why this tip?')),
            findsOneWidget);
        expect(
            find.descendant(
                of: summaryTip,
                matching:
                    find.text('Using your current area as an assumed area')),
            findsOneWidget);
        await _save(tester, key, '${prefix}_readout_tip');

        final later = plans.currentEvents
            .singleWhere((e) => e.event.nativeId == 'market');
        final laterTile = find.byWidgetPredicate((widget) =>
            widget is PlanCastEventTile &&
            widget.item.event.id == later.event.id);
        await tester.scrollUntilVisible(laterTile, 400,
            scrollable: find.byType(Scrollable).first, maxScrolls: 20);
        final laterTip =
            find.descendant(of: laterTile, matching: find.byType(GuidanceView));
        await tester.ensureVisible(laterTip);
        await _frames(tester);
        expect(
            find.descendant(
                of: laterTip, matching: find.byTooltip('Why this tip?')),
            findsOneWidget,
            reason:
                'The later event has a different interval at the same area.');
        await _save(tester, key, '${prefix}_event_action');

        openPlanCastEvent(tester.element(find.byType(PlanCastScreen)), later);
        await _frames(tester);
        expect(find.text('Event details'), findsOneWidget);
        await _save(tester, key, '${prefix}_event_detail_top');
        final detailScaffold = find
            .ancestor(
                of: find.text('Event details'), matching: find.byType(Scaffold))
            .first;
        final detailGuidance = find.descendant(
            of: detailScaffold, matching: find.byType(PlanCastEventGuidance));
        final detailScroll = find
            .descendant(of: detailScaffold, matching: find.byType(Scrollable))
            .first;
        await tester.scrollUntilVisible(detailGuidance, 400,
            scrollable: detailScroll, maxScrolls: 20);
        final detailTip = find.descendant(
            of: detailGuidance, matching: find.byType(GuidanceView));
        await tester.ensureVisible(detailTip);
        await _frames(tester);
        expect(
            find.descendant(
                of: detailTip, matching: find.byTooltip('Why this tip?')),
            findsOneWidget);
        expect(
            find.descendant(
                of: detailTip,
                matching:
                    find.text('Using your current area as an assumed area')),
            findsOneWidget);
        await _save(tester, key, '${prefix}_event_detail');
        expect(serviceCounts(platform, weather, area), counts);
        expect(session.network.blockedRequests, 0);
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox.shrink());
        guidance.dispose();
        plans.dispose();
        session.dispose();
        await tester.pump();
      });
    }
  }
}
