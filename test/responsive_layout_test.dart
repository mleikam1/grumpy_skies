import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import 'package:grumpy_skies/app/daymaker_shell.dart';
import 'package:grumpy_skies/config/app_routes.dart';
import 'package:grumpy_skies/design/dm_theme.dart';
import 'package:grumpy_skies/features/forecast/forecast_screen.dart';
import 'package:grumpy_skies/features/fun/fun_zone_screen.dart';
import 'package:grumpy_skies/features/fun/meme_generator_screen.dart';
import 'package:grumpy_skies/features/radar/radar_screen.dart';
import 'package:grumpy_skies/features/roasts/advanced_roast_reveal_screen.dart';
import 'package:grumpy_skies/features/roasts/roasts_screen.dart';
import 'package:grumpy_skies/features/settings/about_screen.dart';
import 'package:grumpy_skies/features/settings/settings_screen.dart';
import 'package:grumpy_skies/features/splash/splash_screen.dart';
import 'package:grumpy_skies/repositories/fake_roast_repository.dart';
import 'package:grumpy_skies/repositories/fake_weather_repository.dart';
import 'package:grumpy_skies/repositories/in_memory_settings_repository.dart';
import 'package:grumpy_skies/repositories/roast_repository.dart';
import 'package:grumpy_skies/repositories/settings_repository.dart';
import 'package:grumpy_skies/repositories/weather_repository.dart';
import 'package:grumpy_skies/services/persona_roast_service.dart';
import 'package:grumpy_skies/services/settings_controller.dart';

void main() {
  const targetSizes = <String, Size>{
    'small phone': Size(360, 740),
    'reference phone': Size(390, 844),
    'large phone': Size(430, 932),
    'tablet portrait': Size(768, 1024),
    'tablet landscape': Size(1024, 768),
    'desktop web': Size(1440, 900),
  };

  const routes = <String, String>{
    'splash': AppRoutes.splash,
    'forecast': AppRoutes.forecast,
    'roasts': AppRoutes.roasts,
    'roast reveal': AppRoutes.roastReveal,
    'radar': AppRoutes.radar,
    'fun': AppRoutes.fun,
    'meme generator': AppRoutes.memeGenerator,
    'settings': AppRoutes.settings,
    'about': AppRoutes.about,
  };

  for (final sizeEntry in targetSizes.entries) {
    for (final routeEntry in routes.entries) {
      testWidgets(
        '${routeEntry.key} renders without layout exceptions at '
        '${sizeEntry.key}',
        (tester) async {
          await tester.pumpDayMakerRoute(
            size: sizeEntry.value,
            initialLocation: routeEntry.value,
          );

          expectNoFlutterExceptions(tester);
        },
      );
    }
  }

  for (final routeEntry in routes.entries) {
    testWidgets(
      '${routeEntry.key} tolerates large text on a small phone',
      (tester) async {
        await tester.pumpDayMakerRoute(
          size: targetSizes['small phone']!,
          initialLocation: routeEntry.value,
          textScale: 1.35,
        );

        expectNoFlutterExceptions(tester);
      },
    );
  }
}

extension _DayMakerResponsivePump on WidgetTester {
  Future<void> pumpDayMakerRoute({
    required Size size,
    required String initialLocation,
    double textScale = 1,
  }) async {
    view.physicalSize = size;
    view.devicePixelRatio = 1;
    addTearDown(() {
      view.resetPhysicalSize();
      view.resetDevicePixelRatio();
    });

    final settingsRepository = InMemorySettingsRepository();
    final settingsController = SettingsController(
      repository: settingsRepository,
    );
    await settingsController.loadSettings();

    final router = GoRouter(
      initialLocation: initialLocation,
      routes: [
        GoRoute(
          path: AppRoutes.splash,
          builder: (context, state) => const SplashScreen(),
        ),
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
              path: AppRoutes.roasts,
              builder: (context, state) => const RoastsScreen(),
              routes: [
                GoRoute(
                  path: 'reveal',
                  builder: (context, state) =>
                      const AdvancedRoastRevealScreen(),
                ),
              ],
            ),
            GoRoute(
              path: AppRoutes.radar,
              builder: (context, state) => const RadarScreen(),
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
            GoRoute(
              path: AppRoutes.settings,
              builder: (context, state) => const SettingsScreen(),
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

    await pumpWidget(
      MultiProvider(
        providers: [
          Provider<WeatherRepository>.value(
            value: const FakeWeatherRepository(),
          ),
          Provider<RoastRepository>.value(value: const FakeRoastRepository()),
          Provider<SettingsRepository>.value(value: settingsRepository),
          Provider<PersonaRoastService>.value(value: PersonaRoastService()),
          ChangeNotifierProvider<SettingsController>.value(
            value: settingsController,
          ),
        ],
        child: MaterialApp.router(
          theme: DMTheme.light,
          routerConfig: router,
          builder: (context, child) {
            final mediaQuery = MediaQuery.of(context);
            return MediaQuery(
              data: mediaQuery.copyWith(
                textScaler: TextScaler.linear(textScale),
              ),
              child: child!,
            );
          },
        ),
      ),
    );
    await pumpAndSettle();
  }
}

void expectNoFlutterExceptions(WidgetTester tester) {
  final exception = tester.takeException();
  expect(exception, isNull);
}
