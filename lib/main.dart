import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'app.dart';
import 'repositories/weather_repository.dart';
import 'services/cache_service.dart';
import 'services/dummy_weather_service.dart';
import 'services/persona_roast_service.dart';
import 'services/settings_controller.dart';
import 'features/progression/services/achievement_service.dart';
import 'features/progression/services/xp_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  final cacheService = await CacheService.create();
  final weatherService = DummyWeatherService(); // TODO: swap with real WeatherKit service
  final roastService = PersonaRoastService();
  final xpService = await XpService.create();
  final achievementService = await AchievementService.create();

  final weatherRepository = WeatherRepository(
    apiService: weatherService,
    cacheService: cacheService,
  );

  runApp(
    MultiProvider(
      providers: [
        Provider<WeatherRepository>.value(value: weatherRepository),
        Provider<PersonaRoastService>.value(value: roastService),
        ChangeNotifierProvider<XpService>.value(value: xpService),
        Provider<AchievementService>.value(value: achievementService),
        ChangeNotifierProvider<SettingsController>(
          create: (_) => SettingsController(),
        ),
      ],
      child: const GrumpySkiesApp(),
    ),
  );
}
