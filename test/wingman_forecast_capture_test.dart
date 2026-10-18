import 'dart:io';
import 'dart:convert';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:grumpy_skies/config/app_routes.dart';
import 'package:grumpy_skies/features/fun/meme/rendering/meme_renderer.dart';
import 'package:grumpy_skies/models/app_appearance.dart';
import 'package:grumpy_skies/preview/approved_preview.dart';
import 'package:grumpy_skies/preview/approved_fixture.dart';
import 'package:grumpy_skies/features/forecast/widgets/forecast_daily_strip.dart';
import 'package:grumpy_skies/features/forecast/widgets/forecast_hourly_list.dart';

// Opt in to writing review artifacts; normal flutter test runs only assertions.
const _capture = bool.fromEnvironment('CAPTURE_APPROVED_UI');
const _captureRoot = String.fromEnvironment('WINGMAN_CAPTURE_ROOT',
    defaultValue: 'work/wingman_screenshots');

Future<void>? _fontLoading;

// Keep engine font registrations stable across the entire capture suite.
Future<void> _loadFonts() => _fontLoading ??= _loadRegisteredFonts();

Future<void> _loadRegisteredFonts() async {
  // Widget tests default to Ahem unless the actual app font manifest is loaded.
  final manifest =
      jsonDecode(await rootBundle.loadString('FontManifest.json')) as List;
  for (final entry in manifest.cast<Map<String, dynamic>>()) {
    final loader = FontLoader(entry['family'] as String);
    for (final font in (entry['fonts'] as List).cast<Map<String, dynamic>>()) {
      loader.addFont(rootBundle.load(font['asset'] as String));
    }
    await loader.load();
  }
  await loadMemeFonts();
}

Future<void> _pumpPreview(
    WidgetTester tester, ApprovedPreviewSession session, GlobalKey boundary,
    {Size size = const Size(390, 930),
    double textScale = 1,
    bool reducedMotion = false}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  await tester.runAsync(() async {
    await _loadFonts();
    await session.initialize();
    await tester.pumpWidget(session.build(
        captureKey: boundary,
        textScale: textScale,
        reducedMotion: reducedMotion));
    await Future<void>.delayed(const Duration(milliseconds: 100));
  });
  // Decode real bundled artwork without pumpAndSettle's endless animation trap.
  for (var i = 0; i < 10; i++) {
    await tester.pump(const Duration(milliseconds: 80));
    await tester
        .runAsync(() => Future<void>.delayed(const Duration(milliseconds: 35)));
  }
  await tester.pump();
}

Future<void> _save(WidgetTester tester, GlobalKey boundary, String name) async {
  if (!_capture) return;
  await tester.runAsync(() async {
    final render =
        boundary.currentContext!.findRenderObject()! as RenderRepaintBoundary;
    final image = await render.toImage(pixelRatio: 2);
    final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
    final file = File('$_captureRoot/$name.png');
    await file.parent.create(recursive: true);
    await file.writeAsBytes(bytes!.buffer.asUint8List());
    image.dispose();
  });
}

Future<void> _finish(
    WidgetTester tester, ApprovedPreviewSession session) async {
  await tester.pumpWidget(const SizedBox.shrink());
  session.dispose();
  await tester.pump();
}

void main() {
  for (final dark in [false, true]) {
    final theme = dark ? 'dark' : 'light';
    testWidgets('Wingman real forecast below fold $theme', (tester) async {
      final session = ApprovedPreviewSession(
          initialLocation: AppRoutes.forecast,
          appearance: dark ? AppAppearance.dark : AppAppearance.light);
      final boundary = GlobalKey();
      await _pumpPreview(tester, session, boundary, reducedMotion: true);
      final daily = find.byType(ForecastDailyStrip);
      final hourly = find.byType(ForecastHourlyList);
      expect(
          tester.getTopLeft(daily).dy, lessThan(tester.getTopLeft(hourly).dy));
      await Scrollable.ensureVisible(tester.element(daily), alignment: .03);
      await tester.pump(const Duration(milliseconds: 400));
      await _save(
          tester, boundary, '${theme}_daily_horizontal_hourly_vertical');
      await Scrollable.ensureVisible(tester.element(hourly), alignment: .03);
      await tester.pump(const Duration(milliseconds: 400));
      await _save(tester, boundary, '${theme}_hourly_no_interstitials');
      expect(find.byType(ForecastHourlyRow),
          findsNWidgets(ApprovedFixture.hourly.length));
      expect(find.text('Roasts'), findsNothing);
      expect(find.textContaining('I have opinions.'), findsNothing);
      await tester
          .tap(find.descendant(of: hourly, matching: find.text('See all')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      await _save(tester, boundary, '${theme}_hourly_expanded');
      expect(find.byTooltip('Close forecast'), findsOneWidget);
      expect(tester.takeException(), isNull);
      expect(session.weather.requestCount, 1);
      await _finish(tester, session);
    });
  }
}
