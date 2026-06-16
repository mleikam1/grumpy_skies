import 'package:flutter/material.dart';
import 'package:flutter_web_plugins/url_strategy.dart';
import 'package:provider/provider.dart';

import 'app.dart';
import 'repositories/fake_roast_repository.dart';
import 'repositories/fake_weather_repository.dart';
import 'repositories/roast_repository.dart';
import 'repositories/settings_repository.dart';
import 'repositories/shared_preferences_settings_repository.dart';
import 'repositories/weather_repository.dart';
import 'services/persona_roast_service.dart';
import 'services/settings_controller.dart';
import 'features/progression/services/achievement_service.dart';
import 'features/progression/services/xp_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  usePathUrlStrategy();

  // TODO(integration): Swap these fake repositories for provider-backed
  // implementations here. Keep WeatherKit, AccuWeather, and any roast-service
  // credentials on a backend or secure platform layer, never in app source.
  const weatherRepository = FakeWeatherRepository();
  const roastRepository = FakeRoastRepository();
  final settingsRepository = await SharedPreferencesSettingsRepository.create();
  final settingsController = SettingsController(repository: settingsRepository);
  await settingsController.loadSettings();
  final roastService = PersonaRoastService();
  final xpService = await XpService.create();
  final achievementService = await AchievementService.create();

  runApp(
    MultiProvider(
      providers: [
        Provider<WeatherRepository>.value(value: weatherRepository),
        Provider<RoastRepository>.value(value: roastRepository),
        Provider<SettingsRepository>.value(value: settingsRepository),
        Provider<PersonaRoastService>.value(value: roastService),
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
