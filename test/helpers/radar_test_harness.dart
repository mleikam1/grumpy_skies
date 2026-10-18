import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:grumpy_skies/app/daymaker_shell.dart';
import 'package:grumpy_skies/config/app_routes.dart';
import 'package:grumpy_skies/design/dm_theme.dart';
import 'package:grumpy_skies/features/radar/radar_playback_controller.dart';
import 'package:grumpy_skies/features/radar/radar_screen.dart';
import 'package:grumpy_skies/features/radar/radar_session.dart';
import 'package:grumpy_skies/features/radar/widgets/open_weather_radar_map.dart';
import 'package:grumpy_skies/models/weather_models.dart';
import 'package:grumpy_skies/preview/approved_fixture.dart';
import 'package:grumpy_skies/preview/approved_preview.dart';
import 'package:grumpy_skies/repositories/weather_repository.dart';
import 'package:grumpy_skies/services/open_weather_backend_client.dart';
import 'package:grumpy_skies/services/weather_location_controller.dart';
import 'package:grumpy_skies/shared/widgets/dm_bottom_nav.dart';

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

/// Real screen/state/shell, fixed provider boundary. No production data writes,
/// network traffic, generated maps, or invented precipitation imagery.
class RadarTestHarness {
  RadarTestHarness(
      {this.available = true,
      this.empty = false,
      this.productionOwnership = false}) {
    final json = ApprovedFixture.weather.toJson();
    (json['current'] as Map<String, dynamic>)['precipitationChanceKnown'] =
        true;
    weather.bundleOverride = WeatherBundle.fromJson(json);
    location = WeatherLocationController(
      repository: weather,
      initialLocation: ApprovedFixture.location,
      clock: () => now,
    )..updateWeatherSafety(weather.bundleOverride!, ApprovedFixture.location);
    client = OpenWeatherBackendClient(
      baseUrl: 'https://radar.test',
      httpClient: MockClient((request) async {
        counts.update(request.url.path, (value) => value + 1,
            ifAbsent: () => 1);
        final source = request.url.queryParameters['source'] ??
            (request.url.path.endsWith('futureFrames')
                ? 'openweather_futurecast'
                : 'noaa_mrms');
        final health = request.url.path.endsWith('radarHealth');
        final future = source == 'openweather_futurecast';
        final anchor = now.millisecondsSinceEpoch ~/ 1000;
        final times = future
            ? [anchor, anchor + 600, anchor + 1500, anchor + 3600]
            : [anchor - 4200, anchor - 2400, anchor - 900, anchor - 120];
        return http.Response(
          jsonEncode(health
              ? {
                  'ok': available,
                  'source': source,
                  'fallbackCode': available ? null : 'noaa_unavailable',
                }
              : {
                  'source': source,
                  'futureCastAvailable': !empty,
                  'latestTimestamp': times.last,
                  'availableTo': times.last,
                  'frames': [
                    if (!empty)
                      for (var i = 0; i < times.length; i++)
                        {
                          'timestamp': times[i],
                          'label': future ? 'Forecast' : 'Observation',
                          'type': future
                              ? 'forecast'
                              : i == times.length - 1
                                  ? 'latest'
                                  : 'history',
                          'isLatest': !future && i == times.length - 1,
                          'source': source,
                        },
                  ],
                }),
          200,
          headers: {'content-type': 'application/json'},
        );
      }),
    );
    if (!productionOwnership) {
      _injectedRadar = RadarPlaybackController(
          client: client, location: ApprovedFixture.location, now: () => now);
    }
  }

  final bool available;
  final bool empty;
  final bool productionOwnership;
  DateTime now = ApprovedFixture.now;
  final counts = <String, int>{};
  final weather = ApprovedWeatherRepository();
  late final WeatherLocationController location;
  late final OpenWeatherBackendClient client;
  RadarPlaybackController? _injectedRadar;
  RadarSession? session;
  RadarPlaybackController get radar => _injectedRadar ?? session!.controller!;
  late final GoRouter router;
  final boundary = GlobalKey();
  VoidCallback? _disposeSemantics;

  int get metadataRequests => counts.entries
      .where((entry) => entry.key != '/radarHealth')
      .fold(0, (sum, entry) => sum + entry.value);

  Future<void> pump(
    WidgetTester tester, {
    Size size = const Size(390, 844),
    bool dark = false,
    double textScale = 1,
    bool safeAreas = true,
    TileProvider? tileProvider,
    String initialRoute = AppRoutes.radar,
  }) async {
    SharedPreferences.setMockInitialValues({});
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final semantics = tester.ensureSemantics();
    _disposeSemantics = semantics.dispose;
    addTearDown(() {
      _disposeSemantics?.call();
      _disposeSemantics = null;
    });
    router = GoRouter(initialLocation: initialRoute, routes: [
      ShellRoute(
        builder: (_, state, child) =>
            DaymakerShell(location: state.uri.path, child: child),
        routes: [
          GoRoute(
            path: AppRoutes.radar,
            builder: (_, __) => RadarScreen(
              controller: _injectedRadar,
              now: () => now,
              tileProvider: tileProvider ?? PreviewMemoryTiles(),
            ),
          ),
          for (final entry in [
            (AppRoutes.forecast, 'Today'),
            (AppRoutes.planCast, 'PlanCast'),
            (AppRoutes.fun, 'Fun'),
          ])
            GoRoute(
              path: entry.$1,
              builder: (_, __) => Scaffold(
                  body: Center(child: Text('${entry.$2} destination'))),
            ),
        ],
      ),
    ]);
    await tester.runAsync(_loadFonts);
    await tester.pumpWidget(MultiProvider(
      providers: [
        Provider<WeatherRepository>.value(value: weather),
        Provider<OpenWeatherBackendClient>.value(value: client),
        ChangeNotifierProvider<WeatherLocationController>.value(
            value: location),
      ],
      child: RepaintBoundary(
        key: boundary,
        child: MaterialApp.router(
          debugShowCheckedModeBanner: false,
          theme: dark ? DMTheme.dark : DMTheme.light,
          themeAnimationDuration: Duration.zero,
          routerConfig: router,
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context).copyWith(
              textScaler: TextScaler.linear(textScale),
              disableAnimations: true,
              padding: safeAreas
                  ? const EdgeInsets.only(top: 47, bottom: 34)
                  : EdgeInsets.zero,
            ),
            child: child!,
          ),
        ),
      ),
    ));
    await settle(tester);
    session = tester.element(find.byType(DmBottomNav)).read<RadarSession>();
  }

  static Future<void> settle(WidgetTester tester) async {
    for (var i = 0; i < 6; i++) {
      await tester.pump(const Duration(milliseconds: 80));
      await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 10)));
    }
  }

  Future<void> dispose(WidgetTester tester) async {
    _disposeSemantics?.call();
    _disposeSemantics = null;
    await tester.pumpWidget(const SizedBox.shrink());
    _injectedRadar?.dispose();
    location.dispose();
    router.dispose();
    await tester.pump();
  }
}

/// Optional recorded OSM viewport tiles only. Unsupported squares and weather
/// images remain transparent; a capture using this boundary must identify its
/// weather frames as fixture metadata, not live coverage evidence.
class RadarRecordedBasemapTiles extends TileProvider {
  RadarRecordedBasemapTiles(this.directory);
  final String directory;
  int recordedSquares = 0;
  int missingSquares = 0;
  @override
  ImageProvider getImage(TileCoordinates coordinates, TileLayer options) {
    if (options.urlTemplate == radarBasemapUrl) {
      final file = File(
          '$directory/${coordinates.z}_${coordinates.x}_${coordinates.y}.png');
      if (file.existsSync()) {
        recordedSquares++;
        return FileImage(file);
      }
      missingSquares++;
    }
    return MemoryImage(TileProvider.transparentImage);
  }
}
