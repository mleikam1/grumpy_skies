import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:grumpy_skies/design/dm_theme.dart';
import 'package:grumpy_skies/features/fun/meme_generator_screen.dart';
import 'package:grumpy_skies/features/fun/widgets/meme_canvas.dart';

void main() {
  Widget buildSubject() {
    return MaterialApp(
      key: UniqueKey(),
      theme: DMTheme.light,
      home: const MemeGeneratorScreen(),
    );
  }

  void setSurfaceSize(WidgetTester tester, Size size) {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });
  }

  Future<void> scrollUntilTextVisible(
    WidgetTester tester,
    String text,
  ) async {
    final finder = find.text(text);
    for (var attempts = 0; attempts < 8; attempts++) {
      if (finder.evaluate().isNotEmpty) {
        await tester.ensureVisible(finder);
        await tester.pumpAndSettle();
        return;
      }

      await tester.drag(
        find.descendant(
          of: find.byType(MemeGeneratorScreen),
          matching: find.byType(ListView),
        ),
        const Offset(0, -280),
      );
      await tester.pumpAndSettle();
    }

    expect(finder, findsOneWidget);
  }

  testWidgets('renders compact meme generator', (tester) async {
    setSurfaceSize(tester, const Size(390, 844));

    await tester.pumpWidget(buildSubject());
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.text('DayMaker'), findsWidgets);
    expect(find.text('Meme Generator'), findsOneWidget);
    expect(find.text('Pro'), findsOneWidget);

    await scrollUntilTextVisible(tester, 'Epic');

    expect(find.text('Epic'), findsOneWidget);
    expect(find.text('Cute'), findsOneWidget);
    expect(find.text('Sarcastic'), findsOneWidget);
    expect(find.text('Cozy'), findsOneWidget);
    expect(find.text('Retro'), findsOneWidget);

    await scrollUntilTextVisible(tester, 'Change Background');

    expect(find.text('Change Background'), findsOneWidget);
    expect(find.text('Use Current Roast'), findsOneWidget);
    expect(find.text('Randomize Text'), findsOneWidget);
    expect(find.text('Export & Share'), findsOneWidget);
    expect(find.bySemanticsLabel('Top Text meme text field'), findsOneWidget);
    expect(
      find.bySemanticsLabel('Bottom Text meme text field'),
      findsOneWidget,
    );
    expect(find.bySemanticsLabel('Randomize meme text'), findsOneWidget);
    expect(find.bySemanticsLabel('Export and share meme'), findsOneWidget);
  });

  testWidgets('text fields update meme preview live', (tester) async {
    setSurfaceSize(tester, const Size(390, 844));

    await tester.pumpWidget(buildSubject());
    await tester.pumpAndSettle();

    await scrollUntilTextVisible(tester, 'Top Text');
    await tester.enterText(find.byType(TextField).at(0), 'storm mode');
    await tester.enterText(find.byType(TextField).at(1), 'bring snacks');
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.text('STORM MODE'), findsNWidgets(2));
    expect(find.text('BRING SNACKS'), findsNWidgets(2));
  });

  testWidgets('tool cards update copy and show export SnackBar',
      (tester) async {
    setSurfaceSize(tester, const Size(390, 844));

    await tester.pumpWidget(buildSubject());
    await tester.pumpAndSettle();

    await scrollUntilTextVisible(tester, 'Use Current Roast');
    await tester.tap(find.text('Use Current Roast'));
    await tester.pumpAndSettle();

    expect(
      find.descendant(
        of: find.byType(MemeCanvas),
        matching: find.text('TODAY\'S FORECAST'),
      ),
      findsNWidgets(2),
    );
    expect(
      find.descendant(
        of: find.byType(MemeCanvas),
        matching: find.text('A LITTLE RUDE, VERY SHAREABLE'),
      ),
      findsNWidgets(2),
    );
    expect(find.text('Current roast dropped into the meme.'), findsOneWidget);

    await tester.pump(const Duration(seconds: 4));
    await tester.pumpAndSettle();
    await scrollUntilTextVisible(tester, 'Export & Share');
    await tester.tap(find.text('Export & Share'));
    await tester.pump();

    expect(
      find.text('Export & Share will capture this canvas soon.'),
      findsOneWidget,
    );
  });
}
