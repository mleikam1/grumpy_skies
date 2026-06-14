import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:grumpy_skies/design/dm_theme.dart';
import 'package:grumpy_skies/shared/widgets/daymaker_components.dart';

void main() {
  Widget buildSubject(Widget child) {
    return MaterialApp(
      theme: DMTheme.light,
      home: Scaffold(body: Center(child: child)),
    );
  }

  testWidgets('DmBottomNav exposes five semantic tabs', (tester) async {
    var selectedIndex = 0;

    await tester.pumpWidget(
      MaterialApp(
        theme: DMTheme.light,
        home: StatefulBuilder(
          builder: (context, setState) {
            return Scaffold(
              bottomNavigationBar: DmBottomNav(
                currentIndex: selectedIndex,
                onDestinationSelected: (index) {
                  setState(() => selectedIndex = index);
                },
              ),
            );
          },
        ),
      ),
    );

    expect(find.text('Forecast'), findsOneWidget);
    expect(find.text('Roasts'), findsOneWidget);
    expect(find.text('Radar'), findsOneWidget);
    expect(find.text('Fun'), findsOneWidget);
    expect(find.text('Settings'), findsOneWidget);

    await tester.tap(find.bySemanticsLabel('Radar tab'));
    await tester.pumpAndSettle();

    expect(selectedIndex, 2);
  });

  testWidgets('DmAssetImage renders gradient placeholder for missing assets',
      (tester) async {
    await tester.pumpWidget(
      buildSubject(
        const DmAssetImage(
          assetPath: 'assets/missing/not_here.png',
          width: 80,
          height: 80,
          semanticLabel: 'Missing art',
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byIcon(Icons.image_outlined), findsOneWidget);
    expect(find.bySemanticsLabel('Missing art'), findsOneWidget);
  });

  testWidgets('DmSvgIcon falls back to Flutter Icons when SVG is missing',
      (tester) async {
    await tester.pumpWidget(
      buildSubject(
        const DmSvgIcon(
          assetPath: 'assets/icons/missing.svg',
          fallbackIcon: Icons.cloud_outlined,
          semanticLabel: 'Missing svg icon',
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byIcon(Icons.cloud_outlined), findsOneWidget);
    expect(find.bySemanticsLabel('Missing svg icon'), findsOneWidget);
  });
}
