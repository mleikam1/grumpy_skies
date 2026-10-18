import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'package:grumpy_skies/config/app_routes.dart';
import 'package:grumpy_skies/design/dm_theme.dart';
import 'package:grumpy_skies/features/settings/about_screen.dart';

void main() {
  GoRouter buildRouter() {
    return GoRouter(
      initialLocation: AppRoutes.about,
      routes: [
        GoRoute(
          path: AppRoutes.about,
          builder: (context, state) => const AboutScreen(),
        ),
        GoRoute(
          path: AppRoutes.settings,
          builder: (context, state) {
            return const Scaffold(
              body: Center(child: Text('Settings route reached')),
            );
          },
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
        key: UniqueKey(),
        theme: DMTheme.light,
        routerConfig: buildRouter(),
      ),
    );
    await tester.pumpAndSettle();
  }

  Future<void> scrollUntilTextVisible(
    WidgetTester tester,
    String text,
  ) async {
    final finder = find.text(text);
    for (var attempts = 0; attempts < 8; attempts++) {
      if (finder.evaluate().isNotEmpty) {
        await tester.ensureVisible(finder.first);
        await tester.pumpAndSettle();
        return;
      }

      await tester.drag(
        find.descendant(
          of: find.byType(AboutScreen),
          matching: find.byType(ListView),
        ),
        const Offset(0, -280),
      );
      await tester.pumpAndSettle();
    }

    expect(finder, findsWidgets);
  }

  testWidgets('About screen renders Wingman Weather content across breakpoints',
      (tester) async {
    for (final size in const [
      Size(390, 844),
      Size(820, 1180),
      Size(1280, 900),
    ]) {
      await pumpAboutScreen(tester, size: size);

      expect(tester.takeException(), isNull);
      expect(find.text('About Wingman Weather'), findsOneWidget);
      expect(find.text('Wingman Weather'), findsOneWidget);
      expect(find.text('We’ve got your back, in any weather.'), findsWidgets);
      await scrollUntilTextVisible(tester, 'Live Data Sources');

      expect(find.text('Live Data Sources'), findsOneWidget);
      expect(find.text('OpenWeather'), findsOneWidget);
      expect(find.text('Weather data © OpenWeather'), findsOneWidget);
      expect(find.text('One Call API 4.0'), findsOneWidget);
      expect(find.text('US Precipitation Map Forecast'), findsOneWidget);

      await scrollUntilTextVisible(tester, 'Version 0.1.0');

      expect(find.text('Version 0.1.0'), findsOneWidget);

      await scrollUntilTextVisible(tester, 'Privacy information');

      expect(find.text('Privacy information'), findsOneWidget);
      expect(find.text('Terms of Use'), findsOneWidget);
    }

    tester.view.resetPhysicalSize();
    tester.view.resetDevicePixelRatio();
  });

  testWidgets('About back button returns to Settings', (tester) async {
    await pumpAboutScreen(tester, size: const Size(390, 844));

    expect(find.text('About Wingman Weather'), findsOneWidget);

    await tester.tap(find.byIcon(Icons.arrow_back_rounded));
    await tester.pumpAndSettle();

    expect(find.text('Settings route reached'), findsOneWidget);

    tester.view.resetPhysicalSize();
    tester.view.resetDevicePixelRatio();
  });
}
