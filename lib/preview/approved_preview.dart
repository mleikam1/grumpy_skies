// Explicit opt-in preview composition. Production main.dart never imports this.
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:go_router/go_router.dart';
import 'package:http/http.dart' as http;
import 'package:provider/provider.dart';

import '../app/daymaker_shell.dart';
import '../config/app_routes.dart';
import '../design/dm_theme.dart';
import '../features/forecast/forecast_screen.dart';
import '../features/plancast/screens/plancast_screen.dart';
import '../features/fun/fun_zone_screen.dart';
import '../features/fun/meme/storage/meme_store.dart';
import '../features/fun/meme_generator_screen.dart';
import '../features/radar/radar_screen.dart';
import '../features/settings/about_screen.dart';
import '../features/settings/settings_screen.dart';
import '../features/splash/splash_screen.dart';
import '../models/weather_models.dart';
import '../models/temperature_unit.dart';
import '../repositories/in_memory_settings_repository.dart';
import '../repositories/settings_repository.dart';
import '../repositories/fun_repository.dart';
import '../repositories/local_fun_repository.dart';
import '../repositories/weather_repository.dart';
import '../services/open_weather_backend_client.dart';
import '../services/settings_controller.dart';
import '../services/weather_location_controller.dart';
import 'approved_fixture.dart';

/// Owns fresh, independent state for each screenshot or preview launch.
/// No SharedPreferences, ad controller, analytics, or progression service exists
/// in this composition. Meme documents and setting changes stay in memory.
class ApprovedPreviewSession {
  ApprovedPreviewSession({
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
      locationService: const PreviewLocationService(),
      initialLocation: hasWeatherLocation ? ApprovedFixture.location : null,
      clock: () => ApprovedFixture.now,
    )..updateWeatherSafety(ApprovedFixture.weather, ApprovedFixture.location);
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
                  ForecastScreen(clock: () => ApprovedFixture.now),
            ),
            GoRoute(
              path: AppRoutes.planCast,
              builder: (_, state) => PlanCastScreen(
                eventId: state.uri.queryParameters['event'],
                day: DateTime.tryParse(state.uri.queryParameters['day'] ?? ''),
              ),
            ),
            GoRoute(
              path: AppRoutes.radar,
              builder: (_, __) =>
                  RadarScreen(tileProvider: PreviewMemoryTiles()),
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

  final weather = ApprovedWeatherRepository();
  final network = PreviewNoNetworkClient();
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
          GoRouter? routerOverride,
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
              title: 'Wingman Weather — synthetic fixture preview',
              theme: DMTheme.lightTheme,
              darkTheme: DMTheme.darkTheme,
              themeMode: appearance.themeMode,
              themeAnimationDuration: Duration.zero,
              routerConfig: routerOverride ?? router,
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
class PreviewNoNetworkClient extends http.BaseClient {
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
class PreviewMemoryTiles extends TileProvider {
  @override
  ImageProvider getImage(TileCoordinates coordinates, TileLayer options) =>
      MemoryImage(TileProvider.transparentImage);
}
