import '../models/weather_models.dart';

/// Abstraction for any weather provider.
///
/// TODO(integration): Implement WeatherKit and AccuWeather adapters behind this
/// contract, preferably through a backend/proxy so API keys and signed provider
/// requests do not ship in the Flutter app.
abstract class WeatherApiService {
  Future<WeatherBundle> fetchWeather({
    required double latitude,
    required double longitude,
  });
}
