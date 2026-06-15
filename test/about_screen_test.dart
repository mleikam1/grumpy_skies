import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'package:grumpy_skies/app/daymaker_shell.dart';
import 'package:grumpy_skies/config/app_routes.dart';
import 'package:grumpy_skies/design/dm_theme.dart';
import 'package:grumpy_skies/features/settings/about_screen.dart';

void main() {
  GoRouter buildRouter() {
    return GoRouter(
      initialLocation: AppRoutes.about,
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
              path: AppRoutes.settings,
              builder: (context, state) {
                return const Scaffold(
                  body: Center(child: Text('Settings route reached')),
                );
              },
              routes: [
                GoRoute(
                  path: 'about',
                  builder: (context, state) => const AboutScreen(),
                ),
              ],
            ),
          ],
        ),
      ],
    );
  }

  Future<void> pumpAboutScreen(
    WidgetTester tester, {
    required Size size,
  }) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;

    await tester.pumpWidget(
      MaterialApp.router(
        theme: DMTheme.light,
        routerConfig: buildRouter(),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('About screen renders DayMaker content across breakpoints',
      (tester) async {
    for (final size in const [
      Size(390, 844),
      Size(820, 1180),
      Size(1280, 900),
    ]) {
      await pumpAboutScreen(tester, size: size);

      expect(tester.takeException(), isNull);
      expect(find.text('About DayMaker'), findsOneWidget);
      expect(find.text('DayMaker'), findsOneWidget);
      expect(find.text('Weather with personality.'), findsWidgets);
      expect(
        find.text(
          'A personality-driven weather app that brightens your forecast '
          'instead of politely whispering it.',
        ),
        findsOneWidget,
      );
      expect(find.text('Planned Data Sources'), findsOneWidget);
      expect(find.text('Apple WeatherKit'), findsOneWidget);
      expect(find.text('AccuWeather'), findsOneWidget);
      expect(find.text('RainViewer'), findsOneWidget);
      expect(find.text('Version 0.1.0'), findsOneWidget);
      expect(find.text('Privacy Policy'), findsOneWidget);
      expect(find.text('Terms of Use'), findsOneWidget);
    }

    tester.view.resetPhysicalSize();
    tester.view.resetDevicePixelRatio();
  });

  testWidgets('About back button returns to Settings inside the shell',
      (tester) async {
    await pumpAboutScreen(tester, size: const Size(390, 844));

    expect(find.text('Settings'), findsOneWidget);
    expect(find.text('About DayMaker'), findsOneWidget);

    await tester.tap(find.byIcon(Icons.arrow_back_rounded));
    await tester.pumpAndSettle();

    expect(find.text('Settings route reached'), findsOneWidget);

    tester.view.resetPhysicalSize();
    tester.view.resetDevicePixelRatio();
  });
}
