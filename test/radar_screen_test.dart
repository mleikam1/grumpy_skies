import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:grumpy_skies/features/radar/widgets/open_weather_radar_map.dart';
import 'package:grumpy_skies/shared/widgets/dm_bottom_nav.dart';

import 'helpers/radar_test_harness.dart';

void main() {
  testWidgets('RadarScreen has one playback dock and preserves app navigation',
      (tester) async {
    final h = RadarTestHarness();
    await h.pump(tester);
    expect(find.text('Overland Park, KS'), findsOneWidget);
    expect(find.text('Live Radar'), findsOneWidget);
    expect(find.text('FutureCast'), findsOneWidget);
    expect(find.bySemanticsLabel('Play radar timeline'), findsOneWidget);
    expect(find.byType(DmBottomNav), findsOneWidget);
    expect(find.textContaining('Latest · 9:58 AM'), findsOneWidget);
    expect(find.textContaining('Chaos '), findsOneWidget);
    expect(find.byTooltip('Expand map'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await h.dispose(tester);
  });

  testWidgets('desktop secondary controls keep zoom and timing accessible',
      (tester) async {
    final h = RadarTestHarness();
    await h.pump(tester, size: const Size(1200, 900));
    await tester.tap(find.byTooltip('Radar layers'));
    await RadarTestHarness.settle(tester);
    expect(find.text('Weather overlay'), findsOneWidget);
    expect(find.text('Zoom in'), findsOneWidget);
    expect(find.text('Zoom out'), findsOneWidget);
    final map =
        tester.widget<OpenWeatherRadarMap>(find.byType(OpenWeatherRadarMap));
    await tester.tap(find.text('Zoom in'));
    await tester.pump();
    expect(map.mapController.camera.zoom, 11);
    await tester.tap(find.byTooltip('Close Layers'));
    await RadarTestHarness.settle(tester);
    await tester.tap(find.text('Details'));
    await RadarTestHarness.settle(tester);
    expect(find.textContaining('Selected frame:'), findsOneWidget);
    expect(find.textContaining('Last successful metadata refresh:'),
        findsOneWidget);
    expect(find.text('Refresh radar'), findsOneWidget);
    expect(find.textContaining('not confirmed clear weather'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await h.dispose(tester);
  });

  testWidgets('RadarScreen retains city-level map zoom', (tester) async {
    final h = RadarTestHarness();
    await h.pump(tester);
    final map = tester.widget<FlutterMap>(find.byType(FlutterMap));
    expect(map.options.initialZoom, radarCityZoom);
    expect(radarCityZoom, inInclusiveRange(9.5, 10.5));
    await h.dispose(tester);
  });

  testWidgets('unavailable tiles never imply clear weather', (tester) async {
    final h = RadarTestHarness(available: false);
    await h.pump(tester);
    expect(find.text('Radar source unavailable; base map still usable.'),
        findsOneWidget);
    expect(find.byType(FlutterMap), findsOneWidget);
    expect(tester.takeException(), isNull);
    await h.dispose(tester);
  });

  testWidgets(
      'missing metadata has no synthetic selected frame or weather tiles',
      (tester) async {
    final h = RadarTestHarness(empty: true);
    await h.pump(tester);
    final map =
        tester.widget<OpenWeatherRadarMap>(find.byType(OpenWeatherRadarMap));
    expect(map.frame, isNull);
    expect(find.text('Radar unavailable'), findsOneWidget);
    expect(tester.widgetList<TileLayer>(find.byType(TileLayer)), hasLength(1));
    expect(tester.takeException(), isNull);
    await h.dispose(tester);
  });
}
