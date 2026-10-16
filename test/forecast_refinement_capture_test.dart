import 'dart:io';
import 'dart:convert';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:grumpy_skies/config/app_routes.dart';
import 'package:grumpy_skies/features/fun/meme/rendering/meme_renderer.dart';
import 'package:grumpy_skies/features/forecast/widgets/forecast_daily_strip.dart';
import 'package:grumpy_skies/features/forecast/widgets/forecast_hourly_list.dart';
import 'package:grumpy_skies/features/forecast/widgets/forecast_metric_chips.dart';
import 'package:grumpy_skies/models/weather_models.dart';
import 'package:grumpy_skies/design/dm_theme.dart';
import 'package:grumpy_skies/preview/approved_preview.dart';

// Opt in to writing review artifacts; normal flutter test runs only assertions.
const _capture = bool.fromEnvironment('CAPTURE_FORECAST_REFINEMENT');
const _captureRoot = 'docs/ui_implementation/refinement/screenshots';

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
  TestWidgetsFlutterBinding.ensureInitialized();
  const phase =
      String.fromEnvironment('REFINEMENT_PHASE', defaultValue: 'after');
  for (final dark in [false, true]) {
    final theme = dark ? 'dark' : 'light';
    testWidgets('real Today $theme sun times and daily sheet', (tester) async {
      final session = ApprovedPreviewSession(
          initialLocation: AppRoutes.forecast,
          appearance: dark ? AppAppearance.dark : AppAppearance.light);
      final boundary = GlobalKey();
      await _pumpPreview(tester, session, boundary);
      await Scrollable.ensureVisible(
          tester.element(find.byType(ForecastMetricChips)),
          alignment: .12);
      await tester.pump(const Duration(milliseconds: 400));
      if (phase != 'before') {
        await _save(tester, boundary, '${phase}_${theme}_metrics');
      }
      await tester.ensureVisible(find.text('Sunrise & sunset'));
      await tester.pump(const Duration(milliseconds: 400));
      await _save(tester, boundary, '${phase}_${theme}_sun_times');
      final daily = find.byType(ForecastDailyStrip);
      await tester.ensureVisible(daily);
      await tester.pump(const Duration(milliseconds: 400));
      await tester
          .tap(find.descendant(of: daily, matching: find.text('See all')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      await _save(tester, boundary, '${phase}_${theme}_daily_sheet');
      expect(tester.takeException(), isNull);
      expect(session.weather.requestCount, 1);
      expect(find.text('Fun').hitTestable(), findsNothing);
      expect(find.byTooltip('Close forecast'), findsOneWidget);
      await _finish(tester, session);
    });
  }
  for (final dark in [false, true]) {
    for (final scale in [1.0, 2.0]) {
      final name =
          '${dark ? 'dark' : 'light'}_${scale == 2 ? 'large_text' : 'normal'}';
      testWidgets('seven days long conditions $name', (tester) async {
        tester.view.physicalSize = const Size(390, 930);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        final boundary = GlobalKey();
        final now = DateTime.utc(2026, 10, 12, 15);
        const condition = 'Sunny Then Chance Showers And Thunderstorms';
        final days = List.generate(
            7,
            (i) => DailyForecast(
                date: DateTime(2026, 10, 12 + i),
                maxTempC: 30 - i.toDouble(),
                minTempC: 20 - i.toDouble(),
                condition: i == 0 ? condition : 'Cloudy',
                precipitationChance: 40,
                weatherId: 200));
        await tester.runAsync(() async {
          await _loadFonts();
          await tester.pumpWidget(RepaintBoundary(
              key: boundary,
              child: MaterialApp(
                  debugShowCheckedModeBanner: false,
                  theme: dark ? DMTheme.dark : DMTheme.light,
                  builder: (context, child) => MediaQuery(
                      data: MediaQuery.of(context)
                          .copyWith(textScaler: TextScaler.linear(scale)),
                      child: child!),
                  home: Scaffold(
                      body: SafeArea(
                          child: SingleChildScrollView(
                              child: Padding(
                                  padding: const EdgeInsets.all(18),
                                  child: Column(children: [
                                    const Text(
                                        'Synthetic forecast stress fixture'),
                                    ForecastHourlyList(
                                        hourly: [
                                          for (var i = 0; i < 12; i++)
                                            HourlyForecast(
                                                time:
                                                    now.add(Duration(hours: i)),
                                                temperatureC: 22,
                                                condition: condition,
                                                precipitationChance: 40,
                                                weatherId: 200)
                                        ],
                                        referenceTime: now,
                                        timezoneOffset: -18000),
                                    ForecastDailyStrip(
                                        daily: days,
                                        referenceTime: now,
                                        timezoneOffset: -18000),
                                  ]))))))));
        });
        await tester.pump();
        final daily = find.byType(ForecastDailyStrip);
        await tester.ensureVisible(daily);
        await tester.pump();
        await tester
            .tap(find.descendant(of: daily, matching: find.text('See all')));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 400));
        await _save(tester, boundary, 'after_${name}_seven_day_sheet');
        expect(tester.takeException(), isNull);
        final longText = find.text(condition);
        expect(longText, findsOneWidget);
        final paragraph = tester.renderObject<RenderParagraph>(longText);
        expect(paragraph.didExceedMaxLines, isFalse);
        final sheetList = find.descendant(
            of: find.byType(DraggableScrollableSheet),
            matching: find.byType(ListView));
        await tester.drag(sheetList, const Offset(0, -1400));
        await tester.pumpAndSettle();
        // The last day is reachable, including at twice the system text size.
        final lastDay = find.descendant(
            of: sheetList,
            matching: find.byKey(
                const ValueKey('detail-daily-2026-10-18T00:00:00.000Z')));
        await tester.scrollUntilVisible(lastDay, 300,
            scrollable: find.descendant(
                of: sheetList, matching: find.byType(Scrollable)));
        await tester.pumpAndSettle();
        // Hit-test the real date text, as the original test did, rather than
        // the row's center (which can lie between its text columns).
        final lastDayText =
            find.descendant(of: lastDay, matching: find.byType(Text));
        await tester.ensureVisible(lastDayText.first);
        await tester.pumpAndSettle();
        expect(lastDayText.first.hitTestable(), findsOneWidget);
        await tester.ensureVisible(lastDayText.last);
        await tester.pumpAndSettle();
        await _save(tester, boundary, 'after_${name}_seven_day_bottom');
        expect(lastDayText.last.hitTestable(), findsOneWidget);
        expect(tester.takeException(), isNull);
        await tester.tap(find.byTooltip('Close forecast'));
        await tester.pumpAndSettle();
        expect(find.byType(DraggableScrollableSheet), findsNothing);
        final hourly = find.byType(ForecastHourlyList);
        await tester.ensureVisible(hourly);
        await tester.pump();
        await tester
            .tap(find.descendant(of: hourly, matching: find.text('See all')));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 400));
        await _save(tester, boundary, 'after_${name}_hourly_sheet');
        expect(tester.takeException(), isNull);
        await tester.tap(find.byTooltip('Close forecast'));
        await tester.pumpAndSettle();
        await tester.pumpWidget(const SizedBox());
      });
    }
  }
}
