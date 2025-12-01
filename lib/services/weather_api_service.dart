import '../models/weather_models.dart';

/// Abstraction for any weather provider (WeatherKit, AccuWeather, Open-Meteo, etc.)
abstract class WeatherApiService {
  Future<WeatherBundle> fetchWeather({
    required double latitude,
    required double longitude,
  });
}
