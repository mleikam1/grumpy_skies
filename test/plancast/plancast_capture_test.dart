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
import 'package:grumpy_skies/models/app_appearance.dart';
import 'package:grumpy_skies/features/forecast/widgets/forecast_daily_strip.dart';
import 'package:grumpy_skies/features/forecast/widgets/forecast_hourly_list.dart';
import 'package:grumpy_skies/features/plancast/plancast_controller.dart';
import 'package:grumpy_skies/features/plancast/screens/plancast_screen.dart';
import 'package:grumpy_skies/shared/widgets/dm_bottom_nav.dart';
import 'package:grumpy_skies/features/plancast/widgets/plancast_card.dart';
import 'package:grumpy_skies/preview/approved_fixture.dart';
import 'package:grumpy_skies/preview/approved_preview.dart';
import '../../integration_test/plancast_smart_locations_preview.dart';

const _captureRoot = String.fromEnvironment('PLANCAST_CAPTURE_ROOT');
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
  for (var i = 0; i < 8; i++) {
    await tester.pump(const Duration(milliseconds: 80));
    await tester
        .runAsync(() => Future<void>.delayed(const Duration(milliseconds: 25)));
  }
}

Future<void> _save(WidgetTester tester, GlobalKey key, String name) async {
  if (_captureRoot.isEmpty) return;
  await tester.runAsync(() async {
    final render =
        key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
    final image = await render.toImage(pixelRatio: 2);
    final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
    final file = File('$_captureRoot/$name.png');
    await file.parent.create(recursive: true);
    await file.writeAsBytes(bytes!.buffer.asUint8List());
    image.dispose();
  });
}

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));
  for (final dark in [false, true]) {
    for (final width in [360.0, 390.0, 430.0]) {
      for (final scale in width == 390 ? [1.0, 2.0] : [1.0]) {
        testWidgets(
            'PlanCast real widgets width=$width dark=$dark scale=$scale',
            (tester) async {
          final controller = PlanCastController(
              weatherRepository:
                  PlanCastPreviewWeather(() => ApprovedFixture.now),
              platform: PlanCastPreviewPlatform(),
              deviceAreaService: PlanCastPreviewArea(ApprovedFixture.now),
              clock: () => ApprovedFixture.now);
          final session = ApprovedPreviewSession(
              appearance: dark ? AppAppearance.dark : AppAppearance.light);
          final router = session.router;
          final boundary = GlobalKey();
          tester.view.physicalSize = Size(width, 930);
          tester.view.devicePixelRatio = 1;
          addTearDown(tester.view.resetPhysicalSize);
          addTearDown(tester.view.resetDevicePixelRatio);
          await controller.initialize();
          await session.initialize();
          await tester.runAsync(() async {
            await _loadFonts();
            await tester.pumpWidget(ChangeNotifierProvider.value(
                value: controller,
                child: session.build(
                    routerOverride: router,
                    captureKey: boundary,
                    textScale: scale,
                    reducedMotion: true)));
          });
          await _frames(tester);
          final name =
              '${dark ? 'dark' : 'light'}_${width.toInt()}_${scale == 2 ? 'large' : 'normal'}';
          if (width == 390 && scale == 1) {
            await _save(tester, boundary, 'widget_today_top_$name');
            // These existing sections keep their original order and components.
            expect(
                tester.getTopLeft(find.byType(ForecastDailyStrip)).dy,
                lessThan(
                    tester.getTopLeft(find.byType(ForecastHourlyList)).dy));
            expect(find.byType(PlanCastCard), findsNothing);
          }
          await tester.tap(find.bySemanticsLabel('PlanCast tab'));
          await _frames(tester);
          expect(find.byType(PlanCastScreen), findsOneWidget);
          expect(
              tester.widget<DmBottomNav>(find.byType(DmBottomNav)).currentIndex,
              1);
          expect(router.routeInformationProvider.value.uri.path,
              AppRoutes.planCast);
          await _save(tester, boundary, 'widget_agenda_$name');
          expect(tester.takeException(), isNull);
          await tester.tap(find.widgetWithText(ChoiceChip, 'Tomorrow'));
          await _frames(tester);
          await _save(tester, boundary, 'widget_tomorrow_$name');
          expect(tester.takeException(), isNull);
          await tester.pumpWidget(const SizedBox.shrink());
          controller.dispose();
          session.dispose();
        });
      }
    }
  }
}
