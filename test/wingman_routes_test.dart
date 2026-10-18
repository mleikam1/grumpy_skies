import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:grumpy_skies/app/daymaker_app.dart';
import 'package:grumpy_skies/app/daymaker_router.dart';
import 'package:grumpy_skies/app/daymaker_shell.dart';
import 'package:grumpy_skies/config/app_routes.dart';
import 'package:grumpy_skies/features/forecast/forecast_screen.dart';
import 'package:grumpy_skies/features/settings/settings_screen.dart';
import 'package:grumpy_skies/shared/widgets/dm_bottom_nav.dart';

import 'helpers/daymaker_test_helpers.dart';

void main() {
  for (final route in [
    '/roasts',
    '/roasts/reveal',
    '/burns',
    '/burns/reveal',
    '/roast?persona=unknown&text=old',
    '/personas',
    '/closet',
  ]) {
    testWidgets('production router retires $route without persona providers',
        (tester) async {
      tester.setDayMakerSurfaceSize(const Size(390, 844));
      final router = createDaymakerRouter(initialLocation: route);
      await tester.pumpWidget(await buildDayMakerTestProviders(
          child: DaymakerApp(routerConfig: router)));
      await tester.pumpAndSettle();
      expect(
          router.routeInformationProvider.value.uri.path, AppRoutes.forecast);
      expect(find.byType(ForecastScreen), findsOneWidget);
      expect(find.text('Roasts'), findsNothing);
      expect(
          tester.widget<DmBottomNav>(find.byType(DmBottomNav)).currentIndex, 0);
      expect(tester.takeException(), isNull);
      router.push(AppRoutes.settings);
      await tester.pumpAndSettle();
      expect(find.byType(SettingsScreenBody), findsOneWidget);
      router.pop();
      await tester.pumpAndSettle();
      expect(
          router.routeInformationProvider.value.uri.path, AppRoutes.forecast);
      await tester.pumpWidget(const SizedBox());
      router.dispose();
    });
  }

  test('surviving routes and tab indices stay aligned', () {
    expect(DaymakerShell.tabLocations, [
      AppRoutes.forecast,
      AppRoutes.planCast,
      AppRoutes.radar,
      AppRoutes.fun
    ]);
    expect(DmBottomNav.defaultItems.map((item) => item.label),
        ['Today', 'PlanCast', 'Radar', 'Fun']);
    expect(DaymakerShell.indexForLocation('/roasts/reveal'), 0);
    expect(DaymakerShell.indexForLocation('/plancast'), 1);
    expect(DaymakerShell.indexForLocation('/plancast?day=2026-10-17'), 1);
    expect(DaymakerShell.indexForLocation('/radar'), 2);
    expect(DaymakerShell.indexForLocation('/fun'), 3);
    expect(DaymakerShell.indexForLocation('/fun/meme'), 3);
    for (final route in [
      '/forecast',
      '/radar',
      '/fun/meme?document=kept',
      '/settings/about',
      '/plancast?day=2026-10-17'
    ]) {
      expect(AppRoutes.retiredRedirect(Uri.parse(route)), isNull);
    }
  });

  test('production imports and assets cannot restart retired generation', () {
    for (final file
        in Directory('lib').listSync(recursive: true).whereType<File>()) {
      if (!file.path.endsWith('.dart')) continue;
      final source = file.readAsStringSync();
      expect(
          RegExp(r'''(?:import|export)\s+['"][^'"]*(?:features/roasts|persona_roast_service|roast_repository)''')
              .hasMatch(source),
          isFalse,
          reason: file.path);
    }
    final main = File('lib/main.dart').readAsStringSync();
    expect(main, isNot(contains('Roast')));
    expect(main, contains('PlanCastLifecycle'));
    expect(main, contains('monetization.start()'));
    final pubspec = File('pubspec.yaml').readAsStringSync();
    for (final path in [
      'assets/roasts/',
      'assets/personas/',
      'assets/approved_v1/personas/',
      'assets/backgrounds/reveal/',
      'assets/backgrounds/roasts/'
    ]) {
      expect(pubspec, isNot(contains('- $path')));
    }
  });
}
