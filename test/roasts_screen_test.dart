import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:grumpy_skies/design/dm_theme.dart';
import 'package:grumpy_skies/features/roasts/roasts_screen.dart';
import 'package:grumpy_skies/repositories/fake_roast_repository.dart';

void main() {
  Widget buildSubject() {
    return MaterialApp(
      theme: DMTheme.light,
      home: const RoastsScreen(
        roastRepository: FakeRoastRepository(),
      ),
    );
  }

  testWidgets('RoastsScreen renders DayMaker persona roasts on mobile',
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
    expect(find.text('DayMaker'), findsOneWidget);
    expect(find.text('Roasts'), findsOneWidget);
    expect(find.text('Pick your weather personality.'), findsOneWidget);
    expect(find.text('Karen'), findsWidgets);
    expect(find.text('ROAST QUEEN'), findsOneWidget);
    expect(
      find.text('It’s 72°F and somehow still making a scene.'),
      findsWidgets,
    );
    expect(find.text('Wind'), findsOneWidget);
    expect(find.text('Humidity'), findsOneWidget);
    expect(find.text('Persona carousel'), findsOneWidget);
    expect(find.text('Roast history'), findsOneWidget);
    expect(find.text('New roast coming soon'), findsOneWidget);
    expect(find.text('Cooling down'), findsOneWidget);
  });

  testWidgets('RoastsScreen updates featured roast when persona is selected',
      (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    await tester.pumpWidget(buildSubject());
    await tester.pumpAndSettle();

    await tester.ensureVisible(find.text('Frat Bro').first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Frat Bro').first);
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(
      find.text(
        'It’s 72°F, bro. The clouds are mid and the humidity is doing keg stands.',
      ),
      findsOneWidget,
    );

    await tester.ensureVisible(find.text('Share').first);
    await tester.pumpAndSettle();
    expect(
      find.bySemanticsLabel('Share featured roast from Frat Bro'),
      findsOneWidget,
    );
    await tester.tap(find.text('Share').first);
    await tester.pump();

    expect(find.text('Share action coming soon.'), findsOneWidget);
  });

  testWidgets('RoastsScreen shows full carousel across expanded web width',
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
    expect(find.text('Karen'), findsWidgets);
    expect(find.text('Frat Bro'), findsOneWidget);
    expect(find.text('Grandpa'), findsOneWidget);
    expect(find.text('Politician'), findsOneWidget);
    expect(find.text('2-Year-Old'), findsOneWidget);
  });
}
