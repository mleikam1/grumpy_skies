import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:grumpy_skies/features/radar/radar_playback_controller.dart';
import 'package:grumpy_skies/models/weather_models.dart';
import 'package:grumpy_skies/services/open_weather_backend_client.dart';

const _location = LocationCandidate(
  name: 'Overland Park',
  state: 'Kansas',
  country: 'US',
  lat: 38.98,
  lon: -94.67,
  source: 'city',
);

const _elsewhere = LocationCandidate(
  name: 'Chicago',
  country: 'US',
  lat: 41.88,
  lon: -87.63,
  source: 'city',
);

final _start = DateTime.utc(2026, 10, 18, 12);
final _timestamp = _start.millisecondsSinceEpoch ~/ 1000;

void main() {
  _controllerTest(
      'Latest starts the real history; scrub pauses and resumes in place',
      (tester) async {
    final client = _RadarClient((_) async => _frames([-1200, -720, 0]));
    final controller = _controller(client);
    await controller.initialize();

    expect(client.requests, hasLength(1));
    expect(controller.isLatest, isTrue);
    expect(controller.selectedFrame!.timestamp, _timestamp);
    controller.togglePlayback();
    expect(controller.playing, isTrue);
    expect(controller.selectedFrame!.timestamp, _timestamp - 1200);
    await tester.pump(const Duration(milliseconds: 900));
    expect(controller.selectedFrame!.timestamp, _timestamp - 720);

    controller.selectIndex(1);
    expect(controller.playing, isFalse);
    expect(controller.hasPlaybackTimer, isFalse);
    await tester.pump(const Duration(seconds: 3));
    expect(controller.selectedIndex, 1);
    controller.togglePlayback();
    expect(controller.selectedIndex, 1);
    await tester.pump(const Duration(milliseconds: 900));
    expect(controller.selectedIndex, 2);
    await tester.pump(const Duration(milliseconds: 900));
    expect(controller.selectedIndex, 0);
  });

  _controllerTest(
      'mode caches restore separate selections without duplicate loads',
      (tester) async {
    final client = _RadarClient((request) async => request.mode.isFutureCast
        ? _frames([0, 600, 1800], mode: RadarMode.futureCast)
        : _frames([-1200, -600, 0]));
    final controller = _controller(client);
    await controller.initialize();
    controller.selectIndex(1);
    controller.togglePlayback();
    await controller.setMode(RadarMode.futureCast);
    expect(controller.playing, isFalse);
    expect(controller.selectedFrame!.timestamp, _timestamp);
    expect(controller.selectedFrame!.source, 'openweather_futurecast');
    controller.selectIndex(2);

    await controller.setMode(RadarMode.usForecast);
    expect(controller.selectedIndex, 1);
    expect(controller.selectedFrame!.source, 'noaa_mrms');
    await controller.setMode(RadarMode.futureCast);
    expect(controller.selectedIndex, 2);
    expect(client.requests, hasLength(2));
  });

  _controllerTest(
      'refresh follows Latest but retains manual history and nearest gaps',
      (tester) async {
    var offsets = [-1200, -600, 0];
    final client = _RadarClient((_) async => _frames(offsets));
    final controller = _controller(client);
    await controller.initialize();
    offsets = [-1200, -600, 0, 300];
    await controller.refresh();
    expect(controller.selectedFrame!.timestamp, _timestamp + 300);

    controller.selectIndex(1);
    offsets = [-1200, -600, 0, 300, 600];
    await controller.refresh();
    expect(controller.selectedFrame!.timestamp, _timestamp - 600);
    offsets = [-900, -300, 0, 600];
    await controller.refresh();
    expect(controller.selectedFrame!.timestamp, _timestamp - 900);
    expect(controller.isLatest, isFalse);
    controller.jumpToLatestOrNow();
    expect(controller.selectedFrame!.timestamp, _timestamp + 600);
  });

  _controllerTest('slow refresh cannot undo a newer manual selection',
      (tester) async {
    final deferred = Completer<RadarFrameSet>();
    final client = _RadarClient((_) async => _frames([-1200, -600, 0]));
    final controller = _controller(client);
    await controller.initialize();
    client.response = (_) => deferred.future;
    final pending = controller.refresh();
    final samePending = controller.refresh();
    controller.selectIndex(0);
    deferred.complete(_frames([-1200, -600, 0, 300]));
    await Future.wait([pending, samePending]);
    expect(client.requests, hasLength(2));
    expect(controller.selectedFrame!.timestamp, _timestamp - 1200);
    expect(controller.loading, isFalse);
  });

  _controllerTest(
      'late mode and location responses never replace active imagery',
      (tester) async {
    final initial = Completer<RadarFrameSet>();
    final client = _RadarClient((request) {
      if (request.location == _location.lat && !request.mode.isFutureCast) {
        return initial.future;
      }
      return Future.value(request.mode.isFutureCast
          ? _frames([0, 600], mode: RadarMode.futureCast)
          : _frames([-300, 0]));
    });
    final controller = _controller(client);
    final oldLoad = controller.initialize();
    await controller.setMode(RadarMode.futureCast);
    initial.complete(_frames([-1200, 0]));
    await oldLoad;
    expect(controller.mode, RadarMode.futureCast);
    expect(controller.selectedFrame!.source, 'openweather_futurecast');

    final oldLocation = Completer<RadarFrameSet>();
    client.response = (request) => request.location == _location.lat
        ? oldLocation.future
        : Future.value(_frames([600, 1200], mode: RadarMode.futureCast));
    final oldRefresh = controller.refresh();
    await controller.setLocation(_elsewhere);
    expect(controller.location, _elsewhere);
    expect(controller.selectedFrame!.timestamp, _timestamp + 600);
    oldLocation.complete(_frames([0, 1800], mode: RadarMode.futureCast));
    await oldRefresh;
    expect(controller.selectedFrame!.timestamp, _timestamp + 600);
  });

  _controllerTest(
      'Now chooses next real forecast, and expired data disables it',
      (tester) async {
    var now = _start.add(const Duration(minutes: 3));
    final client = _RadarClient((request) async => request.mode.isFutureCast
        ? _frames([-600, 0, 600, 1200], mode: RadarMode.futureCast)
        : _frames([-600, 0]));
    final controller = _controller(client, now: () => now);
    await controller.initialize();
    await controller.setMode(RadarMode.futureCast);
    expect(controller.selectedFrame!.timestamp, _timestamp + 600);
    expect(controller.frames, hasLength(2));
    controller.selectIndex(1);
    controller.jumpToLatestOrNow();
    expect(controller.selectedFrame!.timestamp, _timestamp + 600);
    now = _start.add(const Duration(hours: 1));
    await controller.refresh();
    expect(controller.frames, isEmpty);
    expect(controller.selectedFrame, isNull);
    expect(controller.canJumpToNow, isFalse);
    expect(controller.message, contains('expired'));
    await controller.setMode(RadarMode.usForecast);
    expect(controller.selectedFrame, isNotNull);
  });

  _controllerTest(
      'failed refresh retains frame timing and does not renew freshness',
      (tester) async {
    var now = _start;
    final client = _RadarClient((_) async => _frames([-1200, -600]));
    final controller = _controller(client, now: () => now);
    await controller.initialize();
    final frame = controller.selectedFrame;
    final success = controller.lastSuccessfulRefresh;
    now = now.add(const Duration(minutes: 10));
    client.response = (_) => Future.error(
          const OpenWeatherBackendException('Offline.'),
        );
    await controller.refresh();
    expect(controller.selectedFrame, frame);
    expect(controller.lastSuccessfulRefresh, success);
    expect(controller.message, contains('previously loaded'));
    expect(controller.loading, isFalse);
  });

  _controllerTest(
      'visibility gates all schedulers and repeated resume creates one',
      (tester) async {
    final client = _RadarClient((_) async => _frames([-1200, -600, 0]));
    final controller = _controller(client);
    await controller.initialize();
    controller.togglePlayback();
    controller.setActive(false);
    final frame = controller.selectedFrame;
    await tester.pump(const Duration(minutes: 3));
    expect(client.requests, hasLength(1));
    expect(client.healthRequests, isEmpty);
    expect(controller.selectedFrame, frame);
    expect(controller.hasPlaybackTimer, isFalse);
    expect(controller.hasRefreshTimer, isFalse);
    for (var i = 0; i < 20; i++) {
      controller.setActive(true);
      controller.setActive(false);
    }
    controller.setActive(true);
    controller.setActive(true);
    expect(controller.playing, isFalse);
    expect(controller.hasRefreshTimer, isTrue);
    await tester.pump(const Duration(minutes: 1));
    expect(client.requests, hasLength(2));
    _disposeController(controller);
    await tester.pump(const Duration(minutes: 3));
    expect(client.requests, hasLength(2));
  });

  _controllerTest('rapid scrubbing coalesces the bounded two-frame warmup',
      (tester) async {
    final client =
        _RadarClient((_) async => _frames([-1200, -900, -600, -300, 0]));
    final controller = _controller(client);
    await controller.initialize();
    for (var i = 0; i < 100; i++) {
      controller.selectIndex(i % 5);
    }
    expect(client.healthRequests, isEmpty);
    await tester.pump(const Duration(milliseconds: 180));
    expect(client.healthRequests, hasLength(2));
    for (var i = 0; i < 100; i++) {
      controller.selectIndex(4);
    }
    await tester.pump(const Duration(milliseconds: 180));
    expect(client.healthRequests, hasLength(2));
    expect(client.requests, hasLength(1));
  });

  _controllerTest('empty or wrong-source metadata never creates a fake frame',
      (tester) async {
    final client = _RadarClient((_) async => _frames([]));
    final controller = _controller(client);
    await controller.initialize();
    expect(controller.selectedFrame, isNull);
    expect(controller.frames, isEmpty);
    expect(controller.canJumpToNow, isFalse);
    controller.togglePlayback();
    expect(controller.playing, isFalse);
    client.response = (_) async => _frames([-600, 0]);
    await controller.setMode(RadarMode.futureCast);
    expect(controller.mode, RadarMode.futureCast);
    expect(controller.selectedFrame, isNull);
    expect(controller.message, contains('unavailable'));
    await tester.pump(const Duration(minutes: 2));
    expect(client.requests, hasLength(2));
  });

  _controllerTest('initially hidden radar starts no requests or schedulers',
      (tester) async {
    final client = _RadarClient((_) async => _frames([-600, 0]));
    final controller = _controller(client);
    controller.setActive(false);
    await controller.initialize();
    await controller.initialize();
    await tester.pump(const Duration(minutes: 2));
    expect(client.requests, isEmpty);
    expect(client.healthRequests, isEmpty);
    expect(controller.hasRefreshTimer, isFalse);
    expect(controller.hasPlaybackTimer, isFalse);

    controller.setActive(true);
    await tester.pump();
    await controller.initialize();
    controller.setActive(true);
    expect(client.requests, hasLength(1));
    expect(controller.hasRefreshTimer, isTrue);
    expect(controller.playing, isFalse);
  });

  _controllerTest(
      'late hidden or disposed requests do not render or warm tiles',
      (tester) async {
    final initial = Completer<RadarFrameSet>();
    final client = _RadarClient((_) => initial.future);
    final controller = _controller(client);
    var notifications = 0;
    controller.addListener(() => notifications++);
    final pending = controller.initialize();
    controller.setActive(false);
    final hiddenNotifications = notifications;
    initial.complete(_frames([-600, 0]));
    await pending;
    await tester.pump(const Duration(seconds: 2));
    expect(notifications, hiddenNotifications);
    expect(client.healthRequests, isEmpty);
    expect(controller.hasRefreshTimer, isFalse);
    expect(controller.selectedFrame, isNotNull);

    controller.setActive(true);
    expect(client.requests, hasLength(1));
    final refresh = Completer<RadarFrameSet>();
    client.response = (_) => refresh.future;
    final finishingAfterDispose = controller.refresh();
    final beforeDispose = notifications;
    _disposeController(controller);
    refresh.complete(_frames([-600, 0, 300]));
    await finishingAfterDispose;
    await tester.pump(const Duration(minutes: 2));
    expect(notifications, beforeDispose);
    expect(client.requests, hasLength(2));
    expect(client.healthRequests, isEmpty);
  });

  _controllerTest('playback stops when the last forecast frame expires',
      (tester) async {
    var now = _start;
    final client = _RadarClient((request) async => request.mode.isFutureCast
        ? _frames([0, 600], mode: RadarMode.futureCast)
        : _frames([-600, 0]));
    final controller = _controller(client, now: () => now);
    await controller.initialize();
    await controller.setMode(RadarMode.futureCast);
    controller.togglePlayback();
    expect(controller.playing, isTrue);
    now = now.add(const Duration(minutes: 11));
    await tester.pump(RadarPlaybackController.playbackInterval);
    expect(controller.playing, isFalse);
    expect(controller.hasPlaybackTimer, isFalse);
    expect(controller.selectedFrame, isNull);
    expect(controller.canJumpToNow, isFalse);
    expect(controller.message, contains('expired'));
    expect(client.requests, hasLength(2));
  });

  _controllerTest(
      'failed mode and tab entries coalesce retries without freshening',
      (tester) async {
    var now = _start;
    final client = _RadarClient((_) => Future.error(
          const OpenWeatherBackendException('Offline.'),
        ));
    final controller = _controller(client, now: () => now);
    await controller.initialize();
    await controller.setMode(RadarMode.futureCast);
    for (var i = 0; i < 10; i++) {
      await controller.setMode(RadarMode.usForecast);
      await controller.setMode(RadarMode.futureCast);
      controller.setActive(false);
      controller.setActive(true);
      await tester.pump();
    }
    expect(client.requests, hasLength(2));
    expect(controller.lastSuccessfulRefresh, isNull);
    expect(controller.message, 'Offline.');

    now = now.add(const Duration(seconds: 61));
    controller.setActive(false);
    controller.setActive(true);
    await tester.pump();
    expect(client.requests, hasLength(3));
    expect(controller.lastSuccessfulRefresh, isNull);
    await controller.refresh();
    expect(client.requests, hasLength(4));
  });
}

RadarPlaybackController _controller(
  _RadarClient client, {
  DateTime Function()? now,
}) {
  final controller = RadarPlaybackController(
    client: client,
    location: _location,
    now: now ?? () => _start,
  );
  _controllers.add(controller);
  return controller;
}

final _controllers = <RadarPlaybackController>[];

// Dispose before Flutter's end-of-test timer invariants, including on failure.
void _controllerTest(
    String description, Future<void> Function(WidgetTester) body) {
  testWidgets(description, (tester) async {
    try {
      await body(tester);
    } finally {
      for (final controller in _controllers.toList()) {
        _disposeController(controller);
      }
    }
  });
}

void _disposeController(RadarPlaybackController controller) {
  if (_controllers.remove(controller)) controller.dispose();
}

RadarFrameSet _frames(List<int> offsets,
    {RadarMode mode = RadarMode.usForecast}) {
  final values = offsets
      .map((offset) => RadarFrame(
            timestamp: _timestamp + offset,
            label: '',
            type: mode.isFutureCast
                ? RadarFrameType.forecast
                : offset == offsets.last
                    ? RadarFrameType.latest
                    : RadarFrameType.history,
            isLatest: !mode.isFutureCast && offset == offsets.last,
            source: mode.sourceParam,
          ))
      .toList();
  return RadarFrameSet(
    source: mode.sourceParam,
    latestTimestamp: values.isEmpty ? 0 : values.last.timestamp,
    frames: values,
    futureCastAvailable: mode.isFutureCast && values.isNotEmpty,
  );
}

class _Request {
  const _Request(this.mode, this.location);
  final RadarMode mode;
  final double location;
}

class _RadarClient extends OpenWeatherBackendClient {
  _RadarClient(this.response) : super(baseUrl: 'https://example.com/api');

  Future<RadarFrameSet> Function(_Request) response;
  final List<_Request> requests = [];
  final List<int> healthRequests = [];

  @override
  Future<RadarFrameSet> radarFrames({
    required RadarMode mode,
    required double latitude,
    required double longitude,
    int hours = 6,
  }) {
    final request = _Request(mode, latitude);
    requests.add(request);
    return response(request);
  }

  @override
  Future<RadarHealth> radarTileHealth({
    required RadarMode mode,
    required int timestamp,
    required double latitude,
    required double longitude,
    String? source,
  }) async {
    healthRequests.add(timestamp);
    return RadarHealth(
      ok: true,
      source: source ?? mode.sourceParam,
      humanReadableMessage: 'Available',
    );
  }
}
