import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'package:grumpy_skies/app/daymaker_shell.dart';
import 'package:grumpy_skies/config/app_routes.dart';
import 'package:grumpy_skies/design/dm_theme.dart';
import 'package:grumpy_skies/features/fun/fun_zone_screen.dart';
import 'package:grumpy_skies/features/fun/meme_generator_screen.dart';
import 'package:grumpy_skies/features/fun/widgets/meme_canvas.dart';
import 'package:grumpy_skies/features/forecast/forecast_screen.dart';

void main() {
  Widget buildSubject() {
    final router = GoRouter(
      initialLocation: AppRoutes.memeGenerator,
      routes: [
        ShellRoute(
          builder: (context, state, child) {
            return DaymakerShell(
              location: state.uri.path,
              child: child,
            );
          },
          routes: [
            GoRoute(
              path: AppRoutes.forecast,
              builder: (context, state) => const ForecastScreen(),
            ),
            GoRoute(
              path: AppRoutes.fun,
              builder: (context, state) => const FunZoneScreen(),
              routes: [
                GoRoute(
                  path: 'meme',
                  builder: (context, state) => const MemeGeneratorScreen(),
                ),
              ],
            ),
          ],
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

  testWidgets('renders compact meme generator with bottom nav', (tester) async {
    setSurfaceSize(tester, const Size(390, 844));

    await tester.pumpWidget(buildSubject());
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.text('DayMaker'), findsWidgets);
    expect(find.text('Meme Generator'), findsOneWidget);
    expect(find.text('Pro'), findsOneWidget);
    expect(find.text('Epic'), findsOneWidget);
    expect(find.text('Cute'), findsOneWidget);
    expect(find.text('Sarcastic'), findsOneWidget);
    expect(find.text('Cozy'), findsOneWidget);
    expect(find.text('Retro'), findsOneWidget);
    expect(find.text('Change Background'), findsOneWidget);
    expect(find.text('Use Current Roast'), findsOneWidget);
    expect(find.text('Randomize Text'), findsOneWidget);
    expect(find.text('Export & Share'), findsOneWidget);
    expect(find.text('Fun'), findsOneWidget);
  });

  testWidgets('text fields update meme preview live', (tester) async {
    setSurfaceSize(tester, const Size(390, 844));

    await tester.pumpWidget(buildSubject());
    await tester.pumpAndSettle();

    await tester.ensureVisible(find.text('Top Text'));
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

    await tester.scrollUntilVisible(
      find.text('Use Current Roast'),
      280,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();
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
    await tester.scrollUntilVisible(
      find.text('Export & Share'),
      280,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Export & Share'));
    await tester.pump();

    expect(
      find.text('Export & Share will capture this canvas soon.'),
      findsOneWidget,
    );
  });
}
