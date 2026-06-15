import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'package:grumpy_skies/config/app_routes.dart';
import 'package:grumpy_skies/design/dm_theme.dart';
import 'package:grumpy_skies/features/fun/fun_zone_screen.dart';

void main() {
  Widget buildSubject() {
    final router = GoRouter(
      initialLocation: AppRoutes.fun,
      routes: [
        GoRoute(
          path: AppRoutes.fun,
          builder: (context, state) => const FunZoneScreen(),
        ),
        GoRoute(
          path: AppRoutes.memeGenerator,
          builder: (context, state) => const Scaffold(
            body: Center(child: Text('Meme route reached')),
          ),
        ),
      ],
    );

    return MaterialApp.router(
      theme: DMTheme.light,
      routerConfig: router,
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

  testWidgets('FunZoneScreen renders the compact DayMaker fun stack',
      (tester) async {
    setSurfaceSize(tester, const Size(390, 844));

    await tester.pumpWidget(buildSubject());
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.text('Fun Zone'), findsOneWidget);
    expect(find.text('Play. Predict. Laugh. Repeat.'), findsOneWidget);
    expect(find.text('Weather Fortune Cookie'), findsOneWidget);
    expect(find.text('Crack a cookie. Get a weather reveal.'), findsOneWidget);
    expect(find.text('Crack One'), findsOneWidget);
    expect(find.text('Daily Weather Poll'), findsOneWidget);
    expect(find.text('Sunny 56%'), findsOneWidget);
    expect(find.text('Cloudy 28%'), findsOneWidget);
    expect(find.text('Rainy 16%'), findsOneWidget);
    expect(find.text('1,842 votes'), findsOneWidget);
  });

  testWidgets('FunZoneScreen buttons reveal playful results', (tester) async {
    setSurfaceSize(tester, const Size(390, 844));

    await tester.pumpWidget(buildSubject());
    await tester.pumpAndSettle();

    await tester.tap(find.text('Crack One'));
    await tester.pumpAndSettle();
    expect(
      find.text('Your umbrella has main-character energy today.'),
      findsOneWidget,
    );

    await tester.ensureVisible(find.text('Vote Now'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Vote Now'));
    await tester.pump();
    expect(find.text('Vote counted for today.'), findsOneWidget);

    await tester.ensureVisible(find.text('Spin Now'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Spin Now'));
    await tester.pumpAndSettle();
    expect(find.text('74% chance of accidental sparkle.'), findsOneWidget);

    await tester.ensureVisible(find.text('Find Out'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Find Out'));
    await tester.pumpAndSettle();
    expect(find.text('Sunbeam Instigator'), findsOneWidget);
  });

  testWidgets('FunZoneScreen uses a two-column grid at medium width',
      (tester) async {
    setSurfaceSize(tester, const Size(800, 900));

    await tester.pumpWidget(buildSubject());
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);

    final pollOffset = tester.getTopLeft(find.text('Daily Weather Poll'));
    final predictorOffset = tester.getTopLeft(find.text('Crazy Day Predictor'));

    expect((pollOffset.dy - predictorOffset.dy).abs(), lessThan(4));
    expect((pollOffset.dx - predictorOffset.dx).abs(), greaterThan(300));
  });

  testWidgets('FunZoneScreen renders expanded masonry and navigates to memes',
      (tester) async {
    setSurfaceSize(tester, const Size(1200, 900));

    await tester.pumpWidget(buildSubject());
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.text('Weather Menace'), findsOneWidget);
    expect(find.text('Meme Generator'), findsOneWidget);

    await tester.ensureVisible(find.text('Make a Meme'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Make a Meme'));
    await tester.pumpAndSettle();

    expect(find.text('Meme route reached'), findsOneWidget);
  });
}
