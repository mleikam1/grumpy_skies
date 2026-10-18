import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:grumpy_skies/config/app_routes.dart';
import 'package:grumpy_skies/features/forecast/widgets/forecast_daily_strip.dart';
import 'package:grumpy_skies/features/forecast/widgets/forecast_hourly_list.dart';
import 'package:grumpy_skies/features/forecast/widgets/forecast_insight_card.dart';
import 'package:grumpy_skies/features/guidance/guidance_controller.dart';
import 'package:grumpy_skies/features/guidance/widgets/guidance_preferences_tile.dart';
import 'package:grumpy_skies/features/guidance/widgets/guidance_view.dart';
import 'package:grumpy_skies/features/plancast/plancast_controller.dart';
import 'package:grumpy_skies/models/app_appearance.dart';
import 'package:grumpy_skies/models/guidance_preferences.dart';
import 'package:grumpy_skies/preview/approved_fixture.dart';
import 'package:grumpy_skies/preview/approved_preview.dart';
import '../../integration_test/plancast_smart_locations_preview.dart';
import 'guidance_test_support.dart';

const _root = String.fromEnvironment('GUIDANCE_CAPTURE_ROOT');
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
  if (_root.isEmpty) return;
  await tester.runAsync(() async {
    final render =
        key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
    final image = await render.toImage(pixelRatio: 2);
    final data = await image.toByteData(format: ui.ImageByteFormat.png);
    final file = File('$_root/$name.png');
    await file.parent.create(recursive: true);
    await file.writeAsBytes(data!.buffer.asUint8List());
    image.dispose();
  });
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => SharedPreferences.setMockInitialValues({}));
  for (final dark in [false, true]) {
    for (final scenario in [
      'rain',
      'activity',
      'alert',
      'unavailable',
      'large_text'
    ]) {
      testWidgets('guidance capture $scenario dark=$dark', (tester) async {
        final size = scenario == 'activity'
            ? const Size(360, 930)
            : const Size(390, 930);
        tester.view.physicalSize = size;
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        final session = ApprovedPreviewSession(
            appearance: dark ? AppAppearance.dark : AppAppearance.light);
        session.weather.bundleOverride = guidanceTestBundle(
            alert: scenario == 'alert',
            stale: scenario == 'unavailable',
            missing: scenario == 'unavailable',
            heat: scenario == 'activity');
        final guidance = GuidanceController(
            catalog: testGuidanceCatalog(), clock: () => ApprovedFixture.now);
        final planCast = PlanCastController(
            weatherRepository:
                PlanCastPreviewWeather(() => ApprovedFixture.now),
            platform: PlanCastPreviewPlatform(),
            deviceAreaService: PlanCastPreviewArea(ApprovedFixture.now),
            clock: () => ApprovedFixture.now);
        await planCast.initialize();
        await session.initialize();
        session.settings.setGuidancePreferences(const GuidancePreferences(
            dogWalking: true, cycling: true, driving: true));
        final key = GlobalKey();
        await tester.runAsync(() async {
          await _loadFonts();
          await tester.pumpWidget(MultiProvider(
              providers: [
                ChangeNotifierProvider.value(value: guidance),
                ChangeNotifierProvider.value(value: planCast),
              ],
              child: session.build(
                  captureKey: key,
                  reducedMotion: true,
                  textScale: scenario == 'large_text' ? 2 : 1)));
        });
        await _frames(tester);
        final prefix = '${dark ? 'dark' : 'light'}_$scenario';
        await _save(tester, key, '${prefix}_today');
        await tester.ensureVisible(find.byType(ForecastInsightCard));
        await _frames(tester);
        await _save(tester, key, '${prefix}_tip');
        if (scenario == 'rain') {
          final why = find.descendant(
              of: find.byType(ForecastInsightCard),
              matching: find.byType(GuidanceView));
          expect(why, findsOneWidget);
          await tester.tap(why);
          await _frames(tester);
          expect(find.text('Why this tip?'), findsOneWidget);
          await _save(tester, key, '${prefix}_why');
          await tester.tap(find.byTooltip('Close tip details'));
          await _frames(tester);
          for (final type in [ForecastDailyStrip, ForecastHourlyList]) {
            final section = find.byType(type);
            await tester.ensureVisible(section);
            await _frames(tester);
            final action =
                find.descendant(of: section, matching: find.text('See all'));
            await tester.ensureVisible(action);
            await tester.tap(action);
            await _frames(tester);
            await _save(tester, key,
                '${prefix}_${type == ForecastDailyStrip ? 'daily' : 'hourly'}');
            await tester.tap(find.byTooltip('Close forecast'));
            await _frames(tester);
          }
          session.router.go(AppRoutes.settings);
          await _frames(tester);
          final preferences = find.byType(GuidancePreferencesTile);
          await tester.ensureVisible(preferences);
          await tester.tap(preferences);
          await _frames(tester);
          await _save(tester, key, '${prefix}_preferences');
          await tester.tap(find.byTooltip('Close tip preferences'));
          session.router.go(AppRoutes.planCast);
          await _frames(tester);
          await _save(tester, key, '${prefix}_plancast');
        }
        await tester.pumpWidget(const SizedBox.shrink());
        guidance.dispose();
        planCast.dispose();
        session.dispose();
        await tester.pump();
      });
    }
  }
}
