import 'dart:async';
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:latlong2/latlong.dart';

import 'package:grumpy_skies/design/dm_theme.dart';
import 'package:grumpy_skies/features/radar/widgets/open_weather_radar_map.dart';
import 'package:grumpy_skies/models/weather_models.dart';
import 'package:grumpy_skies/services/open_weather_backend_client.dart';

const _live = RadarFrame(
  timestamp: 1792326000,
  label: 'Latest',
  type: RadarFrameType.latest,
  isLatest: true,
);
const _forecast = RadarFrame(
  timestamp: 1792329600,
  label: 'Forecast',
  type: RadarFrameType.forecast,
  isLatest: false,
  source: 'openweather_futurecast',
);
const _location = LocationCandidate(
  name: 'Overland Park',
  state: 'KS',
  country: 'US',
  lat: 38.9822,
  lon: -94.6708,
  source: 'city',
);

class _ControlledStream extends ImageStreamCompleter {
  void complete(ui.Image image) => setImage(ImageInfo(image: image.clone()));
}

class _ControlledImage extends ImageProvider<_ControlledImage> {
  final stream = _ControlledStream();

  @override
  Future<_ControlledImage> obtainKey(ImageConfiguration configuration) =>
      SynchronousFuture(this);

  @override
  ImageStreamCompleter loadImage(
          _ControlledImage key, ImageDecoderCallback decode) =>
      stream;
}

class _ControlledTiles extends TileProvider {
  final frames = <String, _ControlledImage>{};
  int weatherImageRequests = 0;

  @override
  ImageProvider getImage(TileCoordinates coordinates, TileLayer options) {
    if (options.urlTemplate == radarBasemapUrl) {
      return MemoryImage(TileProvider.transparentImage);
    }
    weatherImageRequests++;
    return frames.putIfAbsent(options.urlTemplate!, _ControlledImage.new);
  }
}

class _Harness extends StatefulWidget {
  const _Harness({super.key, required this.client, required this.tiles});
  final OpenWeatherBackendClient client;
  final _ControlledTiles tiles;

  @override
  State<_Harness> createState() => _HarnessState();
}

class _HarnessState extends State<_Harness> {
  final controller = MapController();
  final loading = <bool>[];
  final issues = <String?>[];
  RadarMode mode = RadarMode.usForecast;
  RadarFrame? frame = _live;
  bool active = true;
  bool visible = true;
  double opacity = .65;

  void update(VoidCallback change) => setState(change);

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => MaterialApp(
        theme: DMTheme.light,
        home: Scaffold(
          body: OpenWeatherRadarMap(
            client: widget.client,
            mapController: controller,
            location: _location,
            mode: mode,
            frame: frame,
            opacity: opacity,
            active: active,
            overlayVisible: visible,
            onFrameLoading: loading.add,
            onTileIssue: issues.add,
            tileProvider: widget.tiles,
          ),
        ),
      );
}

Future<ui.Image> _image(WidgetTester tester) async =>
    (await tester.runAsync(() async {
      final codec =
          await ui.instantiateImageCodec(TileProvider.transparentImage);
      final frame = await codec.getNextFrame();
      codec.dispose();
      return frame.image;
    }))!;

Future<void> _flush(WidgetTester tester) async {
  await tester.pump();
  await tester.pump();
}

void main() {
  testWidgets('only current frame can report tile loading or failure',
      (tester) async {
    final tiles = _ControlledTiles();
    final responses = <Completer<http.Response>>[];
    final client = OpenWeatherBackendClient(
      baseUrl: 'https://radar.test',
      httpClient: MockClient((request) {
        final response = Completer<http.Response>();
        responses.add(response);
        return response.future;
      }),
    );
    final key = GlobalKey<_HarnessState>();
    await tester.pumpWidget(_Harness(key: key, client: client, tiles: tiles));
    await _flush(tester);
    final state = key.currentState!;
    final mapState = tester.state(find.byType(FlutterMap));
    expect(state.loading.last, isTrue);
    final observedImage = tiles.frames.values.single;
    await tester.pump(const Duration(milliseconds: 261));
    expect(responses, hasLength(1));

    state.controller.move(const LatLng(39.2, -94.5), 9);
    state.update(() {
      state.mode = RadarMode.futureCast;
      state.frame = _forecast;
    });
    await _flush(tester);
    expect(identical(mapState, tester.state(find.byType(FlutterMap))), isTrue);
    expect(state.controller.camera.center.latitude, closeTo(39.2, .001));
    expect(state.controller.camera.zoom, 9);
    final weatherLayers = tester
        .widgetList<TileLayer>(find.byType(TileLayer))
        .where((layer) => layer.urlTemplate != radarBasemapUrl);
    expect(weatherLayers, hasLength(1));
    expect(weatherLayers.single.urlTemplate, contains('futurecast'));
    expect(state.loading.last, isTrue);

    // Obsolete frame image and health completions cannot make the forecast
    // appear ready or turn it into an unavailable historical observation.
    final image = await _image(tester);
    observedImage.stream.complete(image);
    responses.first.complete(http.Response(
        '{"ok":false,"fallbackCode":"old_frame_failure"}', 200,
        headers: {'content-type': 'application/json'}));
    await _flush(tester);
    expect(state.loading.last, isTrue);
    expect(state.issues, isNot(contains('old_frame_failure')));
    tiles.frames.values.last.stream.complete(image);
    await _flush(tester);
    expect(state.loading.last, isFalse);
    expect(state.issues, isNot(contains('radar_tile_network_error')));
    image.dispose();
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
  });

  testWidgets('an unavailable probe survives hide and quick mode return',
      (tester) async {
    final tiles = _ControlledTiles();
    var healthRequests = 0;
    final health = Completer<http.Response>();
    final client = OpenWeatherBackendClient(
      baseUrl: 'https://radar.test',
      httpClient: MockClient((request) {
        healthRequests++;
        return health.future;
      }),
    );
    final key = GlobalKey<_HarnessState>();
    await tester.pumpWidget(_Harness(key: key, client: client, tiles: tiles));
    await _flush(tester);
    final state = key.currentState!;
    final image = await _image(tester);
    tiles.frames.values.single.stream.complete(image);
    await tester.pump(const Duration(milliseconds: 261));
    expect(healthRequests, 1);

    state.update(() => state.active = false);
    await _flush(tester);
    health.complete(http.Response(
      '{"ok":false,"fallbackCode":"noaa_unavailable"}',
      200,
      headers: {'content-type': 'application/json'},
    ));
    await _flush(tester);
    expect(state.issues, isEmpty);
    state.update(() => state.active = true);
    await _flush(tester);
    await _flush(tester);
    expect(state.issues.last, 'noaa_unavailable');
    expect(healthRequests, 1);

    // A second mode is selected briefly, before its own debounced probe.
    // Returning to A must restore its actual unavailable result even though
    // all transparent fallback tiles have decoded successfully.
    state.update(() {
      state.mode = RadarMode.futureCast;
      state.frame = _forecast;
    });
    await _flush(tester);
    expect(state.issues.last, isNull);
    state.update(() {
      state.mode = RadarMode.usForecast;
      state.frame = _live;
    });
    await _flush(tester);
    await tester.pump(const Duration(milliseconds: 300));
    await _flush(tester);
    expect(state.issues.last, 'noaa_unavailable');
    expect(healthRequests, 1);
    image.dispose();
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
  });

  testWidgets('opacity rebuilds keep camera and do not request tiles or health',
      (tester) async {
    final tiles = _ControlledTiles();
    var healthRequests = 0;
    final client = OpenWeatherBackendClient(
      baseUrl: 'https://radar.test',
      httpClient: MockClient((request) async {
        healthRequests++;
        return http.Response('{"ok":true}', 200,
            headers: {'content-type': 'application/json'});
      }),
    );
    final key = GlobalKey<_HarnessState>();
    await tester.pumpWidget(_Harness(key: key, client: client, tiles: tiles));
    await _flush(tester);
    final state = key.currentState!;
    final image = await _image(tester);
    tiles.frames.values.single.stream.complete(image);
    await tester.pump(const Duration(milliseconds: 300));
    await _flush(tester);
    expect(healthRequests, 1);
    expect(state.issues, isEmpty);
    final mapState = tester.state(find.byType(FlutterMap));
    state.controller.move(const LatLng(39.2, -94.5), 9);
    await _flush(tester);
    final imageRequests = tiles.weatherImageRequests;
    for (var i = 1; i <= 10; i++) {
      state.update(() => state.opacity = i / 10);
      await tester.pump(const Duration(milliseconds: 300));
    }
    expect(identical(mapState, tester.state(find.byType(FlutterMap))), isTrue);
    expect(state.controller.camera.zoom, 9);
    expect(state.controller.camera.center.latitude, closeTo(39.2, .001));
    expect(healthRequests, 1);
    expect(tiles.weatherImageRequests, imageRequests);
    image.dispose();
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
  });

  testWidgets(
      'missing or hidden weather has no imagery; inactive cancels probe',
      (tester) async {
    final tiles = _ControlledTiles();
    var requests = 0;
    final client = OpenWeatherBackendClient(
      baseUrl: 'https://radar.test',
      httpClient: MockClient((request) async {
        requests++;
        return http.Response('{"ok":true}', 200,
            headers: {'content-type': 'application/json'});
      }),
    );
    final key = GlobalKey<_HarnessState>();
    await tester.pumpWidget(_Harness(key: key, client: client, tiles: tiles));
    final state = key.currentState!;
    state.update(() => state.active = false);
    // Apply the visibility change before advancing past the debounce. A timed
    // pump advances fake time before rendering the newly scheduled widget.
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    await _flush(tester);
    expect(requests, 0);
    expect(find.byType(FlutterMap), findsOneWidget);
    expect(find.byType(TileLayer), findsOneWidget);
    expect(state.loading.last, isFalse);

    state.update(() {
      state.active = true;
      state.frame = null;
    });
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    await _flush(tester);
    expect(requests, 0);
    expect(find.byType(TileLayer), findsOneWidget);
    expect(state.loading.last, isFalse);
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
  });
}
