import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'package:grumpy_skies/design/dm_theme.dart';
import 'package:grumpy_skies/features/radar/radar_playback_controller.dart';
import 'package:grumpy_skies/features/radar/radar_presentation.dart';
import 'package:grumpy_skies/features/radar/widgets/radar_control_dock.dart';
import 'package:grumpy_skies/models/weather_models.dart';
import 'package:grumpy_skies/services/open_weather_backend_client.dart';

void main() {
  for (final offsets in [
    [-3600, 0],
    [-3600, -3590, 0],
  ]) {
    testWidgets(
        'keyboard visits each actual frame across ${offsets.length} irregular points',
        (tester) async {
      final now = DateTime.utc(2026, 10, 18, 12);
      final anchor = now.millisecondsSinceEpoch ~/ 1000;
      final client = OpenWeatherBackendClient(
        baseUrl: 'https://radar.test',
        httpClient: MockClient((request) async => http.Response(
              jsonEncode(request.url.path.endsWith('radarHealth')
                  ? {'ok': true, 'source': 'noaa_mrms'}
                  : {
                      'source': 'noaa_mrms',
                      'latestTimestamp': anchor,
                      'frames': [
                        for (final offset in offsets)
                          {
                            'timestamp': anchor + offset,
                            'source': 'noaa_mrms',
                            'type': offset == 0 ? 'latest' : 'history',
                            'isLatest': offset == 0,
                          }
                      ],
                    }),
              200,
              headers: {'content-type': 'application/json'},
            )),
      );
      final controller = RadarPlaybackController(
        client: client,
        location: const LocationCandidate(
          name: 'Chicago',
          country: 'US',
          lat: 41.88,
          lon: -87.63,
          source: 'city',
        ),
        now: () => now,
      );
      try {
        await controller.initialize();
        controller.selectIndex(0);
        await tester.pumpWidget(MaterialApp(
          theme: DMTheme.light,
          home: Scaffold(
            body: Center(
              child: SizedBox(
                width: 390,
                child: ListenableBuilder(
                  listenable: controller,
                  builder: (context, _) => RadarControlDock(
                    controller: controller,
                    presentation: RadarPresentation(
                      mode: controller.mode,
                      frames: controller.frames,
                      frame: controller.selectedFrame,
                      now: now,
                    ),
                    expanded: false,
                    onDetails: () {},
                    onLegend: () {},
                  ),
                ),
              ),
            ),
          ),
        ));
        for (var i = 0;
            i < 12 &&
                FocusManager.instance.primaryFocus?.debugLabel !=
                    'Radar timeline';
            i++) {
          await tester.sendKeyEvent(LogicalKeyboardKey.tab);
          await tester.pump();
        }
        expect(
            FocusManager.instance.primaryFocus?.debugLabel, 'Radar timeline');

        for (var index = 1; index < offsets.length; index++) {
          await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
          await tester.pump();
          expect(controller.selectedIndex, index);
          final expected = (offsets[index] - offsets.first) / -offsets.first;
          expect(tester.widget<Slider>(find.byType(Slider)).value,
              closeTo(expected, .00001));
        }
        await tester.sendKeyEvent(LogicalKeyboardKey.home);
        await tester.pump();
        expect(controller.selectedIndex, 0);
        controller.togglePlayback();
        await tester.pump();
        expect(controller.playing, isTrue);
        await tester.sendKeyEvent(LogicalKeyboardKey.arrowUp);
        await tester.pump();
        expect(controller.selectedIndex, 1);
        expect(controller.playing, isFalse);
        await tester.sendKeyEvent(LogicalKeyboardKey.end);
        await tester.pump();
        expect(controller.selectedIndex, offsets.length - 1);
        await tester.sendKeyEvent(LogicalKeyboardKey.arrowLeft);
        await tester.pump();
        expect(controller.selectedIndex, offsets.length - 2);
        expect(tester.takeException(), isNull);
      } finally {
        await tester.pumpWidget(const SizedBox.shrink());
        controller.dispose();
        await tester.pump();
      }
    });
  }
}
