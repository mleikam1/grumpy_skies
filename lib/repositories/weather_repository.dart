import '../models/weather_models.dart';
import '../services/cache_service.dart';
import '../services/weather_api_service.dart';

class WeatherRepository {
  final WeatherApiService apiService;
  final CacheService cacheService;
  final Duration cacheTtl;

  WeatherRepository({
    required this.apiService,
    required this.cacheService,
    this.cacheTtl = const Duration(minutes: 15),
  });

  Future<WeatherBundle> getWeather({
    required double latitude,
    required double longitude,
    bool forceRefresh = false,
  }) async {
    final cached = cacheService.getWeatherBundle(latitude, longitude);
    final lastTs = cacheService.getLastFetchTime(latitude, longitude);

    final now = DateTime.now();
    final isFresh =
        lastTs != null && now.difference(lastTs) <= cacheTtl;

    if (!forceRefresh && cached != null && isFresh) {
      return cached;
    }

    final fresh = await apiService.fetchWeather(
      latitude: latitude,
      longitude: longitude,
    );

    await cacheService.saveWeatherBundle(
      lat: latitude,
      lon: longitude,
      bundle: fresh,
    );

    return fresh;
  }
}
