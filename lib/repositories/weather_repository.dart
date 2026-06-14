import '../models/weather_models.dart';

abstract class WeatherRepository {
  const WeatherRepository();

  Future<WeatherSnapshot> getSnapshot({
    required double latitude,
    required double longitude,
    bool forceRefresh = false,
  });

  Future<List<RadarAlert>> getRadarAlerts({
    required double latitude,
    required double longitude,
  });

  Future<WeatherBundle> getWeather({
    required double latitude,
    required double longitude,
    bool forceRefresh = false,
  }) async {
    final snapshot = await getSnapshot(
      latitude: latitude,
      longitude: longitude,
      forceRefresh: forceRefresh,
    );

    return WeatherBundle.fromSnapshot(snapshot);
  }
}
