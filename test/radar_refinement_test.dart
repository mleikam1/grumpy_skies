import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:grumpy_skies/features/radar/widgets/open_weather_radar_map.dart';
import 'package:grumpy_skies/models/weather_models.dart';
import 'package:grumpy_skies/shared/widgets/dm_bottom_nav.dart';

import 'helpers/radar_test_harness.dart';

void main() {
  testWidgets(
      'basemap identifies app, retains viewport cache settings and credits',
      (tester) async {
    final h = RadarTestHarness();
    await h.pump(tester);
    final tiles = tester.widgetList<TileLayer>(find.byType(TileLayer)).toList();
    final base = tiles.first;
    expect(base.urlTemplate, radarBasemapUrl);
    expect(base.panBuffer, 0);
    expect(base.tileProvider.headers['User-Agent'], contains('WingmanWeather'));
    expect(
        tiles.skip(1).every(
            (tile) => tile.urlTemplate!.startsWith('https://radar.test/')),
        isTrue);
    expect(find.textContaining('OpenStreetMap'), findsOneWidget);
    expect(find.textContaining('CARTO'), findsNothing);
    expect(tester.takeException(), isNull);
    await h.dispose(tester);
  });

  testWidgets(
      'basemap failure stays distinct from weather imagery availability',
      (tester) async {
    final h = RadarTestHarness(available: false);
    await h.pump(tester);
    final map =
        tester.widget<OpenWeatherRadarMap>(find.byType(OpenWeatherRadarMap));
    map.onBasemapIssue!(true);
    await tester.pump();
    expect(
        find.textContaining('Base map tiles could not load.'), findsOneWidget);
    expect(find.textContaining('base map still usable'), findsNothing);
    map.onBasemapIssue!(false);
    await tester.pump();
    expect(find.text('Radar source unavailable; base map still usable.'),
        findsOneWidget);
    await h.dispose(tester);
  });

  testWidgets(
      'Live playback starts history and manual scrub pauses the scheduler',
      (tester) async {
    final h = RadarTestHarness();
    await h.pump(tester);
    expect(h.radar.isLatest, isTrue);
    await tester.tap(find.bySemanticsLabel('Play radar timeline'));
    await tester.pump();
    expect(h.radar.selectedIndex, 0);
    expect(h.radar.hasPlaybackTimer, isTrue);
    final slider = tester.widget<Slider>(find.byType(Slider));
    slider.onChanged!(.45);
    await tester.pump();
    final selected = h.radar.selectedFrame!.timestamp;
    expect(h.radar.playing, isFalse);
    expect(h.radar.hasPlaybackTimer, isFalse);
    await tester.pump(const Duration(seconds: 2));
    expect(h.radar.selectedFrame!.timestamp, selected);
    expect(
        tester
            .widget<OpenWeatherRadarMap>(find.byType(OpenWeatherRadarMap))
            .frame!
            .timestamp,
        selected);
    expect(find.text('Latest'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await h.dispose(tester);
  });

  testWidgets('mode selection restores real frame and retains the map owner',
      (tester) async {
    final h = RadarTestHarness();
    await h.pump(tester);
    final state = tester.state(find.byType(FlutterMap));
    h.radar.selectIndex(1);
    await tester.pump();
    final observed = h.radar.selectedFrame!.timestamp;
    await tester.tap(find.bySemanticsLabel('Show FutureCast'));
    await RadarTestHarness.settle(tester);
    expect(h.radar.mode, RadarMode.futureCast);
    expect(h.radar.selectedFrame!.source, 'openweather_futurecast');
    expect(find.text('Forecast precipitation'), findsOneWidget);
    expect(find.textContaining('Chaos '), findsNothing);
    h.radar.selectIndex(2);
    await tester.pump();
    final forecast = h.radar.selectedFrame!.timestamp;
    await tester.tap(find.bySemanticsLabel('Show Live Radar'));
    await RadarTestHarness.settle(tester);
    expect(h.radar.selectedFrame!.timestamp, observed);
    expect(h.radar.selectedFrame!.source, 'noaa_mrms');
    expect(find.textContaining('Chaos '), findsNothing);
    await tester.tap(find.bySemanticsLabel('Show FutureCast'));
    await RadarTestHarness.settle(tester);
    expect(h.radar.selectedFrame!.timestamp, forecast);
    expect(identical(tester.state(find.byType(FlutterMap)), state), isTrue);
    expect(h.metadataRequests, 2);
    expect(tester.takeException(), isNull);
    await h.dispose(tester);
  });

  for (final dark in [false, true]) {
    testWidgets('small large-text radar and panels remain usable, dark=$dark',
        (tester) async {
      final h = RadarTestHarness();
      await h.pump(tester,
          size: const Size(320, 740), dark: dark, textScale: 2);
      expect(find.byType(DmBottomNav), findsOneWidget);
      expect(find.byTooltip('Radar layers'), findsOneWidget);
      expect(find.byTooltip('Expand map'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.tap(find.byTooltip('Radar layers'));
      await RadarTestHarness.settle(tester);
      expect(find.text('Weather overlay'), findsOneWidget);
      expect(find.byTooltip('Close Layers'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.tap(find.byTooltip('Close Layers'));
      await RadarTestHarness.settle(tester);
      await tester.tap(find.byTooltip('Expand map'));
      await RadarTestHarness.settle(tester);
      expect(find.byType(DmBottomNav), findsNothing);
      expect(find.text('Done'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await h.dispose(tester);
    });
  }
}
