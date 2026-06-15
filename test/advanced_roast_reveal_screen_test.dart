import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:grumpy_skies/design/dm_theme.dart';
import 'package:grumpy_skies/features/roasts/advanced_roast_reveal_screen.dart';
import 'package:grumpy_skies/features/roasts/widgets/advanced_roast_reveal_card.dart';

void main() {
  const roastText = 'You have more unopened tabs than opportunities.';

  Widget buildSubject() {
    return MaterialApp(
      theme: DMTheme.light,
      home: const AdvancedRoastRevealScreen(),
    );
  }

  void setViewport(WidgetTester tester, Size size) {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });
  }

  testWidgets('renders advanced roast reveal screen on mobile', (tester) async {
    setViewport(tester, const Size(390, 844));

    await tester.pumpWidget(buildSubject());
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.text('DayMaker'), findsOneWidget);
    expect(find.text('Level 3'), findsOneWidget);
    expect(find.text('420 XP'), findsOneWidget);
    expect(find.text('5 day streak'), findsOneWidget);
    expect(find.text('Advanced Roast'), findsOneWidget);
    expect(find.text('Today\'s roast is extra toasty.'), findsOneWidget);
    expect(find.text('How it works'), findsOneWidget);
    expect(find.text('Clear the clouds to reveal your roast'), findsOneWidget);
    expect(find.text(roastText), findsNothing);
    expect(find.text('Karen'), findsOneWidget);
    expect(find.text('Sunny'), findsOneWidget);
  });

  testWidgets('tap toggles the reveal state', (tester) async {
    setViewport(tester, const Size(390, 844));

    await tester.pumpWidget(buildSubject());
    await tester.pumpAndSettle();

    await tester.tap(find.text('Clear the clouds to reveal your roast'));
    await tester.pumpAndSettle();

    expect(find.text(roastText), findsOneWidget);
    expect(find.text('+20 XP'), findsOneWidget);
    expect(find.text('Share'), findsOneWidget);

    await tester.tap(find.byType(AdvancedRoastRevealCard));
    await tester.pumpAndSettle();

    expect(find.text('Clear the clouds to reveal your roast'), findsOneWidget);
    expect(find.text(roastText), findsNothing);
  });

  testWidgets('drag reveals the roast and wide rows show locked states',
      (tester) async {
    setViewport(tester, const Size(960, 900));

    await tester.pumpWidget(buildSubject());
    await tester.pumpAndSettle();

    await tester.drag(
      find.byType(AdvancedRoastRevealCard),
      const Offset(80, 0),
    );
    await tester.pumpAndSettle();

    expect(find.text(roastText), findsOneWidget);
    expect(find.text('Cloudy Carl'), findsOneWidget);
    expect(find.text('Drizzle'), findsOneWidget);
    expect(find.text('Thunder'), findsOneWidget);
    expect(find.text('Locked'), findsWidgets);
    expect(find.text('Early Bird'), findsOneWidget);
    expect(find.text('Roast Master'), findsOneWidget);
    expect(find.text('Streak King'), findsOneWidget);
    expect(find.text('Cloud Clearer'), findsOneWidget);
    expect(find.text('Mood Maker'), findsOneWidget);
  });
}
