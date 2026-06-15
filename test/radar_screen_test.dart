import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:grumpy_skies/design/dm_theme.dart';
import 'package:grumpy_skies/features/radar/radar_screen.dart';

void main() {
  Widget buildSubject() {
    return MaterialApp(
      theme: DMTheme.light,
      home: const RadarScreen(),
    );
  }

  testWidgets('RadarScreen renders compact DayMaker radar shell',
      (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    await tester.pumpWidget(buildSubject());
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.text('Live Radar'), findsOneWidget);
    expect(find.text('San Francisco, CA'), findsOneWidget);
    expect(find.text('Moderate storm moving in'), findsOneWidget);
    expect(find.text('Lightning'), findsOneWidget);
    expect(find.text('FutureCast'), findsOneWidget);
    expect(find.text('Now'), findsOneWidget);
    expect(find.text('+120m'), findsOneWidget);
    expect(find.text('82% chance of drama'), findsOneWidget);
    expect(find.text('within 8 miles'), findsOneWidget);
    expect(find.text('in 24 min'), findsOneWidget);
    expect(find.text('Provider-ready placeholder'), findsOneWidget);
  });

  testWidgets('RadarScreen keeps controls and alert panel available on web',
      (tester) async {
    tester.view.physicalSize = const Size(1200, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    await tester.pumpWidget(buildSubject());
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.bySemanticsLabel('Zoom in'), findsOneWidget);
    expect(find.bySemanticsLabel('Use current location'), findsOneWidget);
    expect(find.bySemanticsLabel('Radar layers'), findsOneWidget);
    expect(find.text('Chaos Meter'), findsOneWidget);
    expect(find.text('Lightning nearby'), findsOneWidget);
    expect(find.text('Rain'), findsOneWidget);
  });
}
