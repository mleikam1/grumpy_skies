import 'dart:async';
import 'package:flutter/material.dart';
import 'monetization/ad_config.dart';
import 'monetization/monetization_controller.dart';
import 'package:flutter_web_plugins/url_strategy.dart';
import 'package:provider/provider.dart';

import 'app.dart';
import 'features/plancast/plancast_controller.dart';
import 'features/plancast/widgets/plancast_lifecycle.dart';
import 'app/daymaker_router.dart';
import 'repositories/open_weather_repository.dart';
import 'repositories/settings_repository.dart';
import 'repositories/fun_repository.dart';
import 'repositories/local_fun_repository.dart';
import 'repositories/shared_preferences_settings_repository.dart';
import 'repositories/weather_repository.dart';
import 'services/cache_service.dart';
import 'services/open_weather_backend_client.dart';
import 'services/settings_controller.dart';
import 'services/weather_location_controller.dart';
import 'features/progression/services/achievement_service.dart';
import 'features/progression/services/xp_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  usePathUrlStrategy();

  final weatherClient = OpenWeatherBackendClient();
  final weatherCache = await CacheService.create();
  final weatherRepository = OpenWeatherRepository(
    client: weatherClient,
    cacheService: weatherCache,
  );
  final settingsRepository = await SharedPreferencesSettingsRepository.create();
  final settingsController = SettingsController(repository: settingsRepository);
  await settingsController.loadSettings();
  final locationController = await WeatherLocationController.create(
    repository: weatherRepository,
  );
  final xpService = await XpService.create();
  final achievementService = await AchievementService.create();
  void evaluateAchievements() => achievementService.evaluate(
        xpService.state,
        severeWeather:
            locationController.safetyStatus == WeatherSafetyStatus.activeAlert,
      );
  evaluateAchievements();
  xpService.addListener(evaluateAchievements);
  locationController.addListener(evaluateAchievements);

  final planCast = PlanCastController(weatherRepository: weatherRepository);

  final monetization = MonetizationController(
    config: AdConfig.fromEnvironment(),
    weather: locationController,
  );

  // Gate-only router observation closes async presentation races for browser
  // history/deep links. Presentation remains exclusive to the explicit Done API.
  daymakerRouter.routerDelegate.addListener(() {
    monetization.setRoute(
        daymakerRouter.routerDelegate.currentConfiguration.uri.path,
        deferNotification: true);
  });

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider<PlanCastController>.value(value: planCast),
        ChangeNotifierProvider<MonetizationController>.value(
            value: monetization),
        Provider<OpenWeatherBackendClient>.value(value: weatherClient),
        Provider<WeatherRepository>.value(value: weatherRepository),
        Provider<CacheService>.value(value: weatherCache),
        Provider<FunRepository>.value(value: const LocalFunRepository()),
        Provider<SettingsRepository>.value(value: settingsRepository),
        ChangeNotifierProvider<WeatherLocationController>.value(
          value: locationController,
        ),
        ChangeNotifierProvider<XpService>.value(value: xpService),
        Provider<AchievementService>.value(value: achievementService),
        ChangeNotifierProvider<SettingsController>.value(
          value: settingsController,
        ),
      ],
      child: PlanCastLifecycle(
        controller: planCast,
        router: daymakerRouter,
        child: const GrumpySkiesApp(),
      ),
    ),
  );
  WidgetsBinding.instance.addPostFrameCallback((_) {
    unawaited(monetization.start());
  });
}
