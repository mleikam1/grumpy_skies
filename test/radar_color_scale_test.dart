import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:grumpy_skies/design/dm_theme.dart';
import 'package:grumpy_skies/features/radar/widgets/radar_color_scale.dart';

void main() {
  testWidgets('only the documented global product gets a numerical color bar',
      (tester) async {
    Future<void> pump(String source) => tester.pumpWidget(MaterialApp(
          theme: DMTheme.light,
          home: Scaffold(
            body: SizedBox(
              width: 280,
              child: RadarColorScale(source: source),
            ),
          ),
        ));
    await pump('openweather_global');
    expect(find.text('70+ dBZ'), findsOneWidget);
    expect(find.text('Severe'), findsNothing);
    await pump('noaa_mrms');
    expect(find.text('Reflectivity · dBZ'), findsOneWidget);
    expect(find.text('70+ dBZ'), findsNothing);
    await pump('openweather_futurecast');
    expect(find.text('Precipitation color guide'), findsOneWidget);
    expect(find.text('70+ dBZ'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('color guide action fits narrow large text and remains reachable',
      (tester) async {
    var opened = 0;
    await tester.pumpWidget(MaterialApp(
      theme: DMTheme.dark,
      home: Scaffold(
        body: MediaQuery(
          data: const MediaQueryData(textScaler: TextScaler.linear(2)),
          child: SizedBox(
            width: 280,
            child: RadarColorScale(
              source: 'openweather_futurecast',
              onOpenGuide: () => opened++,
            ),
          ),
        ),
      ),
    ));
    await tester.tap(find.text('Precipitation color guide'));
    expect(opened, 1);
    expect(
        tester.getSize(find.byType(InkWell)).height, greaterThanOrEqualTo(48));
    expect(tester.takeException(), isNull);
  });
}
