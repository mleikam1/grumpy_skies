import 'package:flutter/material.dart';
import 'package:flutter_web_plugins/url_strategy.dart';
import 'package:provider/provider.dart';

import 'app.dart';
import 'repositories/open_weather_repository.dart';
import 'repositories/fake_roast_repository.dart';
import 'repositories/roast_repository.dart';
import 'repositories/settings_repository.dart';
import 'repositories/shared_preferences_settings_repository.dart';
import 'repositories/weather_repository.dart';
import 'services/cache_service.dart';
import 'services/open_weather_backend_client.dart';
import 'services/persona_roast_service.dart';
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
  const roastRepository = FakeRoastRepository();
  final settingsRepository = await SharedPreferencesSettingsRepository.create();
  final settingsController = SettingsController(repository: settingsRepository);
  await settingsController.loadSettings();
  final locationController = await WeatherLocationController.create(
    repository: weatherRepository,
  );
  final roastService = PersonaRoastService();
  final xpService = await XpService.create();
  final achievementService = await AchievementService.create();

  runApp(
    MultiProvider(
      providers: [
        Provider<OpenWeatherBackendClient>.value(value: weatherClient),
        Provider<WeatherRepository>.value(value: weatherRepository),
        Provider<RoastRepository>.value(value: roastRepository),
        Provider<SettingsRepository>.value(value: settingsRepository),
        Provider<PersonaRoastService>.value(value: roastService),
        ChangeNotifierProvider<WeatherLocationController>.value(
          value: locationController,
        ),
        ChangeNotifierProvider<XpService>.value(value: xpService),
        Provider<AchievementService>.value(value: achievementService),
        ChangeNotifierProvider<SettingsController>.value(
          value: settingsController,
        ),
      ],
      child: const GrumpySkiesApp(),
    ),
  );
}
