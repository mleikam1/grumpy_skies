import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import 'package:grumpy_skies/app.dart';
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
import 'package:grumpy_skies/models/weather_models.dart';
import 'package:grumpy_skies/repositories/fake_roast_repository.dart';
import 'package:grumpy_skies/repositories/fake_weather_repository.dart';
import 'package:grumpy_skies/repositories/in_memory_settings_repository.dart';
import 'package:grumpy_skies/repositories/roast_repository.dart';
import 'package:grumpy_skies/repositories/settings_repository.dart';
import 'package:grumpy_skies/repositories/weather_repository.dart';
import 'package:grumpy_skies/services/persona_roast_service.dart';
import 'package:grumpy_skies/services/settings_controller.dart';
import 'package:grumpy_skies/services/weather_location_controller.dart';

class DayMakerTestViewport {
  const DayMakerTestViewport({
    required this.label,
    required this.size,
  });

  final String label;
  final Size size;

  @override
  String toString() => label;
}

const dayMakerPhoneViewport = DayMakerTestViewport(
  label: '390x844 phone',
  size: Size(390, 844),
);

const dayMakerTabletViewport = DayMakerTestViewport(
  label: '768x1024 tablet',
  size: Size(768, 1024),
);

const dayMakerDesktopViewport = DayMakerTestViewport(
  label: '1440x900 desktop',
  size: Size(1440, 900),
);

const dayMakerTestViewports = <DayMakerTestViewport>[
  dayMakerPhoneViewport,
  dayMakerTabletViewport,
  dayMakerDesktopViewport,
];

extension DayMakerWidgetTester on WidgetTester {
  void setDayMakerSurfaceSize(Size size) {
    view.physicalSize = size;
    view.devicePixelRatio = 1;
    addTearDown(() {
      view.resetPhysicalSize();
      view.resetDevicePixelRatio();
    });
  }

  Future<void> pumpDayMakerApp({
    DayMakerTestViewport viewport = dayMakerPhoneViewport,
  }) async {
    setDayMakerSurfaceSize(viewport.size);

    await pumpWidget(
      await buildDayMakerTestProviders(
        child: const GrumpySkiesApp(),
      ),
    );
    await pumpAndSettle();
  }

  Future<void> pumpDayMakerRoute({
    required String initialLocation,
    DayMakerTestViewport viewport = dayMakerPhoneViewport,
    double textScale = 1,
  }) async {
    setDayMakerSurfaceSize(viewport.size);

    final router = buildDayMakerTestRouter(initialLocation: initialLocation);

    await pumpWidget(
      await buildDayMakerTestProviders(
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

Future<Widget> buildDayMakerTestProviders({
  required Widget child,
  WeatherLocation? initialWeatherLocation,
}) async {
  final settingsRepository = InMemorySettingsRepository();
  final settingsController = SettingsController(repository: settingsRepository);
  await settingsController.loadSettings();
  const weatherRepository = FakeWeatherRepository();
  final locationController = WeatherLocationController(
    repository: weatherRepository,
    initialLocation: initialWeatherLocation ?? buildTestWeatherLocation(),
  );

  return MultiProvider(
    providers: [
      Provider<WeatherRepository>.value(value: weatherRepository),
      Provider<RoastRepository>.value(value: const FakeRoastRepository()),
      Provider<SettingsRepository>.value(value: settingsRepository),
      Provider<PersonaRoastService>.value(value: PersonaRoastService()),
      ChangeNotifierProvider<WeatherLocationController>.value(
        value: locationController,
      ),
      ChangeNotifierProvider<SettingsController>.value(
        value: settingsController,
      ),
    ],
    child: child,
  );
}

WeatherLocation buildTestWeatherLocation() {
  return WeatherLocation(
    name: 'Demo City',
    country: 'US',
    latitude: 41.8781,
    longitude: -87.6298,
    source: WeatherLocationSource.manual,
    updatedAt: DateTime(2026, 6, 14, 9),
  );
}

GoRouter buildDayMakerTestRouter({required String initialLocation}) {
  return GoRouter(
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
                builder: (context, state) => const AdvancedRoastRevealScreen(),
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
}

void expectNoFlutterExceptions(WidgetTester tester) {
  final exception = tester.takeException();
  expect(exception, isNull);
}
