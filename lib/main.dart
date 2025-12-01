import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'app.dart';
import 'repositories/weather_repository.dart';
import 'services/cache_service.dart';
import 'services/dummy_weather_service.dart';
import 'services/persona_roast_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  final cacheService = await CacheService.create();
  final weatherService = DummyWeatherService(); // TODO: swap with real WeatherKit service
  final roastService = PersonaRoastService();

  final weatherRepository = WeatherRepository(
    apiService: weatherService,
    cacheService: cacheService,
  );

  runApp(
    MultiProvider(
      providers: [
        Provider<WeatherRepository>.value(value: weatherRepository),
        Provider<PersonaRoastService>.value(value: roastService),
      ],
      child: const GrumpySkiesApp(),
    ),
  );
}
