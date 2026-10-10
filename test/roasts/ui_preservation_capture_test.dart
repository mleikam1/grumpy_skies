import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:grumpy_skies/config/app_routes.dart';
import 'package:grumpy_skies/models/app_appearance.dart';
import 'package:grumpy_skies/features/forecast/widgets/forecast_daily_grid.dart';
import 'package:grumpy_skies/features/forecast/widgets/forecast_hourly_strip.dart';
import 'package:grumpy_skies/features/forecast/widgets/forecast_roast_card.dart';
import 'package:grumpy_skies/features/roasts/widgets/featured_roast_card.dart';
import 'support/ui_preservation_session.dart';

const capture = bool.fromEnvironment('CAPTURE_UI_PRESERVATION');
const phase =
    String.fromEnvironment('UI_PRESERVATION_PHASE', defaultValue: 'final');
Future<void>? fonts;
Future<void> loadFonts() => fonts ??= () async {
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
Future<void> settle(WidgetTester tester) async {
  for (var i = 0; i < 8; i++) {
    await tester.pump(const Duration(milliseconds: 80));
    await tester
        .runAsync(() => Future<void>.delayed(const Duration(milliseconds: 35)));
  }
}

Future<void> save(WidgetTester tester, GlobalKey key, String name) async {
  if (!capture) return;
  await tester.runAsync(() async {
    final file = File('docs/roasts/ui_evidence/$phase/$name.png');
    if (phase == 'baseline' && file.existsSync()) {
      throw StateError('Immutable baseline exists: ${file.path}');
    }
    final boundary =
        key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
    final image = await boundary.toImage(pixelRatio: 1);
    final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
    await file.parent.create(recursive: true);
    await file.writeAsBytes(bytes!.buffer.asUint8List());
    image.dispose();
  });
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  for (final dark in [false, true]) {
    for (final device in [
      (name: 'phone', size: const Size(390, 844), scale: 1.0),
      (name: 'compact200', size: const Size(320, 844), scale: 2.0),
      (name: 'tablet', size: const Size(820, 1180), scale: 1.0)
    ]) {
      testWidgets(
          'production composition ${dark ? 'dark' : 'light'} ${device.name}',
          (tester) async {
        tester.view.physicalSize = device.size;
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        final session = UiPreservationSession(
            appearance: dark ? AppAppearance.dark : AppAppearance.light);
        final key = GlobalKey();
        final prefix = '${dark ? 'dark' : 'light'}_${device.name}';
        await tester.runAsync(() async {
          await loadFonts();
          await session.initialize();
          await tester.pumpWidget(session.build(
              captureKey: key, textScale: device.scale, reducedMotion: true));
        });
        await settle(tester);
        await save(tester, key, '${prefix}_today');
        expect(tester.takeException(), isNull);
        await tester.ensureVisible(find.byType(ForecastRoastCard));
        await settle(tester);
        await save(tester, key, '${prefix}_today_roast');
        for (final section in [
          ('hourly', find.byType(ForecastHourlyStrip)),
          ('daily', find.byType(ForecastDailyGrid))
        ]) {
          await tester.ensureVisible(section.$2);
          await settle(tester);
          await tester.tap(
              find.descendant(of: section.$2, matching: find.text('See all')));
          await settle(tester);
          expect(find.byTooltip('Close forecast'), findsOneWidget);
          expect(find.text('Fun').hitTestable(), findsNothing);
          await save(tester, key, '${prefix}_${section.$1}_sheet');
          expect(tester.takeException(), isNull);
          await tester.tap(find.byTooltip('Close forecast'));
          await settle(tester);
        }
        expect(session.weather.requestCount, 1);
        session.router.go(AppRoutes.roasts);
        await settle(tester);
        await save(tester, key, '${prefix}_roasts');
        await tester.ensureVisible(find.byType(FeaturedRoastCard));
        await settle(tester);
        await save(tester, key, '${prefix}_roasts_card');
        expect(tester.takeException(), isNull);
        for (final route in [
          ('radar', AppRoutes.radar),
          ('fun', AppRoutes.fun),
          ('appearance', AppRoutes.settings)
        ]) {
          session.router.go(route.$2);
          await settle(tester);
          if (route.$1 == 'appearance') {
            await tester.ensureVisible(find.text('Appearance'));
            await settle(tester);
          }
          await save(tester, key, '${prefix}_${route.$1}');
          expect(tester.takeException(), isNull);
        }
        await tester.pumpWidget(const SizedBox.shrink());
        session.dispose();
        await tester.pump();
      });
    }
  }
}
