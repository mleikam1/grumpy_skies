import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:grumpy_skies/features/radar/widgets/open_weather_radar_map.dart';
import 'package:grumpy_skies/features/radar/widgets/radar_control_dock.dart';
import 'package:grumpy_skies/models/weather_models.dart';
import 'package:grumpy_skies/shared/widgets/dm_bottom_nav.dart';

import 'helpers/radar_test_harness.dart';

const _rootDefine = String.fromEnvironment('RADAR_CAPTURE_ROOT');
const _tileDefine = String.fromEnvironment('RADAR_REVIEW_TILE_DIRECTORY');
String get _root => _rootDefine.isNotEmpty
    ? _rootDefine
    : Platform.environment['RADAR_CAPTURE_ROOT'] ?? '';
String get _tiles => _tileDefine.isNotEmpty
    ? _tileDefine
    : Platform.environment['RADAR_REVIEW_TILE_DIRECTORY'] ?? '';

Future<void> _save(WidgetTester tester, RadarTestHarness h, String name) async {
  expect(tester.takeException(), isNull);
  if (_root.isEmpty) return;
  await tester.runAsync(() async {
    final boundary =
        h.boundary.currentContext!.findRenderObject()! as RenderRepaintBoundary;
    final image = await boundary.toImage(pixelRatio: 2);
    final data = await image.toByteData(format: ui.ImageByteFormat.png);
    final file = File('$_root/$name.png');
    await file.parent.create(recursive: true);
    await file.writeAsBytes(data!.buffer.asUint8List());
    image.dispose();
  });
}

OpenWeatherRadarMap _map(WidgetTester tester) =>
    tester.widget<OpenWeatherRadarMap>(find.byType(OpenWeatherRadarMap));

Future<void> _close(WidgetTester tester, String title) async {
  await tester.tap(find.byTooltip('Close $title'));
  await RadarTestHarness.settle(tester);
}

Future<void> _dragDockToTarget(
    WidgetTester tester, Finder scroll, Finder target, double delta) async {
  for (var attempt = 0;
      attempt < 10 && target.hitTestable().evaluate().isEmpty;
      attempt++) {
    await tester.drag(scroll, Offset(0, delta));
    await RadarTestHarness.settle(tester);
  }
  expect(target.hitTestable(), findsOneWidget,
      reason: 'Dock controls must become touch reachable by scrolling.');
}

Future<void> _checkConstrainedControls(
    WidgetTester tester, RadarTestHarness h, String prefix) async {
  final scroll = find.ancestor(
      of: find.byType(RadarControlDock),
      matching: find.byType(SingleChildScrollView));
  final timeline = find.descendant(
      of: find.byType(RadarControlDock), matching: find.byType(Slider));
  final details = find.text('Details');
  final metadataBefore = h.metadataRequests;
  await _dragDockToTarget(tester, scroll, timeline, -160);
  final previousFrame = h.radar.selectedFrame!.timestamp;
  final timelineBounds = tester.getRect(timeline);
  await tester.tapAt(Offset(timelineBounds.left + timelineBounds.width * .35,
      timelineBounds.center.dy));
  await RadarTestHarness.settle(tester);
  expect(h.radar.selectedFrame!.timestamp, isNot(previousFrame));
  expect(_map(tester).frame!.timestamp, h.radar.selectedFrame!.timestamp);
  expect(h.radar.playing, isFalse);

  await _dragDockToTarget(tester, scroll, details, -160);
  await _save(tester, h, '${prefix}_controls_scrolled');
  await tester.tap(details.hitTestable());
  await RadarTestHarness.settle(tester);
  expect(find.byTooltip('Close Radar details').hitTestable(), findsOneWidget);
  expect(find.textContaining('Selected frame:'), findsOneWidget);
  expect(find.textContaining('Chaos '), findsNothing,
      reason: 'Current Chaos must not describe a historical frame.');
  await _close(tester, 'Radar details');
  h.radar.jumpToLatestOrNow();
  await RadarTestHarness.settle(tester);
  expect(find.textContaining('Chaos '), findsNothing,
      reason: 'The compact chip is hidden at constrained viewport sizes.');
  await tester.tap(details.hitTestable());
  await RadarTestHarness.settle(tester);
  expect(find.textContaining('Chaos '), findsOneWidget,
      reason: 'Current Chaos explanation must remain available in Details.');
  expect(find.textContaining('A snapshot of current and upcoming'),
      findsOneWidget);
  await _close(tester, 'Radar details');
  expect(find.byTooltip('Close Radar details'), findsNothing);
  expect(h.metadataRequests, metadataBefore);

  // The same dock must return to its mode selector by an ordinary touch drag.
  // This also keeps the subsequent FutureCast capture at its normal position.
  await _dragDockToTarget(
      tester, scroll, find.bySemanticsLabel('Show FutureCast'), 160);
  await tester.drag(scroll, const Offset(0, 1000));
  await RadarTestHarness.settle(tester);
  expect(tester.widget<SingleChildScrollView>(scroll).controller!.offset,
      closeTo(0, .01));
}

void main() {
  for (final dark in [false, true]) {
    for (final view in [
      ('phone', const Size(390, 844), 1.0),
      ('reference', const Size(427, 922), 1.0),
      ('compact', const Size(320, 740), 1.0),
      ('large_text', const Size(320, 740), 2.0),
      ('tablet', const Size(768, 1024), 1.0),
      ('landscape', const Size(844, 390), 1.0),
    ]) {
      testWidgets('radar cleanup ${view.$1} dark=$dark three connected states',
          (tester) async {
        final tiles = _tiles.isEmpty ? null : RadarRecordedBasemapTiles(_tiles);
        final h = RadarTestHarness();
        await h.pump(tester,
            size: view.$2, textScale: view.$3, dark: dark, tileProvider: tiles);
        final prefix = '${dark ? 'dark' : 'light'}_${view.$1}';
        final mapState = tester.state(find.byType(FlutterMap));
        expect(find.byType(DmBottomNav), findsOneWidget);
        await _save(tester, h, '${prefix}_live');
        if (view.$1 == 'large_text' || view.$1 == 'landscape') {
          await _checkConstrainedControls(tester, h, prefix);
        }
        await tester.tap(find.bySemanticsLabel('Show FutureCast'));
        await RadarTestHarness.settle(tester);
        expect(h.radar.mode, RadarMode.futureCast);
        expect(_map(tester).frame!.source, 'openweather_futurecast');
        expect(find.text('Forecast precipitation'), findsOneWidget);
        await _save(tester, h, '${prefix}_futurecast');
        await tester.tap(find.byTooltip('Expand map'));
        await RadarTestHarness.settle(tester);
        expect(find.byType(DmBottomNav), findsNothing);
        expect(find.text('Done'), findsOneWidget);
        expect(
            identical(tester.state(find.byType(FlutterMap)), mapState), isTrue);
        await _save(tester, h, '${prefix}_expanded_futurecast');
        await tester.tap(find.text('Done'));
        await RadarTestHarness.settle(tester);
        await tester.tap(find.bySemanticsLabel('Show Live Radar'));
        await RadarTestHarness.settle(tester);
        await tester.tap(find.byTooltip('Expand map'));
        await RadarTestHarness.settle(tester);
        expect(_map(tester).frame!.source, 'noaa_mrms');
        await _save(tester, h, '${prefix}_expanded_live');
        if (view.$1 == 'phone') {
          await tester.tap(find.byTooltip('Radar layers'));
          await RadarTestHarness.settle(tester);
          await _save(tester, h, '${prefix}_layers');
          await _close(tester, 'Layers');
          await tester.tap(find.byTooltip('Radar details'));
          await RadarTestHarness.settle(tester);
          await _save(tester, h, '${prefix}_details');
          await _close(tester, 'Radar details');
        }
        if (_root.isNotEmpty) {
          await tester.runAsync(() async {
            await File('$_root/${prefix}_evidence.json')
                .writeAsString(const JsonEncoder.withIndent('  ').convert({
              'viewport': [view.$2.width, view.$2.height],
              'textScale': view.$3,
              'theme': dark ? 'dark' : 'light',
              'screen': 'Production RadarScreen in production DaymakerShell',
              'metadata': 'Deterministic fixture, not current weather coverage',
              'basemap': tiles == null
                  ? 'Transparent test tiles'
                  : 'Recorded real OSM tiles',
              'recordedBasemapRequests': tiles?.recordedSquares ?? 0,
              'missingRecordedBasemapSquares': tiles?.missingSquares ?? 0,
              'weatherImagery': 'Transparent; no simulated precipitation',
              'metadataRequests': h.metadataRequests,
            }));
          });
        }
        await h.dispose(tester);
      });
    }
  }

  testWidgets(
      'twenty expand cycles preserve camera frame mode opacity and playback owner',
      (tester) async {
    final h = RadarTestHarness();
    await h.pump(tester);
    await tester.tap(find.byTooltip('Radar layers'));
    await RadarTestHarness.settle(tester);
    final opacity = tester.widget<Slider>(find.descendant(
        of: find.byType(BottomSheet), matching: find.byType(Slider)));
    opacity.onChanged!(.4);
    opacity.onChangeEnd?.call(.4);
    await tester.pump();
    await _close(tester, 'Layers');
    _map(tester).mapController.move(const LatLng(39.05, -94.58), 11);
    await tester.pump();
    final mapState = tester.state(find.byType(FlutterMap));
    final mapOwner = tester.state(find.byType(OpenWeatherRadarMap));
    final center = _map(tester).mapController.camera.center;
    final requestEvidence = <Map<String, Object?>>[];
    for (final mode in [RadarMode.usForecast, RadarMode.futureCast]) {
      await h.radar.setMode(mode);
      await RadarTestHarness.settle(tester);
      h.radar.selectIndex(1);
      await RadarTestHarness.settle(tester);
      h.radar.togglePlayback();
      await tester.pump();
      final frame = h.radar.selectedFrame!.timestamp;
      final metadataBefore = h.metadataRequests;
      for (var cycle = 0; cycle < 10; cycle++) {
        await tester.tap(find.byTooltip('Expand map'));
        await tester.pump();
        await tester.pump();
        expect(find.byType(DmBottomNav), findsNothing);
        expect(h.radar.selectedFrame!.timestamp, frame);
        expect(h.radar.mode, mode);
        expect(h.radar.playing, isTrue);
        expect(h.radar.hasPlaybackTimer, isTrue);
        expect(_map(tester).opacity, .4);
        expect(_map(tester).mapController.camera.zoom, 11);
        expect(_map(tester).mapController.camera.center.latitude,
            closeTo(center.latitude, 1e-9));
        expect(_map(tester).mapController.camera.center.longitude,
            closeTo(center.longitude, 1e-9));
        expect(
            identical(tester.state(find.byType(FlutterMap)), mapState), isTrue);
        expect(
            identical(tester.state(find.byType(OpenWeatherRadarMap)), mapOwner),
            isTrue);
        await tester.tap(find.text('Done'));
        await tester.pump();
        await tester.pump();
        expect(find.byType(DmBottomNav), findsOneWidget);
        expect(h.radar.selectedFrame!.timestamp, frame);
        expect(h.radar.playing, isTrue);
      }
      expect(h.metadataRequests, metadataBefore);
      requestEvidence.add({
        'mode': mode.name,
        'cycles': 10,
        'metadataBefore': metadataBefore,
        'metadataAfter': h.metadataRequests,
        'frameTimestamp': frame,
        'opacity': _map(tester).opacity,
        'mapStatePreserved': true,
        'playingPreserved': true,
      });
      h.radar.togglePlayback();
      await tester.pump();
    }
    final requestsBeforePanels = h.metadataRequests;
    final allBeforePanels = Map<String, int>.of(h.counts);
    for (var count = 0; count < 3; count++) {
      await tester.tap(find.byTooltip('Radar layers'));
      await RadarTestHarness.settle(tester);
      await _close(tester, 'Layers');
      await tester.tap(find.text('Details'));
      await RadarTestHarness.settle(tester);
      await _close(tester, 'Radar details');
    }
    expect(h.metadataRequests, requestsBeforePanels);
    expect(h.counts, allBeforePanels);
    if (_root.isNotEmpty) {
      await tester.runAsync(() async {
        await Directory(_root).create(recursive: true);
        await File('$_root/request-state-proof.json')
            .writeAsString(const JsonEncoder.withIndent('  ').convert({
          'scope':
              'Real screen and controller; deterministic provider and transparent tile boundary',
          'cycles': requestEvidence,
          'panelCycles': 3,
          'requestsBeforePanels': allBeforePanels,
          'requestsAfterPanels': h.counts,
          'weatherRepositoryRequests': h.weather.requestCount,
          'remoteWrites': 0,
          'note':
              'Normal map tile downloads are outside the synthetic request counter. No production billing assertion.',
        }));
      });
    }
    expect(tester.takeException(), isNull);
    await h.dispose(tester);
  });

  testWidgets(
      'background stops scheduling and resume never creates duplicate playback',
      (tester) async {
    final h = RadarTestHarness();
    await h.pump(tester);
    h.radar.togglePlayback();
    await tester.pump();
    expect(h.radar.hasPlaybackTimer, isTrue);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    await tester.pump();
    expect(h.radar.active, isFalse);
    expect(h.radar.hasPlaybackTimer, isFalse);
    expect(h.radar.hasRefreshTimer, isFalse);
    final selected = h.radar.selectedFrame!.timestamp;
    final requests = h.metadataRequests;
    await tester.pump(const Duration(minutes: 3));
    expect(h.radar.selectedFrame!.timestamp, selected);
    expect(h.metadataRequests, requests);
    for (var count = 0; count < 5; count++) {
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pump();
    }
    expect(h.radar.hasRefreshTimer, isTrue);
    expect(h.radar.playing, isFalse);
    expect(h.radar.hasPlaybackTimer, isFalse);
    expect(h.metadataRequests, requests);
    h.radar.togglePlayback();
    await tester.pump(const Duration(milliseconds: 901));
    expect(h.radar.selectedIndex, 1);
    expect(tester.takeException(), isNull);
    await h.dispose(tester);
  });

  testWidgets(
      'Escape dismisses a panel then exits expanded map without resetting frame',
      (tester) async {
    final h = RadarTestHarness();
    await h.pump(tester);
    h.radar.selectIndex(1);
    await tester.pump();
    final frame = h.radar.selectedFrame!.timestamp;
    await tester.tap(find.byTooltip('Expand map'));
    await RadarTestHarness.settle(tester);
    await tester.tap(find.byTooltip('Radar layers'));
    await RadarTestHarness.settle(tester);
    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await RadarTestHarness.settle(tester);
    expect(find.byTooltip('Close Layers'), findsNothing);
    expect(find.text('Done'), findsOneWidget);
    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await RadarTestHarness.settle(tester);
    expect(find.text('Done'), findsNothing);
    expect(find.byType(DmBottomNav), findsOneWidget);
    expect(h.radar.selectedFrame!.timestamp, frame);
    expect(tester.takeException(), isNull);
    await h.dispose(tester);
  });
}
