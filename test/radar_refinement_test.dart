import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:provider/provider.dart';

import 'package:grumpy_skies/design/dm_theme.dart';
import 'package:grumpy_skies/features/radar/radar_screen.dart';
import 'package:grumpy_skies/features/radar/widgets/open_weather_radar_map.dart';
import 'package:grumpy_skies/preview/approved_fixture.dart';
import 'package:grumpy_skies/preview/approved_preview.dart';
import 'package:grumpy_skies/repositories/weather_repository.dart';
import 'package:grumpy_skies/services/open_weather_backend_client.dart';
import 'package:grumpy_skies/services/weather_location_controller.dart';

const _capture = bool.fromEnvironment('CAPTURE_RADAR_REFINEMENT');
const _tileDirectory = String.fromEnvironment('RADAR_REVIEW_TILE_DIRECTORY');
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

// Evidence-only files from the exact visible OSM viewport. Never used by app
// code or ordinary tests, and never substitutes invented precipitation tiles.
class _ReviewTiles extends TileProvider {
  _ReviewTiles({this.actualRadar = false});
  final bool actualRadar;
  @override
  ImageProvider getImage(TileCoordinates coordinates, TileLayer options) {
    if (options.urlTemplate == radarBasemapUrl) {
      final tile = File(
          '$_tileDirectory/${coordinates.z}_${coordinates.x}_${coordinates.y}.png');
      if (!tile.existsSync()) {
        throw StateError('Missing actual map evidence: ${tile.path}');
      }
      return FileImage(tile);
    }
    if (actualRadar) {
      final tile = File(
          '$_tileDirectory/noaa_${coordinates.z}_${coordinates.x}_${coordinates.y}.png');
      if (!tile.existsSync()) {
        throw StateError('Missing actual radar evidence: ${tile.path}');
      }
      return FileImage(tile);
    }
    return MemoryImage(TileProvider.transparentImage);
  }
}

Future<WeatherLocationController> _pumpRadar(
  WidgetTester tester, {
  bool dark = false,
  bool available = true,
  double scale = 1,
  Size size = const Size(390, 930),
  GlobalKey? boundary,
  bool actualMapEvidence = false,
  bool actualRadar = false,
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  final weather = ApprovedWeatherRepository();
  final location = WeatherLocationController(
      repository: weather, initialLocation: ApprovedFixture.location);
  final client = OpenWeatherBackendClient(
      baseUrl: 'https://radar.test',
      httpClient: MockClient((request) async {
        final health = request.url.path.endsWith('radarHealth');
        if (actualRadar && request.url.path.contains('radar')) {
          return http.Response(
              File('$_tileDirectory/${health ? 'noaa_health' : 'noaa_frames'}.json')
                  .readAsStringSync(),
              200,
              headers: {'content-type': 'application/json'});
        }
        return http.Response(
            jsonEncode(health
                ? {
                    'ok': available,
                    'source': 'noaa_mrms',
                    'fallbackCode': available ? null : 'noaa_unavailable',
                  }
                : {
                    'source': 'noaa_mrms',
                    'futureCastAvailable': true,
                    'frames': [
                      for (var i = 0; i < 3; i++)
                        {
                          'timestamp': 1791820800 + i * 300,
                          'label': i == 2 ? 'Latest' : '-${(2 - i) * 5} min',
                          'type': i == 2 ? 'latest' : 'past',
                          'isLatest': i == 2,
                          'source': 'noaa_mrms',
                        },
                    ],
                  }),
            200,
            headers: {'content-type': 'application/json'});
      }));
  await tester.runAsync(() async {
    await _loadFonts();
    await tester.pumpWidget(MultiProvider(
        providers: [
          Provider<WeatherRepository>.value(value: weather),
          Provider<OpenWeatherBackendClient>.value(value: client),
          ChangeNotifierProvider<WeatherLocationController>.value(
              value: location),
        ],
        child: MaterialApp(
          theme: dark ? DMTheme.dark : DMTheme.light,
          home: MediaQuery(
            data: MediaQueryData(
                size: size, textScaler: TextScaler.linear(scale)),
            child: RepaintBoundary(
                key: boundary,
                child: RadarScreen(
                  tileProvider: actualMapEvidence
                      ? _ReviewTiles(actualRadar: actualRadar)
                      : PreviewMemoryTiles(),
                )),
          ),
        )));
  });
  for (var i = 0; i < 8; i++) {
    await tester.pump(const Duration(milliseconds: 100));
    await tester
        .runAsync(() => Future<void>.delayed(const Duration(milliseconds: 20)));
  }
  return location;
}

Future<void> _save(WidgetTester tester, GlobalKey key, String name) async {
  if (!_capture) return;
  await tester.runAsync(() async {
    final render =
        key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
    final image = await render.toImage(pixelRatio: 2);
    final data = await image.toByteData(format: ui.ImageByteFormat.png);
    final file =
        File('docs/ui_implementation/refinement/radar_evidence/$name.png');
    await file.parent.create(recursive: true);
    await file.writeAsBytes(data!.buffer.asUint8List());
    image.dispose();
  });
}

Future<void> _finish(
    WidgetTester tester, WeatherLocationController location) async {
  await tester.pumpWidget(const SizedBox.shrink());
  location.dispose();
  await tester.pump();
}

void main() {
  testWidgets('radar basemap config identifies app, caches and avoids prefetch',
      (tester) async {
    final location = await _pumpRadar(tester);
    final tiles = tester.widgetList<TileLayer>(find.byType(TileLayer)).toList();
    final base = tiles.first;
    expect(base.urlTemplate, 'https://tile.openstreetmap.org/{z}/{x}/{y}.png');
    expect(base.panBuffer, 0);
    expect(base.tileProvider.headers['User-Agent'], contains('WingmanWeather'));
    expect(
        tiles.skip(1).every(
            (tile) => tile.urlTemplate!.startsWith('https://radar.test/')),
        isTrue);
    expect(find.text('© OpenStreetMap contributors'), findsOneWidget);
    expect(find.textContaining('CARTO'), findsNothing);
    expect(tester.takeException(), isNull);
    await _finish(tester, location);
  });

  testWidgets(
      'radar basemap failure is distinct from overlay health and recovers',
      (tester) async {
    final location = await _pumpRadar(tester, available: false);
    final map =
        tester.widget<OpenWeatherRadarMap>(find.byType(OpenWeatherRadarMap));
    expect(find.text('Radar source unavailable; base map still usable.'),
        findsOneWidget);
    map.onBasemapIssue!(true);
    await tester.pump();
    expect(
        find.textContaining('Base map tiles could not load.'), findsOneWidget);
    expect(find.textContaining('base map still usable'), findsNothing);
    map.onBasemapIssue!(false);
    await tester.pump();
    expect(find.text('Radar source unavailable; base map still usable.'),
        findsOneWidget);
    await _finish(tester, location);
  });

  testWidgets(
      'radar keeps zoom, recenter, playback and visible attribution over sheet',
      (tester) async {
    final location = await _pumpRadar(tester);
    final map =
        tester.widget<OpenWeatherRadarMap>(find.byType(OpenWeatherRadarMap));
    await tester.tap(find.bySemanticsLabel('Zoom in'));
    await tester.pump();
    expect(map.mapController.camera.zoom, 11);
    await tester.tap(find.bySemanticsLabel('Recenter radar map'));
    await tester.pump();
    expect(map.mapController.camera.zoom, radarCityZoom);
    await tester.tap(find.bySemanticsLabel('Play radar timeline'));
    await tester.pump(const Duration(milliseconds: 901));
    expect(
        tester
            .widget<OpenWeatherRadarMap>(find.byType(OpenWeatherRadarMap))
            .frame
            .isLatest,
        isFalse);
    await tester.tap(find.bySemanticsLabel('Pause radar timeline'));
    await tester.pump();
    await tester.tap(find.bySemanticsLabel('Radar layers'));
    await tester.pumpAndSettle();
    expect(find.text('FutureCast'), findsOneWidget);
    await tester.drag(find.byType(ListView), const Offset(0, -200));
    await tester.pumpAndSettle();
    expect(find.text('Precipitation legend'), findsOneWidget);
    expect(
        tester.getBottomLeft(find.byType(RadarMapAttribution)).dy,
        lessThan(tester
            .getTopLeft(find.bySemanticsLabel('Radar timeline and information'))
            .dy));
    expect(tester.takeException(), isNull);
    await _finish(tester, location);
  });

  for (final dark in [false, true]) {
    final theme = dark ? 'dark' : 'light';
    testWidgets('radar $theme actual basemap review and expanded controls',
        (tester) async {
      final boundary = GlobalKey();
      final location = await _pumpRadar(tester,
          dark: dark,
          available: false,
          boundary: boundary,
          actualMapEvidence: _capture && _tileDirectory.isNotEmpty);
      await _save(tester, boundary, '${theme}_radar_map');
      expect(tester.takeException(), isNull);
      await tester.tap(find.bySemanticsLabel('Radar legend and info'));
      await tester.pumpAndSettle();
      await _save(tester, boundary, '${theme}_radar_controls');
      expect(tester.takeException(), isNull);
      await _finish(tester, location);
    });
    testWidgets('radar $theme current NOAA frame evidence', (tester) async {
      final boundary = GlobalKey();
      final actual = _capture && _tileDirectory.isNotEmpty;
      final location = await _pumpRadar(tester,
          dark: dark,
          boundary: boundary,
          actualMapEvidence: actual,
          actualRadar: actual);
      // Current weather fixture is unrelated to the live map evidence.
      await tester.tap(find.byTooltip('Close Chaos Meter'));
      await tester.pumpAndSettle();
      await _save(tester, boundary, '${theme}_radar_live_noaa');
      expect(tester.takeException(), isNull);
      await _finish(tester, location);
    });
    testWidgets('radar $theme narrow large text keeps attribution readable',
        (tester) async {
      final location = await _pumpRadar(tester,
          dark: dark, scale: 2, size: const Size(320, 740));
      await tester.tap(find.bySemanticsLabel('Radar layers'));
      await tester.pumpAndSettle();
      expect(find.text('© OpenStreetMap contributors'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await _finish(tester, location);
    });
  }
}
