// Test-only dependency harness around active production screens/shell.
// Production main.dart and providers remain unchanged. No preview screens used.
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:go_router/go_router.dart';
import 'package:http/http.dart' as http;
import 'package:provider/provider.dart';

import 'package:grumpy_skies/app/daymaker_shell.dart';
import 'package:grumpy_skies/config/app_routes.dart';
import 'package:grumpy_skies/design/dm_theme.dart';
import 'package:grumpy_skies/features/forecast/forecast_screen.dart';
import 'package:grumpy_skies/features/fun/fun_zone_screen.dart';
import 'package:grumpy_skies/features/fun/meme/storage/meme_store.dart';
import 'package:grumpy_skies/features/fun/meme_generator_screen.dart';
import 'package:grumpy_skies/features/radar/radar_screen.dart';
import 'package:grumpy_skies/features/settings/about_screen.dart';
import 'package:grumpy_skies/features/settings/settings_screen.dart';
import 'package:grumpy_skies/features/splash/splash_screen.dart';
import 'package:grumpy_skies/models/weather_models.dart';
import 'package:grumpy_skies/models/temperature_unit.dart';
import 'package:grumpy_skies/repositories/in_memory_settings_repository.dart';
import 'package:grumpy_skies/repositories/settings_repository.dart';
import 'package:grumpy_skies/repositories/weather_repository.dart';
import 'package:grumpy_skies/services/open_weather_backend_client.dart';
import 'package:grumpy_skies/services/settings_controller.dart';
import 'package:grumpy_skies/services/weather_location_controller.dart';
import 'ui_preservation_fixture.dart';
import 'package:grumpy_skies/repositories/fun_repository.dart';
import 'package:grumpy_skies/repositories/local_fun_repository.dart';

/// Owns fresh, independent state for each screenshot or preview launch.
/// No SharedPreferences, ad controller, analytics, or progression service exists
/// in this composition. Meme documents and setting changes stay in memory.
class UiPreservationSession {
  UiPreservationSession({
    String initialLocation = AppRoutes.forecast,
    AppAppearance appearance = AppAppearance.light,
    bool hasWeatherLocation = true,
  }) {
    settingsRepository = InMemorySettingsRepository(
      initialSettings: UserSettings(
        appearance: appearance,
        temperatureUnit: TemperatureUnit.fahrenheit,
        notificationsEnabled: false,
        adsEnabled: false,
        xp: 0,
        level: 1,
        streakDays: 0,
      ),
    );
    settings = SettingsController(repository: settingsRepository);
    location = WeatherLocationController(
      repository: weather,
      locationService: const FixtureLocationService(),
      initialLocation:
          hasWeatherLocation ? UiPreservationFixture.location : null,
      clock: () => UiPreservationFixture.now,
    )..updateWeatherSafety(
        UiPreservationFixture.weather, UiPreservationFixture.location);
    backend = OpenWeatherBackendClient(
      httpClient: network,
      baseUrl: 'https://preview.invalid',
    );
    router = GoRouter(
      initialLocation: initialLocation,
      redirect: (_, state) => AppRoutes.retiredRedirect(state.uri),
      routes: [
        GoRoute(
          path: AppRoutes.splash,
          builder: (_, __) => const SplashScreen(),
        ),
        ShellRoute(
          builder: (_, state, child) => DaymakerShell(
            location: state.uri.path,
            child: child,
          ),
          routes: [
            GoRoute(
              path: AppRoutes.forecast,
              builder: (_, __) =>
                  ForecastScreen(clock: () => UiPreservationFixture.now),
            ),
            GoRoute(
              path: AppRoutes.radar,
              builder: (_, __) =>
                  RadarScreen(tileProvider: FixtureMemoryTiles()),
            ),
            GoRoute(
              path: AppRoutes.fun,
              builder: (_, __) => FunZoneScreen(store: memeStore),
              routes: [
                GoRoute(
                  path: 'meme',
                  builder: (_, state) => MemeGeneratorScreen(
                    store: memeStore,
                    recoverLostImages: false,
                    initialTemplateId: state.uri.queryParameters['template'],
                    initialDocumentId: state.uri.queryParameters['document'],
                  ),
                ),
              ],
            ),
            GoRoute(
              path: AppRoutes.settings,
              builder: (_, __) => const SettingsScreen(),
              routes: [
                GoRoute(
                  path: 'about',
                  builder: (_, __) => const AboutScreen(),
                ),
              ],
            ),
          ],
        ),
      ],
    );
  }

  final weather = FixtureWeatherRepository();
  final network = FixtureNoNetworkClient();
  final memeStore = MemeStore(MemoryMemeBackend());
  late final InMemorySettingsRepository settingsRepository;
  late final SettingsController settings;
  late final WeatherLocationController location;
  late final OpenWeatherBackendClient backend;
  late final GoRouter router;

  Future<void> initialize() => settings.loadSettings();

  Widget build(
          {double textScale = 1,
          Key? captureKey,
          bool reducedMotion = false}) =>
      MultiProvider(
        providers: [
          Provider<WeatherRepository>.value(value: weather),
          Provider<OpenWeatherBackendClient>.value(value: backend),
          Provider<FunRepository>.value(value: const LocalFunRepository()),
          Provider<SettingsRepository>.value(value: settingsRepository),
          ChangeNotifierProvider<SettingsController>.value(value: settings),
          ChangeNotifierProvider<WeatherLocationController>.value(
              value: location),
        ],
        child: Builder(builder: (context) {
          final appearance = context.watch<SettingsController>().appearance;
          return RepaintBoundary(
            key: captureKey,
            child: MaterialApp.router(
              debugShowCheckedModeBanner: false,
              title: 'Wingman Weather — UI preservation fixture',
              theme: DMTheme.lightTheme,
              darkTheme: DMTheme.darkTheme,
              themeMode: appearance.themeMode,
              themeAnimationDuration: Duration.zero,
              routerConfig: router,
              builder: (context, child) => MediaQuery(
                data: MediaQuery.of(context).copyWith(
                    textScaler: TextScaler.linear(textScale),
                    disableAnimations: reducedMotion,
                    accessibleNavigation: reducedMotion),
                child: child!,
              ),
            ),
          );
        }),
      );

  void dispose() {
    router.dispose();
    settings.dispose();
    location.dispose();
    network.close();
  }
}

/// Radar renders its real unavailable state; no invented radar imagery.
class FixtureNoNetworkClient extends http.BaseClient {
  int blockedRequests = 0;
  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    blockedRequests++;
    throw const OpenWeatherBackendException(
      'Radar is unavailable in the offline fixture preview.',
      code: 'preview_network_disabled',
    );
  }
}

/// Transparent tiles convey no map or coverage claim and perform no IO.
class FixtureMemoryTiles extends TileProvider {
  @override
  ImageProvider getImage(TileCoordinates coordinates, TileLayer options) =>
      MemoryImage(TileProvider.transparentImage);
}
